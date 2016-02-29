require("./setup") "SEARCH", (test) ->


  test ":: find ride", (t) ->
    t.plan 3
    test.post from: "Berlin", to: "Leipzig", expire: 1000, (res) ->
      test.find "/Berlin/Leipzig#1", (rides) ->
        t.equal rides[0].det, 0, "Kein Umweg"
        t.equal rides.length, 1, "Ein Treffer"
        t.equal rides[0].route, "/Berlin/Leipzig", "Route passt"
