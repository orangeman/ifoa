sockjs = require "sockjs-client"
request = require "request"

require("./setup") "USER", (test) ->

  xtest = (a,b) -> console.log "nix"

  test ":: connect user", (t) ->
    t.plan 4
    user = test.connect {route: "/Berlin/Munich", since: 1}, (ride) ->
      if ride.user.name != "foo"
        t.equal ride.route, "/Berlin/Munich", "me"
        test.auth user.token, ride.id, "foo"
      else
        t.ok "foo", "User Name"
        user.close()
        setTimeout (() ->
          u = test.connect {route: "/Berlin/Munich", id: ride.id}, (r) ->
            if r.fail
              t.equal r.fail, "ACCESS DENIED", "Log in"
              test.auth u.token, ride.id, "foo"
            else
              t.equal r.user.name, "foo", "User Name"
        ), 300

  test ":: simultaneous sessions", (t) ->
    t.plan 5
    firstLogIn = false
    user = test.connect {route: "/Berlin/Munich", since: 1}, (ride) ->
      console.log "FIRST BROWSER " + JSON.stringify ride
      if !ride.user["A"]
        test.auth user.token, ride.id, "foo"
      else if !ride.seats && !firstLogIn
        t.equal ride.user["A"].name, "foo", "User Name"
        console.log "LOGGED IN"
        firstLogIn = true
        setTimeout (() -> # second browser
          u = test.connect {route: "/Berlin/Munich", id: ride.id}, (r) ->
            console.log "SECOND BROWSER " + JSON.stringify r
            if r.fail
              t.equal r.fail, "ACCESS DENIED", "no access"
              test.auth u.token, ride.id, "foo"
            else if r.user["A"] && !r.seats #&& !secondLogIn
              t.equal r.user["A"].name, "foo", "User Name"
              u.send JSON.stringify id: ride.id, seats: 3
            else
              t.equal r.seats, 3, "second session seats"
        ), 300
      else if ride.seats
        t.equal ride.seats, 3, "first session seats seats"
