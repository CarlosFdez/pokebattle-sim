{Protocol} = require '../../shared/protocol'
{Weather} = require '../../shared/weather'
util = require './util'
Query = require './queries'
{_} = require 'underscore'

@Attachment = Attachment = {}
@Status = Status = {}

class @Attachments
  constructor: ->
    @attachments = []

  push: (attachmentClass, options={}, attributes={}) ->
    throw new Error("Passed a non-existent Attachment.")  if !attachmentClass?
    return null  if Query.untilFalse('shouldAttach', @all(), attachmentClass, options) == false
    return null  if attachmentClass.preattach?(options, attributes) == false
    attachment = @get(attachmentClass)
    if !attachment?
      attachment = new attachmentClass()
      for attribute, value of attributes
        attachment[attribute] = value
      @attachments.push(attachment)
      attachment.initialize?(options)

    return null  if attachment.layers == attachment.maxLayers
    attachment.layers++
    return attachment

  unattach: (klass) ->
    index = @indexOf(klass)
    if index >= 0
      attachment = @attachments.splice(index, 1)[0]
      attachment.unattach?()
      attachment.attached = false
      attachment

  unattachAll: (condition) ->
    condition ||= -> true
    i = 0
    while i < @attachments.length
      attachment = @attachments[i]
      if condition(attachment)
        attachment.unattach?()
        @attachments.splice(i, 1)
      else
        i++

  # Returns a list of attachments that can be passed to another Pokemon.
  getPassable: ->
    passable = @attachments.filter((attachment) -> attachment.passable)
    passable.map((a) -> a.constructor)

  indexOf: (attachment) ->
    @attachments.map((a) -> a.constructor).indexOf(attachment)

  get: (attachment) ->
    @attachments[@indexOf(attachment)]

  contains: (attachment) ->
    @indexOf(attachment) != -1

  all: ->
    _.clone(@attachments)

  size: ->
    @attachments.length

# Attachments represents a pokemon's state. Some examples are
# status effects, entry hazards, and fire spin's trapping effect.
# Attachments are "attached" with Pokemon.attach(), and after
# that the attachment can be retrieved with Attachment.pokemon
class @BaseAttachment
  name: "BaseAttachment"

  maxLayers: 1

  constructor: ->
    @layers = 0
    @attached = true

  valid: ->
    return false  if !@attached
    return false  if @battle?.isOver()
    return false  if @item && @pokemon?.item && @pokemon?.isItemBlocked()
    return false  if @ability && @pokemon?.isAbilityBlocked()
    return false  if @isAliveCheck() == false
    return true

  isAliveCheck: ->
    @pokemon && @pokemon.isAlive()

  # initialize: ->
  # unattach: ->
  # calculateWeight: (weight) -> weight
  # afterBeingHit: (move, user, target, damage, isDirect) ->
  # afterSuccessfulHit: (move, user, target, damage) ->
  # beforeMove: (move, user, targets) ->
  # isImmune: (type) ->
  # switchOut: ->
  # switchIn: ->
  # beginTurn: ->
  # endTurn: ->
  # update: (owner) ->
  # editBoosts: (stages) ->
  # afterFaint: ->
  # shouldBlockExecution: (move, user) ->

  # Pokemon-specific attachments
  # TODO: Turn Attachment into abstract class
  # TODO: Move into own PokemonAttachment
  # editHp: (stat) -> stat
  # editAttack: (stat) -> stat
  # editSpeed: (stat) -> stat
  # editSpecialAttack: (stat) -> stat
  # editDefense: (stat) -> stat
  # editSpecialDefense: (stat) -> stat

# Used for effects like Tailwind or Reflect.
class @TeamAttachment extends @BaseAttachment
  name: "TeamAttachment"

# Used for effects like Trick Room or Magic Room.
class @BattleAttachment extends @BaseAttachment
  name: "BattleAttachment"

# An attachment that removes itself when a pokemon
# deactivates.
class @VolatileAttachment extends @BaseAttachment
  name: "VolatileAttachment"
  volatile: true

class @Attachment.Flinch extends @VolatileAttachment
  name: "FlinchAttachment"

  beforeMove: (move, user, targets) ->
    @battle.cannedText('FLINCH', @pokemon)
    @pokemon.boost(speed: 1)  if @pokemon.hasAbility("Steadfast")
    false

  endTurn: ->
    @pokemon.unattach(@constructor)

class @Attachment.Confusion extends @VolatileAttachment
  name: "ConfusionAttachment"
  passable: true

  initialize: (attributes = {}) ->
    cannedText = attributes.cannedText ? 'CONFUSION_START'
    @turns = @battle?.rng.randInt(1, 4, "confusion turns") || 1
    @pokemon?.tell(Protocol.POKEMON_ATTACH, @name)
    @battle?.cannedText(cannedText, @pokemon)
    @turn = 0

  @preattach: (options, attributes) ->
    {pokemon} = attributes
    {source} = options
    return false  if (pokemon.team?.has(Attachment.Safeguard) && source != pokemon)

  unattach: ->
    @pokemon?.tell(Protocol.POKEMON_UNATTACH, @name)

  beforeMove: (move, user, targets) ->
    @battle.cannedText('IS_CONFUSED', @pokemon)
    @turn++
    if @turn > @turns
      @battle.cannedText('CONFUSION_END', @pokemon)
      @pokemon.unattach(@constructor)
    else if @battle.rng.next('confusion') < 0.5
      @battle.cannedText('CONFUSION_HURT_SELF', @pokemon)
      damage = @battle.confusionMove.calculateDamage(@battle, user, user)
      user.damage(damage, source: "move")
      return false

class @Attachment.Disable extends @VolatileAttachment
  name: "DisableAttachment"

  @preattach: (options, attributes) ->
    {pokemon} = attributes
    move = options.move ? pokemon.lastMove
    return false  if !move? || !pokemon.knows(move) || pokemon.pp(move) <= 0

  initialize: (attributes = {}) ->
    @blockedMove = attributes.move ? @pokemon.lastMove
    @turns = 4
    @battle.cannedText('DISABLE_START', @pokemon, @blockedMove.name)
    @pokemon.blockMove(@blockedMove)

  beginTurn: ->
    @pokemon.blockMove(@blockedMove)

  beforeMove: (move, user, target) ->
    if move == @blockedMove
      @battle.cannedText('DISABLE_CONTINUE', @pokemon, move.name)
      return false

  endTurn: ->
    @turns--
    if @turns == 0
      @battle.cannedText('DISABLE_END', @pokemon)
      @pokemon.unattach(@constructor)

