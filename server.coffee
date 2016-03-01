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
html = require("fs").readFileSync("ride.html").toString()
distance = require "./dist"
render = require "./ride"
nextTime = 9999999999999999
EXPIRE = 180 * 1000

paths = level "./data/path"

server = http.createServer (req, response) ->
  console.log req.url
  if req.method == "POST"
    req.on "data", (r) ->
      ride = JSON.parse r
      ride.url = "nada"
      ride.route = "/" + ride.from + "/" + ride.to
      console.log "\nPOST " + JSON.stringify ride
      ride = post ride, ride.expire || EXPIRE
      insert ride, 9999999999999999, (latest) ->
        search ride, latest + 1
        .on "end", () ->
          console.log "ENDETED"
          response.writeHead 200, "Content-Type": "application/json"
          response.end JSON.stringify ride
    return
  if req.url == "/"
    response.writeHead 200, "Content-Type": "text/html"
    fs.createReadStream __dirname + "/index.html"
    .pipe response
  else if m = req.url.match /paths\/(.*)\/(.*)/
    response.writeHead 200, "Content-Type": "application/json"
    key = if m[1] < m[2] then m[1] + m[2] else m[2] + m[1]
    key = decodeURI(key).toUpperCase()
    console.log decodeURI key
    paths.createValueStream gte: key, lte: key
    .pipe response
  else if m = req.url.match /rides\/(.*)/
    console.log "ID = " + m[1]
    response.writeHead 200, "Content-Type": "application/json"
    rides.createReadStream gte: "id:" + m[1], lt: "id:" + m[1] + "~"
    .pipe es.mapSync (p) -> JSON.stringify p.value
    .pipe response
  else if m = req.url.match /(\/.*\/.*)/
    console.log "\nGET" + req.url + "  " +  req.connection.remoteAddress + "   " + decodeURI m[1]
    if req.headers.accept && req.headers.accept == "application/json"
      console.log "JSON"
      response.writeHead 200, "Content-Type": "application/json"
      cache(decodeURI m[1]).pipe es.map (ride, cb) ->
        return cb() if ride.key.match /#latest/
        cb null, ride.value
      .pipe es.writeArray (err, rides) ->
        response.end JSON.stringify rides
    else
      response.writeHead 200, "Content-Type": "text/html"
      fs.createReadStream __dirname + "/index.html"
      .pipe hyperstream
        '#rides': cache(decodeURI m[1]).pipe through.obj (ride, enc, next) ->
          return next() if ride.key.match /#latest/
          console.log "render #{ride.value.from}->#{ride.value.to}"
          this.push render ride.value
          next()
      .pipe response
  else if q = req.url.match /q=(.*)/
    suggest(decodeURI(q[1])).pipe response
  else
    ecstatic req, response

socket = {}

shoe (sockjs) ->
  session =
  query = null
  sockjs.on "data", (url) ->
    console.log "OPEN " + url
    if query
      query.del = true
      rides.put new Date().getTime(), query
      remove query
    m = decodeURI(url).match /(\/(.*)\/(.*))#(\d*)/
    return unless m
    query = route: m[1], from: m[2], to: m[3]
    query.url = sockjs._session.connection.pathname
    socket[query.url] = sockjs
    if query.from.length > 0 && query.to.length > 0
      query = post query
      insert query, parseInt(m[4]), (latest) ->
        search query, latest + 1
        .pipe(JSONStream.stringify(false), end: false)
        .pipe sockjs, end: false
      .pipe sockjs, end: false
  sockjs.on "close", () ->
    console.log "\nCLOSE " + session
    if query
      query.del = true
      rides.put new Date().getTime(), query
      remove query
.installHandlers server, prefix: "/sockjs"

clean = (t) ->
  () ->
    now = new Date().getTime()
    console.log "\nCLEAN " + now + " - " + t
    rides.createReadStream(gt: (now - t) + "/", lt: "a")
    .on "end", () -> nextTime = 9999999999999999
    .pipe through.obj (r, enc, next) ->
      ride = r.value
      console.log "consider " + JSON.stringify ride
      if ride.time - now < 3000
        if ride.del
          remove ride
        else
          console.log "no clean up " + JSON.stringify ride
      else
        nextTime = ride.time
        console.log "schedule " + (nextTime - now)
        setTimeout clean, nextTime - now
        this.destroy()
      next()

