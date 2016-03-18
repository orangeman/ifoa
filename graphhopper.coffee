
request = require('request')

distance = (from, to, done) ->
  args = "locale=de&instructions=false&key=07fc74e8-677c-4f9f-841f-953b84fa3ad4"
  points = "&point=#{from.latitude},#{from.longitude}&point=#{to.latitude},#{to.longitude}"
  #url = "http://localhost:8989/route?" + args + points
  url = "https://graphhopper.com/api/1/route?" + args + points
  request url, (err, resp, page) ->
    if err
      console.log "GRAPHHOPPER " + err
      done null
    else
      #console.log page
      json = JSON.parse(page)
      #console.log json.paths?[0]?.points
      if (p = json.paths?[0])?.distance
        done
          dist: Math.floor(p.distance / 1000)
          time: Math.floor(p.time / 60000)
          path: p.points
      else
        done null

dist = (from, to, done) ->
  if !(from && to && from.latitude && to.latitude)
    done err: "NO lat/lon" + from + "->" + to
    return
  distance from, to, (d) =>
    if d
      done(d)
    else
      distance to, from, (d) =>
        if d
          done(d)
        else
          done err: "GRAPHHOPPER FAIL " + from.name+" -> "+to.name

module.exports.dist = dist