class @Attachment.Yawn extends @VolatileAttachment
  name: 'YawnAttachment'

  @preattach: (options, attributes) ->
    {pokemon} = attributes
    return false  if pokemon.hasStatus()
    return false  if pokemon.team.has(Attachment.Safeguard)

  initialize: (attributes = {}) ->
    {@source} = attributes
    @turn = 0
    @battle.cannedText('YAWN_BEGIN', @pokemon)

  endTurn: ->
    @turn += 1
    if @turn == 2
      @pokemon.attach(Status.Sleep, {@source, bypassSafeguard: true})
      @pokemon.unattach(@constructor)

# TODO: Does weight get lowered if speed does not change?
class @Attachment.Autotomize extends @VolatileAttachment
  name: "AutotomizeAttachment"

  maxLayers: -1

  calculateWeight: (weight) ->
    Math.max(weight - 100 * @layers, .1)

class @Attachment.Nightmare extends @VolatileAttachment
  name: "NightmareAttachment"

  @preattach: (options, attributes) ->
    {pokemon} = attributes
    return false  if !pokemon.hasStatus(Status.Sleep)

  initialize: ->
    @battle.message("#{@pokemon.name} began having a nightmare!")

  endTurn: ->
    if @pokemon.has(Status.Sleep)
      amount = Math.floor(@pokemon.stat('hp') / 4)
      if @pokemon.damage(amount)
        @battle.message "#{@pokemon.name} is locked in a nightmare!"
    else
      @pokemon.unattach(@constructor)

class @Attachment.Safeguard extends @TeamAttachment
  name: "SafeguardAttachment"

  initialize: (attributes) ->
    {@source} = attributes
    @turns = 5
    @turn = 0

  endTurn: ->
    @turn++
    if @turn >= @turns
      @battle.cannedText('SAFEGUARD_END', @source)
      @team.unattach(@constructor)

class @Attachment.Taunt extends @VolatileAttachment
  name: "TauntAttachment"

  initialize: (attributes) ->
    @turns = 4
    @turns = 3  if @battle.willMove(@pokemon)
    @turn = 0
    @battle.cannedText('TAUNT_START', @pokemon)

  beginTurn: ->
    for move in @pokemon.moves
      if move.power == 0
        @pokemon.blockMove(move)

  beforeMove: (move, user, targets) ->
    # TODO: user is always == pokemon. Will this change?
    if user == @pokemon && move.power == 0
      @battle.cannedText('TAUNT_PREVENT', @pokemon, move.name)
      return false

  endTurn: ->
    @turn++
    if @turn >= @turns
      @battle.cannedText('TAUNT_END', @pokemon)
      @pokemon.unattach(@constructor)

class @Attachment.HealBlock extends @VolatileAttachment
  name: "HealBlockAttachment"

  initialize: (attributes) ->
    @turns = 5
    @turn = 0
    @battle.cannedText('HEAL_BLOCK_START', @pokemon)

  beginTurn: ->
    for move in @pokemon.moves
      if move.hasFlag("heal")
        @pokemon.blockMove(move)

  beforeMove: (move, user, targets) ->
    # TODO: user is always == pokemon. Will this change?
    if user == @pokemon && move.hasFlag("heal")
      @battle.cannedText('HEAL_BLOCK_PREVENT', @pokemon, move.name)
      return false

  endTurn: ->
    @turn++
    if @turn >= @turns
      @battle.cannedText('HEAL_BLOCK_END', @pokemon)
      @pokemon.unattach(@constructor)

class @Attachment.Tailwind extends @TeamAttachment
  name: "TailwindAttachment"

  initialize: ->
    @turns = 4
    @turn = 0

  editSpeed: (speed) ->
    2 * speed

  endTurn: ->
    @turn++
    if @turn >= @turns
      @battle.cannedText('TAILWIND_END')
      @team.unattach(@constructor)

class @Attachment.Wish extends @TeamAttachment
  name: "WishAttachment"

  initialize: (attributes) ->
    {user} = attributes
    @amount = Math.round(user.stat('hp') / 2)
    @wisherName = user.name
    @slot = @team.indexOf(user)
    @turns = 2
    @turn = 0

  endTurn: ->
    @turn++
    if @turn >= @turns
      pokemon = @team.at(@slot)
      if !pokemon.isFainted()
        @battle.cannedText('WISH_END', @wisherName)
        pokemon.heal(@amount)
      @team.unattach(@constructor)

class @Attachment.PerishSong extends @VolatileAttachment
  name: "PerishSongAttachment"
  passable: true

  initialize: ->
    @turns = 4
    @turn = 0
    @battle.cannedText('PERISH_SONG_START')

  endTurn: ->
    @turn++
    @battle.cannedText('PERISH_SONG_CONTINUE', @pokemon, @turns - @turn)
    if @turn >= @turns
      @pokemon.faint()
      @pokemon.unattach(@constructor)

class @Attachment.Roost extends @VolatileAttachment
  name: "RoostAttachment"

  initialize: ->
    @oldTypes = @pokemon.types
    @pokemon.types = (type for type in @pokemon.types when type != 'Flying')
    if @pokemon.types.length == 0 then @pokemon.types = [ 'Normal' ]

  endTurn: ->
    @pokemon.types = @oldTypes
    @pokemon.unattach(@constructor)

class @Attachment.Encore extends @VolatileAttachment
  name: "EncoreAttachment"

  initialize: ->
    @turns = 4
    @turns = 3  if @battle.willMove(@pokemon)
    @turn = 0
    @move = @pokemon.lastMove

  beginTurn: ->
    @pokemon.lockMove(@move)

  endTurn: ->
    @turn++
    if @turn >= @turns || @pokemon.pp(@move) == 0
      @battle.cannedText('ENCORE_END', @pokemon)
      @pokemon.unattach(@constructor)

