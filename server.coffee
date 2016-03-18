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
routing = require "./routing"
getDist = routing.dist
getPath = routing.path
lookUp = routing.lookup
render = require "./ride"
nextTime = 9999999999999999
EXPIRE = 180 * 1000


server = http.createServer (req, response) ->
  console.log req.url
  if req.method == "POST"
    req.on "data", (q) ->
      console.log "HTTP POST " + q
      q = JSON.parse q
      if !req.headers.token
        console.log "NO TOKEN"
        response.end JSON.stringify(fail: "ACCESS DENIED") + "\n"
        return
      u = user[req.headers.token]
      if q.session
        return response.end "ACCESS DENIED" if req.headers.token != "XYZ"
        return if !q.user || !q.user.id || !q.user.name
        u = user[q.session] ||= {}
        console.log "USER LOOKUP" + JSON.stringify u
        for k,v of q.user
          console.log "AUTH USER " + k + "   " + JSON.stringify v
          u[k] = v
        console.log "USER AFTER" + JSON.stringify u
      if !req.url.match /ride/
        return response.end "OK"
      if !u
        return response.end "NO USER"
      console.log "USER " + JSON.stringify u
      if m = req.url.match /ride\/(.+)/
        console.log "ride ID = " + m[1]
        q.id = m[1]
      post q, u,
        ((ride) -> # INSERT
          ride.url = q.url || "nadaradada"
          rides.put ride.time + ride.route, ride
          insert ride, 9999999999999999, (latest) ->
            search ride, latest + 1
            .on "end", () ->
              console.log "DONE HTTP INSERT"
              response.writeHead 200, "Content-Type": "application/json"
              response.end JSON.stringify ride
        ), ((ride) -> # UPDATE
          ride.url = q.url || "nadaradada"
          rides.put ride.time + ride.route, ride
          rides.put ride.route + ">" + ride.route + "#" + ride.id, ride
          cache ride.route
          .pipe notifyAbout ride, 1
          .on "end", () ->
            console.log "DONE HTTP UPDATE"
            response.writeHead 200, "Content-Type": "application/json"
            response.end JSON.stringify ride
        ), ((fail) ->
          console.log fail
          response.end JSON.stringify(fail: fail) + "\n"
        )
    return
  if req.url == "/"
    response.writeHead 200, "Content-Type": "text/html"
    fs.createReadStream __dirname + "/index.html"
    .pipe response
  else if m = req.url.match /path\/(.*)\/(.*)/
    getPath decodeURI(m[1]), decodeURI(m[2]), (d) ->
      console.log "PATH NOT FOUND " + d.err if d.err
      response.end d.path
  else if m = req.url.match /ride\/(.*)/
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
  else if req.url.match /info/
    response.writeHead 200,
      "Access-Control-Allow-Origin": "*"
    response.end ""
  else if q = req.url.match /q=(.*)/
    response.writeHead 200,
      "Content-Type": "text/plain"
      "Access-Control-Allow-Origin": "*"
    suggest(decodeURI(q[1]))
    .pipe es.writeArray (e, a) ->
      response.end a.join ","
  else
    ecstatic req, response

url = {}
sockets = {}
sessions = {}

