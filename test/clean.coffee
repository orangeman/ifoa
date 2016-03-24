spawn = require('better-spawn')

require("./setup") "CLEAN", (test) ->

  test ":: clean up", (t) ->
    newsearch = false
    u1 = test.connect {route: "/Berlin/Munich", status: "published"}, (r1) ->
      if r1.me
        id = r1.id
        u2 = test.connect {route: "/Berlin/Leipzig", status: "published"}, (r2) ->
          if r2.me
            u3 = test.connect {route: "/Berlin/Nürnberg", status: "published"}, (r3) ->
              if r3.route == "/Berlin/Munich"
                if r3.status == "published"
                  t.ok !(r3.driver && r3.passenger), "only one role in matching"
                  u1.close()
                else if r3.status = "deleted"
                  t.ok true, "got delete notification"
                  test.connect {route: "/Berlin/Nürnberg", status: "published"}, (another) ->
                    if another.id == id && another.status = "deleted"
                      t.fail "new client should not get delete notification"
                    if !newsearch
                      t.ok true, "new client did not get delete notification"
                      newsearch = true
                      count = 0
                      test.connect {route: "/Berlin/Ingolstadt", status: "published"}, (newroute) ->
                        if newroute.status == "deleted"
                          t.fail "new search route should not re-notify deletes"
                        count += 1
                        if count == 4
                          t.ok true, "found everyone else"
                          t.end()
