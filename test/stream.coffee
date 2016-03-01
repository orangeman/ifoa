require("./setup") "STREAM", (test) ->


  test ":: match self", (t) ->
    t.plan 1
    test.connect "/Berlin/Leipzig#0", (ride) ->
      t.equal ride.route, "/Berlin/Leipzig", "Erkenne Dich selbst"

  test ":: match each other", (t) ->
    t.plan 4
    user = test.connect "/Berlin/Leipzig#0", (ride) ->
      if ride.route == "/Berlin/Leipzig" # self
        test.connect "/Berlin/Munich#0", (ride2) ->
          if ride2.route == "/Berlin/Leipzig"
            t.equal ride2.det, 30, "Umweg für den Fahrer ist 30km"
            t.ok true if ride2.del
      else if ride.route == "/Berlin/Munich"
        t.equal ride.det, 30, "Umweg als Mitfahrer ist 30km"
        user.close()

  test ":: match other each", (t) ->
    t.plan 3
    test.connect "/Berlin/Leipzig#0", (ride) ->
      test.connect "/Berlin/Munich#0", (ride) ->
        test.connect "/Leipzig/Munich#0", (ride) ->
          t.ok true
