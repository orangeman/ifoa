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

  test ":: two socket same session", (t) ->
    t.plan 6
    user = test.connect {route: "/Berlin/Munich", since: 1}, (ride) ->
      if ride.me && !ride.seats
        t.equal ride.route, "/Berlin/Munich", "me"
        t.equal ride.status, "private", "see private self"
        sockjs "http://localhost:5000/sockjs", { 'force new connection': true }
        .onopen = () ->
          @send '{"session":"' + user.token + '"}\n'
          @send JSON.stringify id: ride.id, seats: 5
          @onmessage = (msg) ->
            r = JSON.parse(msg.data)
            t.equal r.route, "/Berlin/Munich"
            t.equal r.seats, 5, "seats window 2"
      else
        t.equal ride.route, "/Berlin/Munich"
        t.equal ride.seats, 5, "seats window 1"

  test ":: two searches same session", (t) ->
    t.plan 9
    token = "abcd"
    b = browse route: "/Berlin/Munich", token, (ride) ->
      if ride.me && !ride.seats
        t.equal ride.route, "/Berlin/Munich", "me"
        b = browse route: "/Berlin/Leipzig", seats: 5, token, (r) ->
          if r.route == "/Berlin/Leipzig"
            t.ok true, "/Berlin/Leipzig"
            t.equal r.seats, 5, "/Berlin/Leipzig seats window 2"
          if r.route == "/Berlin/Munich"
            t.ok true, "/Berlin/Munich"
            t.ok !r.seats, "no seats"
            b.close()
            browse route: "/Berlin/Leipzig", token, (m) ->
              if m.route == "/Berlin/Leipzig"
                t.ok m.me, "me after refresh"
                t.ok !m.seats, "no seats refresh"
              else
                t.equal m.route, "/Berlin/Munich", "me"
                t.ok !m.me, "not me"



  browse = (ride, token, cb) ->
    s = sockjs "http://localhost:5000/sockjs", { 'force new connection': true }
    s.onopen = () ->
      s.send '{"session":"' + token + '"}\n'
      ride.status = "published"
      s.send JSON.stringify ride
      s.onmessage = (msg) =>
#        console.log "MSG " + msg.data
        r = JSON.parse(msg.data)
        cb r
    s
