if SERVER then
    AddCSLuaFile()
    util.AddNetworkString("ttt2_morphling_morph_net")
    resource.AddWorkshop("3263839562")
    resource.AddWorkshop("2144375749")
end

DEFINE_BASECLASS("weapon_tttbase")
SWEP.Base = "weapon_tttbase"
SWEP.HoldType = "knife"
SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/cstrike/c_knife_t.mdl"
SWEP.WorldModel = "models/weapons/w_knife_t.mdl"
SWEP.Primary.Damage = 0
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Delay = 1
SWEP.Primary.Ammo = "none"
SWEP.Kind = WEAPON_CLASS
SWEP.AllowDrop = false
SWEP.overrideDropOnDeath = DROP_ON_DEATH_TYPE_DENY
SWEP.AutoSpawnable = false
SWEP.notBuyable = true
SWEP.NoSights = true
SWEP.IsSilent = true
SWEP.DeploySpeed = 2

local channel = "ttt2_morphling_morph_net"

local function CanMorph(ply, wep)
    return IsValid(ply) and ply:IsPlayer() and ply:Alive() and ply:IsTerror()
        and ply:GetSubRole() == ROLE_MORPHLING and GetRoundState() == ROUND_ACTIVE
        and IsValid(wep) and wep:GetClass() == "weapon_ttt_morph_disguise"
        and wep:GetOwner() == ply and ply:GetActiveWeapon() == wep
end

-- Keep the corpse as the source of its appearance, not the player's current model.
local function ResolveTarget(source)
    if not IsValid(source) then return end
    if source:IsPlayer() then
        if source:Alive() and not source:IsSpec() then return source, source end
        return
    end
    if source:GetClass() ~= "prop_ragdoll" or not CORPSE.IsValidBody(source)
        or not CORPSE.IsRealPlayerCorpse(source) then return end
    local ply = CORPSE.GetPlayer(source)
    if IsValid(ply) and ply:IsPlayer() and not ply:Alive() then return ply, source end
end

function SWEP:Initialize()
    BaseClass.Initialize(self)
    if CLIENT then
        self:AddTTT2HUDHelp("morphling_menu_help")
        self:AddHUDHelpLine("morphling_menu_help_line")
    end
end

function SWEP:SecondaryAttack() end
function SWEP:Reload() end
function SWEP:OnDrop() if SERVER then self:Remove() end end

if SERVER then
    -- This is a menu tool; never inherit the base gun's firing behavior.
    function SWEP:PrimaryAttack()
        self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
    end

    net.Receive(channel, function(_, ply)
        local source = net.ReadEntity()
        if not IsValid(ply) or not ply:IsPlayer() then return end
        if not CanMorph(ply, ply:GetActiveWeapon()) then return end
        -- Throttle invalid requests too, without creating chat/network spam.
        if (ply.morphNextRequest or 0) > CurTime() then return end
        ply.morphNextRequest = CurTime() + 1
        local target, appearance = ResolveTarget(source)
        if not IsValid(target) then
            LANG.Msg(ply, "morphling_invalid_target", nil, MSG_MSTACK_WARN)
            return
        end
        if target == ply then
            ply:DeactivateDisguiserTarget()
            ply:UpdateStoredDisguiserTarget(NULL)
            LANG.Msg(ply, "morphling_removed", nil, MSG_MSTACK_PLAIN)
            return
        end
        -- Both supported Identity Disguisers use this three-argument API.
        ply:UpdateStoredDisguiserTarget(target, appearance:GetModel(), appearance:GetSkin())
        ply:DeactivateDisguiserTarget()
        ply:ActivateDisguiserTarget()
        local effect = EffectData()
        effect:SetEntity(ply)
        effect:SetOrigin(ply:GetNetworkOrigin())
        util.PaintDown(ply:LocalToWorld(ply:OBBCenter()), "Antlion.Splat", ply)
        util.Effect("AntlionGib", effect)
    end)
end

if CLIENT then
    SWEP.PrintName = "morphling_disguise_name"
    SWEP.Slot = 8
    SWEP.ViewModelFlip = false
    SWEP.ViewModelFOV = 90
    SWEP.DrawCrosshair = false
    SWEP.EquipMenuData = {type = "item_weapon", desc = "morphling_disguise_desc"}
    SWEP.Icon = "vgui/ttt/icon_identity_disguiser"
    SWEP.IconLetter = "j"

    local frame
    local function CloseMenu(wep)
        if IsValid(frame) and frame.weapon == wep then frame:Close() end
    end

    function SWEP:PrimaryAttack()
        self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
        if not IsFirstTimePredicted() or IsValid(frame) then return end
        local ply = LocalPlayer()
        if not CanMorph(ply, self) then return end
        frame = vgui.Create("DFrame")
        frame.weapon = self
        frame:SetSize(360, 360)
        frame:Center()
        frame:SetTitle(LANG.TryTranslation("morphling_menu_title"))
        frame:SetDeleteOnClose(true)
        frame:MakePopup()
        surface.PlaySound("npc/antlion/attack_single1.wav")
        frame.Think = function(panel)
            if not CanMorph(ply, self) then panel:Close() end
        end
        local list = vgui.Create("DListView", frame)
        list:Dock(FILL)
        list:SetMultiSelect(false)
        list:AddColumn(LANG.TryTranslation("morphling_menu_column_nick"))
        local seen = {}
        local function AddSource(source)
            local target = ResolveTarget(source)
            if not IsValid(target) or seen[target] then return end
            seen[target] = true
            list:AddLine(target:Nick()).morphTarget = source
        end
        for _, target in ipairs(player.GetAll()) do AddSource(target) end
        for _, corpse in ipairs(ents.FindByClass("prop_ragdoll")) do AddSource(corpse) end
        list.OnRowSelected = function(_, _, row)
            if not CanMorph(ply, self) then CloseMenu(self); return end
            if not IsValid(ResolveTarget(row.morphTarget)) then
                LANG.Msg("morphling_invalid_target", nil, MSG_MSTACK_WARN)
                return
            end
            local source = row.morphTarget
            CloseMenu(self)
            surface.PlaySound("npc/antlion/distract1.wav")
            net.Start(channel)
            net.WriteEntity(source)
            net.SendToServer()
        end
    end

    function SWEP:Holster() CloseMenu(self); return true end
    function SWEP:OnRemove()
        CloseMenu(self)
        BaseClass.OnRemove(self)
    end
end