class @Attachment.Torment extends @VolatileAttachment
  name: "TormentAttachment"

  initialize: ->
    @battle.cannedText('TORMENT_START', @pokemon)

  beginTurn: ->
    @pokemon.blockMove(@pokemon.lastMove)  if @pokemon.lastMove?

class @Attachment.Spikes extends @TeamAttachment
  name: "SpikesAttachment"

  maxLayers: 3

  initialize: ->
    id = @team.playerId
    @battle.cannedText('SPIKES_START', @battle.getPlayerIndex(id))

  switchIn: (pokemon) ->
    return  if pokemon.isImmune("Ground")
    fraction = (10 - 2 * @layers)
    hp = pokemon.stat('hp')
    damage = Math.floor(hp / fraction)
    if pokemon.damage(damage)
      @battle.cannedText('SPIKES_HURT', pokemon)

  unattach: ->
    id = @team.playerId
    @battle.cannedText('SPIKES_END', @battle.getPlayerIndex(id))

class @Attachment.StealthRock extends @TeamAttachment
  name: "StealthRockAttachment"

  initialize: ->
    id = @team.playerId
    @battle.cannedText('STEALTH_ROCK_START', @battle.getPlayerIndex(id))

  switchIn: (pokemon) ->
    multiplier = util.typeEffectiveness("Rock", pokemon.types)
    hp = pokemon.stat('hp')
    damage = ((hp * multiplier) >> 3)
    if pokemon.damage(damage)
      @battle.cannedText('STEALTH_ROCK_HURT', pokemon)

  unattach: ->
    id = @team.playerId
    @battle.cannedText('STEALTH_ROCK_END', @battle.getPlayerIndex(id))

class @Attachment.ToxicSpikes extends @TeamAttachment
  name: "ToxicSpikesAttachment"

  maxLayers: 2

  initialize: ->
    id = @team.playerId
    @battle.cannedText('TOXIC_SPIKES_START', @battle.getPlayerIndex(id))

  switchIn: (pokemon) ->
    if pokemon.hasType("Poison") && !pokemon.isImmune("Ground")
      @team.unattach(@constructor)

    return  if pokemon.isImmune("Poison") || pokemon.isImmune("Ground")

    if @layers == 1
      pokemon.attach(Status.Poison)
    else
      pokemon.attach(Status.Toxic)

  unattach: ->
    id = @team.playerId
    @battle.cannedText('TOXIC_SPIKES_END', @battle.getPlayerIndex(id))

# A trap created by Fire Spin, Magma Storm, Bind, Clamp, etc
class @Attachment.Trap extends @VolatileAttachment
  name: "TrapAttachment"

  initialize: (attributes) ->
    {@moveName, @user, @turns} = attributes
    @user.attach(Attachment.TrapLeash, target: @pokemon)

  beginTurn: ->
    @pokemon.blockSwitch()

  endTurn: ->
    # For the first numTurns turns it will damage, and at numTurns + 1 it will wear off.
    # Therefore, if @turns = 5, this attachment should actually last for 6 turns.
    if @turns == 0
      @pokemon.unattach(@constructor)
    else
      amount = Math.floor(@pokemon.stat('hp') / @getDamagePerTurn())
      if @pokemon.damage(amount)
        @battle.cannedText('TRAP_HURT', @pokemon, @moveName)
      @turns -= 1

  getDamagePerTurn: ->
    if @user.hasItem("Binding Band")
      8
    else
      16

  unattach: ->
    @battle.cannedText('FREE_FROM', @pokemon, @moveName)
    @user.unattach(Attachment.TrapLeash)
    delete @user

# If the creator if fire spin switches out, the trap will end
# TODO: What happens if another ability removes the trap, and then firespin is used again?
class @Attachment.TrapLeash extends @VolatileAttachment
  name: "TrapLeashAttachment"

  initialize: (attributes) ->
    {@target} = attributes

  unattach: ->
    @target.unattach(Attachment.Trap)
    delete @target

# Has a 50% chance to immobilize a Pokemon before it moves.
class @Attachment.Attract extends @VolatileAttachment
  name: "AttractAttachment"

  @preattach: (options, attributes) ->
    {source} = options
    {pokemon} = attributes
    return false  if (!(pokemon.gender == 'M' && source.gender == 'F') &&
                      !(pokemon.gender == 'F' && source.gender == 'M'))

  initialize: (attributes) ->
    {@source} = attributes
    if @pokemon.hasItem("Destiny Knot") && !@source.has(Attachment.Attract)
      @pokemon.removeItem()
      @source.attach(Attachment.Attract, source: @pokemon)
    @battle.message("#{@pokemon.name} fell in love with #{@source.name}!")

  beforeMove: (move, user, targets) ->
    if @source not in @battle.getOpponents(@pokemon)
      @pokemon.unattach(@constructor)
      return
    if @battle.rng.next('attract chance') < .5
      @battle.message "#{@pokemon.name} is immobilized by love!"
      return false

class @Attachment.FocusEnergy extends @VolatileAttachment
  name: "FocusEnergyAttachment"
  passable: true

class @Attachment.MicleBerry extends @VolatileAttachment
  name: "MicleBerryAttachment"

  initialize: ->
    @turns = 1

  editAccuracy: (accuracy) ->
    Math.floor(accuracy * 1.2)

  endTurn: ->
    if @turns == 0
      @pokemon.unattach(@constructor)
    else
      @turns--

class @Attachment.Metronome extends @VolatileAttachment
  name: "MetronomeAttachment"

  maxLayers: 5

  initialize: (attributes) ->
    {@move} = attributes

  beforeMove: (move) ->
    @pokemon.unattach(@constructor)  if move != @move

class @Attachment.Screen extends @TeamAttachment
  name: "ScreenAttachment"

  initialize: (attributes) ->
    {user} = attributes
    @turns = (if user?.hasItem("Light Clay") then 8 else 5)

  endTurn: ->
    @turns--
    if @turns == 0
      @team.unattach(@constructor)

  unattach: ->
    @team.tell(Protocol.TEAM_UNATTACH, @name)

