fs = require "fs"
http = require "http"
level = require('level')
index = fs.readFileSync __dirname + "/index.html"
js = fs.readFileSync __dirname + "/index.js"
names = level "./data/names"

http.createServer (req, res) ->
  if req.url == "/"
    res.writeHead 200, {"Content-Type": "text/html"}
    res.end index
  else if req.url == "/index.js"
        res.end js
  else
    text = decodeURI(req.url.replace('/', '')).trim().toUpperCase()
    places = []
    names.createReadStream(start: text + ":999", end: text, reverse: true)
    .on "data", (p) ->
      places.push p.key.split("!")[1]
    .on "end", () ->
      res.end places.join(',')
.listen process.env.PORT || 5000
