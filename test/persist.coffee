require("./setup") "PERSIST", (test) ->

  xtest = (a,b) -> console.log "nix"

  test ":: private by default", (t) ->
    t.plan 5
    user = test.connect {route: "/Berlin/Munich", since: 1}, (ride) ->
      if ride.me
        t.equal ride.route, "/Berlin/Munich", "me"
        t.equal ride.status, "private", "see private self"
        test.connect {route: "/Leipzig/Munich", status: "published"}, (r) ->
    test.connect {route: "/Berlin/Starnberg", since: 1}, (ride) ->
      if ride.route == "/Berlin/Munich"
        t.fail "should not see private ride"
      else if ride.route == "/Leipzig/Munich"
        t.equal ride.status, "published", "see published ride"
        test.connect {route: "/Kreuzberg/Munich"}, (r) ->
          if r.route == "/Berlin/Munich"
            t.fail "should not find private ride"
          else if r.route == "/Leipzig/Munich"
            t.equal ride.status, "published", "found published ride"
            t.ok !(ride.driver && ride.passenger), "only one role in matching"
