
import_csv = (slug, file) ->
	fs.readFile file, "utf8", (err, data) ->
		if err then throw err
		match_strings = data.split("\n")
		for i, match_string of match_strings

			if +i is 0 then continue

			match_array = match_string.split(",")
			time = match_array[1] ? false
			set = if match_array[2]? then +match_array[2] else 3
			players = [match_array[4], match_array[5]]
			games = []
			for j in [9, 13, 17, 21, 25] # game winner columns
				if match_array[j] is 'Defender' or match_array[j] is 'Challenger'
					games.push {
						reports: [
							{
								characters: [match_array[j-3] ? "", match_array[j-2] ? ""]
								stage: match_array[j-1] ? ""
								winner: +(match_array[j] is 'Defender') # then 1 else 0
							},
							{
								characters: [match_array[j-3] ? "", match_array[j-2] ? ""]
								stage: match_array[j-1] ? ""
								winner: +(match_array[j] is 'Defender') # then 1 else 0
							}
						]
					}
			console.log """
				i = #{ i }
				players: #{ players }
				set: #{ set }
				time: #{ time }
				"""
			db.ref("ladders/#{ slug }/matches").push(match = {
				games: games
				players: players
				set: set
				time: time
			})

import_csv "smash-4", "spreadsheet.csv"
