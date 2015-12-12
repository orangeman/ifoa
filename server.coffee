fs = require "fs"
http = require "http"
shoe = require "shoe"
level = require "level"
sockjs = require "sockjs"
es = require "event-stream"
ms = require "merge-stream"
through = require "through2"
JSONStream = require "JSONStream"
hyperstream = require "hyperstream"
ecstatic = require("ecstatic")(__dirname + "/public", cache: "no-cache")
html = require("fs").readFileSync "ride.html"
distance = require "./dist"
render = require "./ride"

server = http.createServer (req, response) ->
  if req.url == "/"
    response.writeHead 200, "Content-Type": "text/html"
    fs.createReadStream __dirname + "/index.html"
    .pipe response
  else if m = req.url.match /(\/.*\/.*)/
    console.log "\nGET" + req.url + "  " +  req.connection.remoteAddress + "   " + decodeURI m[1]
    response.writeHead 200, "Content-Type": "text/html"
    fs.createReadStream __dirname + "/index.html"
    .pipe hyperstream
      '#rides': cache(decodeURI m[1]).pipe through.obj (r, enc, next) ->
        ride = r.value
        return next() if ride.del
        hyperstream render ride
        .pipe es.map (h, next) =>
          this.push h; next()
        .on "end", () -> next()
        .end html
    .pipe response
  else if q = req.url.match /q=(.*)/
    suggest(decodeURI(q[1])).pipe response
  else
    ecstatic req, response

socket = {}

shoe (sockjs) ->
  session = sockjs._session.connection.pathname
  query = null
  sockjs.on "data", (url) ->
    console.log "OPEN " + url
    if query
      remove query
    m = decodeURI(url).match /(\/(.*)\/(.*))#(\d*)/
    return unless m
    query = route: m[1], from: m[2], to: m[3], time: new Date().getTime()
    if query.from.length > 0 && query.to.length > 0
      insert query, sockjs, m[4]
  sockjs.on "close", () ->
    console.log "\nCLOSE " + session
    remove query if query
.installHandlers server, prefix: "/sockjs"

server.listen process.env.PORT || 5000


rides = level "./data/rides", valueEncoding: "json"

insert = (query, sockjs, after) ->
  console.log "INSERT " + query.time + query.route
  rides.put query.time + query.route, query
  socket[query.time + query.route] = sockjs
  cache query.route
  .pipe notifyAbout query, after, (latest) ->
    search latest + 1
    .pipe match query
    .pipe notifyAbout query, 0
    .pipe(JSONStream.stringify(false), end: false)
    .pipe sockjs, end: false
  .pipe(JSONStream.stringify(false), end: false)
  .pipe sockjs, end: false
  #sockjs.write "\n{ \"time\": \"1449506492402\", \"from\": \"debug\", \"to\": \"debug\", \"det\": 78, \"session\": \"/sockjs/874/lr2x3pcr/websocket\" }\n"

remove = (query) ->
  console.log "REMOVE " + query.time + "/" + query.route
  query.del = true
  rides.put new Date().getTime() + query.route, query
  cache query.route
  .pipe match query
  .pipe notifyAbout query, 9999999999999999
  .on "end", () ->
    console.log "removed.\n"

cache = (route) ->
  latest = 0
  console.log " :: cache " + route
  rides.createReadStream(gt: route + ">", lt: route+">~")

search = (since) ->
  console.log " :: search  since " + since
  rides.createReadStream(gt: since + "/", lt: "a", reverse: true)

DET = 300
match = (q) ->
  console.log "   match " + q.route
  dist = distance()
  det = (driver, passenger, done) ->
    dist driver.from, passenger.from, (pickup) ->
      dist passenger.from, passenger.to, (join) ->
        dist passenger.to, driver.to, (dropoff) ->
          dist driver.from, driver.to, (alone) ->
            done pickup, join, dropoff, alone
  visited = {}
  latest = 0
  through.obj (ride, enc, next) ->
    if ride.key.match /#latest/
      latest = ride.value
      return next()
    r = ride.value
    latest = r.time if r.time > latest
    if visited[r.time]
      console.log "     visited " + r.time
      visited[r.time] = true
      return next()
    if r.del || q.del
      this.push ride
      if ride.key.match /#del/
        return next()
      visited[r.time] = true
      if r.del
        console.log "   - UNMATCH " + q.route + ">/" + r.from + "/" + r.to + "#" + r.time
        rides.del q.route + ">/" + r.from + "/" + r.to + "#" + r.time
      if q.del
        console.log "   - UNMATCH " + "/" + r.from + "/" + r.to + ">" + q.route + "#" + q.time
        rides.del "/" + r.from + "/" + r.to + ">" + q.route + "#" + q.time
      return next()
    visited[r.time] = true
    det r, q, (pickup, join, dropoff, alone) =>
      detDriver = pickup + join + dropoff - alone
      detPassenger = pickup + alone + dropoff - join
      r.det = Math.min detDriver, detPassenger
      if r.det < DET
        r.dist = alone
        r.pickup = pickup
        r.dropoff = dropoff
        if detDriver < detPassenger
          r.driver = true
        else
          r.passenger = true
        console.log "   + MATCH " + q.route + " ---> " + r.from + "/" + r.to + "#" + r.time
        rides.put q.route + ">/" + r.from + "/" + r.to + "#" + r.time, r, (err) =>
          this.push ride
          next()
      else
        next()
  .on "end", () ->
    console.log " END " + latest
    rides.put q.route + ">" + "#latest", latest


notifyAbout = (q, after, done) ->
  latest = 0
  es.map (ride, next) ->
    if ride.key.match /#latest/
      latest = ride.value
      return next()
    r = ride.value
    if r.del
      return next(null, del: true, time: r.time)
    q.det = r.det
    q.pickup = r.pickup
    q.dropoff = r.dropoff
    q.driver = true if r.passenger
    q.passenger = true if r.driver
    q.dist = r.dist + r.det - r.pickup - r.dropoff if r.driver
    q.dist = r.pickup + r.dist + r.dropoff - r.det if r.passenger
    if r.time != q.time
      if sock = socket[r.time + "/" + r.from + "/" + r.to]
        console.log "     NOTIFY " + r.time + "/" + r.from + "/" + r.to
        sock.write JSON.stringify(q) + "\n"
        console.log "   + MATCH " + "/" + r.from + "/" + r.to + " <--- " + q.route + "#" + q.time
        rides.put "/" + r.from + "/" + r.to + ">" + q.route + "#" + q.time, q
      else
        console.log "     no socket "
        console.log "   - UNMATCH " + q.route + ">/" + r.from + "/" + r.to + "#" + r.time
        rides.del q.route + ">/" + r.from + "/" + r.to + "#" + r.time
        socket[q.time + q.route].write JSON.stringify(del: true, time: r.time) + "\n"
        return next()
    else
      console.log "     SELBST " + r.time + "/" + r.from + "/" + r.to
      r.me = true
    if r.time > after
      console.log "     send " + r.time + "/" + r.from + "/" + r.to
      next(null, r)
    else
      next()
  .on "end", () ->  done latest if done

names = level "./data/names"
suggest = (text) ->
  text = text.trim().toUpperCase()
  names.createReadStream(start: text + ":999", end: text, reverse: true)
  .pipe es.mapSync (p) -> p.key.split("!")[1]
  .pipe es.join ","
