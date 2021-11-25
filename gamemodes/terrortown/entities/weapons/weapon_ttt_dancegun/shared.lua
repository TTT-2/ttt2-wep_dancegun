if SERVER then
	AddCSLuaFile()

	resource.AddFile("sound/scythe.wav")

	resource.AddFile("materials/vgui/ttt/icon_dancegun")
	resource.AddFile("materials/vgui/ttt/dance_overlay")
	resource.AddFile("materials/vgui/ttt/hud_icon_dancing.png")
end

local cvDancegunAmmo = CreateConVar("ttt_dancegun_ammo", "3", {FCVAR_ARCHIVE, FCVAR_NOTIFY, FCVAR_REPLICATED})

SWEP.Base = "weapon_tttbase"

SWEP.Spawnable = true
SWEP.AutoSpawnable = false
SWEP.AdminSpawnable = true

SWEP.HoldType = "pistol"

SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false

sound.Add({
	name = "Weapon_Deagle.Reaper",
	channel = CHAN_STATIC,
	volume = 1.0,
	level = 130,
	sound = "terrortown/dancegun/scythe.wav"
})

if CLIENT then
	SWEP.Author = "Mineotopia"

	SWEP.ViewModelFOV = 54
	SWEP.ViewModelFlip = false

	SWEP.Category = "Deagle"
	SWEP.Icon = "vgui/ttt/icon_dancegun"
	SWEP.EquipMenuData = {
		type = "item_weapon",
		name = "ttt2_weapon_dancegun",
		desc = "ttt2_weapon_dancegun_desc"
	}
end

-- dmg
SWEP.Primary.Delay = 1
SWEP.Primary.Recoil = 6
SWEP.Primary.Automatic = false
SWEP.Primary.NumShots = 1
SWEP.Primary.Damage = 0
SWEP.Primary.Cone = 0.00001
SWEP.Primary.Ammo = ""
SWEP.Primary.ClipSize = cvDancegunAmmo:GetInt()
SWEP.Primary.DefaultClip = cvDancegunAmmo:GetInt()

-- some other stuff
SWEP.IsSilent = false
SWEP.NoSights = false
SWEP.UseHands = true
SWEP.Kind = WEAPON_EXTRA
SWEP.CanBuy = {ROLE_TRAITOR, ROLE_DETECTIVE}

-- view / world
SWEP.ViewModel = "models/weapons/cstrike/c_pist_deagle.mdl"
SWEP.WorldModel = "models/weapons/w_pist_deagle.mdl"
SWEP.Weight = 5
SWEP.Primary.Sound = Sound("Weapon_Deagle.Reaper")

-- modify default weapon clip
function SWEP:Initialize()
	local clip = math.max(0, GetConVar("ttt_dancegun_ammo"):GetInt())

	self:SetClip1(clip)

	self.BaseClass.Initialize(self)
end

-- register status effect icon
if CLIENT then
	hook.Add("Initialize", "ttt2_dancegun_status_init", function()
		STATUS:RegisterStatus("ttt2_dancegun_status", {
			hud = Material("vgui/ttt/hud_icon_dancing.png"),
			type = "bad"
		})
	end)

	--- HANDLE WEAPON ACTION ---
	net.Receive("ttt2_dancegun_dance", function()
		local target = net.ReadEntity()

		if not target or not IsValid(target) then return end

		target.current_song = net.ReadString()
		target.dancing = net.ReadBool()

		if target.dancing then
			-- start dance animation
			if math.random(0, 1) == 0 then
				target:AnimRestartGesture(GESTURE_SLOT_CUSTOM, ACT_GMOD_GESTURE_TAUNT_ZOMBIE, false)
			else
				target:AnimRestartGesture(GESTURE_SLOT_CUSTOM, ACT_GMOD_TAUNT_DANCE, false)
			end

			-- start dance song
			target:EmitSound(target.current_song, 130)
		else
			-- stop dance animation
			target:AnimResetGestureSlot(GESTURE_SLOT_CUSTOM)

			-- stop dance song
			target:StopSound(target.current_song)
		end
	end)

	-- draw a screen overlay
	hook.Add("RenderScreenspaceEffects", "ttt2_dancegun_screen_overlay", function()
		if not LocalPlayer().dancing then return end

		DrawMaterialOverlay("vgui/ttt/dance_overlay", 0)
	end)
end

