$ () ->
  suggest $("#orig")
  suggest $("#dest")

suggest = (div) ->
  div.find("input").focus();
  places = []
  text = null
  index = -1
  caret = 0
  div.find("input").keyup (e) ->
    k = e.keyCode;
    text = div.find("input").val().trim();
    if k == 37
      caret = caret - 1
      if caret < 0
        $("#orig").find("input").focus()
    else if k == 39
      caret = caret + 1
      if caret > text.length
        $("#dest").find("input").focus()
    else if k == 40 || k == 32
      index = index + 1
    else if k == 38
      index = index - 1
    else if k == 13
      div.find("input").val text + places[index]
      caret = text.length + places[index].length
      div.find(".suggest").html ""
      places = []
      return
    else
      caret = text.length
      if k == 8 # backspace (delete a character)
        index = -1
      if text.length > 0
        $.get "/" + encodeURI(text), (data) ->
          if data && data.length > 0
            places = data.split ","
            renderSuggestions()
          else
            div.find( ".suggest" ).html('')
      return
    renderSuggestions places

  renderSuggestions = () ->
    count = 0
    row = null
    html = places.map (place) ->
      row = oddEven count
      active = activeWord count, index
      count = count + 1
      "<a class='sug "+row+"' id='"+active+"' >"+text+place+"</a>"
    div.find(".suggest").html html.join('')

activeWord = (count, index) -> if count == index then 'active' else ''

oddEven = (count) -> if count % 2 == 0 then 'even' else 'odd'
