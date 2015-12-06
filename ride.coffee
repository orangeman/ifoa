hyperspace = require "hyperspace"
html = require("fs").readFileSync "ride.html"

module.exports = () ->
  hyperspace html.toString(), (r) ->
    '.detour': r.det,
    '.orig': r.from,
    '.dest': r.to
