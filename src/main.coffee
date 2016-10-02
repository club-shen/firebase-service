firebase = require "firebase"
fs = require "fs"

{Database} = require "shn-ladder-api"
DiscordBot = require "./discord"

firebaseConfig = {
	serviceAccount: {
		projectId: "#{ process.env.FIREBASE_PROJECT_ID }"
		clientEmail: "#{ process.env.FIREBASE_CLIENT_EMAIL }"
		privateKey: "-----BEGIN PRIVATE KEY-----\n#{ process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, "\n") }\n-----END PRIVATE KEY-----\n"
	}
	databaseURL: "#{ process.env.FIREBASE_DATABASE_URL }"
}

# Initialize the app with a service account, granting admin privileges
fb = firebase.initializeApp firebaseConfig

# As an admin, the app has access to read and write all data, regardless of Security Rules
database = new Database(fb.database())

ladder = null

# database.on "ready", ->
#
# 	database.getLadder "ssb4", (ladder) -> @ladder = ladder

bot = new DiscordBot("#{ process.env.DISCORD_BOT_TOKEN }")

# ==========================================================================
# elo command - prints the rating of the specified player
bot.registerCommand '!ratings', (author, channel, args) ->
	strings = []
	if args.length is 1
		slug_array = args[0].split("/")

		ladderSlug = slug_array[0]
		seasonSlug = slug_array[1]

		bot.chat(channel, "`#{ args[0] }` Printing everyone's ratings...")
		database.getLadderAsync ladderSlug, (ladder) ->
			if not ladder?
				bot.chat channel, "The ladder `#{ ladderSlug }` does not exist."
				return

			season = ladder.getSeason seasonSlug
			if not season?
				bot.chat channel, "The season `#{ ladderSlug }/#{ seasonSlug }` does not exist."
				return

			season.playerMap.forEach (player) ->
				strings.push "#{ player.getName() }: #{ player.elo.getRating() }"

			bot.chat channel, """
				```
				#{ strings.join("\n") }
				```
			"""
			
bot.registerCommand '!match', (author, channel, args) ->

	playerStats = (match, i) ->
		player = match.getPlayerFromIndex(i)
		elo = player.getRatingAtMatch(match)
		return """
			#{ player.getName() }:
				characters: #{ match.getCharactersByPlayerIndex(i) }
				rating: #{ elo.getLastRating() } (#{ if elo.getLastAdjustment() > 0 then "+" + elo.getLastAdjustment() else elo.getLastAdjustment() })
		"""

	printMatch = (match) ->
		bot.chat channel, """
			Match ##{ match.id }: **#{ match.getPlayerFromIndex(0).getName() } vs. #{ match.getPlayerFromIndex(1).getName() }**
			```
			match info
			----------
			score:  #{ match.score[0] }:#{ match.score[1] }
			status: #{ if match.status is 0 then "VALID" else if match.status is 1 then "PENDING" else if match.status is 2 then "INVALID" }
			winner: #{ if match.getWinningPlayer()? then match.getWinningPlayer().getName() else "- none -" }
			stages: #{ match.getStages() }

			player statistics
			-----------------
			#{ playerStats(match, 0) }

			#{ playerStats(match, 1) }
			```
		"""

	if args.length is 0
		bot.chat(channel, "`!elo <player>`: prints the ELO rating of the specified player.")

	if args.length is 2
		slug_array = args[0].split("/")

		ladderSlug = slug_array[0]
		seasonSlug = slug_array[1]
		matchId = args[1]

		bot.chat(channel, "`#{ args[0] }` Printing match ##{ (new Number(matchId)) + 1 } report...")
		database.getLadderAsync ladderSlug, (ladder) ->
			if not ladder?
				bot.chat channel, "The ladder `#{ ladderSlug }` does not exist."
				return

			season = ladder.getSeason seasonSlug
			if not season?
				bot.chat channel, "The season `#{ ladderSlug }/#{ seasonSlug }` does not exist."
				return

			match = season.getMatchByIndex matchId
			if not match?
				bot.chat channel, "The match `##{ new Number(matchId) + 1}` does not exist."
				return

			printMatch(match)

	if args.length is 3
		slug_array = args[0].split("/")

		ladderSlug = slug_array[0]
		seasonSlug = slug_array[1]
		userUid = args[1]
		matchId = args[2]

		bot.chat(channel, "`#{ args[0] }` Printing match ##{ (new Number(matchId)) + 1 } report for player `#{ userUid }`...")
		database.getLadderAsync ladderSlug, (ladder) ->
			if not ladder?
				bot.chat channel, "The ladder `#{ ladderSlug }` does not exist."
				return

			season = ladder.getSeason seasonSlug
			if not season?
				bot.chat channel, "The season `#{ ladderSlug }/#{ seasonSlug }` does not exist."
				return

			player = season.getPlayer userUid
			if not player?
				bot.chat channel, "The player `#{ userUid }` does not exist."
				return

			match = player.getMatchByIndex matchId
			if not match?
				bot.chat channel, "The match `##{ new Number(matchId) + 1}` does not exist."
				return

			printMatch(match)

