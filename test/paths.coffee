get = require "request"

require("./setup") "PATHS", (test) ->


  test ":: get path", (t) ->
    t.plan 1
    get "http://localhost:5000/paths/Kreuzberg/Wedding", (e, r, path) ->
      t.equal path, "_bv_IapopAl@dAT]p@jAlG{KUk@yE_JzToe@`" +
                    "@u@d@s@vAkDdCuFjEwI~BaEvAaDNg@dFsI~As" +
                    "Cr@yAPIFMDa@Vi@v@iA~AuBVe@b@Wf@q@Lc@l" +
                    "HqJvCeEpCsDnDoEbBgChGmItGwInCkDf@[j@g" +
                    "@nAu@xQcBXYlGg@fLkALDdBITDtD_@P[rHm@p" +
                    "Hs@n@Bt@If@QrAMb@F`AK\\QjOsANFrCWNMl@" +
                    "GJFnAKLKtHs@dAIJDj@E\\MjBSq@eWa@}PC}A" +
                    "?]Be@tAgI~Gk_@TuAtC}OtTfQrG~E", "Path passt"
