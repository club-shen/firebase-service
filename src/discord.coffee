Discord = require 'discord.js'

###
	A wrapper class for discord.js
###
module.exports = class DiscordBot

	bot: null

	online: false

	# map of command roots and function callbacks
	commandMap: new Map()

	constructor: (@token) ->

		@bot = new Discord.Client()

		@bot.login(@token)

		@bot.on "ready", =>

			console.log "The bot is online!"

			@channel = @bot.guilds.find("id", "174405074087313408").channels.find("name", "general")

			@online = true

		@bot.on "message", (message) =>

			str = message.content
			args = str.split(" ")

			if args.length > 0

				root = args[0]
				args.splice 0, 1 # remove first argument

				if @commandMap.has root

					@commandMap.get(root)(message.author, message.channel, args)

	###
		Registers a command.
	###
	registerCommand: (root, callback) ->

		@commandMap.set root, callback

		console.log "[INFO] command registered: #{ root }"

	on_command: (prefixes, callback) -> @bot.on "message", (message) ->

		str = message.content

		if str.charAt(0) in prefixes

			console.log "[INFO] user #{ message.author.username } has ran command: #{ str.slice(1) }"

			callback(message.author, message.channel, str.slice(1).split(" "))

	chat: (channel, message) -> channel.sendMessage message
