if SERVER then
    AddCSLuaFile()

    resource.AddFile('sound/scythe.mp3')

    resource.AddFile('materials/vgui/ttt/icon_dancegun')
    resource.AddFile('materials/vgui/ttt/dance_overlay')
    resource.AddFile('materials/vgui/ttt/hud_icon_dancing.png')
end

SWEP.Base = 'weapon_tttbase'

SWEP.Spawnable = true
SWEP.AutoSpawnable = false
SWEP.AdminSpawnable = true

SWEP.HoldType = 'pistol'

SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false

sound.Add({
    name = 'Weapon_Deagle.Reaper',
    channel = CHAN_STATIC,
    volume = 1.0,
    level = 130,
    sound = 'scythe.mp3'
})

if CLIENT then
    hook.Add('Initialize', 'ttt2_dancegun_init_language', function()
        LANG.AddToLanguage('English', 'ttt2_weapon_dancegun', 'Dancegun')
        LANG.AddToLanguage('Deutsch', 'ttt2_weapon_dancegun', 'Tanzpistole')
        
        LANG.AddToLanguage('English', 'ttt2_weapon_dancegun_desc', 'Shoot a player to let him dance.')
        LANG.AddToLanguage('Deutsch', 'ttt2_weapon_dancegun_desc', 'Schieße auf einen Spieler, um ihn tanzen zu lassen.')
    end)

    SWEP.Author = 'Mineotopia'

    SWEP.ViewModelFOV = 54
    SWEP.ViewModelFlip = false

    SWEP.Category = 'Deagle'
    SWEP.Icon = 'vgui/ttt/icon_dancegun'
    SWEP.EquipMenuData = {
        type = 'Weapon',
        name = 'ttt2_weapon_dancegun',
        desc = 'ttt2_weapon_dancegun_desc'
    }
end

-- dmg
SWEP.Primary.Delay = 1
SWEP.Primary.Recoil = 6
SWEP.Primary.Automatic = false
SWEP.Primary.NumShots = 1
SWEP.Primary.Damage = 0
SWEP.Primary.Cone = 0.00001
SWEP.Primary.Ammo = ''
SWEP.Primary.ClipSize = 3
SWEP.Primary.ClipMax = 3
SWEP.Primary.DefaultClip = 3

-- some other stuff
SWEP.IsSilent = false
SWEP.NoSights = false
SWEP.UseHands = true
SWEP.Kind = WEAPON_EXTRA
SWEP.CanBuy = {ROLE_TRAITOR, ROLE_DETECTIVE}

-- view / world
SWEP.ViewModel = 'models/weapons/cstrike/c_pist_deagle.mdl'
SWEP.WorldModel = 'models/weapons/w_pist_deagle.mdl'
SWEP.Weight = 5
SWEP.Primary.Sound = Sound('Weapon_Deagle.Reaper')

-- register status effect icon
if CLIENT then
    hook.Add('Initialize', 'ttt2_dancegun_status_init', function() 
        STATUS:RegisterStatus('ttt2_dancegun_status', {
            hud = Material('vgui/ttt/hud_icon_dancing.png'),
            type = 'bad'
        })
    end)
end

--- HANDLE WEAPON ACTION ---
if CLIENT then
    net.Receive('ttt2_dancegun_dance', function()
        local target = net.ReadEntity()

        if not target or not IsValid(target) then return end
        
        target.dancing = net.ReadBool()

        if target.dancing then
            -- start dance animation
            if math.random(0, 1) == 0 then
                target:AnimRestartGesture(GESTURE_SLOT_CUSTOM, ACT_GMOD_GESTURE_TAUNT_ZOMBIE, false)
            else
                target:AnimRestartGesture(GESTURE_SLOT_CUSTOM, ACT_GMOD_TAUNT_DANCE, false)
            end
        else
            -- stop dance animation
            target:AnimResetGestureSlot(GESTURE_SLOT_CUSTOM)
        end
    end)

    -- draw a screen overlay
    hook.Add('RenderScreenspaceEffects', 'ttt2_dancegun_screen_overlay', function()
        if not LocalPlayer().dancing then return end

        DrawMaterialOverlay('vgui/ttt/dance_overlay', 0)
    end)
end

