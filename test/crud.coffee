require("./setup") "CRUD", (test) ->


  test ":: store ride", (t) ->
    t.plan 3
    test.post from: "Berlin", to: "Leipzig", expire: 1000, (res) ->
      test.get "/rides/" + res.id, (ride) ->
        t.equal ride.to, "Leipzig", "Ziel passt"
        t.equal ride.from, "Berlin", "Start passt"
        setTimeout (() ->
          test.get "/rides/" + res.id, (ride) ->
            t.equal ride.status, "deleted", "Fahrt Expired"
          ), 1000
