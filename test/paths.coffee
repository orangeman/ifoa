get = require "request"

require("./setup") "PATHS", (test) ->


  test ":: get path", (t) ->
    t.plan 1
    get "http://localhost:5000/path/Kreuzberg/Wedding", (e, r, path) ->
      t.equal path, "cyl_Iy}xpA~E|DFnh@JlDTlDr@pNLhEApDIbBM`Bm@hEoCbQ_@zCKdAM~CArBNdF?z@EvBOjBYjC]lAK^Ud@e@v@]`@[XeF|CqBnBaAdAq@rAeAhDy@`Ci@fAo@z@sBfB}@`A}@rAy@xB[McGaAmAM{@Bo@H{YlGeGnBaBv@iAZg@LgAJoCL}BCyCk@eBg@gBq@mMcGg@KmBBiBv@kAp@wCzB}BrBs@|@W`@M\\i@vBe@bAe@l@c@^ULi@NmCHoAl@_AZc@FqFQs@Im@Sa@Yq@s@a@m@[y@k@{BQYKAeBbAOPULeB|Aeb@|a@kAkDyScc@mA_EsCdFeHdOm@`Ai@hAiBlEgTjd@pFdKP`@}B~D_@m@_C`EQ[U\\m@eA", "Path passt"
