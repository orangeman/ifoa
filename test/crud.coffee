require("./setup") "CRUD", (test) ->

  xtest = (a,b) -> console.log "nix"

  test ":: rest post ride", (t) ->
    t.plan 5
    token = "abc"
    test.auth token, null, "user foo", () ->
      test.post from: "Berlin", to: "Leipzig", expire: 1000, token, (res) ->
        test.get "/ride/" + res.id, (ride) ->
          t.ok !(ride.driver && ride.passenger), "only one role in matching"
          t.equal ride.to, "Leipzig", "Ziel passt"
          t.equal ride.from, "Berlin", "Start passt"
          t.equal ride.dist, 191, "Dist passt"
          setTimeout (() ->
            test.get "/ride/" + res.id, (ride) ->
              t.equal ride.status, "deleted", "Fahrt Expired"
            ), 1000

  test ":: proxy post ride with guid", (t) ->
    t.plan 4
    token = "ABC"
    user = name: "Sepp"
    test.connect {route: "/Berlin/Munich"}, (ride) ->
      if ride.me
        test.post guid: "abc42", from: "Berlin", to: "Leipzig", status: "published", user: user, token, (res) ->
      else
        t.equal ride.id, "abc42", "guid"
        t.equal ride.status, "published", "published"
        t.equal ride.route, "/Berlin/Leipzig", "route"
        t.deepEqual ride.user, user, "user assigned"

  test ":: proxy post ride", (t) ->
    t.plan 3
    token = "ABC"
    user = name: "Sepp"
    test.connect {route: "/Berlin/Munich"}, (ride) ->
      if ride.me
        test.post from: "Berlin", to: "Leipzig", status: "published", user: user, token, (res) ->
      else
        t.equal ride.status, "published", "published"
        t.equal ride.route, "/Berlin/Leipzig", "route"
        t.deepEqual ride.user, user, "user assigned"

  test ":: alternate names", (t) ->
    t.plan 3
    token = "abc"
    test.auth token, null, "user foo", () ->
      test.post route: "/Berlin/München", expire: 1000, token, (res) ->
        t.equal res.route, "/Berlin/Munich", "Munich as key for München"
        test.post route: "/Wien/Leipzig", expire: 1000, token, (rr) ->
          t.equal rr.route, "/Vienna/Leipzig", "Vienna as key for Wien"
          test.post route: "/Řezno/Cologne", expire: 1000, token, (r) ->
            t.equal r.route, "/Regensburg/Köln", "Rezno/Cologne"

  test ":: unknown route", (t) ->
    t.plan 2
    token = "abc"
    test.auth token, null, "user foo", () ->
      test.post route: "/Berlin/Leip", expire: 1000, token, (res) ->
        t.equal res.fail, "UNKNOWN ROUTE Leip", "place Leip"
        test.post route: "/Ber/Leipzig", expire: 1000, token, (res) ->
          t.equal res.fail, "UNKNOWN ROUTE Ber", "place Ber"

  test ":: meaningless route", (t) ->
    t.plan 1
    token = "abc"
    test.auth token, null, "user foo", () ->
      test.post route: "/Berlin/Berlin", expire: 1000, token, (res) ->
        t.ok res.id, "should not crash"
