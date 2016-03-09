geolocator = require "./geolocator"
JSONStream = require "JSONStream"
tablesort = require "tablesort"
es = require "event-stream"
htmlize = require "./ride"
decode = require "./path"
shoe = require "shoe"
HOST = window.location.origin
API = "https://ifoa.herokuapp.com"


$ () ->
  console.log "ORIG " + window.location.origin
  console.log ""

  m = $(location).attr('pathname').match /\/(.*)\/(.*)/
  dest = autosuggest $("#dest"), if m then decodeURI m[2] else ""
  orig = autosuggest $("#orig"), if m then decodeURI m[1] else ""
  time = $(".time").last().html()
  sort = tablesort $("table")[0]

  rides = $("#rides")
#  (stream = shoe "https://ifoa.herokuapp.com/sockjs")
  (stream = shoe API)
  .pipe JSONStream.parse()
  .pipe es.map (ride, next) ->
    if ride.fail
      alert ride.fail
      return next()
    console.log JSON.stringify ride
    $("#" + ride.id).remove()
    console.log k + ":" + v for k,v of stream.sock._options.info
    if ride.me
      console.log "ME " + ride.id
      history.replaceState {}, "", HOST +
        window.location.pathname + "#" + ride.id
    if !time || ride.time > time
      time = ride.time
    if ride.status == "deleted"
      console.log "DELETE " + ride.time
      return next()
    rides.append htmlize ride
    sort.refresh()
    next()
  .onclose = () -> console.log "CLOSE"
  console.log "time " + time

  query = () ->
    console.log "QUERY " + window.location.href.split("#")[1]
    stream.write JSON.stringify
      id: window.location.href.split("#")[1],
      route: window.location.pathname,
      details: details.val().trim()
      status: "published",
      since: (time ||= 1)

  search = () ->
    route = "/#{orig()}/#{dest()}"
    if window.location.pathname != route
      id = window.location.href.split("#")[1]
      history.replaceState {}, "", HOST + route +
        (if id then "#" + id else "")
      rides.html ""
      time = 1
      query()

  sst = ->
    'xxxxxxxxxxxxxxxxxxxxxxxx'.replace(/[xy]/g, (c) ->
      r = Math.random() * 16 | 0
      v = if c is 'x' then r else (r & 0x3|0x8)
      v.toString(16)
    )

  details = $("#details").find "input"
  details.on "input", query
  if !s = window.localStorage.getItem "session"
    window.localStorage.setItem "session", s = sst()
    console.log "NEW SESSION " + s
  else
    console.log "SESSION " + s
  stream.write JSON.stringify session: s
  query()

  $("#login").on "click", () ->
    window.open "https://ifoauth.herokuapp.com/auth/github?token=" +
      s + "&ride=" + window.location.href.split("#")[1], "Auth", "height=400,width=300"
    login()


  map = L.map("map").setView [48.505, 9.09], 10
  L.tileLayer('http://stamen-tiles-{s}.a.ssl.fastly.net/toner-lite/{z}/{x}/{y}.{ext}',
  	attribution: 'Map tiles by <a href="http://stamen.com">Stamen Design</a>, <a href="http://creativecommons.org/licenses/by/3.0">CC BY 3.0</a> &mdash; Map data &copy; <a href="http://www.openstreetmap.org/copyright">OpenStreetMap</a>',
  	subdomains: 'abcd',
  	minZoom: 0,
  	maxZoom: 20,
  	ext: 'png'
  ).addTo map
  L.control.zoom(position: "bottomright").addTo map

  geolocator.locateByIP ( (l) ->
    console.log l.address.city
    map.setView [l.coords.latitude, l.coords.longitude]
  ), ((err) ->
    console.log err
  ), 1 # 0 (FreeGeoIP), 1 (GeoPlugin), 2 (Wikimedia)


  points = []
  showMap = (p) ->
    points = []
    map.eachLayer (l) -> map.removeLayer l unless l.getAttribution
    from = $(this).siblings(".orig").html()
    to = $(this).siblings(".dest").html()
    pickup = orig()
    dropoff = dest()
    drawPath from, pickup, color: "#004565", weight: 7, dashArray:"1, 10", opacity: 1
    drawPath dropoff, to, color: "#004565", weight: 7, dashArray:"1, 10", opacity: 1
    if $(this).siblings(".driver").length
      console.log "driver"
      drawPath from, to, color: "#004565", weight: 10, opacity: 1
      drawPath pickup, dropoff, color: "#ffcc00", weight: 3, opacity: 1
    else
      console.log "passenger"
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
        l = L.geoJson().addTo map
        l.options = style: style
        l.addData "type": "LineString", "coordinates": pois
        points.push pois
        if points.length == 4
          panAndZoom points

  paths = {}
  getPath = (from, to, cb) ->
    if paths[from+to]
      cb decode paths[from+to]
    else
      console.log "hi"
      $.ajax HOST + "/path/" + encodeURI(from) + "/" + encodeURI(to)
      , success: (p) ->
        paths[from+to] = p
        cb decode p

  panAndZoom = (points) ->
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
      if height > width / 2
        bbx[1][1] = (b.getEast() - screen / 3.2)
        bbx[0][1] = (b.getWest() - screen / 3.2)
      else
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
        console.log text
        $.ajax
          url: API + "?q=" + encodeURI(text.toString()) #+ " &callback=?"
        #,  crossDomain: true
        #dataType: "jsonp"
        #  jsonp: "callback"
        #  jsonpCallback: "foo"
          success: (p) ->
            console.log "GOT " + p
            render null, p.split(",")
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
