sockjs = require "sockjs-client"
request = require "request"

require("./setup") "USER", (test) ->

  xtest = (a,b) -> console.log "nix"

  test ":: establish chat sessiom", (t) ->
    t.plan 8
    bob = null
    alice = null
    watcher = test.connect {route: "/Kreuzberg/Oldenburg", status: "published"}, (w) ->
      t.fail "watcher should not get one-to-one msges" if w.msg
      if w.me
        alice = test.connect {route: "/Berlin/Bremen", status: "published"}, (ride) ->
          if ride.me
            alice.id = ride.id
            bob = test.connect {route: "/Hamburg/Bremen", status: "published"}, (r) ->
              if r.me
                bob.id = r.id
              else if r.id == alice.id
                t.ok true, "bob found alice"
              else if r.msg
                t.equal r.msg, "answer", "bob got answer"
                t.equal r.from, alice.id, "from sender alice"
          else if ride.route == "/Hamburg/Bremen"
            t.ok true, "alice found bob"
          else if ride.msg
            t.equal ride.msg, "offer", "alice got offer"
            t.equal ride.from, bob.id, "from sender bob"
            alice.send JSON.stringify msg: "answer", to: bob.id
      else
        if w.route == "/Berlin/Bremen"
          t.ok true, "watcher found alice"
        if w.route == "/Hamburg/Bremen"
          t.ok true, "watcher found bob"
          bob.send JSON.stringify msg: "offer", to: alice.id
