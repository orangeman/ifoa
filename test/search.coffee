require("./setup") "SEARCH", (test) ->


  test ":: find ride", (t) ->
    t.plan 5
    token = "abc"
    test.auth token, null, "user foo", () ->
      test.post from: "Berlin", to: "Leipzig", expire: 1000, token, (res) ->
        test.find "/Berlin/Leipzig#1", (rides) ->
          #console.log "FOUND " + JSON.stringify rides
          t.equal rides[0].det, 0, "Kein Umweg"
          t.equal rides.length, 1, "Ein Treffer"
          t.equal rides[0].route, "/Berlin/Leipzig", "Route passt"
          test.post from: "Berlin", to: "Munich", expire: 1000, token, (res2) ->
            test.find "/Berlin/Munich#1", (rides2) ->
              t.equal rides2[0].det, 30, "30km Umweg"
              t.equal rides2.length, 2, "Zwei Treffer"
