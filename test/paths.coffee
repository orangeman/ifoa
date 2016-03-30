get = require "request"

require("./setup") "PATHS", (test) ->

  xtest = (a,b) -> console.log "nix"

  test ":: get place", (t) ->
    t.plan 1
    get "http://localhost:5000/place/Berlin", (e, r, place) ->
      t.deepEqual JSON.parse(place).latlon, [52.52437, 13.41053], "latlon"

  test ":: alternate place names", (t) ->
    t.plan 4
    get "http://localhost:5000/place/Cologne", (e, r, place) ->
      t.deepEqual JSON.parse(place).latlon, [ 50.93333, 6.95 ]
      t.equal JSON.parse(place).name, "Köln", "Cologne maps to Köln"
      get "http://localhost:5000/place/#{encodeURI("Řezno")}", (e, r, place) ->
        t.deepEqual JSON.parse(place).latlon, [ 49.01513, 12.10161 ]
        t.equal JSON.parse(place).name, "Regensburg"

  test ":: get path", (t) ->
    t.plan 1
    get "http://localhost:5000/path/Kreuzberg/Wedding", (e, r, path) ->
      t.equal path, "cyl_Iy}xpA~E|DFnh@JlDTlDr@pNLhEApDIbBM`Bm@hEoCbQ_@zCKdAM~CArBNdF?z@EvBOjBYjC]lAK^Ud@e@v@]`@[XeF|CqBnBaAdAq@rAeAhDy@`Ci@fAo@z@sBfB}@`A}@rAy@xB[McGaAmAM{@Bo@H{YlGeGnBaBv@iAZg@LgAJoCL}BCyCk@eBg@gBq@mMcGg@KmBBiBv@kAp@wCzB}BrBs@|@W`@M\\i@vBe@bAe@l@c@^ULi@NmCHoAl@_AZc@FqFQs@Im@Sa@Yq@s@a@m@[y@k@{BQYKAeBbAOPULeB|Aeb@|a@kAkDyScc@mA_EsCdFeHdOm@`Ai@hAiBlEgTjd@pFdKP`@}B~D_@m@_C`EQ[U\\m@eA", "Path passt"

  test ":: get alternate names path", (t) ->
    t.plan 1
    get "http://localhost:5000/path/Vienna/Munich", (e, r, path) ->
      get "http://localhost:5000/path/Wien/#{encodeURI("München")}", (e, r, alt) ->
        t.equal alt, path, "path Wien München passt"

  test ":: get alternate names path", (t) ->
    t.plan 1
    get "http://localhost:5000/path/Cologne/Prag", (e, r, path) ->
      get "http://localhost:5000/path/#{encodeURI("Köln")}/Prague", (e, r, alt) ->
        t.equal alt, path, "path Köl Prag passt"