if SERVER then
    util.AddNetworkString('ttt2_dancegun_dance')

    -- this function removes the loadout of a player
    -- while also storing all information for a later use
    -- credit: Alf21
    local function RemoveLoadout(ply)
        ply.savedDancegunInventoryItems = table.Copy(ply:GetEquipmentItems())

        -- reset inventory
        ply.savedDancegunInventory = {}

        -- save inventory
        for _, v in pairs(ply:GetWeapons()) do
            ply.savedDancegunInventory[#ply.savedDancegunInventory + 1] = {cls = WEPS.GetClass(v), clip1 = v:Clip1(), clip2 = v:Clip2()}
        end

        ply.savedDancegunInventoryWeapon = WEPS.GetClass(ply:GetActiveWeapon())

        -- clear inventory
        ply:StripWeapons()
    end

    -- this function returns the loadout of a player
    -- which was previously stored
    -- credit: Alf21
    local function GiveLoadout(ply)
        if ply.savedDancegunInventory then
            for _, tbl in ipairs(ply.savedDancegunInventory) do
                if tbl.cls then
                    local wep = ply:Give(tbl.cls)

                    if IsValid(wep) then
                        wep:SetClip1(tbl.clip1 or 0)
                        wep:SetClip2(tbl.clip2 or 0)
                    end
                end
            end
        end

        if ply.savedDancegunInventoryWeapon then
            ply:SelectWeapon(ply.savedDancegunInventoryWeapon)
        end

        -- reset inventory
        ply.savedDancegunInventory = nil
        ply.savedDancegunInventoryItems = nil
    end

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
        net.Start('ttt2_dancegun_dance')
        net.WriteEntity(ply)
        net.WriteBool(ply.dancing)
        net.Broadcast()
    end

    local function EndDancing(ply)
        if not ply or not IsValid(ply) then return end

        -- unfreeze player
        ply:Freeze(false)
        ply.dancing = false
        ply:StopSound(ply.current_song)
        STATUS:RemoveStatus(ply, 'ttt2_dancegun_status')

        -- stop the dance - transmit to clients
        UpdateDancingOnClients(ply)

        -- give loadout back
        GiveLoadout(ply)

        timer.Stop(ply.dancing_timer)
    end

    function StartDancing(ply, attacker)
        if ply.dancing then return end

        ply.dancing = true
        ply.dancing_timer = 'ttt2_dancegun_timer_' .. tostring(CurTime())
        ply.damage_tick = 0
        ply.current_song = DANCEGUN:GetRandomSong()

        -- freeze player
        ply:Freeze(true)
        ply:EmitSound(ply.current_song, 80)
        STATUS:AddStatus(ply, 'ttt2_dancegun_status')

        -- let him dance - transmit to clients
        UpdateDancingOnClients(ply)

        -- save and remove player loadout
        RemoveLoadout(ply)

        -- precalc dancegun parameters based on convars
        local duration = GetConVar('ttt_dancegun_duration'):GetInt()
        local damage = GetConVar('ttt_dancegun_damage'):GetInt()

        local tick_damage = damage / duration

        -- start damage timer
        timer.Create(ply.dancing_timer, 1, 0, function()
            if not ply or not IsValid(ply) then return end
            if not attacker or not IsValid(attacker) then return end

            -- create damage
            InstantDamage(ply, tick_damage, attacker, ents.Create('weapon_ttt_dancegun'))
            
            -- add dance motion
            ply:ViewPunch(Angle(
                (math.random() * 60) - 20,
                (math.random() * 60) - 20,
                (math.random() * 40) - 10
            ))

            ply.damage_tick = ply.damage_tick + 1

            if ply.damage_tick == duration then
                EndDancing(ply)
            end
        end)
    end

    -- handle hit with dancegun
    hook.Add('ScalePlayerDamage', 'ttt2_dancegun_hit_reg', function(ply, hitgroup, dmginfo)
        local attacker = dmginfo:GetAttacker()
        if not attacker or not IsValid(attacker) or not attacker:IsPlayer() or not IsValid(attacker:GetActiveWeapon()) then return end

        local wep = attacker:GetActiveWeapon()

        if wep:GetClass() ~= 'weapon_ttt_dancegun' then return end

        -- handle dancegun
        StartDancing(ply, attacker)

        -- remove damage
        dmginfo:SetDamage(0)
        return true
    end)

    -- handle no damage for dancing players
    hook.Add('ScalePlayerDamage', 'ttt2_dancegun_dance_handler', function(ply, hitgroup, dmginfo)
        if not ply or not IsValid(ply) or not ply:IsPlayer() then return end

        if not ply.dancing then return end

        -- remove damage
        dmginfo:SetDamage(0)
        return true
    end)

    -- handle death of dancing player
    hook.Add('PlayerDeath', 'ttt2_dancegun_player_death', function(ply)
        if not ply or not IsValid(ply) or not ply:IsPlayer() then return end

        if not ply.dancing then return end

        EndDancing(ply)
    end)

    -- stop dancing on round end
    hook.Add('TTTEndRound', 'ttt2_dancegun_end_round', function(ply)
        for _, p in ipairs(player.GetAll()) do
            if p.dancing then
                EndDancing(p)
            end
        end
    end)

    -- dancing players should not be able to pick up weapons
    hook.Add('PlayerCanPickupWeapon', 'ttt2_dancegun_no_pickup_while_dancing', function(ply, wep)
        if not ply or not IsValid(ply) then return end

        if ply.dancing then
            return false
        end
    end)
end