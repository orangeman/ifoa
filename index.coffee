JSONStream = require "JSONStream"
tablesort = require "tablesort"
through = require "through2"
request = require "request"
hyperglue = require "hyperglue"
es = require "event-stream"
css = require "./ride"
shoe = require "shoe"
HOST = window.location.origin
rideHtml = require("fs").readFileSync("ride.html").toString()
search = null


$ () ->
  console.log window.location.pathname
  dest = autosuggest $("#dest")
  orig = autosuggest $("#orig")
  time = $(".time").last().html()
  sort = tablesort $("table")[0]
  console.log "time " + time

  rides = $("#rides")[0]
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
    rides.appendChild hyperglue(rideHtml, css ride)
    #sort.refresh()
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
      $("#rides").html ""


autosuggest = (div) ->
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