class @Attachment.Reflect extends @Attachment.Screen
  name: "ReflectAttachment"

  modifyDamageTarget: (move, user) ->
    if move.isPhysical() && !user.crit && !user.hasAbility("Infiltrator")
      return 0x800
    return 0x1000

class @Attachment.LightScreen extends @Attachment.Screen
  name: "LightScreenAttachment"

  modifyDamageTarget: (move, user) ->
    if move.isSpecial() && !user.crit && !user.hasAbility("Infiltrator")
      return 0x800
    return 0x1000

class @Attachment.Identify extends @VolatileAttachment
  name: "IdentifyAttachment"

  initialize: (attributes) ->
    {@types} = attributes

  editBoosts: (stages) ->
    stages.evasion = 0
    stages

  isImmune: (type) ->
    return false  if type in @types

class @Attachment.DefenseCurl extends @VolatileAttachment
  name: "DefenseCurl"

class @Attachment.FocusPunch extends @VolatileAttachment
  name: "FocusPunchAttachment"

  beforeMove: (move, user, targets) ->
    hit = user.lastHitBy
    return  if !hit?
    if !hit.move.isNonDamaging() && hit.turn == @battle.turn && hit.direct
      @battle.message "#{user.name} lost its focus and couldn't move!"
      return false

  afterMove: ->
    @pokemon.unattach(@constructor)

class @Attachment.MagnetRise extends @VolatileAttachment
  name: "MagnetRiseAttachment"
  passable: true

  initialize: ->
    @turns = 5

  isImmune: (type) ->
    return true  if type == "Ground"

  endTurn: ->
    @turns -= 1
    @pokemon.unattach(@constructor)  if @turns == 0

class @Attachment.LockOn extends @VolatileAttachment
  name: "LockOnAttachment"

  initialize: (attributes) ->
    {@target} = attributes
    @turns = 2

  # Effect hardcoded in Move#willMiss

  endTurn: ->
    @turns -= 1
    @pokemon.unattach(@constructor)  if @turns == 0

class @Attachment.Minimize extends @VolatileAttachment
  name: "MinimizeAttachment"

class @Attachment.MeanLook extends @VolatileAttachment
  name: "MeanLookAttachment"

  initialize: (attributes) ->
    {@user} = attributes
    @user.attach(Attachment.MeanLookLeash, target: @pokemon)

  beginTurn: ->
    @pokemon.blockSwitch()

  unattach: ->
    @user.unattach(Attachment.MeanLookLeash)
    delete @user

class @Attachment.MeanLookLeash extends @VolatileAttachment
  name: "MeanLookAttachment"

  initialize: (attributes) ->
    {@target} = attributes

  unattach: ->
    @target.unattach(Attachment.MeanLook)
    delete @target

class @Attachment.Recharge extends @VolatileAttachment
  name: "RechargeAttachment"

  initialize: ->
    @turns = 2

  beginTurn: ->
    @pokemon.blockSwitch()
    @pokemon.blockMoves()
    id = @battle.getOwner(@pokemon)
    @battle.recordMove(id, @battle.getMove("Recharge"))

  beforeMove: (move, user, targets) ->
    @battle.message "#{user.name} must recharge!"
    return false

  endTurn: ->
    @turns -= 1
    @pokemon.unattach(@constructor)  if @turns == 0

class @Attachment.Momentum extends @VolatileAttachment
  name: "MomentumAttachment"

  maxLayers: 5

  initialize: (attributes) ->
    {@move} = attributes
    @turns = 1

  beginTurn: ->
    @pokemon.blockSwitch()
    @pokemon.lockMove(@move)

  endTurn: ->
    @turns -= 1
    @pokemon.unattach(@constructor)  if @turns == 0 || @layers == @maxLayers

class @Attachment.MeFirst extends @VolatileAttachment
  name: "MeFirstAttachment"

  modifyAttack: ->
    0x1800

  endTurn: ->
    @pokemon.unattach(@constructor)

class @Attachment.Charge extends @VolatileAttachment
  name: "ChargeAttachment"

  initialize: ->
    @turns = 2

  modifyAttack: (move, target) ->
    return 0x2000  if move.getType(@battle, @pokemon, target) == 'Electric'
    return 0x1000

  endTurn: ->
    @turns -= 1
    @pokemon.unattach(@constructor)  if @turns == 0

class @Attachment.LeechSeed extends @VolatileAttachment
  name: "LeechSeedAttachment"
  passable: true

  initialize: (attributes) ->
    {@source} = attributes
    @slot = @source.team.indexOf(@source)
    @battle.cannedText('LEECH_SEED_START', @pokemon)

  endTurn: ->
    user = @source.team.at(@slot)
    return  if user.isFainted() || @pokemon.isFainted()
    hp = @pokemon.stat('hp')
    damage = Math.min(Math.floor(hp / 8), @pokemon.currentHP)
    if @pokemon.damage(damage)
      user.drain(damage, @pokemon)
      @battle.cannedText('LEECH_SEED_HURT', @pokemon)

  unattach: ->
    @battle.cannedText('FREE_FROM', @pokemon, "Leech Seed")

class @Attachment.ProtectCounter extends @VolatileAttachment
  name: "ProtectCounterAttachment"

  maxLayers: -1

  successMultiplier: 2

  successChance: ->
    x = Math.pow(@successMultiplier, @layers - 1)
    if @layers > 8 then Math.pow(2, 32) else x

  endTurn: ->
    @turns--
    @pokemon.unattach(@constructor)  if @turns == 0

class @Attachment.Protect extends @VolatileAttachment
  name: "ProtectAttachment"

  initialize: ->
    @pokemon.tell(Protocol.POKEMON_ATTACH, @name)

  shouldBlockExecution: (move, user) ->
    return true  if move.hasFlag("protect")

  endTurn: ->
    @pokemon.unattach(@constructor)

  unattach: ->
    @pokemon.tell(Protocol.POKEMON_UNATTACH, @name)

