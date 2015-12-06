fs = require "fs"
http = require "http"
shoe = require "shoe"
level = require "level"
sockjs = require "sockjs"
es = require "event-stream"
through = require "through2"
JSONStream = require "JSONStream"
hyperstream = require "hyperstream"
ecstatic = require("ecstatic")(__dirname + "/public", cache: "no-cache")
html = require "./ride"


server = http.createServer (req, response) ->
  if m = req.url.match /\/(.*)\/(.*)/
    console.log req.url + "  " +  req.connection.remoteAddress + "   " + decodeURI(m[1]) + "->" + m[2]
    response.writeHead 200, "Content-Type": "text/html"
    fs.createReadStream __dirname + "/index.html"
    .pipe hyperstream
      '#rides': search().pipe html()
    .pipe response
  else if q = req.url.match /q=(.*)/
    suggest(decodeURI(q[1])).pipe response
  else
    ecstatic req, response

socket = {}

life = shoe (stream) ->
  console.log "CONN " + stream.remoteAddress
  session = stream._session.connection.pathname
  socket[session] = stream
  stream.on "data", (ride) ->
    console.log "DATA " + ride
    rides.put ride + "!" + new Date().getTime(), det: Math.random()
  stream.on "close", () -> console.log "CLOSE"
  search().pipe stream, end: false
  .on "end", () -> console.log "end"

life.installHandlers server, prefix: "/sockjs"
server.listen process.env.PORT || 5000


names = level "./data/names"
suggest = (text) ->
  text = text.trim().toUpperCase()
  names.createReadStream(start: text + ":999", end: text, reverse: true)
  .pipe es.mapSync (p) -> p.key.split("!")[1]
  .pipe es.join ","

rides = level "./data/rides", valueEncoding: "json"
search = () ->
  rides.createReadStream().pipe es.mapSync (r) ->
    s = r.key.split("!")[0].split("->")
    from: s[0], to: s[1], det: Math.floor(r.value.det * 100)
  .pipe JSONStream.stringify(false)