if SERVER then
	local cvDancegunDuration = CreateConVar("ttt_dancegun_duration", "20", {FCVAR_ARCHIVE, FCVAR_NOTIFY})
	local cvDancegunDamage = CreateConVar("ttt_dancegun_damage", "55", {FCVAR_ARCHIVE, FCVAR_NOTIFY})

	util.AddNetworkString("ttt2_dancegun_dance")

	local function InstantDamage(ply, damage, attacker, inflictor)
		local dmg = DamageInfo()

		dmg:SetDamage(damage or 2000)
		dmg:SetAttacker(attacker or ply)
		dmg:SetDamageForce(ply:GetAimVector())
		dmg:SetDamagePosition(ply:GetPos())
		dmg:SetDamageType(DMG_SLASH)

		if inflictor then
			dmg:SetInflictor(inflictor)
		end

		ply:TakeDamageInfo(dmg)
	end

	-- transmit dancing update to all clients
	local function UpdateDancingOnClients(ply)
		net.Start("ttt2_dancegun_dance")
		net.WriteEntity(ply)
		net.WriteString(ply.current_song)
		net.WriteBool(ply.dancing)
		net.Broadcast()
	end

	local function EndDancing(ply)
		if not IsValid(ply) then return end

		-- unfreeze player
		ply:Freeze(false)
		ply.dancing = false
		STATUS:RemoveStatus(ply, "ttt2_dancegun_status")

		-- stop the dance - transmit to clients
		UpdateDancingOnClients(ply)

		-- give loadout back
		if GetRoundState() ~= ROUND_PREP then
			ply:RestoreCachedWeapons()
		end

		timer.Stop(ply.dancing_timer)
	end

	local function StartDancing(ply, attacker)
		-- do not register shot when player is already dancing
		if ply.dancing then return end

		ply.dancing = true
		ply.dancing_timer = "ttt2_dancegun_timer_" .. tostring(CurTime())
		ply.damage_tick = 0
		ply.damage_took = 0
		ply.current_song = dancegun.GetRandomSong()

		-- precalc dancegun parameters based on convars
		local duration = cvDancegunDuration:GetInt()
		local damage = cvDancegunDamage:GetInt()

		-- freeze player
		ply:Freeze(true)
		STATUS:AddTimedStatus(ply, "ttt2_dancegun_status", duration, true)

		-- let him dance - transmit to clients
		UpdateDancingOnClients(ply)

		-- save and remove player loadout
		ply:CacheAndStripWeapons()

		-- start damage timer
		timer.Create(ply.dancing_timer, 1, 0, function()
			if not IsValid(ply) then return end

			ply.damage_tick = ply.damage_tick + 1

			local tick_damage = math.Round(damage / duration * ply.damage_tick, 0) - ply.damage_took

			ply.damage_took = ply.damage_took + tick_damage

			-- create damage
			InstantDamage(ply, tick_damage, attacker, ents.Create("weapon_ttt_dancegun"))

			-- add dance motion
			ply:ViewPunch(Angle(
				(math.random() * 60) - 20,
				(math.random() * 60) - 20,
				(math.random() * 40) - 10
			))

			if ply.damage_tick == duration then
				EndDancing(ply)
			end
		end)
	end

	-- handle hit with dancegun
	hook.Add("ScalePlayerDamage", "ttt2_dancegun_hit_reg", function(ply, hitgroup, dmginfo)
		local attacker = dmginfo:GetAttacker()

		if not IsValid(attacker) or not attacker:IsPlayer() or not IsValid(attacker:GetActiveWeapon()) then return end

		local wep = attacker:GetActiveWeapon()

		if wep:GetClass() ~= "weapon_ttt_dancegun" then return end

		-- handle dancegun
		StartDancing(ply, attacker)

		-- remove damage
		dmginfo:SetDamage(0)

		return true
	end)

	-- handle no damage for dancing players
	hook.Add("ScalePlayerDamage", "ttt2_dancegun_dance_handler", function(ply, hitgroup, dmginfo)
		if IsValid(ply) or not ply:IsPlayer() then return end

		if not ply.dancing then return end

		-- remove damage
		dmginfo:SetDamage(0)
		return true
	end)

	-- handle death of dancing player
	hook.Add("PlayerDeath", "ttt2_dancegun_player_death", function(ply)
		if not IsValid(ply) or not ply:IsPlayer() then return end

		if not ply.dancing then return end

		EndDancing(ply)
	end)

	-- stop dancing on round end
	hook.Add("TTTPrepareRound", "ttt2_dancegun_prepare_round", function()
		local plys = player.GetAll()

		for i = 1, #plys do
			local ply = plys[i]

			if not ply.dancing then continue end

			EndDancing(ply)
		end
	end)
end

-- MENU STUFF
if CLIENT then
	function SWEP:AddToSettingsMenu(parent)
		local form = vgui.CreateTTT2Form(parent, "header_equipment_additional")

		form:MakeSlider({
			serverConvar = "ttt_dancegun_duration",
			label = "label_dancegun_duration",
			min = 0,
			max = 60,
			decimal = 0
		})

		form:MakeSlider({
			serverConvar = "ttt_dancegun_damage",
			label = "label_dancegun_damage",
			min = 0,
			max = 200,
			decimal = 0
		})

		form:MakeSlider({
			serverConvar = "ttt_dancegun_ammo",
			label = "label_dancegun_ammo",
			min = 0,
			max = 10,
			decimal = 0
		})

		local form2 = vgui.CreateTTT2Form(parent, "header_equipment_dancegun_songs")

		form2:MakeHelp({
			label = "help_dancegun_songs"
		})

		for i = 1, #dancegun.songs do
			local songName = dancegun.songs[i]

			form2:MakeCheckBox({
				serverConvar = "ttt_dancegun_song_" .. songName .. "_enable",
				label = "label_dancegun_song_enable",
				params = {song = songName}
			})
		end
	end
end