shoe (sockjs) ->
  session = null
  myRide = null
  path = sockjs._session.connection.pathname
  sockjs.on "data", (q) ->
    console.log "SOCKET POST " + q
    q = JSON.parse q
    if q.session
      console.log path + " SESSION " + q.session
      session = q.session
      return
    if !session
      console.log " NO SESSION"
      return sockjs.write JSON.stringify(fail: "ACCESS DENIED") + "\n"
    console.log " USER " + JSON.stringify user[session] + "  SESSION " + session
    q.id = myRide.id if !q.id && myRide && myRide.id
    post q, user[session] || {},
      ((ride) -> # INSERT
        if !myRide
          (sockets[ride.id] ||= {})[path] = sockjs
        myRide = ride
        rides.put ride.time + ride.route, ride
        insert ride, parseInt(q.since || 1), (latest) ->
          search ride, latest + 1
          .pipe(JSONStream.stringify(false), end: false)
          .pipe sockjs, end: false
        .pipe sockjs, end: false
      ), ((ride) -> # UPDATE
        if !myRide
          (sockets[ride.id] ||= {})[path] = sockjs
        myRide = ride
        rides.put ride.time + ride.route, ride
        rides.put ride.route + ">" + ride.route + "#" + ride.id, ride
        cache ride.route
        .pipe notifyAbout ride, 1
      ), ((fail) ->
        console.log fail
        sockjs.write JSON.stringify(fail: fail) + "\n"
      )
  sockjs.on "close", () ->
    if myRide
      console.log "\nCLOSE"
      console.log " USER " + JSON.stringify myRide.user
      console.log " SUSSER " + JSON.stringify user[session]
      delete sockets[myRide.id][path]
      if !user[session] || Object.keys(user[session]).length == 0
        console.log  " NO USER"
        remove myRide
.installHandlers server, prefix: "/sockjs"

user = {}

post = (q, u, toInsert, toUpdate, onFail) ->
  ride = null
  find q, (r) ->
    if !r
      ride = id: uid(), user: u
    else
      console.log " EXISTING version " + r.time + "  " + r.route + "  " + r.status + " " + JSON.stringify r.user
      if r.user && Object.keys(r.user).length > 0
        if (true for id,v of r.user when u[id]).length == 0
          return onFail "ACCESS DENIED"
      ride = r
      if q.user
        for id,v of q.user
          if u[id]
            console.log "  ADD USER " + JSON.stringify v
            (ride.user || = {})[id] = v
          else
            console.log "  NOT ALLOWED TO ADD USER " + JSON.stringify v
    delete ride.user if ride.user && Object.keys(ride.user).length == 0
    ride.time = new Date().getTime()
    if q.time && q.time > ride.time
      ride.time = q.time
    ride.dep = q.dep if q.dep
    ride.dep = ride.time
    ride.seats = q.seats if q.seats
    ride.details = q.details if q.details
    ride.status = q.status || ride.status || "private"
    q.route = decodeURI q.route if q.route
    q.route = "/#{decodeURI(q.from)}/#{decodeURI(q.to)}" if q.from && q.to
    if r && (!q.route || q.route == r.route) && r.status != "deleted"
      console.log " UPDATE " + ride.route + ">" + ride.route + "#" + r.time
      ride.det = 0
      ride.pickup = 0
      ride.dropof = 0
      toUpdate ride
    else
      if r && r.status != "deleted"
        remove id: r.id, time: r.time, route: r.route, user: r.user
        ride.status = "updated"
      ride.route = q.route if q.route
      m = ride.route.match /\/(.*)\/(.*)/
      return unless m
      ride.from = m[1]
      ride.to = m[2]
      lookUp ride.from, ride.to, (d) ->
        return onFail "UNKNOWN ROUTE " + d.err if d.err
        ride.dist_time = d.time
        ride.dist = d.dist
        if q.expire
          ride.expire = q.expire
          rides.put ride.time + q.expire, status: "deleted", id: ride.id, time: ride.time + q.expire, route: ride.route, url: ride.url
          if ride.time + q.expire < nextTime
            nextTime = ride.time + q.expire
            console.log "schedule " + (nextTime - new Date().getTime())
            setTimeout clean(1000), nextTime - new Date().getTime()
        toInsert ride

find = (q, cb) ->
  if q.id
    rides.get "id:" + q.id, (err, r) ->
      cb r
  else
    cb null

uid = ->
  'xxxxxxxxxxx'.replace(/[xy]/g, (c) ->
    r = Math.random() * 16 | 0
    v = if c is 'x' then r else (r & 0x3|0x8)
    v.toString(16)
  )

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
        nextTime = ride.time
      else
        nextTime = ride.time unless nextTime
        console.log "DONE CLEAN up to " + latest + " Next in " + (nextTime - now) + "\n"
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





