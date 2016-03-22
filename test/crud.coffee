require("./setup") "CRUD", (test) ->


  test ":: store ride", (t) ->
    t.plan 4
    token = "abc"
    test.auth token, null, "user foo", () ->
      test.post from: "Berlin", to: "Leipzig", expire: 1000, token, (res) ->
        test.get "/ride/" + res.id, (ride) ->
          t.equal ride.to, "Leipzig", "Ziel passt"
          t.equal ride.from, "Berlin", "Start passt"
          t.equal ride.dist, 187, "Dist passt"
          setTimeout (() ->
            test.get "/ride/" + res.id, (ride) ->
              t.equal ride.status, "deleted", "Fahrt Expired"
            ), 1000

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
          console.log JSON.stringify res
          t.ok res.id, "should not crash"
