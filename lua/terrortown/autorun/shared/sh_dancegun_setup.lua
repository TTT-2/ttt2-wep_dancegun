-- dancegun HANDLING
dancegun = {}
dancegun.songs = {}

if SERVER then
	function dancegun.GetRandomSong()
		local enabledSongs = {}

		for i = 1, #dancegun.songs do
			local songName = dancegun.songs[i]
			local convarName = "ttt_dancegun_song_" .. songName .. "_enable"

			if not GetConVar(convarName):GetBool() then continue end

			enabledSongs[#enabledSongs + 1] = songName
		end

		-- no song enabled
		if #enabledSongs == 0 then return end

		-- return an enabled song
		return enabledSongs[math.random(#enabledSongs)]
	end
end

function dancegun.OnLoaded()
	local foundSongs = file.Find("sound/terrortown/dancegun/songs/*", "GAME")

	for i = 1, #foundSongs do
		local foundSong = foundSongs[i]

		local nameExploded = string.Explode(".", foundSong)
		nameExploded[#nameExploded] = nil

		local songName = table.concat(nameExploded, ".")

		dancegun.RegisterSong(songName, foundSong)
	end
end

function dancegun.RegisterSong(song_id, song_path)
	if SERVER then
		CreateConVar("ttt_dancegun_song_" .. song_id .. "_enable", 1, {FCVAR_ARCHIVE, FCVAR_NOTIFY})
	end

	dancegun.songs[#dancegun.songs + 1] = song_id

	sound.Add({
		name = song_id,
		channel = CHAN_STATIC,
		volume = 1.0,
		level = 130,
		sound = "terrortown/dancegun/songs/" .. song_path
	})

	resource.AddFile("sound/terrortown/dancegun/songs/" .. song_path)
end

hook.Add("InitPostEntity", "DanceGunInitPostEntity", dancegun.OnLoaded)
hook.Add("OnReloaded", "DanceGunOnReloaded", dancegun.OnLoaded)