# ==========================================================================
# elo command - prints the rating of the specified player
bot.registerCommand '!elo', (author, channel, args) ->

	if args.length is 0

		bot.chat(channel, "`!elo <player>`: prints the ELO rating of the specified player.")

	if args.length is 1

		players = ladder.getPlayersByName args[1]

		if players.length is 0
			bot.chat channel, "A player with that name cannot be found."
		else
			message = "The ELO of **#{ players[0].user.display_name }** is **#{ players[0].rating }**."
			if players.length > 1
				message = "We have found multiple players with the name #{ args[1] }, but only the first match will be printed.\n" + message
			bot.chat channel, message

# ==========================================================================
# top10 command - prints the first 10 players ordered by highest rating
bot.registerCommand '!t10', (author, channel, args) ->

	msg = "The current top 10 players are:"
	for i in [0..9]
		player = ladder.getPlayerByRank(i)
		win_rate = Math.floor((player.match_wins / player.total_matches) * 1000) / 10
		msg += "\n#{i + 1}. **#{ player.user.display_name }** (**#{ win_rate }% wins**) #{ if win_rate is 100 then "*undefeated*" else "" }"
	bot.chat channel, msg

# ==========================================================================
# i command - prints various information about the specified player
bot.registerCommand '!i', (author, channel, args) ->

	if args.length is 0

		bot.chat(channel, "`!i <player>`: prints various information about the specified player.")

	if args.length is 1

		players = ladder.getPlayersByName args[1]
		player = if players.length is 0 then null else players[0]

		if not player?
			bot.chat channel, "A player with that name cannot be found."
		else
			winrate = (player.match_wins / player.total_matches).toFixed(2) * 100
			message = """
				`player: #{ player.user.display_name }`
				`rating: #{ player.rating }`
				`total matches: #{ player.total_matches }`
				`total wins: #{ player.match_wins } (#{ winrate }%)`
			"""
			bot.chat channel, message

# db.ref "ladders/smash-4/matches"
# .on "child_changed", (snapshot, oldKey) ->
#
# 	match = new Match(snapshot.key, snapshot.val())
#
# 	if match.status is MatchStatus.VALID
# 		message = """
# 			[**#{ match.challenger() } vs. #{ match.defender() }**]: **#{ match.winnerName() }** won! (#{ match.score[0] }-#{ match.score[1] })
#
# 				**#{ match.challenger() }** used the following characters: [**#{ match.characters[0] }**]
# 				**#{ match.defender() }** used the following characters: [**#{ match.characters[1] }**]
#
# 				stages used: [**#{ match.stages }**]\n
# 			"""
#
# 		if online then bot.sendMessage(channel, message)