server.listen process.env.PORT || 5000
setTimeout clean(1000 * 1000), 1000


uid = ->
  'xxxxxxxxxxx'.replace(/[xy]/g, (c) ->
    r = Math.random() * 16 | 0
    v = if c is 'x' then r else (r & 0x3|0x8)
    v.toString(16)
  )

rides = level "./data/rides", valueEncoding: "json"
post = (ride, expire) ->
  ride.id = uid()
  now = new Date().getTime()
  if !ride.time || ride.time < now
    ride.time = now
  rides.put "id:" + ride.id, ride
  rides.put ride.time + ride.route, ride
  if expire
    rides.put ride.time + expire, del: true, id: ride.id, time: ride.time + expire, route: ride.route, url: ride.url
    if ride.time + expire < nextTime
      nextTime = ride.time + expire
      console.log "schedule " + (nextTime - now)
      setTimeout clean(1000), nextTime - now
  ride

insert = (query, after, done) ->
  console.log "INSERT " + "id:" + query.id + " :: " + query.time + query.route
  cache query.route
  .pipe notifyAbout query, after, done
  .pipe(JSONStream.stringify(false), end: false)

search = (query, since) ->
  fresh since
  .pipe match query
  .pipe notifyAbout query, 1

remove = (query) ->
  console.log "REMOVE " + query.id + " :: " + query.time + query.route
  rides.put "id:" + query.id, status: 'deleted'
  cache query.route
  .pipe match query
  .pipe notifyAbout query
  .on "end", () ->
    console.log "removed.\n"

cache = (route) ->
  console.log " :: cache " + route
  rides.createReadStream(gt: route + ">", lt: route+">~")

fresh = (since) ->
  console.log " :: search  since " + since
  rides.createReadStream(gt: since + "/", lt: new Date().getTime() + "/", reverse: true)

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
      rides.del ride.key
      return next()
    if q.del
      this.push ride
      visited[r.time] = true
      if ride.key.match /#del/
        return next()
      console.log " <-- UNMATCH " + r.route + ">" + q.route + "#" + q.time
      rides.del r.route + ">" + q.route + "#" + q.time
      return next()
    visited[r.time] = true
    det r, q, (pickup, join, dropoff, alone) =>
      detDriver = pickup + join + dropoff - alone
      detPassenger = pickup + alone + dropoff - join
      r.det = Math.min detDriver, detPassenger
      if r.det < DET
        if r.del
          console.log " --> UNMATCH " + q.route + ">" + r.route + "#" + r.time
          rides.del q.route + ">" + r.route + "#" + r.time, (err) =>
            this.push ride
            next()
        else
          r.dist = alone
          r.pickup = pickup
          r.dropoff = dropoff
          if detDriver < detPassenger
            r.driver = true
          else
            r.passenger = true
          console.log " --> MATCH " + q.route + " ---> " + r.from + "/" + r.to + "#" + r.time
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
  after = 9999999999999999 if !after
  es.map (ride, next) ->
    if ride.key.match /#latest/
      latest = ride.value
      return next()
    r = ride.value
    if !r.del
      q.det = r.det
      q.pickup = r.pickup
      q.dropoff = r.dropoff
      q.driver = true if r.passenger
      q.passenger = true if r.driver
      q.dist = r.dist + r.det - r.pickup - r.dropoff if r.driver
      q.dist = r.pickup + r.dist + r.dropoff - r.det if r.passenger
    if r.time != q.time
      if r.url.match /sockjs/
        if sock = socket[r.url]
          unless q.del
            console.log " <-- MATCH " + r.route + " <--- " + q.route + "#" + q.time
            rides.put r.route + ">" + q.route + "#" + q.time, q
          console.log "     NOTIFY " + r.time + r.route
          sock.write JSON.stringify(q) + "\n"
        else
          console.log "     no socket "
          console.log " --> UNMATCH " + q.route + ">/" + r.from + "/" + r.to + "#" + r.time
          rides.del q.route + ">/" + r.from + "/" + r.to + "#" + r.time
          if q.url.match /sockjs/
            if sock = socket[q.url]
              socket[q.url].write JSON.stringify(del: true, time: r.time) + "\n"
            else
              console.log  "      no socket query"
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
