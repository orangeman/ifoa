level = require "level"
dists = level "./data/dist"
paths = level "./data/path"
places = level "./data/places"
gh = require "./graphhopper"
log = require("fs").createWriteStream("lol.log", flags: "a")

key = (from, to) ->
  if from < to
    (from + to).toUpperCase()
  else if from > to
    (to + from).toUpperCase()
  else null

lookup = (k, from, to, cb) ->
  dists.get k, (err, d) ->
    unless err
      cb parseInt d
    else
      graphhop k, from, to, (d) ->
        cb d.dist

graphhop = (k, from, to, cb) ->
  place from, (orig) ->
    place to, (dest) ->
      gh.dist orig, dest, (d) ->
        log.write "GH #{k}\n"
        dists.put k, d.dist
        paths.put k, d.path, (e) -> cb d

place = (id, cb) ->
  places.get id.toUpperCase(), (e, p) ->
    cb JSON.parse p

module.exports.path = (from, to, cb) ->
  k = key from, to
  paths.get k, (err, path) ->
    unless err
      cb path
    else
      graphhop k, from, to, (d) ->
        cb d.path

module.exports.dist = () ->
  distCache = {}

  (from, to, cb) ->
    k = key from, to
    if k
      if d = distCache[k]
        cb d
      else
        lookup k, from, to, (d) ->
          distCache[k] = d
          cb d
    else
      cb 0

# alternate names
# min dist between cities
# score route -> dauer insereriert route for all users
# suggest name space split