class @Attachment.Endure extends @VolatileAttachment
  name: "EndureAttachment"

  endTurn: ->
    @pokemon.unattach(@constructor)

  transformHealthChange: (amount, options) ->
    if amount >= @pokemon.currentHP
      @battle.message "#{@pokemon.name} endured the hit!"
      return @pokemon.currentHP - 1
    return amount

class @Attachment.Curse extends @VolatileAttachment
  name: "CurseAttachment"
  passable: true

  endTurn: ->
    amount = Math.floor(@pokemon.stat('hp') / 4)
    if @pokemon.damage(amount)
      @battle.message "#{@pokemon.name} was afflicted by the curse!"

class @Attachment.DestinyBond extends @VolatileAttachment
  name: "DestinyBondAttachment"

  isAliveCheck: -> true

  initialize: ->
    @battle.cannedText('DESTINY_BOND_START', @pokemon)

  afterFaint: ->
    pokemon = @battle.currentPokemon
    if pokemon? && pokemon.isAlive()
      pokemon.faint()
      @battle.cannedText('DESTINY_BOND_CONTINUE', @pokemon)

  beforeMove: (move, user, targets) ->
    @pokemon.unattach(@constructor)

class @Attachment.Grudge extends @VolatileAttachment
  name: "GrudgeAttachment"

  isAliveCheck: -> true

  afterFaint: ->
    hit = @pokemon.lastHitBy
    return  if !hit
    {team, slot, move, turn} = hit
    pokemon = team.at(slot)
    if pokemon.isAlive() && !move.isNonDamaging()
      pokemon.setPP(move, 0)
      @battle.message "#{pokemon.name}'s #{move.name} lost all its PP due to the grudge!"

  beforeMove: (move, user, targets) ->
    @pokemon.unattach(@constructor)

class @Attachment.Pursuit extends @VolatileAttachment
  name: "PursuitAttachment"

  informSwitch: (switcher) ->
    team = switcher.team
    return  if team.has(Attachment.BatonPass)
    pursuit = @battle.getMove('Pursuit')
    @battle.cancelAction(@pokemon)
    @pokemon.attach(Attachment.PursuitModifiers)
    # TODO: You will have to record the target for 2v2.
    @battle.performMove(@pokemon, pursuit)
    @pokemon.unattach(Attachment.PursuitModifiers)
    @pokemon.unattach(@constructor)

  beforeMove: ->
    @pokemon.unattach(@constructor)

  endTurn: ->
    @pokemon.unattach(@constructor)

class @Attachment.PursuitModifiers extends @VolatileAttachment
  name: "PursuitModifiersAttachment"

  editAccuracy: ->
    0  # Always hits

class @Attachment.Substitute extends @VolatileAttachment
  name: "SubstituteAttachment"
  passable: true
  reinitializeOnPass: true

  initialize: (attributes) ->
    {@hp} = attributes || this
    @pokemon?.tell(Protocol.POKEMON_ATTACH, @name)

  transformHealthChange: (damage, options = {}) ->
    if options.direct != false
      # Substitute does not trigger on direct damage
      return damage

    @hp -= damage
    if @hp <= 0
      @battle.cannedText('SUBSTITUTE_END', @pokemon)
      @hp = 0
    else
      @battle.cannedText('SUBSTITUTE_HURT', @pokemon)
    return 0

  failsOnSub: (move, user) ->
    @pokemon != user && move.isNonDamaging() &&
      !move.isDirectHit(@battle, user, @pokemon)

  shouldBlockExecution: (move, user) ->
    if @failsOnSub(move, user)
      move.fail(@battle, user)
      return true

  afterBeingHit: (move, user, target) ->
    @pokemon.unattach(@constructor)  if @hp <= 0

  unattach: ->
    @pokemon.tell(Protocol.POKEMON_UNATTACH, @name)

class @Attachment.Stockpile extends @VolatileAttachment
  name: "StockpileAttachment"

  maxLayers: 3

class @Attachment.Rage extends @VolatileAttachment
  name: "RageAttachment"

  beforeMove: (move, user, targets) ->
    @pokemon.unattach(@constructor)

  afterBeingHit: (move, user, target) ->
    return  if move.isNonDamaging()
    target.boost(attack: 1)
    @battle.message "#{target.name}'s rage is building!"

class @Attachment.ChipAway extends @VolatileAttachment
  name: "ChipAwayAttachment"

  editBoosts: (stages) ->
    stages.evasion = 0
    stages.defense = 0
    stages.specialDefense = 0
    stages

class @Attachment.AquaRing extends @VolatileAttachment
  name: "AquaRingAttachment"
  passable: true

  endTurn: ->
    amount = Math.floor(@pokemon.stat('hp') / 16)
    # Aqua Ring is considered a drain move for the purposes of Big Root.
    @pokemon.drain(amount, @pokemon)
    @battle.message "Aqua Ring restored #{@pokemon.name}'s HP!"

class @Attachment.Ingrain extends @VolatileAttachment
  name: "IngrainAttachment"
  passable: true

  initialize: ->
    @battle.message("#{@pokemon.name} planted its roots!")

  endTurn: ->
    amount = Math.floor(@pokemon.stat('hp') / 16)
    # Ingrain is considered a drain move for the purposes of Big Root.
    @pokemon.drain(amount, @pokemon)
    @battle.message "#{@pokemon.name} absorbed nutrients with its roots!"

  beginTurn: ->
    @pokemon.blockSwitch()

  shouldPhase: (phaser) ->
    @battle.message "#{@pokemon.name} anchored itself with its roots!"
    return false

  shouldBlockExecution: (move, user) ->
    if move == @battle.getMove("Telekinesis")
      move.fail(@battle, user)
      return true

  isImmune: (type) ->
    return false  if type == 'Ground'

class @Attachment.Embargo extends @VolatileAttachment
  name: "EmbargoAttachment"
  passable: true

  initialize: ->
    @turns = 5
    @pokemon.blockItem()
    @battle.message("#{@pokemon.name} can't use items anymore!")

  beginTurn: ->
    @pokemon.blockItem()

  endTurn: ->
    @turns--
    if @turns == 0
      @battle.message "#{@pokemon.name} can use items again!"
      @pokemon.unattach(@constructor)

