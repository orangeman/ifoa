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
  label = "DRIVER"
  if r.passenger
    label = "PASSENGER"
  det = 2 * (r.pickup + r.dropoff) - r.det
  if det < 300
    if r.driver
      label = label + " or PASSENGER det #{det}km"
    else
      label = label + " or DRIVER det #{det}km"
  label

module.exports = (r) ->
  r.who = who r
  r.who_css = r.who.toLowerCase()
  r.dist_css = "dist_" + r.who_css
  r.pickupLabel = duration r.pickup
  mustache.render html, r
