sockjs = require "sockjs-client"
request = require "request"

require("./setup") "USER", (test) ->

  xtest = (a,b) -> console.log "nix"

  test ":: connect user", (t) ->
    t.plan 5
    user = test.connect {route: "/Berlin/Munich", since: 1}, (ride) ->
      if !ride.user
        t.equal ride.route, "/Berlin/Munich", "me"
        test.auth user.token, ride.id, "foo"
      else
        t.equal ride.user.name, "foo", "User Name"
        user.close()
        setTimeout (() ->
          u = test.connect {route: "/Berlin/Munich", id: ride.id}, (r) ->
            if r.fail
              t.equal r.fail, "ACCESS DENIED", "no access"
              test.auth u.token, ride.id, "foo", () ->
                u.send JSON.stringify route: "/Berlin/Munich", id: ride.id
            else
              t.equal r.user.name, "foo", "User Name"
              t.ok !(r.driver && r.passenger), "only one role in matching"
        ), 300

  test ":: simultaneous sessions", (t) ->
    t.plan 7
    firstLogIn = false
    user = test.connect {route: "/Berlin/Munich", since: 1}, (ride) ->
      if !ride.user
        test.auth user.token, ride.id, "foo"
      else if !ride.seats && !firstLogIn
        t.equal ride.user.name, "foo", "User Name"
        firstLogIn = true
        setTimeout (() -> # second browser
          u = test.connect {route: "/Berlin/Munich", id: ride.id}, (r) ->
            if r.fail
              t.equal r.fail, "ACCESS DENIED", "no access"
              test.auth u.token, ride.id, "foo", () ->
                u.send JSON.stringify id: ride.id, seats: 3
            else if r.user
              t.equal r.user.name, "foo", "User Name"
              t.equal r.seats, 3, "second session seats"
              t.ok !(r.driver && r.passenger), "only one role in matching"
        ), 300
      else if ride.seats
        t.equal ride.seats, 3, "first session seats seats"
        t.ok !(ride.driver && ride.passenger), "only one role in matching"


  test ":: watch simultaneous sessions", (t) ->
    t.plan 11
    u = null
    firstLogIn = false
    secondLogIn = false
    user = test.connect {route: "/Berlin/Munich", status: "published"}, (ride) ->
      if !ride.user
        test.auth user.token, ride.id, "foo"
      else if !ride.seats && !firstLogIn
        t.equal ride.user.name, "foo", "Logged in"
        firstLogIn = true
        setTimeout (() ->
          watch = test.connect {route: "/Berlin/Leipzig"}, (w) ->
            if w.me
              t.equal w.status, "private", "new watcher session"
            else if w.route == "/Berlin/Munich"
              if Object.keys(w.user).length > 0
                t.equal w.user.name, "foo", "watcher found persisted"
                if !secondLogIn
                  secondLogIn = true
                  setTimeout (() -> # user again from another browser
                    refreshed = false
                    u = test.connect {route: "/Berlin/Munich", id: ride.id}, (r) ->
                      if r.status && r.status == "private"
                        t.equal r.route, "/Berlin/Munich", "new search session"
                      if r.fail
                        t.equal r.fail, "ACCESS DENIED", "no access"
                        test.auth u.token, ride.id, "foo"
                      else if !refreshed
                        t.equal r.seats, 3, "second session seats"
                        refreshed = true
                        setTimeout (() ->
                          user.close()
                          setTimeout (() ->
                            t.ok true, "refresh"
                            user.reconnect {route: "/Berlin/Munich", id: ride.id}, (again) ->
                              t.ok again.user, "REFRESH RECONNECT"
                          ), 300
                        ), 300
                  ), 300
                else if w.user && !w.seats
                  t.ok true, "watch seats updated"
                  u.send JSON.stringify id: ride.id, seats: 3
        ), 300