class @Attachment.Charging extends @VolatileAttachment
  name: "ChargingAttachment"

  initialize: (attributes) ->
    {@message, @vulnerable, @move, @condition} = attributes
    @charging = false

  beforeMove: (move, user, targets) ->
    if user.hasItem("Power Herb")
      @battle.message "#{user.name} became fully charged due to its Power Herb!"
      @charging = true
      user.removeItem()

    if @charging || @condition?(@battle, move, user, targets)
      @pokemon.unattach(@constructor)
      return

    @charging = true
    @battle.message @message.replace("$1", user.name)
    return false

  beginTurn: ->
    # TODO: Add targets
    id = @battle.getOwner(@pokemon)
    @battle.recordMove(id, @move)

  editEvasion: (accuracy, move) ->
    return -1  if @vulnerable && @charging &&
                (move not in @vulnerable.map((v) => @battle.getMove(v)))
    return accuracy

  unattach: ->
    delete @move
    delete @message
    delete @vulnerable

class @Attachment.FuryCutter extends @VolatileAttachment
  name: "FuryCutterAttachment"

  maxLayers: 3

  initialize: (attributes) ->
    {@move} = attributes

  beforeMove: (move, user, targets) ->
    @pokemon.unattach(@constructor)  if move != @move

class @Attachment.Imprison extends @VolatileAttachment
  name: "ImprisonAttachment"

  initialize: (attributes) ->
    {@moves} = attributes
    for pokemon in @battle.getOpponents(@pokemon)
      pokemon.attach(Attachment.ImprisonPrevention, {@moves})

  beginTurn: ->
    for pokemon in @battle.getOpponents(@pokemon)
      pokemon.attach(Attachment.ImprisonPrevention, {@moves})

  switchOut: ->
    for pokemon in @battle.getOpponents(@pokemon)
      pokemon.unattach(Attachment.ImprisonPrevention)

class @Attachment.ImprisonPrevention extends @VolatileAttachment
  name: "ImprisonPreventionAttachment"

  initialize: (attributes) ->
    {@moves} = attributes

  beginTurn: ->
    @pokemon.blockMove(move)  for move in @moves

  beforeMove: (move, user, targets) ->
    if move in @moves
      @battle.message "#{user.name} can't use the sealed #{move.name}!"
      return false

class @Attachment.Present extends @VolatileAttachment
  name: "PresentAttachment"

  initialize: (attributes) ->
    {@power} = attributes

  endTurn: ->
    @pokemon.unattach(@constructor)

# Lucky Chant's CH prevention is inside Move#isCriticalHit.
class @Attachment.LuckyChant extends @TeamAttachment
  name: "LuckyChantAttachment"

  initialize: ->
    @turns = 5

  endTurn: ->
    @turns--
    if @turns == 0
      # TODO: Less hacky?
      id = (id for id in @battle.playerIds when @battle.getTeam(id) == @team)[0]
      @battle.message "#{id}'s team's Lucky Chant wore off!"
      @team.unattach(@constructor)

class @Attachment.LunarDance extends @TeamAttachment
  name: "LunarDanceAttachment"

  switchIn: (pokemon) ->
    @battle.message "#{pokemon.name} became cloaked in mystical moonlight!"
    pokemon.setHP(pokemon.stat('hp'))
    pokemon.cureStatus()
    pokemon.resetAllPP()
    @team.unattach(@constructor)

class @Attachment.HealingWish extends @TeamAttachment
  name: "HealingWishAttachment"

  switchIn: (pokemon) ->
    @battle.message "The healing wish came true for #{pokemon.name}!"
    pokemon.setHP(pokemon.stat('hp'))
    pokemon.cureStatus()
    @team.unattach(@constructor)

class @Attachment.MagicCoat extends @VolatileAttachment
  name: "MagicCoatAttachment"

  initialize: ->
    @bounced = false

  shouldBlockExecution: (move, user) ->
    return  unless move.hasFlag("reflectable")
    return  if user.get(Attachment.MagicCoat)?.bounced
    return  if @bounced
    @bounced = true
    @battle.cannedText('BOUNCE_MOVE', @pokemon, move.name)
    move.execute(@battle, @pokemon, [ user ])
    return true

  shouldBlockFieldExecution: (move, userId) ->
    return  unless move.hasFlag("reflectable")
    return  if @bounced
    team = @battle.getTeam(userId)
    for p in team.getActiveAlivePokemon()
      return  if p.get(Attachment.MagicCoat)?.bounced
    for p in @team.getActiveAlivePokemon()
      continue  unless p.has(Attachment.MagicCoat)
      @bounced = true
      @battle.cannedText('BOUNCE_MOVE', p, move.name)
      @battle.executeMove(move, p, [ userId ])
      return true

  endTurn: ->
    if @pokemon?
      @pokemon.unattach(@constructor)
    else if @team?
      @team.unattach(@constructor)

class @Attachment.Telekinesis extends @VolatileAttachment
  name: "TelekinesisAttachment"

  initialize: ->
    @turns = 3
    @battle.cannedText('TELEKINESIS_START', @pokemon)

  editEvasion: (accuracy, move) ->
    if move.hasFlag("ohko") then accuracy else 0

  isImmune: (type) ->
    return true  if type == 'Ground'

  endTurn: ->
    @turns--
    if @turns == 0
      @battle.cannedText('TELEKINESIS_END', @pokemon)
      @pokemon.unattach(@constructor)

class @Attachment.SmackDown extends @VolatileAttachment
  name: "SmackDownAttachment"

  isImmune: (type) ->
    return false  if type == 'Ground'

  shouldBlockExecution: (move, user) ->
    if move in [ @battle.getMove("Telekinesis"), @battle.getMove("Magnet Rise") ]
      move.fail(@battle, user)
      return true

class @Attachment.EchoedVoice extends @BattleAttachment
  name: "EchoedVoiceAttachment"

  maxLayers: 4

  initialize: ->
    @turns = 2

  endTurn: ->
    @turns--
    @battle.unattach(@constructor)  if @turns == 0

