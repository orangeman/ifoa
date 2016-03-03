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
      ride = {}
      r = JSON.parse r
      ride.expire = r.expire
      ride.url = r.url || "nada"
      ride.from = r.from
      ride.to = r.to
      ride.route = "/" + r.from + "/" + r.to
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
  ride = null
  sockjs.on "data", (q) ->
    q = JSON.parse q
    console.log "RECEIVE " + JSON.stringify q
    if q.id && ride != null
      rides.get "id:" + q.id, (err, r) ->
        console.log "EXISTING " + JSON.stringify r
        rides.del r.route + ">" + r.route + "#" + r.id if r
        ride = r
        ride.time = new Date().getTime()
        ride.url = sockjs._session.connection.pathname
        socket[ride.url] = sockjs
        ride.seats = q.seats if q.seats
        ride.details = q.details if q.details
        if (q.route && ride.route != decodeURI q.route) || r.status == "deleted"
          if r && r.status != "deleted"
            console.log "UNMATCH " + r.id + " :: " + r.time + r.route
            remove id: ride.id, time: r.time, route: r.route, url: r.url, status: "deleted"
          ride.status = "updated"
          ride.route = decodeURI q.route
          m = ride.route.match /\/(.*)\/(.*)/
          return unless m
          ride.from = m[1]
          ride.to = m[2]
          rides.put ride.time + ride.route, ride
          insert ride, parseInt(q.since || 1), (latest) ->
            search ride, latest + 1
            .pipe(JSONStream.stringify(false), end: false)
            .pipe sockjs, end: false
          .pipe sockjs, end: false
        else
          console.log "UPDATE " + ride.route + ">" + ride.route + "#" + r.time
          ride.det = 0
          ride.pickup = 0
          ride.dropof = 0
          rides.put ride.time + ride.route, ride
          rides.put ride.route + ">" + ride.route + "#" + ride.id, ride
          cache ride.route
          .pipe notifyAbout ride, 1
          #sockjs.write JSON.stringify ride
    else
      ride = id: q.id || uid()
      ride.url = sockjs._session.connection.pathname
      socket[ride.url] = sockjs
      ride.seats = q.seats if q.seats
      ride.details = q.details if q.details
      ride.route = decodeURI q.route
      m = ride.route.match /\/(.*)\/(.*)/
      return unless m
      ride.from = m[1]
      ride.to = m[2]
      ride = post ride
      insert ride, parseInt(q.since || 1), (latest) ->
        search ride, latest + 1
        .pipe(JSONStream.stringify(false), end: false)
        .pipe sockjs, end: false
      .pipe sockjs, end: false

  sockjs.on "close", () ->
    if ride
      ride.status = "deleted"
      rides.put new Date().getTime(), ride
      delete socket[ride.url]
      remove ride
.installHandlers server, prefix: "/sockjs"

clean = (t) ->
  () ->
    latest = 0
    now = new Date().getTime()
    console.log "\nCLEAN " + now + " - " + t
    rides.createReadStream(gt: (now - t) + "/", lt: "a")
    .on "end", () ->
      console.log "DONE CLEAN up to " + latest
      rides.put "latest_cleanup", latest
      nextTime = 9999999999999999
    .pipe through.obj (r, enc, next) ->
      ride = r.value
      latest = ride.time if ride.time > latest
      console.log "consider " + JSON.stringify ride
      if ride.time - now < 3000
        if ride.status == "deleted"
          remove ride
        else
          console.log "no clean up " + JSON.stringify ride
      else
        nextTime = ride.time
        console.log "DONE CLEAN up to " + latest + " Next in " + (nextTime - now)
        rides.put "latest_cleanup", latest
        setTimeout clean, nextTime - now
        this.destroy()
      next()

rides = level "./data/rides", valueEncoding: "json"

