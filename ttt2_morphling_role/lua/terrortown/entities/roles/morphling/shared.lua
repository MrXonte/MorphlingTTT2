if SERVER then
  AddCSLuaFile()

  resource.AddFile("materials/vgui/ttt/dynamic/roles/icon_morph.vmt")

  CreateConVar(
    "ttt2_morphling_reveal_role_to_team",
    "1",
    {FCVAR_NOTIFY, FCVAR_ARCHIVE, FCVAR_REPLICATED},
    "If enabled, teammates can see the Morphling's real role while disguised.",
    0,
    1
  )
end

function ROLE:PreInitialize()
  self.color = Color(216, 24, 89, 255)

  self.abbr = "morph" -- abbreviation
  self.surviveBonus = 0.5 -- bonus multiplier for every survive while another player was killed
  self.scoreKillsMultiplier = 5 -- multiplier for kill of player of another team
  self.scoreTeamKillsMultiplier = -16 -- multiplier for teamkill
  self.preventFindCredits = false
  self.preventKillCredits = false
  self.preventTraitorAloneCredits = false

  self.isOmniscientRole = true

  self.defaultEquipment = SPECIAL_EQUIPMENT -- here you can set up your own default equipment
  self.defaultTeam = TEAM_TRAITOR

  self.conVarData = {
    pct = 0.17, -- necessary: percentage of getting this role selected (per player)
    maximum = 1, -- maximum amount of roles in a round
    minPlayers = 6, -- minimum amount of players until this role is able to get selected
    credits = 1, -- the starting credits of a specific role
    togglable = true, -- option to toggle a role for a client if possible (F1 menu)
    random = 50,
    traitorButton = 1, -- can use traitor buttons
    shopFallback = SHOP_FALLBACK_TRAITOR
  }
end

-- now link this subrole with its baserole
function ROLE:Initialize()
  roles.SetBaseRole(self, ROLE_TRAITOR)
end

if CLIENT then
  function ROLE:AddToSettingsMenu(parent)
    local form = vgui.CreateTTT2Form(parent, "header_roles_additional")

    form:MakeCheckBox({
      serverConvar = "ttt2_morphling_reveal_role_to_team",
      label = "label_morphling_reveal_role_to_team"
    })

    form:MakeHelp({
      label = "help_morphling_reveal_role_to_team"
    })
  end
end

if SERVER then
  -- Give loadout on respawn and rolechange
  function ROLE:GiveRoleLoadout(ply, isRoleChange)
    ply:GiveEquipmentWeapon("weapon_ttt_morph_disguise")
    ply:DeactivateDisguiserTarget()
    ply:UpdateStoredDisguiserTarget(nil, nil, nil, false)
  end

  -- Remove loadout on death and rolechange
  function ROLE:RemoveRoleLoadout(ply, isRoleChange)
    ply:StripWeapon("weapon_ttt_morph_disguise")
    ply:DeactivateDisguiserTarget()
    ply:UpdateStoredDisguiserTarget(nil, nil, nil, false)
  end
end