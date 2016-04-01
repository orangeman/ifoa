level = require "level"
dists = level "./data/dist"
paths = level "./data/path"
places = level "./data/place"
gh = require "./graphhopper"
log = require("fs").createWriteStream("lol.log", flags: "a")

key = (from, to) ->
  if from < to
    (from + to).toUpperCase()
  else if from > to
    (to + from).toUpperCase()
  else null

lookup = (k, from, to, cb) ->
  return cb dist: 0, time: 0, path: 0 unless k
  dists.get k, (err, d) ->
    unless err
      s = d.split "|"
      if s.length == 2
        cb dist: parseInt(s[0]), time: parseInt(s[1]), route: "/#{from}/#{to}"
      else # tmp legacy hack
        cb dist: parseInt(d), time: Math.floor(parseInt(d) * 0.6), route: "/#{from}/#{to}"
    else
      graphhop k, from, to, cb, lookup, (d) ->
        console.log "ROUTE NOT FOUND " + d.fail if d.fail
        d.route = "/#{from}/#{to}"
        console.log "ROUTE NOW #{d.route}"
        cb d

graphhop = (k, from, to, cb, next, done) ->
  place from, (orig) ->
    return cb dist: 99999999, err: from if !orig
    if from.toUpperCase() != (f = orig.name).toUpperCase()
      return next key(f, to), f, to, cb
    place to, (dest) ->
      return cb dist: 99999999, err: to if !dest
      if to.toUpperCase() != (t = dest.name).toUpperCase()
        return next key(from, t), from, t, cb
      gh.dist orig, dest, (d) ->
        if !d.err
          dists.put key(orig.name, dest.name), d.dist + "|" + d.time
          paths.put key(orig.name, dest.name), d.path, (e) -> done d
        else done d
        log.write "GH #{key(orig.name, dest.name)} #{d.err?}\n"

module.exports.place = place = (id, cb) ->
  places.get id.toUpperCase(), (e, p) ->
    cb (JSON.parse(p) if p)

module.exports.path = (from, to, cb) ->
  lookupPath key(from, to), from, to, cb

lookupPath = (k, from, to, cb) ->
  return cb dist: 0, time: 0, path: 0 unless k
  paths.get k, (err, path) ->
    unless err
      cb path: path
    else
      graphhop k, from, to, cb, lookupPath, (d) ->
        cb d

module.exports.lookup = (from, to, cb) ->
  if k = key from, to
    lookup k, from, to, cb
  else
    cb dist: 0, time: 0

module.exports.dist = () ->
  distCache = {}

  (from, to, cb) ->
    if k = key from, to
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
