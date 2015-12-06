tablesort = require "tablesort"
through = require "through2"
request = require "request"
es = require "event-stream"
html = require "./ride"
shoe = require "shoe"
HOST = "http://localhost:5000"
search = null
query = {}

$ () ->
  orig = autosuggest $("#orig")
  dest = autosuggest $("#dest")
  sort = tablesort($("table")[0])

  (stream = shoe "/sockjs")
  .pipe html().appendTo($("#rides")[0])
  .on "data", (data) -> sort.refresh()
  .onclose = () -> console.log "CLOSE"

  search = () ->
    if query.orig != orig() || query.dest != dest()
      history.replaceState {}, "von #{orig} nach #{dest}", HOST + "/#{orig()}/#{dest()}"
      stream.write orig() + "->" + dest()
      query = orig: orig(), dest: dest()
      console.log "SEARCH"

autosuggest = (div) ->
  div.find("input").focus();
  places = []
  text = null
  index = -1
  caret = 0
  div.find("input").keyup (e) ->
    k = e.keyCode;
    text = div.find("input").val().trim();
    if k == 37 # left
      caret = caret - 1
      if caret < 0
        $("#orig").find("input").focus()
    else if k == 39 # right
      caret = caret + 1
      if caret > text.length
        $("#dest").find("input").focus()
    else if k == 40 || k == 32 # up
      index = index + 1
    else if k == 38 # down
      index = index - 1
    else if k == 13 # enter
      div.find("input").val text + places[index]
      caret = text.length + places[index].length
      div.find(".suggest").html ""
      places = []
      search()
      return
    else
      caret = text.length
      if k == 8 # backspace (delete a character)
        index = -1
      if text.length > 0
        request.get HOST + "/q=" + encodeURI(text)
        .pipe(es.split ",").pipe es.writeArray render
      return
    render places.length == 0, places

  render = (err, names) ->
    return if err
    count = -1
    places = names
    html = places.map (place) ->
      count = count + 1
      "<a class='sug #{oddEven count}' id='#{active count}' >#{text + place}</a>"
    div.find(".suggest").html html.join('')

  active = (count) -> if count == index then 'active' else ''
  oddEven = (count) -> if count % 2 == 0 then 'even' else 'odd'
  () -> div.find("input").val().trim()
