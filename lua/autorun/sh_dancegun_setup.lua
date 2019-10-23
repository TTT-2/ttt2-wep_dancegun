-- DANCEGUN CONVARS
CreateConVar('ttt_dancegun_duration', 20, {FCVAR_NOTIFY, FCVAR_ARCHIVE})
CreateConVar('ttt_dancegun_damage', 55, {FCVAR_NOTIFY, FCVAR_ARCHIVE})

-- DANCEGUN HANDLING
DANCEGUN = {}
DANCEGUN.songs = {}

hook.Add('TTTUlxInitCustomCVar', 'ttt2_dancegun_replicate_convars', function(name)
    for _, song_name in ipairs(DANCEGUN.songs) do
        local convar_name = 'ttt_dancegun_song_' .. song_name .. '_enable'
        local repvar_name = 'rep_ttt_dancegun_song_' .. song_name .. '_enable'

        ULib.replicatedWritableCvar(convar_name, repvar_name, GetConVar(convar_name):GetBool(), true, false, name)
    end

    ULib.replicatedWritableCvar('ttt_dancegun_duration', 'rep_ttt_dancegun_duration', GetConVar('ttt_dancegun_duration'):GetInt(), true, false, name)
    ULib.replicatedWritableCvar('ttt_dancegun_damage', 'rep_ttt_dancegun_damage', GetConVar('ttt_dancegun_damage'):GetInt(), true, false, name)
    ULib.replicatedWritableCvar('ttt_dancegun_ammo', 'rep_ttt_dancegun_ammo', GetConVar('ttt_dancegun_ammo'):GetInt(), true, false, name)
end)

function DANCEGUN:RegisterSong(song_id, song_path)
    CreateConVar('ttt_dancegun_song_' .. song_id .. '_enable', 1, {FCVAR_NOTIFY, FCVAR_ARCHIVE})
    table.insert(self.songs, song_id)

    sound.Add({
        name = song_id,
        channel = CHAN_STATIC,
        volume = 1.0,
        level = 130,
        sound = song_path
    })

    if SERVER then
        resource.AddFile('sound/' .. song_path)
    end
end

if SERVER then
    function DANCEGUN:GetRandomSong()
        local enabled_songs = {}
        for _, song_name in ipairs(DANCEGUN.songs) do
            local convar_name = 'ttt_dancegun_song_' .. song_name .. '_enable'

            if GetConVar(convar_name):GetBool() then
                table.insert(enabled_songs, song_name)
            end
        end

        -- no song enabled
        if #enabled_songs == 0 then return end

        -- return an enabled song
        return enabled_songs[math.random(#enabled_songs)]
    end
end

-- registering songs
hook.Add('OnGamemodeLoaded', 'ttt2_dancegun_register_songs', function()
    DANCEGUN:RegisterSong('russian', 'songs/russian.mp3')
    DANCEGUN:RegisterSong('dug_dance', 'songs/dug_dance.mp3')
    DANCEGUN:RegisterSong('90s_running', 'songs/90s_running.mp3')
    DANCEGUN:RegisterSong('beverly_hills', 'songs/beverly_hills.mp3')
    DANCEGUN:RegisterSong('hey_yeah', 'songs/hey_yeah.mp3')
    DANCEGUN:RegisterSong('horse', 'songs/horse.mp3')
    DANCEGUN:RegisterSong('spongebob', 'songs/spongebob.mp3')
    DANCEGUN:RegisterSong('epic_sax', 'songs/epic_sax.mp3')
    DANCEGUN:RegisterSong('number_one', 'songs/number_one.mp3')

    -- use this hook to add further songs
    hook.Run('TTT2DanceGunAddSongs')
end)

-- add to ULX
if CLIENT then
    hook.Add('TTTUlxModifyAddonSettings', 'ttt2_dancegun_add_to_ulx', function(name)
        local tttrspnl = xlib.makelistlayout{w = 415, h = 318, parent = xgui.null}

        -- Basic Settings
        local tttrsclp = vgui.Create('DCollapsibleCategory', tttrspnl)
        tttrsclp:SetSize(390, 75)
        tttrsclp:SetExpanded(1)
        tttrsclp:SetLabel('Basic Settings')

        local tttrslst = vgui.Create('DPanelList', tttrsclp)
        tttrslst:SetPos(5, 25)
        tttrslst:SetSize(390, 75)
        tttrslst:SetSpacing(5)

        local tttslid1 = xlib.makeslider{label = 'ttt_dancegun_duration (def. 20)', repconvar = 'rep_ttt_dancegun_duration', min = 0, max = 60, decimal = 0, parent = tttrslst}
        tttrslst:AddItem(tttslid1)

        local tttslid2 = xlib.makeslider{label = 'ttt_dancegun_damage (def. 55)', repconvar = 'rep_ttt_dancegun_damage', min = 0, max = 150, decimal = 0, parent = tttrslst}
        tttrslst:AddItem(tttslid2)

        local tttslid3 = xlib.makeslider{label = 'ttt_dancegun_ammo (def. 3)', repconvar = 'rep_ttt_dancegun_ammo', min = 0, max = 10, decimal = 0, parent = tttrslst}
        tttrslst:AddItem(tttslid3)

        -- Song Settings
        local tttrsclp1 = vgui.Create('DCollapsibleCategory', tttrspnl)
        tttrsclp1:SetSize(390, 20 * #DANCEGUN.songs)
        tttrsclp1:SetExpanded(1)
        tttrsclp1:SetLabel('Enable Songs')

        local tttrslst1 = vgui.Create('DPanelList', tttrsclp1)
        tttrslst1:SetPos(5, 25)
        tttrslst1:SetSize(390, 20 * #DANCEGUN.songs)
        tttrslst1:SetSpacing(5)

        for _, song_name in ipairs(DANCEGUN.songs) do
            local convar_name = 'ttt_dancegun_song_' .. song_name .. '_enable'
            local repvar_name = 'rep_ttt_dancegun_song_' .. song_name .. '_enable'
    
            local song = xlib.makecheckbox{label = convar_name .. ' (def. 1)', repconvar = repvar_name, parent = tttrslst1}
            tttrslst1:AddItem(song)
        end

        -- add to ULX
        xgui.hookEvent('onProcessModules', nil, tttrspnl.processModules)
        xgui.addSubModule('Dancegun', tttrspnl, nil, name)
    end)
end