server.listen process.env.PORT || 5000
rides.get "latest_cleanup", (err, latest) ->
  if latest
    setTimeout clean(new Date().getTime() - parseInt(latest) + 2000, 1000)
  else rides.put "latest_cleanup", new Date().getTime()


uid = ->
  'xxxxxxxxxxx'.replace(/[xy]/g, (c) ->
    r = Math.random() * 16 | 0
    v = if c is 'x' then r else (r & 0x3|0x8)
    v.toString(16)
  )

post = (ride, expire) ->
  now = new Date().getTime()
  if !ride.time || ride.time < now
    ride.time = now
  rides.put ride.time + ride.route, ride
  if expire
    rides.put ride.time + expire, status: "deleted", id: ride.id, time: ride.time + expire, route: ride.route, url: ride.url
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
  query.status = "deleted"
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
  rides.createReadStream(gt: since + "/", lte: new Date().getTime() + "/", reverse: true)

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
    console.log JSON.stringify r
    latest = r.time if r.time > latest
    if visited[r.id]
      console.log "     visited " + r.id
      rides.del ride.key
      return next()
    if q.status == "deleted"
      this.push ride
      visited[r.id] = true
      if ride.key.match /#del/
        return next()
      console.log " <-- UNMATCH " + r.route + ">" + q.route + "#" + q.id
      rides.del r.route + ">" + q.route + "#" + q.id
      return next()
    visited[r.id] = true
    det r, q, (pickup, join, dropoff, alone) =>
      detDriver = pickup + join + dropoff - alone
      detPassenger = pickup + alone + dropoff - join
      r.det = Math.min detDriver, detPassenger
      if r.det < DET
        if r.status == "deleted"
          console.log " --> UNMATCH " + q.route + ">" + r.route + "#" + r.id
          rides.del q.route + ">" + r.route + "#" + r.id, (err) =>
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
          console.log " --> MATCH " + q.route + " ---> " + r.from + "/" + r.to + "#" + r.id
          rides.put q.route + ">/" + r.from + "/" + r.to + "#" + r.id, r, (err) =>
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
    if r.id == q.id
      console.log "     SELBST " + r.time + "/" + r.from + "/" + r.to
      r.me = true
    if r.status != "deleted"
      q.det = r.det
      q.pickup = r.pickup
      q.dropoff = r.dropoff
      if r.passenger
        q.driver = true
        delete q.passenger
      if r.driver
        q.passenger = true
        delete q.driver
      q.dist = r.dist + r.det - r.pickup - r.dropoff if r.driver
      q.dist = r.pickup + r.dist + r.dropoff - r.det if r.passenger
    if r.url.match /sockjs/
      if sock = socket[r.url]
        unless q.status == "deleted"
          console.log " <-- MATCH " + r.route + " <--- " + q.route + "#" + q.id
          rides.put r.route + ">" + q.route + "#" + q.id, q
        console.log "     NOTIFY " + r.time + r.route
        if r.id == q.id
          console.log "     SELBST " + r.time + "/" + r.from + "/" + r.to
          q.me = true
          sock.write JSON.stringify(q) + "\n"
          delete q.me
        else
          sock.write JSON.stringify(q) + "\n"
      else
        console.log "     no socket " + JSON.stringify r
        console.log " --> UNMATCH " + q.route + ">/" + r.from + "/" + r.to + "#" + r.id
        rides.del q.route + ">/" + r.from + "/" + r.to + "#" + r.id
        return next null, status: "deleted", id: r.id, time: r.time
    if r.time > after && !r.me
      console.log "     send " + r.time + "/" + r.from + "/" + r.to
      next(null, r)
    else
      next()
  .on "end", () ->
    rides.put "id:" + q.id, q
    done latest if done

names = level "./data/names"
suggest = (text) ->
  text = text.trim().toUpperCase()
  names.createReadStream(start: text + ":999", end: text, reverse: true)
  .pipe es.mapSync (p) -> p.key.split("!")[1]
  .pipe es.join ","
