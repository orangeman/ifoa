sockjs = require "sockjs-client"
request = require "request"

require("./setup") "SESSION", (test) ->

  xtest = (a,b) -> console.log "nix"

  test ":: no rest without session", (t) ->
    t.plan 1
    request.post "http://localhost:5000", (err, r, res) ->
      t.equal JSON.parse(res).fail, "ACCESS DENIED"
    .end JSON.stringify from: "Berlin", to: "Leipzig"

  test ":: no socket without session", (t) ->
    t.plan 1
    sockjs "http://localhost:5000/sockjs"
    .onopen = () ->
      @send JSON.stringify from: "Berlin", to: "Leipzig"
      @onmessage = (msg) ->
        t.equal JSON.parse(msg.data).fail, "ACCESS DENIED"

  test ":: no update with different session", (t) ->
    t.plan 3
    user = test.connect {route: "/Berlin/Munich", since: 1}, (ride) ->
      if ride.me
        t.equal ride.route, "/Berlin/Munich", "me"
        t.equal ride.status, "private", "see private self"
        sockjs "http://localhost:5000/sockjs"
        .onopen = () ->
          token = "XYZab"
          @send '{"session":"' + token + '"}\n'
          @send JSON.stringify id: ride.id, seats: 5
          @onmessage = (msg) ->
            t.equal JSON.parse(msg.data).fail, "ACCESS DENIED"
