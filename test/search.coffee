require("./setup") "SEARCH", (test) ->


  test ":: find ride", (t) ->
    t.plan 2
    test.connect {route: "/Frankfurt am Main/Nürnberg", since: 1}, (r) ->
      if r.me
        test.find "/Frankfurt am Main/Nürnberg/", (rides) ->
          t.equal rides.length, 1, "Ein Treffer"
          t.equal rides[0].route, "/Frankfurt am Main/Nürnberg", "Umlaut / Space"

  test ":: find ride match", (t) ->
    t.plan 1
    test.connect {route: "/Berlin/Munich", since: 1}, (ride) ->
      test.connect {route: "/Berlin/Leipzig", since: 1}, (r) ->
        if r.me
          test.find "/Berlin/Munich/" + r.id, (match) ->
            t.equal match.det, 30, "Umweg 30km"


  test ":: find rides", (t) ->
    t.plan 5
    token = "abc"
    test.auth token, null, "user foo", () ->
      test.post from: "Berlin", to: "Leipzig", expire: 1000, token, (res) ->
        test.find "/Berlin/Leipzig", (rides) ->
          #console.log "FOUND " + JSON.stringify rides
          t.equal rides[0].det, 0, "Kein Umweg"
          t.equal rides.length, 1, "Ein Treffer"
          t.equal rides[0].route, "/Berlin/Leipzig", "Route passt"
          test.post from: "Berlin", to: "Munich", expire: 1000, token, (res2) ->
            test.find "/Berlin/Munich", (rides2) ->
              t.equal rides2[0].det, 30, "30km Umweg"
              t.equal rides2.length, 2, "Zwei Treffer"
