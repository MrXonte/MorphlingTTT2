if SERVER then
   AddCSLuaFile()
   util.AddNetworkString("ttt2_morphling_morph_net")
   resource.AddWorkshop("3263839562") -- Auto download the mod for clients
   resource.AddWorkshop("2144375749") -- Auto download the required mod for clients
end

local NET_MORPHLING_MORPH = "ttt2_morphling_morph_net"

SWEP.HoldType = "knife"

if CLIENT then
   SWEP.PrintName = "Morphling Disguiser"
   SWEP.Slot = 8
   SWEP.ViewModelFlip = false
   SWEP.ViewModelFOV = 90
   SWEP.DrawCrosshair = false

   SWEP.EquipMenuData = {
      type = "item_weapon",
    desc = "morphling_disguise_desc"
   }

   SWEP.Icon = "vgui/ttt/icon_morph_disguise"
   SWEP.IconLetter = "j"

   function SWEP:Initialize()
    self:AddTTT2HUDHelp("morphling_menu_help")
    self:AddHUDHelpLine("morphling_menu_help_line")
   end
end

SWEP.Base = "weapon_tttbase"

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
SWEP.AllowDrop = false -- Is the player able to drop the swep

SWEP.IsSilent = true

-- Pull out faster than standard guns
SWEP.DeploySpeed = 2

local MorphlingMenuOpen = false
local morphFrame
local cvMorphlingRevealRoleToTeam = SERVER and GetConVar("ttt2_morphling_reveal_role_to_team")

local function ShouldRevealRoleToTeam()
  if not SERVER then
    return false
  end

  if not cvMorphlingRevealRoleToTeam then
    cvMorphlingRevealRoleToTeam = GetConVar("ttt2_morphling_reveal_role_to_team")
  end

  return cvMorphlingRevealRoleToTeam and cvMorphlingRevealRoleToTeam:GetBool() or false
end

local function UpdateMorphDisguiserTarget(ply, target, revealRealIdentityToTeam)
  if not IsValid(ply) or not ply.UpdateStoredDisguiserTarget then return end

  if IsValid(target) and target:IsPlayer() then
    ply:UpdateStoredDisguiserTarget(
      target,
      target:GetModel(),
      target:GetSkin(),
      revealRealIdentityToTeam == true
    )

    return
  end

  -- Also pass explicit false when clearing to support identity-disguiser versions
  -- that store a teammate-visibility flag.
  ply:UpdateStoredDisguiserTarget(nil, nil, nil, false)
end

local function CloseMorphMenu()
  if IsValid(morphFrame) then
    morphFrame:Close()
  end

  morphFrame = nil

  MorphlingMenuOpen = false

  if CLIENT then
    gui.EnableScreenClicker(false)
  end
end

-- Removes the disguise tool on death or drop
function SWEP:OnDrop()
  self:Remove()
end

