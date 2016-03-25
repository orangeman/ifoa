require("./setup") "MATCH", (test) ->

  xtest = (a,b) -> console.log "nix"

  test ":: driver XOR passenger", (t) ->
    t.plan 5
    user = test.connect {route: "/Berlin/Nürnberg", status: "published"}, (ride) ->
      if ride.me
        if !ride.user
          t.ok ride.driver, "driver"
          test.auth user.token, ride.id, "foo"
        else
          t.ok ride.passenger, "passenger"
          refresh = test.connect {route: "/Berlin/Nürnberg", status: "published"}, (r) ->
            t.ok !(r.driver && r.passenger), "only one role in matching"
            console.log "GOT " + JSON.stringify r
          setTimeout (() -> t.ok true, "not found twice"), 500

  test ":: search without id", (t) ->
    t.plan 7
    watcher = null
    user = test.connect {route: "/Berlin/Augsburg", status: "published"}, (ride) ->
      if ride.route == "/Berlin/Augsburg"
        if watcher == null
          watcher = test.connect {route: "/Leipzig/Munich", status: "published"}, (r) ->
            if r.route == "/Berlin/Augsburg"
              if r.status != "deleted"
                t.ok true, "change search"
                user.send JSON.stringify route: "/Kreuzberg/Augsburg", status: "published"
                t.ok !(r.driver && r.passenger), "only one role in matching"
              else
                t.ok true, "notify watcher delete"
            else if r.route == "/Kreuzberg/Augsburg"
              t.ok ride.me, "search change watcher"
        else
          t.equal ride.status, "deleted", "notify self delete"
      else if ride.route == "/Kreuzberg/Augsburg"
        t.ok ride.me, "search change self"
        t.ok !(ride.driver && ride.passenger), "only one role in matching"