insert = (query, after, done) ->
  console.log "  INSERT " + "id:" + query.id + " :: " + query.time + query.route
  cache query.route
  .pipe notifyAbout query, after, done
  .pipe(JSONStream.stringify(false), end: false)

search = (query, since) ->
  fresh since
  .pipe match query
  .pipe notifyAbout query, 1

remove = (query) ->
  query.status = "deleted"
  query.time = new Date().getTime()
  console.log "  REMOVE " + query.id + " :: " + query.time + query.route
  cache query.route
  .pipe match query
  .pipe notifyAbout query

cache = (route) ->
  console.log "  :: cache " + route
  rides.createReadStream(gt: route + ">", lt: route+">/~")

fresh = (since) ->
  console.log "  :: search  since " + since
  rides.createReadStream(gt: since + "/", lte: new Date().getTime() + "/", reverse: true)

DET = 300
match = (q) ->
  console.log "     match " + q.route
  dist = getDist()
  det = (driver, passenger, done) ->
    dist driver.from, passenger.from, (pickup) ->
      dist passenger.to, driver.to, (dropoff) ->
        done pickup, dropoff
  visited = {}
  latest = 0
  through.obj (ride, enc, next) ->
    if ride.key.match /#latest/
      latest = ride.value
      return next()
    r = ride.value
    latest = r.time if r.time > latest
    if visited[r.id]
      console.log "     -x- visited " + r.id
      rides.del ride.key
      return next()
    if q.status == "deleted"
      this.push ride
      visited[r.id] = true
      if ride.key.match /#del/
        return next()
      console.log "     <-- UNMATCH " + r.route + ">" + q.route + "#" + q.id
      rides.del r.route + ">" + q.route + "#" + q.id
      return next()
    visited[r.id] = true
    det r, q, (pickup, dropoff) =>
      console.log "DETOUR COMPUTATION ERROR " + pickup.err + " " + dropoff.err if pickup.err || dropoff.err
      detDriver = pickup.dist + q.dist + dropoff.dist - r.dist
      detPassenger = pickup.dist + r.dist + dropoff.dist - q.dist
      r.det = Math.min detDriver, detPassenger
      if r.det < DET
        if r.status == "deleted"
          console.log "     --> UNMATCH " + q.route + ">" + r.route + "#" + r.id
          rides.del q.route + ">" + r.route + "#" + r.id, (err) =>
            this.push ride
            next()
        else
          r.pickup = pickup.dist
          r.pickup_time = pickup.time
          r.dropoff = dropoff.dist
          r.dropoff_time = dropoff.time
          if detDriver < detPassenger
            r.driver = true
          else
            r.passenger = true
          console.log "     --> MATCH " + q.route + ">" + r.route + "#" + r.id
          rides.put q.route + ">" + r.route + "#" + r.id, r, (err) =>
            this.push ride
            next()
      else
        next()
  .on "end", () ->
    console.log "     end match until " + latest
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
      console.log "         ME " + r.time + r.route
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
    socks = sockets[r.id] ||= {}
    console.log "         SOCKS " + JSON.stringify Object.keys(socks)
    if Object.keys(socks).length > 0
      unless q.status == "deleted"
        console.log "     <-- MATCH " + r.route + ">" + q.route + "#" + q.id
        rides.put r.route + ">" + q.route + "#" + q.id, q
      if r.id == q.id
        q.me = true
        for p, sock of socks
          sock.write JSON.stringify(q) + "\n"
          console.log "         NOTIFY SELF   " + r.time + r.route
        delete q.me
      else if q.status != "private"
        for p, sock of socks
          console.log "         NOTIFY ELSE   " + r.time + r.route
          sock.write JSON.stringify(q) + "\n"
    else if !r.user || Object.keys(r.user) == 0
      console.log "         no socket " + r.route + "#" + r.id
      console.log "     --> UNMATCH " + q.route + ">" + r.route + "#" + r.id
      rides.del q.route + ">" + r.route + "#" + r.id
      return next null, status: "deleted", id: r.id, time: r.time
    if r.time > after && !r.me && r.status != "private"
      console.log "          send " + r.time + r.route
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
  #.pipe es.join ","
