{_} = require 'underscore'

crypto = require('crypto')

request = require 'request'
authHeaders = {AUTHUSER: process.env.AUTHUSER, AUTHTOKEN: process.env.AUTHTOKEN}
request = request.defaults(json: true, headers: authHeaders)

config = require './config'
db = require './database'

AUTH_KEY = "auth"

# This middleware checks if a user is authenticated through the site. If yes,
# then information about the user is stored in req.user. In addition, we store
# a token associated with that user into req.user.token.
#
# User information is also stored in a database.
exports.middleware = -> (req, res, next) ->
  authenticate req.cookies.sessionid, (body) ->
    if !body
      redirectURL = "http://pokebattle.com/accounts/login"
      redirectURL += "?next=/sim"
      return res.redirect(redirectURL)
    req.user = _.clone(body)
    hmac = crypto.createHmac('sha256', config.SECRET_KEY)
    req.user.token = hmac.update("#{req.user.id}").digest('hex')
    db.set("users:#{body.id}", JSON.stringify(body), next)

# If the id and token match, the associated user object is returned.
exports.matchToken = (id, token, next) ->
  hmac = crypto.createHmac('sha256', config.SECRET_KEY)
  if hmac.update("#{id}").digest('hex') != token
    return next(new Error("Invalid session!"))
  db.get "users:#{id}", (err, jsonString) ->
    if err then return next(err)
    json = JSON.parse(jsonString)
    return next(new Error("Invalid session!"))  if !json
    exports.getAuth json.username, (err, authLevel) ->
      if err then return next(err)
      json.authority = authLevel
      return next(null, json)

# Authenticates against the site. A user object is returned if successful, or
# null if unsuccessful.
authenticate = (id, next) ->
  return next(generateUser())  if config.IS_LOCAL
  return next()  if !id
  request.get "http://pokebattle.com/api/v1/user/#{id}", (err, res, body) ->
    return next()  if err || res.statusCode != 200
    return next(body)

generateUsername = ->
  {SpeciesData} = require './xy/data'
  randomName = (name  for name of SpeciesData)
  randomName = randomName[Math.floor(Math.random() * randomName.length)]
  randomName = randomName.split(/\s+/)[0]
  randomName += "Fan" + Math.floor(Math.random() * 10000)
  randomName

generateId = ->
  Math.floor(1000000 * Math.random())

generateUser = ->
  {id: generateId(), username: generateUsername()}


# Authorization

exports.levels =
  USER          : 1
  DRIVER        : 2
  MOD           : 3
  MODERATOR     : 3
  ADMIN         : 4
  ADMINISTRATOR : 4
  OWNER         : 5

LEVEL_VALUES = (value  for key, value of exports.levels)

exports.getAuth = (id, next) ->
  db.hget AUTH_KEY, id, (err, auth) ->
    if err then return next(err)
    auth = parseInt(auth, 10) || exports.levels.USER
    next(null, auth)

exports.setAuth = (id, newAuthLevel, next) ->
  if newAuthLevel not in LEVEL_VALUES
    next(new Error("Incorrect auth level: #{newAuthLevel}"))
  db.hset(AUTH_KEY, id, newAuthLevel, next)