test = require "tapes"
request = require "request"
es = require "event-stream"
#shoe = require "../node_modules/shoe/browser"
sockjs = require "sockjs-client"
exec = require("child_process").exec
spawn = require('better-spawn')
rds = null

server = (cb) ->
  exec "rm -rf data/rides", (err, out) ->
    rds = spawn "node ./server.js"
    #rds.stdout.pipe process.stdout
    rds.stderr.pipe process.stderr
    setTimeout cb, 1500

module.exports = (title, run) ->

  test title, (t) ->

    t.beforeEach (t) ->
      server () -> t.end()

    t.afterEach (t) ->
      rds.close()
      t.end()

    t.test.get = (path, cb) ->
      request "http://localhost:5000" + path, (err, r, res) ->
        cb JSON.parse res

    t.test.find = (route, cb) ->
      request url: "http://localhost:5000" + route, headers: {"Accept": "application/json"}, (err, r, res) ->
        cb JSON.parse res

    t.test.post = (ride, token, cb) ->
      id = if ride.id then "/" + ride.id else ""
      request.post {url: "http://localhost:5000/ride" + id, headers: 'token': token}, (err, r, res) ->
        cb JSON.parse res if res
      .end JSON.stringify ride

    t.test.auth = (session, ride, name, cb) ->
      ride = if ride then "/ride/" + ride else ""
      request.post {url: "http://localhost:5000" + ride, headers: 'token': 'XYZ'}, (err, r, res) ->
        cb() if cb
      .end JSON.stringify session: session, user: id: "A", name: name

    t.test.connect = (query, cb) ->
      sock = sockjs "http://localhost:5000/sockjs", { 'force new connection': true }
      sock.token = uid()
      sock.onopen = () ->
        sock.send '{"session":"' + sock.token + '"}\n'
        sock.send JSON.stringify query
        sock.onmessage = (msg) ->
          ride = JSON.parse msg.data
          cb ride #if ride.route
      sock.reconnect = (q, c) ->
        s = sockjs "http://localhost:5000/sockjs", { 'force new connection': true }
        s.onopen = () ->
          s.send '{"session":"' + sock.token + '"}'
          s.send JSON.stringify q
          s.onmessage = (msg) ->
            ride = JSON.parse msg.data
            c ride if c #if ride.route
      sock

    t.test.stopServer = () -> rds.close()
    t.test.startServer = server

    run t.test
    t.end()


uid = ->
  'xxxxx'.replace(/[xy]/g, (c) ->
    r = Math.random() * 16 | 0
    v = if c is 'x' then r else (r & 0x3|0x8)
    v.toString(16)
  )
