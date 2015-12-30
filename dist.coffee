level = require "level"


db = level "./data/dist"

distance = (from, to, done) ->
  db.get (from + to).toUpperCase(), (e, d) -> done parseInt d

module.exports = () ->
  distCache = {}

  dist = (from, to, done) ->
    if cached = distCache[k = from + to]
      done cached
    else
      distance from, to, (d) ->
        distCache[k] = d
        done d

  (from, to, done) ->
    if from < to
      dist from, to, done
    else if from > to
      dist to, from, done
    else
      done 0

# alternate names
# min dist between cities
# score route -> dauer insereriert route for all users
# suggest name space split
