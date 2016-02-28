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
    setTimeout cb, 1000

connect = (query, cb) ->
  sock = sockjs "http://localhost:5000/sockjs", { 'force new connection': true }
  sock.onopen = () ->
    sock.send query
    sock.onmessage = (msg) ->
      ride = JSON.parse msg.data
      #console.log "DA " + msg.data
      cb ride if ride.route

test "RDS :: ", (t) ->

  t.beforeEach (t) ->
    server () -> t.end()

  t.afterEach (t) ->
    rds.close()
    t.end()

  t.test "match self", (t) ->
    t.plan 1
    connect "/Berlin/Leipzig#0", (ride) ->
      t.equal ride.route, "/Berlin/Leipzig", "Erkenne Dich selbst"

  t.test "match each other", (t) ->
    t.plan 2
    connect "/Berlin/Leipzig#0", (ride) ->
      if ride.route == "/Berlin/Leipzig" # self
        connect "/Berlin/Munich#0", (ride) ->
          if ride.route == "/Berlin/Leipzig"
            t.equal ride.det, 30, "Umweg für den Fahrer ist 30km"
      else if ride.route == "/Berlin/Munich"
        t.equal ride.det, 30, "Umweg als Mitfahrer ist 30km"

  t.end()


#  request.post "http://localhost:5000", (err, resp, page) ->
#    console.log "started"
#  .end JSON.stringify from: "Berlin", to: "Leipzig"
#  setTimeout (() -> t.end()), 3000
