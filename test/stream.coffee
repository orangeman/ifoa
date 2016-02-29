require("./setup") "STREAM", (test) ->


  test ":: match self", (t) ->
    t.plan 1
    test.connect "/Berlin/Leipzig#0", (ride) ->
      t.equal ride.route, "/Berlin/Leipzig", "Erkenne Dich selbst"

  test ":: match each other", (t) ->
    t.plan 2
    test.connect "/Berlin/Leipzig#0", (ride) ->
      if ride.route == "/Berlin/Leipzig" # self
        test.connect "/Berlin/Munich#0", (ride) ->
          if ride.route == "/Berlin/Leipzig"
            t.equal ride.det, 30, "Umweg für den Fahrer ist 30km"
      else if ride.route == "/Berlin/Munich"
        t.equal ride.det, 30, "Umweg als Mitfahrer ist 30km"
