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
render = require "./ride"

server = http.createServer (req, response) ->
  if m = req.url.match /(\/.*\/.*)/
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
    query = route: m[1], from: m[2], to: m[3], time: new Date().getTime()
    insert query, sockjs, m[4]
  sockjs.on "close", () ->
    console.log "\nCLOSE " + session
    remove query if query
.installHandlers server, prefix: "/sockjs"

server.listen process.env.PORT || 5000


rides = level "./data/rides", valueEncoding: "json"

insert = (query, sockjs, after) ->
  rides.put query.time + query.route, query
  socket[query.time + query.route] = sockjs
  stream = (s) ->
    s.pipe notifyAbout query, after
    .pipe(JSONStream.stringify(false), end: false)
    .pipe sockjs, end: false
  stream cache query.route, (latest) ->
    stream search(latest + 1).pipe match(query)
  #sockjs.write "\n{ \"time\": \"1449506492402\", \"from\": \"debug\", \"to\": \"debug\", \"det\": 78, \"session\": \"/sockjs/874/lr2x3pcr/websocket\" }\n"

remove = (query) ->
  query.del = true
  rides.put new Date().getTime() + query.route, query
  cache query.route
  .pipe match query
  .pipe notifyAbout query, 9999999999999999
  .on "end", () ->
    console.log "removed.\n"

cache = (route, done) ->
  latest = 0
  console.log ":: cache " + route
  rides.createReadStream(gt: route + ">", lt: route+">~")
  .pipe es.mapSync (r) ->
    console.log "     CACHE " + JSON.stringify r.key
    latest = r.value.time if r.value.time > latest
    r
  .on "end", () -> done latest if done

search = (since) ->
  console.log ":: search  since " + since
  rides.createReadStream(gt: since + "/", lt: "a", reverse: true)

match = (q) ->
  console.log "   match " + JSON.stringify q
  visited = {}
  through.obj (ride, enc, next) ->
    r = ride.value
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
        rides.del q.route + ">/" + r.from + "/" + r.to + "#" + r.time, r
        rides.put q.route + ">" + "#del", r
      if q.del
        console.log "   - UNMATCH " + "/" + r.from + "/" + r.to + ">" + q.route + "#" + q.time
        rides.del "/" + r.from + "/" + r.to + ">" + q.route + "#" + q.time, q
        rides.put "/" + r.from + "/" + r.to + ">" + "#del", q
      return next()
    visited[r.time] = true
    q.det = Math.floor Math.random() * 42
    ride.value.det = q.det
    this.push ride
    console.log "   + MATCH " + q.route + " <---> " + r.from + "/" + r.to + "#" + r.time
    rides.put q.route + ">/" + r.from + "/" + r.to + "#" + r.time, r, (err) -> next()

notifyAbout = (q, after) ->
  es.map (ride, next) ->
    r = ride.value
    if r.del
      return next(null, del: true, time: r.time)
    q.det = r.det
    if r.time != q.time
      if sock = socket[r.time + "/" + r.from + "/" + r.to]
        console.log "     NOTIFY " + r.time + "/" + r.from + "/" + r.to
        sock.write JSON.stringify(q) + "\n"
        console.log "   + MATCH " + "/" + r.from + "/" + r.to + ">" + q.route + "#" + q.time
        rides.put "/" + r.from + "/" + r.to + ">" + q.route + "#" + q.time, q
      else
        console.log "     no socket "
        console.log "   - UNMATCH " + q.route + ">/" + r.from + "/" + r.to + "#" + r.time
        rides.del q.route + ">/" + r.from + "/" + r.to + "#" + r.time
        socket[q.time + q.route].write del: true, time: r.time
        return next()
    else
      console.log "     SELBST " + r.time + "/" + r.from + "/" + r.to
    if r.time > after
      console.log "     send " + r.time + "/" + r.from + "/" + r.to
      next(null, r)
    else
      next()

names = level "./data/names"
suggest = (text) ->
  text = text.trim().toUpperCase()
  names.createReadStream(start: text + ":999", end: text, reverse: true)
  .pipe es.mapSync (p) -> p.key.split("!")[1]
  .pipe es.join ","
