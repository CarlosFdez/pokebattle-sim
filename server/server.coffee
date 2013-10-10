{createHmac} = require 'crypto'
{_} = require 'underscore'

{BattleQueue} = require './queue'
{Battle} = require './bw/battle'
{BattleController} = require './bw/battle_controller'
{Conditions} = require './conditions'
learnsets = require '../shared/learnsets'

class @BattleServer
  constructor: ->
    @queue = new BattleQueue()
    @battles = {}

  queuePlayer: (player, team) ->
    @queue.add(player, team)

  queuedPlayers: ->
    @queue.queuedPlayers()

  beginBattles: ->
    pairs = @queue.pairPlayers()
    battles = []

    # Create a battle for each pair
    for pair in pairs
      id = @createBattle(pair...)
      @beginBattle(id)
      battle = pair.map((o) -> o.player)
      battle.push(id)
      battles.push(battle)

    battles

  # Creates a battle and returns its battleId
  createBattle: (objects...) ->
    players = objects.map (object) -> object.player
    battleId = @generateBattleId(players)
    conditions = [ Conditions.TEAM_PREVIEW, Conditions.SLEEP_CLAUSE ]
    battle = new Battle(battleId, players: objects, conditions: conditions)
    @battles[battleId] = new BattleController(battle)
    battleId

  beginBattle: (battleId) ->
    @battles[battleId].beginBattle()

  # Generate a random ID for a new battle.
  generateBattleId: (players) ->
    # TODO load key from config or env
    hmac = createHmac('sha1', 'INSECURE KEY')
    hmac.update((new Date).toISOString())
    for player in players
      hmac.update(player.id)
    hmac.digest('hex')

  # Returns the battle with battleId.
  findBattle: (battleId) ->
    @battles[battleId]

  # Returns an empty array if the given team is valid, an array of errors
  # otherwise.
  validateTeam: (team) ->
    return [ "Invalid team format." ]  if team not instanceof Array
    return [ "Team must have 1 to 6 Pokemon."]  unless 1 <= team.length <= 6
    return team.map((pokemon, i) => @validatePokemon(pokemon, i + 1)).flatten()

  # Returns an empty array if the given Pokemon is valid, an array of errors
  # otherwise.
  validatePokemon: (pokemon, slot) ->
    {SpeciesData, FormeData} = Battle
    errors = []
    if !pokemon.name
      errors.push("No species given.")
      return errors
    species = SpeciesData[pokemon.name]
    if !species
      errors.push("Invalid species.")
      return errors

    @normalizePokemon(pokemon)
    forme = FormeData[pokemon.name][pokemon.forme]
    if !forme
      errors.push("Slot #{slot}: Invalid forme.")
      return errors

    errors.push("Slot #{slot}: Invalid level.")  if isNaN(pokemon.level)
    # TODO: 100 is a magic constant
    unless 1 <= pokemon.level <= 100
      errors.push("Slot #{slot}: Level must be between 1 and 100.")

    if pokemon.gender not in [ "M", "F", "Genderless" ]
      errors.push("Slot #{slot}: Invalid gender.")
    if species.genderRatio == -1 && pokemon.gender != "Genderless"
      errors.push("Slot #{slot}: Must be genderless.")
    if species.genderRatio == 0 && pokemon.gender != "M"
      errors.push("Slot #{slot}: Must be male.")
    if species.genderRatio == 8 && pokemon.gender != "F"
      errors.push("Slot #{slot}: Must be female.")
    if (typeof pokemon.evs != "object")
      errors.push("Slot #{slot}: Invalid evs.")
    if (typeof pokemon.ivs != "object")
      errors.push("Slot #{slot}: Invalid ivs.")
    if !Object.values(pokemon.evs).all((ev) -> 0 <= ev <= 255)
      errors.push("Slot #{slot}: EVs must be between 0 and 255.")
    if !Object.values(pokemon.ivs).all((iv) -> 0 <= iv <= 31)
      errors.push("Slot #{slot}: IVs must be between 0 and 31.")
    if pokemon.ability not in forme["abilities"] &&
       pokemon.ability != forme["hiddenAbility"]
      errors.push("Slot #{slot}: Invalid ability.")
    if pokemon.moves not instanceof Array
      errors.push("Slot #{slot}: Invalid moves.")
    # TODO: 4 is a magic constant
    else if !(1 <= pokemon.moves.length <= 4)
      errors.push("Slot #{slot}: Must have 1 to 4 moves.")
    else if !learnsets.checkMoveset(SpeciesData, FormeData, pokemon, 5, pokemon.moves)
      errors.push("Slot #{slot}: Invalid moveset.")
    return errors

  # Normalizes a Pokemon by setting default values where applicable.
  # Assumes that the Pokemon is a real Pokemon (i.e. its name is valid)
  normalizePokemon: (pokemon) ->
    pokemon.forme   ?= "default"
    pokemon.ability ?= Battle.FormeData[pokemon.name][pokemon.forme]?["abilities"][0]
    if !pokemon.gender?
      {genderRatio} = Battle.SpeciesData[pokemon.name]
      if genderRatio == -1 then pokemon.gender = "Genderless"
      else if Math.random() < (genderRatio / 8) then pokemon.gender = "F"
      else pokemon.gender = "M"
    pokemon.evs     ?= {}
    pokemon.ivs     ?= {}
    pokemon.level   ?= 100
    pokemon.level    = Math.floor(pokemon.level)
    return pokemon
