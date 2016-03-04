require("./setup") "CRUD", (test) ->


  test ":: store ride", (t) ->
    t.plan 4
    test.post from: "Berlin", to: "Leipzig", expire: 1000, (res) ->
      test.get "/rides/" + res.id, (ride) ->
        t.equal ride.to, "Leipzig", "Ziel passt"
        t.equal ride.from, "Berlin", "Start passt"
        t.equal ride.dist, 187, "Dist passt"
        setTimeout (() ->
          test.get "/rides/" + res.id, (ride) ->
            t.equal ride.status, "deleted", "Fahrt Expired"
          ), 1000