-- Primary attack opens a Disguise menu
if CLIENT then
  function SWEP:PrimaryAttack()
    if MorphlingMenuOpen == true then return end

    -- Store reference to local player
    local ply = LocalPlayer()

      -- Create a GUI and sound
    morphFrame = vgui.Create("DFrame")
    MorphlingMenuOpen = true
    morphFrame:SetSize(360, 360)
    morphFrame:Center()
    morphFrame:SetTitle(LANG.TryTranslation("morphling_menu_title"))
    morphFrame:SetDraggable(true)
    morphFrame:ShowCloseButton(true)
    morphFrame:SetVisible(true)
    morphFrame:SetDeleteOnClose(true)
    morphFrame.OnClose = function()
      MorphlingMenuOpen = false
      gui.EnableScreenClicker(false)
    end

    gui.EnableScreenClicker(true)
    surface.PlaySound("npc/antlion/attack_single1.wav")

      -- Create list of players available to disguise into
    local list = vgui.Create("DListView", morphFrame)
    list:Dock(FILL)
    list:SetMultiSelect(false)
    list:AddColumn(LANG.TryTranslation("morphling_menu_column_nick"))

      -- Populate the list
    for _, v in ipairs(player.GetAll()) do
      if (v:Alive() and not v:IsSpec()) or not v:Alive() then
        local row = list:AddLine(v:Nick())
        row.morphTarget = v
      end
    end

      -- When player selects one of the options, do X
    list.OnRowSelected = function(lst, index, pnl)
      if ply:Alive() and not ply:IsSpec() then
        local selectedTarget = pnl.morphTarget

        if not IsValid(selectedTarget) or not selectedTarget:IsPlayer() then
          ply:PrintMessage(HUD_PRINTTALK, "Error. Invalid morph target.")

          return
        end

        -- Close the menu
        CloseMorphMenu()
        -- Play a sound for the client
        surface.PlaySound("npc/antlion/distract1.wav")
            -- Start a message to the server and send selected target.
            -- The server uses net sender as the morphing player.
        net.Start(NET_MORPHLING_MORPH)
        net.WriteEntity(selectedTarget)
        net.SendToServer()
      else
        ply:PrintMessage(HUD_PRINTTALK, "Error. You must be alive to morph.")
      end
    end
  end

  function SWEP:Holster()
    CloseMorphMenu()

    return true
  end

  function SWEP:OnRemove()
    CloseMorphMenu()
  end

end

net.Receive(NET_MORPHLING_MORPH, function(_, sender)
  -- collect information from net message
  local morphlingPlayer = sender
  local morphTarget = net.ReadEntity()

  -- no clients allowed
  if CLIENT then return end

  if not IsValid(morphlingPlayer) or not morphlingPlayer:IsPlayer() then return end
  if not IsValid(morphTarget) or not morphTarget:IsPlayer() then return end

  if morphlingPlayer:GetRoleString() != "morphling" then
    morphlingPlayer:PrintMessage(HUD_PRINTTALK, "Error. You are no longer a Morphling. You can safely ignore this message.")

    return
  end

  -- Server-authoritative guardrails for forged / stale net messages.
  if not morphlingPlayer:Alive() or morphlingPlayer:IsSpec() then
    morphlingPlayer:PrintMessage(HUD_PRINTTALK, "Error. You must be alive to morph.")

    return
  end

  if not morphlingPlayer:HasWeapon("weapon_ttt_morph_disguise") then
    morphlingPlayer:PrintMessage(HUD_PRINTTALK, "Error. Morphling Disguiser not equipped.")

    return
  end

  if morphTarget:IsSpec() then
    morphlingPlayer:PrintMessage(HUD_PRINTTALK, "Error. Invalid morph target.")

    return
  end

  -- check if morphing player decides to remove disguise
  if morphTarget == morphlingPlayer then
    morphlingPlayer:PrintMessage(HUD_PRINTTALK, "You removed your disguise!")
    morphlingPlayer:DeactivateDisguiserTarget()
    UpdateMorphDisguiserTarget(morphlingPlayer, nil, false)

    return
  end

  -- otherwise, update his disguise
  morphlingPlayer:PrintMessage(HUD_PRINTTALK, "You morphed into: " .. morphTarget:Nick())
  -- Enable teammate real-identity visibility when supported by the identity addon.
  UpdateMorphDisguiserTarget(morphlingPlayer, morphTarget, ShouldRevealRoleToTeam())
  morphlingPlayer:DeactivateDisguiserTarget()
  morphlingPlayer:ToggleDisguiserTarget()

  -- alien effects
  local edata = EffectData()
  edata:SetEntity(morphlingPlayer)
  edata:SetOrigin(morphlingPlayer:GetNetworkOrigin())
  util.PaintDown(morphlingPlayer:LocalToWorld(morphlingPlayer:OBBCenter()), "Antlion.Splat", morphlingPlayer)
  util.Effect("AntlionGib", edata)
end)