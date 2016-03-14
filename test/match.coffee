require("./setup") "MATCH", (test) ->

  xtest = (a,b) -> console.log "nix"

  test ":: search without id", (t) ->
    t.plan 5
    watcher = null
    user = test.connect {route: "/Berlin/Augsburg", status: "published"}, (ride) ->
      if ride.route == "/Berlin/Augsburg"
        if watcher == null
          watcher = test.connect {route: "/Leipzig/Munich", status: "published"}, (r) ->
            if r.route == "/Berlin/Augsburg"
              if r.status != "deleted"
                t.ok true, "change search"
                user.send JSON.stringify route: "/Kreuzberg/Augsburg", status: "published"
              else
                t.ok true, "notify watcher delete"
            else if r.route == "/Kreuzberg/Augsburg"
              t.ok ride.me, "search change watcher"
        else
          t.equal ride.status, "deleted", "notify self delete"
      else if ride.route == "/Kreuzberg/Augsburg"
        t.ok ride.me, "search change self"