class @Attachment.Rampage extends @VolatileAttachment
  name: "RampageAttachment"

  maxLayers: -1

  initialize: (attributes) ->
    {@move} = attributes
    @turns = @battle.rng.randInt(2, 3, "rampage turns")
    @turn = 0

  beginTurn: ->
    @pokemon.blockSwitch()
    @pokemon.lockMove(@move)

  afterMove: ->
    @turn++
    if @turn >= @turns
      @pokemon.attach(Attachment.Confusion, cannedText: 'FATIGUE')
      @pokemon.unattach(@constructor)
    else
      # afterSuccessfulHit increases the number of layers. If the number of
      # layers is not keeping up with the number of turns passed, then the
      # Pokemon's move was interrupted and we should stop rampaging.
      @pokemon.unattach(@constructor)  if @turn > @layers

# The way Trick Room reverses turn order is implemented in Battle#sortActions.
class @Attachment.TrickRoom extends @BattleAttachment
  name: "TrickRoomAttachment"

  initialize: ->
    @turns = 5

  endTurn: ->
    @turns--
    if @turns == 0
      @battle.unattach(@constructor)

  unattach: ->
    @battle.cannedText('TRICK_ROOM_END')

class @Attachment.Transform extends @VolatileAttachment
  name: "TransformAttachment"

  @preattach: (attributes) ->
    {target} = attributes
    !target.has(Attachment.Transform)

  initialize: (attributes) ->
    @pokemon.activateAbility()
    {target} = attributes
    # Save old data
    {@ability, @moves, @stages, @baseStats, @evs} = @pokemon
    {@types, @gender, @weight, @ppHash, @maxPPHash} = @pokemon
    # This data is safe to be copied.
    @pokemon.copyAbility(target.ability, reveal: false)
    @pokemon.gender = target.gender
    @pokemon.weight = target.weight
    # The rest aren't.
    @pokemon.moves     = _.clone(target.moves)
    @pokemon.types     = _.clone(target.types)
    @pokemon.evs       = _.extend({}, target.evs, hp: @pokemon.evs.hp)
    @pokemon.baseStats = _.extend({}, target.baseStats, hp: @pokemon.baseStats.hp)
    @pokemon.setBoosts(target.stages)
    @pokemon.resetAllPP(5)
    # Send updated information to the client
    @pokemon.changeSprite(target.species, target.forme)
    @pokemon.tellPlayer(Protocol.MOVESET_UPDATE, @pokemon.movesetJSON())

  unattach: ->
    # Restore old data
    @pokemon.ability   = @ability
    @pokemon.moves     = @moves
    @pokemon.types     = @types
    @pokemon.gender    = @gender
    @pokemon.weight    = @weight
    @pokemon.ppHash    = @ppHash
    @pokemon.maxPPHash = @maxPPHash
    @pokemon.baseStats = @baseStats
    @pokemon.evs       = @evs
    @pokemon.setBoosts(@stages)
    @pokemon.changeSprite(@pokemon.species, @pokemon.forme)
    @pokemon.tellPlayer(Protocol.MOVESET_UPDATE, @pokemon.movesetJSON())

class @Attachment.Fling extends @VolatileAttachment
  name: "FlingAttachment"

  initialize: ->
    @item = null

  beforeMove: (move, user, targets) ->
    # The move may be changed by something like Encore
    return  if move != @battle.getMove("Fling")
    if user.hasItem() && user.hasTakeableItem() && !user.isItemBlocked()
      @item = user.getItem()
      user.removeItem()

  endTurn: ->
    @pokemon.unattach(@constructor)

class @Attachment.Gravity extends @BattleAttachment
  name: "GravityAttachment"

  initialize: ->
    @turns = 5
    @beginTurn()

  beginTurn: ->
    for pokemon in @battle.getActivePokemon()
      pokemon.attach(Attachment.GravityPokemon)
      for move in pokemon.moves
        pokemon.blockMove(move)  if move.hasFlag("gravity")

  endTurn: ->
    @turns--
    if @turns == 0
      @battle.message "Gravity turned to normal!"
      @battle.unattach(@constructor)

class @Attachment.GravityPokemon extends @VolatileAttachment
  name: "GravityPokemonAttachment"

  beforeMove: (move, user, target) ->
    if move.hasFlag("gravity")
      @battle.message "#{user.name} can't use #{move.name} because of gravity!"
      return false

  editAccuracy: (accuracy) ->
    Math.floor(accuracy * 5 / 3)

  isImmune: (type) ->
    return false  if type == 'Ground'

  shouldIgnoreImmunity: (moveType, target) ->
    return target.hasType("Flying") && moveType == 'Ground'

  endTurn: ->
    @pokemon.unattach(@constructor)

class @Attachment.DelayedAttack extends @TeamAttachment
  name: "DelayedAttackAttachment"

  initialize: (attributes) ->
    {@move, @user} = attributes
    @slot = 0
    @turns = 3

  endTurn: ->
    @turns--
    if @turns == 0
      pokemon = @team.at(@slot)
      if pokemon.isAlive()
        @battle.message "#{pokemon.name} took the #{@move.name} attack!"
        isDirect = @move.isDirectHit(@battle, @user, pokemon)
        damage = @move.hit(@battle, @user, pokemon, 1, isDirect)
        @move.afterHit(@battle, @user, pokemon, damage, isDirect)
      @team.unattach(@constructor)

class @Attachment.BatonPass extends @TeamAttachment
  name: "BatonPassAttachment"

  initialize: (attributes) ->
    {@slot, @attachments, @stages} = attributes

  switchIn: (pokemon) ->
    return  if @slot != @team.indexOf(pokemon)
    # Nasty stitching of attachments to the recipient.
    for attachment in @attachments
      attachment.pokemon = pokemon
      attachment.team = pokemon.team
      attachment.battle = pokemon.battle
      attachment.attached = true
      index = (pokemon.attachments.attachments.push(attachment)) - 1
      if attachment.reinitializeOnPass
        pokemon.attachments.attachments[index]?.initialize?()
    pokemon.setBoosts(@stages)
    @team.unattach(@constructor)

