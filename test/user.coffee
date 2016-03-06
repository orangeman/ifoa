sockjs = require "sockjs-client"
request = require "request"

require("./setup") "USER", (test) ->

  xtest = (a,b) -> console.log "nix"

  test ":: connect user", (t) ->
    t.plan 4
    user = test.connect {route: "/Berlin/Munich", since: 1}, (ride) ->
      if ride.user.name != "foo"
        t.equal ride.route, "/Berlin/Munich", "me"
        request.post {url: "http://localhost:5000/user", headers: 'token': 'X'}, (err, r, res) ->
          console.log "posted " + res
        .end JSON.stringify session: user.token, ride: ride.id, user: id: "A", name: "foo"
      else
        t.ok "foo", "User Name"
        user.close()
        setTimeout (() ->
          u = test.connect {route: "/Berlin/Munich", id: ride.id}, (r) ->
            console.log JSON.stringify r
            if r.fail
              t.equal r.fail, "ACCESS DENIED", "Log in"
              request.post {url: "http://localhost:5000/user", headers: 'token': 'X'}, (err, r, res) ->
                console.log "posted " + res
              .end JSON.stringify session: u.token, ride: ride.id, user: id: "A", name: "foo"
            else
              t.equal r.user.name, "foo", "User Name"
        ), 300
