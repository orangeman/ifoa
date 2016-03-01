JSONStream = require "JSONStream"
tablesort = require "tablesort"
through = require "through2"
request = require "request"
hyperglue = require "hyperglue"
es = require "event-stream"
htmlize = require "./ride"
decode = require "./path"
shoe = require "shoe"
HOST = window.location.origin
search = null


$ () ->
  m = $(location).attr('pathname').match /\/(.*)\/(.*)/
  dest = autosuggest $("#dest"), if m then decodeURI m[2] else ""
  orig = autosuggest $("#orig"), if m then decodeURI m[1] else ""
  time = $(".time").last().html()
  sort = tablesort $("table")[0]

  rides = $("#rides")
  (stream = shoe "/sockjs")
  .pipe JSONStream.parse()
  .pipe es.map (ride, next) ->
    console.log JSON.stringify ride
    if !time || ride.time > time
      time = ride.time
      console.log time
    if ride.del
      console.log "DELETE " + ride.time
      $("#" + ride.time).remove()
      return next()
    rides.append htmlize ride
    sort.refresh()
    next()
  .onclose = () -> console.log "CLOSE"
  console.log "time " + time

  stream.write $(location).attr('pathname') + "#" + (time ||= 1)

  search = () ->
    query = "/#{orig()}/#{dest()}"
    if window.location.pathname != query
      history.replaceState {}, "", HOST + query
      console.log "path " + window.location.pathname + "#0"
      stream.write query + "#0"
      rides.html ""

  map = L.map("map").setView [48.505, 9.09], 10
  L.tileLayer('http://stamen-tiles-{s}.a.ssl.fastly.net/toner-lite/{z}/{x}/{y}.{ext}',
  	attribution: 'Map tiles by <a href="http://stamen.com">Stamen Design</a>, <a href="http://creativecommons.org/licenses/by/3.0">CC BY 3.0</a> &mdash; Map data &copy; <a href="http://www.openstreetmap.org/copyright">OpenStreetMap</a>',
  	subdomains: 'abcd',
  	minZoom: 0,
  	maxZoom: 20,
  	ext: 'png'
  ).addTo map
  L.control.zoom(position: "bottomright").addTo map


  points = []
  showMap = (p) ->
    points = []
    map.eachLayer (l) -> map.removeLayer l unless l.getAttribution
    who = $(this).siblings(".who").html()
    from = $(this).siblings(".orig").html()
    to = $(this).siblings(".dest").html()
    pickup = orig()
    dropoff = dest()
    console.log who
    drawPath from, pickup, color: "#004565", weight: 7, dashArray:"1, 10", opacity: 1
    drawPath dropoff, to, color: "#004565", weight: 7, dashArray:"1, 10", opacity: 1
    if who == "DRIVER"
      drawPath from, to, color: "#004565", weight: 10, opacity: 1
      drawPath pickup, dropoff, color: "#ffcc00", weight: 3, opacity: 1
    else
      drawPath pickup, dropoff, color: "#004565", weight: 10, opacity: 1
      drawPath from, to, color: "#ffcc00", weight: 3, opacity: 1

  $("#rides").on "click", ".pickup", showMap
  $("#rides").on "click", ".detour", showMap
  $("#rides").on "click", ".dist_mich", showMap
  $("#rides").on "click", ".dist_driver", showMap
  $("#rides").on "click", ".dist_passenger", showMap

  drawPath = (from, to, style) ->
    if from == to
      points.push []
      if points.length == 4
        panAndZoom points
    else
      getPath from, to, (pois) ->
        console.log "DRAW " + from + " -> " + to
        l = L.geoJson().addTo map
        l.options = style: style
        l.addData "type": "LineString", "coordinates": pois
        points.push pois
        if points.length == 4
          panAndZoom points

  paths = {}
  getPath = (from, to, done) ->
    if paths[from+to]
      console.log "cache"
      done decode paths[from+to]
    else
      console.log "load"
      request.get HOST + "/paths/" + encodeURI(from) + "/" + encodeURI(to)
      .pipe es.mapSync (p) ->
        console.log "got " + p.toString()
        paths[from+to] = p.toString()
        done decode p.toString()

  panAndZoom = (points) ->
    console.log "ZOOMERNG"
    bbx = [[99999999, 99999999], [0, 0]]
    for pois in points
      for l in pois
        bbx[0][0] = l[1] if l[1] < bbx[0][0]
        bbx[0][1] = l[0] if l[0] < bbx[0][1]
        bbx[1][0] = l[1] if l[1] > bbx[1][0]
        bbx[1][1] = l[0] if l[0] > bbx[1][1]
    map.once "moveend", () ->
      b = map.getBounds()
      width = bbx[1][1] - bbx[0][1]
      height = bbx[1][0] - bbx[0][0]
      screen = b.getEast() - b.getWest()
      console.log width + " x " + height + " screen " + screen
      if height > width / 2
        console.log "VERTICAL"
        bbx[1][1] = (b.getEast() - screen / 3.2)
        bbx[0][1] = (b.getWest() - screen / 3.2)
      else
        console.log "HORIZONTAL"
        bbx[0][1] = (b.getWest() - screen * 2.3)
      map.fitBounds bbx
    map.fitBounds bbx



autosuggest = (div, def) ->
  div.find("input").val def
  div.find("input").focus();
  places = []
  text = null
  index = -1
  caret = 0
  select = (name) ->
    caret = name.length
    div.find("input").val name
    div.find(".suggest").html ""
    index = -1
    places = []
    search()
  div.on "click", ".sug", (p) ->
    console.log "CLICK " + $(this).html()
    select $(this).html()
  div.find("input").keyup (e) ->
    k = e.keyCode;
    console.log "key  " + k
    text = div.find("input").val().trim();
    if k == 27 # esc
      div.find(".suggest").hide()
    else
      div.find(".suggest").show()
    if k == 37 # left
      caret = caret - 1
      if caret < 0
        $("#orig").find("input").focus()
    else if k == 39 # right
      caret = caret + 1
      if caret > text.length
        div.find(".suggest").hide()
        $("#dest").find("input").focus()
    else if k == 40 || k == 32
      index = index + 1
      index = places.length - 1 if index >= places.length
    else if k == 38
      index = index - 1
      index = -1 if index < -1
    else if k == 13 # enter
      if index == -1
        div.find(".suggest").hide()
        return search()
      else
        return select text + places[index]
    else
      caret = text.length
      if k == 8 # backspace (delete a character)
        index = -1
      if text.length > 0
        request.get HOST + "/q=" + encodeURI(text)
        .pipe(es.split ",").pipe es.writeArray render
        .on "end", () ->
      return
    render places.length == 0, places

  render = (err, names) ->
    return if err
    count = -1
    places = names
    if names[0] == ""
      div.find(".suggest").html ""
    else
      html = places.map (place) ->
        count = count + 1
        "<a href='#' class='sug #{oddEven count}' id='#{active count}' >#{text + place}</a>"
      div.find(".suggest").html html.join('')

  active = (count) -> if count == index then 'active' else ''
  oddEven = (count) -> if count % 2 == 0 then 'even' else 'odd'

  titleCase = (str) ->
    str[0].toUpperCase() + str[1..str.length-1]
  () -> titleCase div.find("input").val().trim()
