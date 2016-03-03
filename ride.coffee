html = require("fs").readFileSync("ride.html").toString()
mustache = require "mustache"

duration = (dist) ->
  min = Math.floor(dist * 0.6)
  if min > 60
    h = Math.floor(min / 60)
    min = min % 60
    "#{h} h #{min} min"
  else
    "#{min} min"

who = (r) ->
  if r.me
    return "MICH"
  else if r.driver
    label = "DRIVER"
  else
    label = "PASSENGER"
  det = 2 * (r.pickup + r.dropoff) - r.det
  if det < 300
    if r.driver
      label = label + " or PASSENGER det #{det}km"
    else
      label = label + " or DRIVER det #{det}km"
  label

normalize = (n) ->
  n = "" + n
  prefix = ""
  prefix = "0" + prefix for i in [0..(4 - n.length)]
  prefix + n

module.exports = (r) ->
  r.who = who r
  r.who_css = if r.me then "mich" else if r.driver then "driver" else "passenger"
  r.dist_css = "dist_" + r.who_css
  r.pickupLabel = duration r.pickup
  r.det_sort = normalize r.det
  mustache.render html, r
