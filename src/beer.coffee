# Description:
#    beer me
#
# Commands:
#
# Dependencies:
#   underscore
#   cron

beers = [
  "https://www.instagram.com/p/BHvFFUzgZw5/",
  "https://www.instagram.com/p/BHvDmDqALSG/",
  "https://www.instagram.com/p/BHvERlgg_2Z/",
  "https://www.instagram.com/p/BHkKtwfgPHV/",
  "https://www.instagram.com/p/BHfBcxMAJHX/",
  "https://www.instagram.com/p/BG9z4iMpuYR/",
  "https://www.instagram.com/p/BG5Gyp0JuR0/",
  "https://www.instagram.com/p/BG2SF3mpuZX/",
  "https://www.instagram.com/p/BG2FM_8pudY/",
  "https://www.instagram.com/p/BGui_K9puax/",
  "https://www.instagram.com/p/BGm9NuNJuXU/"
]

cronJob = require('cron').CronJob
_ = require('underscore')


module.exports = (robot) ->
  # Compares current time to the time of the beeroclock to see if it should be fired.
  beeroclockShouldFire = (beeroclock) ->
    beeroclockTime = beeroclock.time
    beeroclockDayOfWeek = getDayOfWeek(beeroclock.dayOfWeek)
    now = new Date()
    beeroclockDate = new Date()
    utcOffset = -beeroclock.utc or (now.getTimezoneOffset() / 60)

    beeroclockHours = parseInt(beeroclockTime.split(":")[0], 10)
    beeroclockMinutes = parseInt(beeroclockTime.split(":")[1], 10)

    beeroclockDate.setUTCMinutes(beeroclockMinutes)
    beeroclockDate.setUTCHours(beeroclockHours + utcOffset)

    result = (beeroclockDate.getUTCHours() == now.getUTCHours()) and
      (beeroclockDate.getUTCMinutes() == now.getUTCMinutes()) and
      (beeroclockDayOfWeek == -1 or (beeroclockDayOfWeek == beeroclockDate.getDay() == now.getUTCDay()))

    if result then true else false

  # Returns the number of a day of the week from a supplied string. Will only attempt to match the first 3 characters
  # Sat/Sun currently aren't supported by the cron but are included to ensure indexes are correct
  getDayOfWeek = (day) ->
    if (!day)
      return -1
    ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'].indexOf(day.toLowerCase().substring(0,3))

  # Returns all beeroclocks.
  getbeeroclocks = ->
    robot.brain.get('beeroclocks') or []

  # Returns just beeroclocks for a given room.
  getbeeroclocksForRoom = (room) ->
    _.where getbeeroclocks(), room: room

  # Gets all beeroclocks, fires ones that should be.
  checkbeeroclocks = ->
    beeroclocks = getbeeroclocks()
    _.chain(beeroclocks).filter(beeroclockShouldFire).pluck('room').each dobeeroclock
    return

  # Fires the beeroclock message.
  dobeeroclock = (room) ->
    beeroclocks = getbeeroclocksForRoom(room)
    beerurl = "https://www.instagram.com/p/BD-mYTgpuRb/"
    beerMessage = ""
    if beeroclocks.length > 0
    # Do some magic here to loop through the beeroclocks and find the one for right now
      thebeeroclock = beeroclocks.filter(beeroclockShouldFire)
      message = "#{PREPEND_MESSAGE} #{_.sample(beeroclock_MESSAGES)} #{thebeeroclock[0].location}"
      beerMessage = "#{PREPEND_MESSAGE} #{beerurl} #{thebeeroclock[0].location}"
    else
      message = "#{PREPEND_MESSAGE} #{_.sample(beeroclock_MESSAGES)} #{beeroclocks[0].location}"
      beerMessage = "#{PREPEND_MESSAGE} #{beerurl} #{beeroclocks[0].location}"
    robot.messageRoom room, message
    robot.messageRoom room, beerMessage
    return

  # Finds the room for most adaptors
  findRoom = (msg) ->
    room = msg.envelope.room
    if _.isUndefined(room)
      room = msg.envelope.user.reply_to
    room

  # Confirm a time is in the valid 00:00 format
  timeIsValid = (time) ->
    validateTimePattern = /([01]?[0-9]|2[0-4]):[0-5]?[0-9]/
    return validateTimePattern.test time

  # Stores a beeroclock in the brain.
  savebeeroclock = (room, dayOfWeek, time, utcOffset, location, msg) ->
    if !timeIsValid time
      msg.send "Sorry, but I couldn't find a time to create the beeroclock at."
      return

    beeroclocks = getbeeroclocks()
    newbeeroclock =
      room: room
      dayOfWeek: dayOfWeek
      time: time
      utc: utcOffset
      location: location.trim()
    beeroclocks.push newbeeroclock
    updateBrain beeroclocks
    displayDate = dayOfWeek or 'weekday'
    msg.send 'Ok, from now on I\'ll remind this room to do a beeroclock every ' + displayDate + ' at ' + time + (if location then location else '')
    return

  # Updates the brain's beeroclock knowledge.
  updateBrain = (beeroclocks) ->
    robot.brain.set 'beeroclocks', beeroclocks
    return

  # Remove all beeroclocks for a room
  clearAllbeeroclocksForRoom = (room, msg) ->
    beeroclocks = getbeeroclocks()
    beeroclocksToKeep = _.reject(beeroclocks, room: room)
    updateBrain beeroclocksToKeep
    beeroclocksCleared = beeroclocks.length - (beeroclocksToKeep.length)
    msg.send 'Deleted ' + beeroclocksCleared + ' beeroclocks for ' + room
    return

  # Remove specific beeroclocks for a room
  clearSpecificbeeroclockForRoom = (room, time, msg) ->
    if !timeIsValid time
      msg.send "Sorry, but I couldn't spot a time in your command."
      return

    beeroclocks = getbeeroclocks()
    beeroclocksToKeep = _.reject(beeroclocks,
      room: room
      time: time)
    updateBrain beeroclocksToKeep
    beeroclocksCleared = beeroclocks.length - (beeroclocksToKeep.length)
    if beeroclocksCleared == 0
      msg.send 'Nice try. You don\'t even have a beeroclock at ' + time
    else
      msg.send 'Deleted your ' + time + ' beeroclock.'
    return

  # Responsd to the help command
  sendHelp = (msg) ->
    message = []
    message.push 'I can remind you to do your beeroclocks!'
    message.push 'Use me to create a beeroclock, and then I\'ll post in this room at the times you specify. Here\'s how:'
    message.push ''
    message.push robot.name + ' create beeroclock hh:mm - I\'ll remind you to beeroclock in this room at hh:mm every weekday.'
    message.push robot.name + ' create beeroclock hh:mm UTC+2 - I\'ll remind you to beeroclock in this room at hh:mm UTC+2 every weekday.'
    message.push robot.name + ' create beeroclock hh:mm at location/url - Creates a beeroclock at hh:mm (UTC) every weekday for this chat room with a reminder for a physical location or url'
    message.push robot.name + ' create beeroclock Monday@hh:mm UTC+2 - I\'ll remind you to beeroclock in this room at hh:mm UTC+2 every Monday.'
    message.push robot.name + ' list beeroclocks - See all beeroclocks for this room.'
    message.push robot.name + ' list all beeroclocks- Be nosey and see when other rooms have their beeroclock.'
    message.push robot.name + ' delete beeroclock hh:mm - If you have a beeroclock at hh:mm, I\'ll delete it.'
    message.push robot.name + ' delete all beeroclocks - Deletes all beeroclocks for this room.'
    msg.send message.join('\n')
    return

  # List the beeroclocks within a specific room
  listbeeroclocksForRoom = (room, msg) ->
    beeroclocks = getbeeroclocksForRoom(findRoom(msg))
    if beeroclocks.length == 0
      msg.send 'Well this is awkward. You haven\'t got any beeroclocks set :-/'
    else
      beeroclocksText = [ 'Here\'s your beeroclocks:' ].concat(_.map(beeroclocks, (beeroclock) ->
        text =  'Time: ' + beeroclock.time
        if beeroclock.utc
          text += ' UTC' + beeroclock.utc
        if beeroclock.location
          text +=', Location: '+ beeroclock.location
        text
      ))
      msg.send beeroclocksText.join('\n')
    return

  listbeeroclocksForAllRooms = (msg) ->
    beeroclocks = getbeeroclocks()
    if beeroclocks.length == 0
      msg.send 'No, because there aren\'t any.'
    else
      beeroclocksText = [ 'Here\'s the beeroclocks for every room:' ].concat(_.map(beeroclocks, (beeroclock) ->
        text =  'Room: ' + beeroclock.room + ', Time: ' + beeroclock.time
        if beeroclock.utc
          text += ' UTC' + beeroclock.utc
        if beeroclock.location
          text +=', Location: '+ beeroclock.location
        text
      ))
      msg.send beeroclocksText.join('\n')
    return

  'use strict'
  # Constants.
  beeroclock_MESSAGES = [
    'beeroclock time!'
    'Time for beeroclock, y\'all.'
    'It\'s beeroclock time once again!'
    'Get up, stand up (it\'s time for our beeroclock)'
    'beeroclock time. Get up, humans'
    'beeroclock time! Now! Go go go!'
  ]
  PREPEND_MESSAGE = process.env.HUBOT_beeroclock_PREPEND or ''
  if PREPEND_MESSAGE.length > 0 and PREPEND_MESSAGE.slice(-1) != ' '
    PREPEND_MESSAGE += ' '

  # Check for beeroclocks that need to be fired, once a minute
  # Monday to Friday.
  new cronJob('1 * * * * 1-5', checkbeeroclocks, null, true)

  robot.respond /beer me/i, (msg) ->
    msg.send msg.random beers

  robot.respond /bitter me/i, (msg) ->
    msg.send msg.random beers

  # Global regex should match all possible options
  robot.respond /(.*)beeroclocks? ?(?:([A-z]*)\s?\@\s?)?((?:[01]?[0-9]|2[0-4]):[0-5]?[0-9])?(?: UTC([- +]\d\d?))?(.*)/i, (msg) ->
    action = msg.match[1].trim().toLowerCase()
    dayOfWeek = msg.match[2]
    time = msg.match[3]
    utcOffset = msg.match[4]
    location = msg.match[5]
    room = findRoom msg

    switch action
      when 'create' then savebeeroclock room, dayOfWeek, time, utcOffset, location, msg
      when 'list' then listbeeroclocksForRoom room, msg
      when 'list all' then listbeeroclocksForAllRooms msg
      when 'delete' then clearSpecificbeeroclockForRoom room, time, msg
      when 'delete all' then clearAllbeeroclocksForRoom room, msg
      else sendHelp msg
    return

return