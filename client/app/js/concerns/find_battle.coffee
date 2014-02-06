# eventName should be one of "challenge" or "find battle"
# opts may include whether to enable clauses, for example
@createChallengePane = (opts) ->
  $wrapper = opts.populate
  $button = opts.button
  $cancel = opts.cancelButton || $()
  $accept = opts.acceptButton || $()
  $reject = opts.rejectButton || $()
  $buttons = $button.add($cancel).add($accept).add($reject)
  eventName = opts.eventName
  generation = opts.generation
  personId = opts.personId
  isChallenger = opts.isChallenger || false

  allTeams = JSON.parse(window.localStorage.getItem('teams'))
  selectedIndex = window.localStorage.getItem('selectedTeamIndex') || 0

  renderCurrentTeam = ($context) ->
    $selectTeam = $context.find('.select-team')
    currentTeam = allTeams[selectedIndex] || allTeams[0]
    html = JST['team_dropdown'](window: window, team: currentTeam)
    $selectTeam.html(html)

  cancelChallenge = ->
    disableButtons()
    if personId
      PokeBattle.socket.send("cancel #{eventName}", personId)
    else
      format = $selectFormat.data('format')
      PokeBattle.socket.send("cancel #{eventName}", format)
    $button.trigger('cancelChallenge').off('.challenge')

  disableButtons = ->
    $wrapper.find('.select').addClass('disabled')
    $buttons.addClass('disabled')

  # Enable buttons
  $buttons.removeClass('disabled')

  $wrapper.html(JST['new_battle']({isChallenger}))
  $selectFormat = $wrapper.find(".select-format")
  # Implement finding battle/challenging
  $button.on 'click.challenge', ->
    format = $selectFormat.data('format')
    # Toggle state when you press the button.
    if !$button.hasClass('disabled')
      teamJSON = allTeams[selectedIndex].pokemon
      # Send the event
      if personId
        PokeBattle.socket.send(eventName, personId, format, teamJSON)
      else
        PokeBattle.socket.send(eventName, format, teamJSON)
      $button.addClass('disabled').trigger('challenge')
    else
      cancelChallenge()

  # Implement cancel button.
  $cancel.on 'click.challenge', ->
    return  if $(this).hasClass('disabled')
    cancelChallenge()

  # Implement accept/reject buttons.
  $accept.on 'click.challenge', ->
    return  if $(this).hasClass('disabled')
    disableButtons()
    teamJSON = allTeams[selectedIndex].pokemon
    PokeBattle.socket.send("accept #{eventName}", personId, teamJSON)

  $reject.on 'click.challenge', ->
    return  if $(this).hasClass('disabled')
    disableButtons()
    PokeBattle.socket.send("reject #{eventName}", personId)

  if allTeams?.length > 0
    renderCurrentTeam($wrapper)
  else
    $selectTeam = $wrapper.find('.select-team')
    $selectTeam.html("You have no teams!")

  # Clicking the team dropdown brings down a team selection menu.
  $wrapper.find('.select-team').click (e) ->
    allTeams = JSON.parse(window.localStorage.getItem('teams'))
    if allTeams && allTeams.length > 0
      html = JST['team_dropdown'](window: window, teams: allTeams)
      $wrapper.find('.team-dropdown').html(html)

  # Selecting a team from the menu
  $wrapper.find('.team-dropdown').on 'click', '.select-team-dropdown-item', (e) ->
    slot = $(e.currentTarget).data('slot')
    selectedIndex = slot
    renderCurrentTeam($wrapper)

  # Selecting the format changes the dropdown.
  $wrapper.find('.format-dropdown').on 'click', '.select-format-dropdown-item', (e) ->
    $target = $(e.currentTarget)
    format = $target.data('format')
    $selectFormat.text($target.text())
    $selectFormat.data('format', format)

  # Auto-select format.
  if generation
    # If a generation is passed, auto-select it.
    $format = $wrapper.find(".format-dropdown a[data-format='#{generation}']")
    $format.first().click()
    $wrapper.find('.select-format').addClass('disabled')
  else
    # Auto-select first available format.
    $wrapper.find('.format-dropdown a').first().click()