class @BattleView extends Backbone.View
  battle_template: JST['battle']
  pokemon_template: JST['battle_pokemon']
  user_info_template: JST['battle_user_info']
  action_template: JST['battle_actions']
  team_preview_template: JST['battle_team_preview']

  events:
    'click .move': 'makeMove'
    'click .switch': 'switchPokemon'
    'click .submit_arrangement': 'submitTeamPreview'

  initialize: =>
    @selected = null
    @chatView = null
    @lastMove = null
    @spectators = new UserList([])
    @renderChat()
    @listenTo(@model, 'team_preview', @renderTeamPreview)

  renderBattle: =>
    locals =
      yourTeam     : @model.getTeam()
      opponentTeam : @model.getOpponentTeam()
      numActive    : @model.numActive
      yourIndex    : @model.index
      window       : window
    @$('.battle_pane').html @battle_template(locals)
    @addImages()
    this

  renderChat: =>
    @chatView = new ChatView(
      el: @$('.chat')
      collection: @spectators
      chatEvent: 'send battle chat'
      chatArgs: [ @model.id ]
    ).render()
    this

  # TODO: Support 2v2
  renderActions: (validActions = []) =>
    locals =
      yourTeam     : @model.getTeam()
      validActions : validActions[0] || {}
      window       : window
    @$('.battle_actions').html @action_template(locals)
    this

  renderUserInfo: =>
    locals =
      yourTeam     : @model.getTeam()
      opponentTeam : @model.getOpponentTeam()
      numActive    : @model.numActive
      yourIndex    : @model.index
      window       : window
    @$('.battle_user_info').html @user_info_template(locals)
    this

  renderTeamPreview: (teams) =>
    locals =
      teams        : teams
      numActive    : @model.numActive
      yourIndex    : @model.index
      isSpectating : @model.get('spectating')
      window       : window
    @$('.battle_pane').html @team_preview_template(locals)
    $arrangeTeam = @$('.arrange_team')
    $arrangeTeam.sortable()
    $arrangeTeam.on 'sortupdateplaceholder', (e, $placeholder) ->
      $visible = $arrangeTeam.children(":visible")
      $first = $visible.first()
      $first.addClass('first-child')
      $visible.not($first).removeClass('first-child')

  submitTeamPreview: (e) =>
    $currentTarget = $(e.currentTarget)
    return  if $currentTarget.hasClass('disabled')
    $currentTarget.addClass('disabled')
    $teamPreview = @$('.battle_teams')
    indices = for element in @$('.arrange_team .pokemon_icon')
      $(element).data('index')
    @model.arrangeTeam(indices)
    move($teamPreview)
      .set('opacity', 0).duration('.25s')
      .end(-> $teamPreview.remove())

  addImages: ($images) =>
    $images ||= @$('.preload')
    $images.each ->
      $this = $(this)
      front = $this.closest('.pokemon').hasClass('top')
      name  = $this.data('name')
      forme = $this.data('forme')
      shiny = $this.data('shiny')
      {id}  = SpeciesData[name]
      url   = PokemonSprite(id, forme, front: front, shiny: shiny)
      scale = if front then 1 else 2
      addPokemonImage($this, url, scale: scale)

  changeHP: (player, slot, done) =>
    $pokemon = @$pokemon(player, slot)
    $info = $pokemon.find(".pokemon-info")
    $hp = $info.find('.hp')
    $allHP = $info.find('.hp, .hp-red')
    $hpText = $info.find('.hp-text')
    pokemon = @model.getPokemon(player, slot)
    percent = Math.floor(pokemon.hp * 100 / pokemon.maxHP)
    percent = Math.max(percent, 0)
    if percent <= 25
      $hp.css(backgroundColor: "#f00")
    else if percent <= 50
      $hp.css(backgroundColor: "#ff0")
    else
      $hp.css(backgroundColor: "#0f0")
    $allHP.width("#{percent}%")
    $hpText.text("#{percent}%")
    done()

  switchIn: (player, slot, done) =>
    $oldPokemon = @$pokemon(player, slot)
    pokemon = @model.getPokemon(player, slot)
    pokemonClass = "pokemon#{player}-#{slot}"
    position = (if player == @model.index then "bottom" else "top")
    @renderUserInfo()

    # Prepare old/new pokemon
    $oldPokemon.removeClass(pokemonClass)
    $newPokemon = $("""<div class="pokemon #{pokemonClass} #{position}">
      #{@pokemon_template(pokemon: pokemon)}
    </div>""")
    $newPokemon.css(opacity: 0)
    $newSprite = $newPokemon.find('.sprite')

    # Add Pokemon
    $newPokemon.appendTo(@$(".battle_pane"))
    @addImages($newPokemon.find('.preload'))

    # Create and position pokeball
    pos = $newSprite.position()
    x = pos.left + $newSprite.width() / 2 - 11
    y = pos.top + $newSprite.height() / 3
    $pokeball = @makePokeball(x, y)
    $pokeball.css(opacity: 0)
    $pokeball.appendTo(@$(".battle_pane"))

    # Start animations
    $pokeball.css(opacity: 1)
    releasePokemon = =>
      $pokeball.css(opacity: 0)
      move($newSprite)
        .y(-15).scale(.1).duration(0).then()
        .scale(10).duration('.25s').then()
        .y(15).duration('.25s').ease('ease-out').pop().pop().end =>
          @removePokeball($pokeball)
          done()
      move($newPokemon).set('opacity', 1).end()
    setTimeout(releasePokemon, 250)

  switchOut: (player, slot, done) =>
    $pokemon = @$pokemon(player, slot)
    $sprite = $pokemon.find('.sprite')
    width = $sprite.width()
    height = $sprite.height()
    move($sprite).scale(0.1).x(width / 2).y(height).duration('.15s').end()
    move($pokemon).set('opacity', 0).duration('.25s').end ->
      $pokemon.remove()
      done()

  makePokeball: (x, y) =>
    $pokeball = $("""<div class="pokeball"/>""")
    $pokeball.css(top: y, left: x)
    size = 22
    $pokeball.width(size).height(size)
    func = ->
      $pokeball.css(backgroundPositionY: -10 - func.counter * 40)
      func.counter = (func.counter + 1) % 8
    func.counter = 1
    id = setInterval(func, 40)
    $pokeball.data('animation-id', id)
    $pokeball

  removePokeball: ($pokeball) =>
    id = $pokeball.data('animation-id')
    clearTimeout(id)
    $pokeball.remove()

  logMove: (player, slot, moveName, done) =>
    {owner} = @model.getTeam(player)
    pokemon = @model.getPokemon(player, slot)
    @addLog("#{owner}'s #{pokemon.name} used <strong>#{moveName}</strong>!")
    @lastMove = moveName
    done()

  moveSuccess: (player, slot, targetSlot, done) =>
    done()

  attachPokemon: (player, slot, attachment, done) =>
    switch attachment
      when 'SubstituteAttachment'
        $pokemon = @$pokemon(player, slot)
        $sprite = @$sprite(player, slot)
        spriteWidth = $sprite.width()
        spriteHeight = $sprite.height()
        $sprite.addClass('fade')
        position = $sprite.position()
        substituteUrl = (if @isFront(player) then "substitute" else "subback")
        substituteUrl = "http://sprites.pokecheck.org/o/#{substituteUrl}.gif"
        addPokemonImage $pokemon, substituteUrl, callback: ($image) ->
          $image.addClass('substitute')
          width = $image.width()
          height = $image.height()
          x = position.left + ((spriteWidth - width) >> 1)
          y = position.top + ((spriteHeight - height) >> 1)
          yOffset = 200
          $image.remove()
          $image.css(left: x, top: y - yOffset)
          $image.appendTo($pokemon)
          setTimeout ->
            move($image)
              .y( yOffset).ease('ease-in-quad').duration('.2s').then()
              .y(-yOffset >> 3).ease('ease-out-quad').duration('.1s').then()
              .y( yOffset >> 3).ease('ease-in-quad').duration('.1s').then()
              .pop().pop().pop().end(done)
          , 0
      when 'Paralyze'
        $pokemon = @$pokemon(player, slot)
        $effects = $pokemon.find('.pokemon-effects')
        $effects.append("""<div class="pokemon-effect paralyze">PAR</div>""")
        done()
      when 'Burn'
        $pokemon = @$pokemon(player, slot)
        $effects = $pokemon.find('.pokemon-effects')
        $effects.append("""<div class="pokemon-effect burn">BRN</div>""")
        done()
      when 'Poison'
        $pokemon = @$pokemon(player, slot)
        $effects = $pokemon.find('.pokemon-effects')
        $effects.append("""<div class="pokemon-effect poison">PSN</div>""")
        done()
      when 'Toxic'
        $pokemon = @$pokemon(player, slot)
        $effects = $pokemon.find('.pokemon-effects')
        $effects.append("""<div class="pokemon-effect toxic">TOX</div>""")
        done()
      when 'Freeze'
        $pokemon = @$pokemon(player, slot)
        $effects = $pokemon.find('.pokemon-effects')
        $effects.append("""<div class="pokemon-effect freeze">FRZ</div>""")
        done()
      when 'Sleep'
        $pokemon = @$pokemon(player, slot)
        $effects = $pokemon.find('.pokemon-effects')
        $effects.append("""<div class="pokemon-effect sleep">SLP</div>""")
        done()
      else
        done()

  attachTeam: (player, attachment, done) =>
    done()

  attachBattle: (attachment, done) =>
    done()

  unattachPokemon: (player, slot, effect, done) =>
    switch effect
      when 'SubstituteAttachment'
        $pokemon = @$pokemon(player, slot)
        $sprite = @$sprite(player, slot)
        $sprite.removeClass('fade')
        hideSub = ->
          $substitute = $pokemon.find('.substitute').first()
          if $substitute.length == 0
            setTimeout(hideSub, 20)
            return
          move($substitute).set('opacity', 0).y(300)
            .then(-> $substitute.remove()).end(done)
        hideSub()
      when 'Paralyze'
        $pokemon = @$pokemon(player, slot)
        $effects = $pokemon.find('.pokemon-effect.paralyze').remove()
        done()
      when 'Burn'
        $pokemon = @$pokemon(player, slot)
        $effects = $pokemon.find('.pokemon-effect.burn').remove()
        done()
      when 'Poison'
        $pokemon = @$pokemon(player, slot)
        $effects = $pokemon.find('.pokemon-effect.poison').remove()
        done()
      when 'Toxic'
        $pokemon = @$pokemon(player, slot)
        $effects = $pokemon.find('.pokemon-effect.toxic').remove()
        done()
      when 'Freeze'
        $pokemon = @$pokemon(player, slot)
        $effects = $pokemon.find('.pokemon-effect.freeze').remove()
        done()
      when 'Sleep'
        $pokemon = @$pokemon(player, slot)
        $effects = $pokemon.find('.pokemon-effect.sleep').remove()
        done()
      else
        done()

  unattachTeam: (slot, effect, done) =>
    done()

  unattachBattle: (effect, done) =>
    done()

  announceWinner: (player, done) =>
    {owner} = @model.getTeam(player)
    @chatView.print("<h3>#{owner} won!</h3>")
    @model.set('finished', true)
    done()

  announceForfeit: (player, done) =>
    {owner} = @model.getTeam(player)
    @chatView.print("<h3>#{owner} has forfeited!</h3>")
    @model.set('finished', true)
    done()

  $pokemon: (player, slot) =>
    @$(".pokemon#{player}-#{slot}")

  $sprite: (player, slot) =>
    @$pokemon(player, slot).find('.sprite')

  isFront: (player) =>
    @model.index != player

  faint: (player, slot, done) =>
    $pokemon = @$pokemon(player, slot)
    $image = $pokemon.find('.sprite img')
    move($image).set('top', '100%').duration('.25s').ease('ease-in').end()
    move($pokemon).set('opacity', 0).end ->
      $pokemon.remove()
      done()
    @renderUserInfo()

  getMoveName: (el) =>
    $el = $(el)
    $el = $el.closest('.button')  if !$el.hasClass('button')
    $el.data('move-id')

  isDisabled: (el) =>
    $el = $(el)
    $el = $el.closest('.button')  if !$el.hasClass('button')
    $el.hasClass('disabled')

  enableButtons: (validActions) =>
    @renderActions(validActions)

  disableButtons: =>
    @renderActions()

  addLog: (message) =>
    @chatView.print("<p>#{message}</p>")

  beginTurn: (turn, done) =>
    @chatView.print("<h2>Turn #{turn}</h2>")
    @model.set('turn', turn)
    done()

  makeMove: (e) =>
    moveName = @getMoveName(e.target)
    if @isDisabled()
      console.log "Cannot use #{moveName}."
      return
    console.log "Making move #{moveName}"
    @model.makeMove(moveName)
    @disableButtons()

  switchPokemon: (e) =>
    toSlot = $(e.currentTarget).data('slot')
    if @isDisabled()
      console.log "Cannot switch to #{toSlot}."
      return
    console.log "Switching to #{toSlot}"
    toSlot = parseInt(toSlot, 10)
    @model.makeSwitch(toSlot)
    @disableButtons()

addPokemonImage = ($div, url, options = {}) ->
  scale = options.scale || 1
  image = new Image()
  $image = $(image)
  $image.load ->
    {width, height} = image
    if scale != 1
      width  *= scale
      height *= scale
      $image.width(width)
      $image.height(height)
    top  = ($div.height() - height) >> 1
    left = ($div.width() - width) >> 1
    $image.css(position: 'absolute', top: top, left: left)
    $image.appendTo($div)
    options.callback?($image, left, top)  # $image, x, y
  image.src = url
