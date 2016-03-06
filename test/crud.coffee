require("./setup") "CRUD", (test) ->


  test ":: store ride", (t) ->
    t.plan 4
    token = "abc"
    test.auth token, null, "user foo", () ->
      test.post from: "Berlin", to: "Leipzig", expire: 1000, token, (res) ->
        test.get "/rides/" + res.id, (ride) ->
          t.equal ride.to, "Leipzig", "Ziel passt"
          t.equal ride.from, "Berlin", "Start passt"
          t.equal ride.dist, 187, "Dist passt"
          setTimeout (() ->
            test.get "/rides/" + res.id, (ride) ->
              t.equal ride.status, "deleted", "Fahrt Expired"
            ), 1000

    test ":: unknown route", (t) ->
      t.plan 2
      token = "abc"
      test.auth token, null, "user foo", () ->
        test.post route: "/Berlin/Leip", expire: 1000, token, (res) ->
          t.equal res.fail, "UNKNOWN ROUTE", "place Leip"
          test.post route: "/Ber/Leipzig", expire: 1000, token, (res) ->
            t.equal res.fail, "UNKNOWN ROUTE", "place Ber"
