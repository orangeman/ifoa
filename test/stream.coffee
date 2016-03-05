require("./setup") "STREAM", (test) ->

  xtest = (a,b) -> console.log "nix"

  test ":: match self", (t) ->
    t.plan 4
    test.connect {route: "/", since: 1}, (ride) ->
    test.connect {route: "/Berlin/Leipzig", since: 1}, (r) ->
      t.equal r.route, "/Berlin/Leipzig", "Erkenne Dich selbst"
      t.equal r.pickup, 0, "Kein Umweg"
      t.equal r.dist, 187, "Distanz"
      console.log "ID "+r.id
      t.ok r.me, "Me self"

  test ":: match each other", (t) ->
    t.plan 3
    test.connect {route: "/Berlin/Leipzig", status: "published"}, (ride) ->
      if ride.me
        t.equal ride.route, "/Berlin/Leipzig", "me"
    test.connect {route: "/Leipzig/Munich", status: "published"}, (ride) ->
    test.connect {route: "/Berlin/Munich", status: "published"}, (r) ->
      t.ok true, "not me" unless r.me

  test ":: match other each", (t) ->
    t.plan 5
    user = test.connect {route: "/Berlin/Leipzig", status: "published"}, (ride) ->
      t.fail "shizzo!" if ride.driver && ride.passenger
      if ride.route == "/Berlin/Leipzig" # self
        test.connect {route: "/Kreuzberg/Leipzig", status: "published"}, (r) ->
          t.fail "shizzo" if r.driver && r.passenger
          if r.route == "/Berlin/Leipzig"
            t.equal r.det, 3, "Umweg für den Fahrer ist 30km" # 4x
            if r.status == "deleted"
              t.ok true, "deleted"
              user.reconnect {route: "/Berlin/Leipzig", id: r.id, status: "published"}
      else if ride.route == "/Kreuzberg/Leipzig"
        t.equal ride.det, 3, "Umweg als Mitfahrer ist 30km"
        user.close()

  test ":: update data", (t) ->
    t.plan 13
    user = test.connect {route: "/Berlin/Leipzig", since: 1, status: "published"}, (r) ->
      t.ok true, "find " + r.route
      if r.seats == 3
        t.ok true, "decr seats self 3"
        t.equal r.det, 0, "Kein Umweg"
      else if r.seats == 2
        t.ok true, "decr seats self 2"
      else if r.route == "/Berlin/Leipzig"
        test.connect {route: "/Berlin/Munich", since: 1, status: "published"}, (ride) ->
          t.ok true, "find " + ride.route
          if ride.route == "/Berlin/Leipzig"
            if not ride.seats
              user.send JSON.stringify id: ride.id, seats: 3
            else if ride.seats == 3
              t.ok true, "decr seats 3"
              setTimeout (() ->
                user.send JSON.stringify id: ride.id, seats: 2), 100
            else if ride.seats == 2
              t.ok true, "decr seats 2"

  test ":: update match", (t) ->
    t.plan 5
    user = test.connect {route: "/Berlin/Leipzig", since: 1, status: "published"}, (r) ->
      if r.route == "/Berlin/Leipzig" && r.status != "deleted"
        test.connect {route: "/Berlin/Munich", since: 1, status: "published"}, (ride) ->
          if ride.route == "/Berlin/Leipzig"
            if ride.status != "deleted"
              t.ok true, "delete " + ride.route # because route change re-match
              user.send JSON.stringify route: "/Kreuzberg/Leipzig", id: ride.id, seats: 3
            else t.ok true, "deleted " + ride.route
          else if ride.route == "/Kreuzberg/Leipzig"
            if ride.status != "deleted"
              t.ok true, "found: " + ride.route
              user.close()
              user.reconnect {route: "/Berlin/Freising", id:ride.id, since: 1}
            else t.ok true, "deleted " + ride.route
          else if ride.route == "/Berlin/Freising"
            t.ok true, "found: " + ride.route