class @Attachment.FlashFire extends @VolatileAttachment
  name: "FlashFireAttachment"

  modifyBasePower: (move, target) ->
    return 0x1000  if move.getType(@battle, @pokemon, target) != 'Fire'
    return 0x1800

class @Attachment.Unburden extends @VolatileAttachment
  name: "UnburdenAttachment"

  editSpeed: (speed) ->
    if @pokemon.hasAbility("Unburden") && !@pokemon.hasItem()
      2 * speed
    else
      @pokemon.unattach(@constructor)
      speed

# Cancels the opponent's ability for one turn
class @Attachment.AbilityCancel extends @VolatileAttachment
  name: "AbilityCancelAttachment"

  initialize: ->
    if !@pokemon.isAbilityBlocked()
      @shouldUnblock = true
      @pokemon.blockAbility()

  unattach: ->
    if @shouldUnblock then @pokemon.unblockAbility()

  endTurn: ->
    @pokemon.unattach(@constructor)

# Suppresses the opponent's ability until they switch out
class @Attachment.AbilitySuppress extends @VolatileAttachment
  name: "AbilitySuppressAttachment"
  passable: true

  @preattach: (options, attributes) ->
    {pokemon} = attributes
    return false  if !pokemon.hasChangeableAbility()

  initialize: ->
    @pokemon.blockAbility()

  beginTurn: this::initialize

class @Attachment.SleepClause extends @BaseAttachment
  name: "SleepClause"

  shouldAttach: (attachment, options) ->
    {source} = options
    return  if attachment != Status.Sleep
    return  if !source || source.team == @pokemon.team
    pokemonSleptByOtherTeams = @pokemon.team.filter (p) =>
      return false  if p.isFainted()
      source = p.get(Status.Sleep)?.source
      return source && source.team != @pokemon.team
    # Attach if we have no pokemon slept by other teams.
    return pokemonSleptByOtherTeams.length == 0

class @StatusAttachment extends @BaseAttachment
  name: "StatusAttachment"

  @status: true

  @preattach: (options, attributes) ->
    {battle, pokemon} = attributes
    {source, force, bypassSafeguard} = options
    force ?= false
    if !force
      return false  if pokemon.hasStatus()
      return false  if (pokemon.team?.has(Attachment.Safeguard) && source != pokemon && !bypassSafeguard)
      return false  unless @worksOn(battle, pokemon)
      if source && this in [ Status.Toxic, Status.Burn, Status.Poison, Status.Paralyze ] && pokemon.hasAbility("Synchronize")
        return false  if source == pokemon
        source.attach(this)  # Do not attach source
        battle.message "#{pokemon.name} synchronized its status with #{source.name}!"
    else
      pokemon.cureStatus(message: false)
    pokemon.status = this
    return true

  initialize: (attributes = {}) ->
    # We store the source for use in other places, like Sleep Clause.
    {@source} = attributes
    @battle?.cannedText("#{@constructor.name.toUpperCase()}_START", @pokemon)
    @pokemon.tell(Protocol.POKEMON_ATTACH, @name)

  @worksOn: (battle, pokemon) ->
    true

  unattach: ->
    @pokemon.tell(Protocol.POKEMON_UNATTACH, @name)
    @pokemon.status = null

class @Status.Paralyze extends @StatusAttachment
  name: "Paralyze"

  beforeMove: (move, user, targets) ->
    if @battle.rng.next('paralyze chance') < .25
      @battle.cannedText('PARALYZE_CONTINUE', @pokemon)
      return false

  editSpeed: (stat) ->
    if @pokemon.hasAbility("Quick Feet") then stat else stat >> 2

class @Status.Freeze extends @StatusAttachment
  name: "Freeze"

  @worksOn: (battle, pokemon) ->
    !(pokemon.hasType("Ice") || battle?.hasWeather(Weather.SUN))

  beforeMove: (move, user, targets) ->
    if move.thawsUser || @battle.rng.next('unfreeze chance') < .2
      @pokemon.cureStatus()
    else
      @battle.cannedText('FREEZE_CONTINUE', @pokemon)
      return false

  afterBeingHit: (move, user, target) ->
    if !move.isNonDamaging() && move.type == 'Fire'
      @pokemon.cureStatus()

class @Status.Poison extends @StatusAttachment
  name: "Poison"

  @worksOn: (battle, pokemon) ->
    !(pokemon.hasType("Poison") || pokemon.hasType("Steel"))

  endTurn: ->
    return  if @pokemon.hasAbility("Poison Heal")
    if @pokemon.damage(@pokemon.stat('hp') >> 3)
      @battle.cannedText('POISON_CONTINUE', @pokemon)

class @Status.Toxic extends @StatusAttachment
  name: "Toxic"

  @worksOn: (battle, pokemon) ->
    !(pokemon.hasType("Poison") || pokemon.hasType("Steel"))

  initialize: ->
    super()
    @counter = 0

  switchOut: ->
    @counter = 0

  endTurn: ->
    @counter = Math.min(@counter + 1, 15)
    return  if @pokemon.hasAbility("Poison Heal")
    if @pokemon.damage(Math.max(@pokemon.stat('hp') >> 4, 1) * @counter)
      @battle.cannedText('POISON_CONTINUE', @pokemon)

class @Status.Sleep extends @StatusAttachment
  name: "Sleep"

  initialize: (attributes) ->
    super(attributes)
    @counter = 0
    {@turns} = attributes
    if !@turns && @battle?
      @turns = @battle.rng.randInt(1, 3, "sleep turns")

  switchOut: ->
    @counter = 0

  beforeMove: (move, user, targets) ->
    @counter += 1  if @pokemon.hasAbility("Early Bird")
    @counter += 1
    if @counter > @turns
      @pokemon.cureStatus()
    else
      @battle.cannedText('SLEEP_CONTINUE', @pokemon)
      return false  unless move.usableWhileAsleep

class @Status.Burn extends @StatusAttachment
  name: "Burn"

  @worksOn: (battle, pokemon) ->
    !pokemon.hasType("Fire")

  endTurn: ->
    if @pokemon.damage(@pokemon.stat('hp') >> 3)
      @battle.cannedText('BURN_CONTINUE', @pokemon)
