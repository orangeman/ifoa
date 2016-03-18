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
      s = d.split "|"
      if s.length == 2
        cb dist: parseInt(s[0]), time: parseInt(s[1])
      else # tmp legacy hack
        cb dist: parseInt(d), time: Math.floor(parseInt(d) * 0.6)
    else
      graphhop k, from, to, (d) ->
        console.log "ROUTE NOT FOUND " + d.err if d.err
        cb d

graphhop = (k, from, to, cb) ->
  place from, (orig) ->
    return cb dist: 99999999, err: from if !orig
    place to, (dest) ->
      return cb dist: 99999999, err: to if !dest
      gh.dist orig, dest, (d) ->
        dists.put k, d.dist + "|" + d.time
        paths.put k, d.path, (e) -> cb d
        log.write "GH #{k}\n"

place = (id, cb) ->
  places.get id.toUpperCase(), (e, p) ->
    cb (JSON.parse(p) if p)

module.exports.path = (from, to, cb) ->
  k = key from, to
  paths.get k, (err, path) ->
    unless err
      cb path: path
    else
      graphhop k, from, to, (d) ->
        cb d

module.exports.lookup = (from, to, cb) ->
  lookup key(from, to), from, to, cb

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
      cb dist: 0, time: 0

# alternate names
# min dist between cities
# score route -> dauer insereriert route for all users
# suggest name space split
