if SERVER then
  AddCSLuaFile()

  resource.AddFile("materials/vgui/ttt/dynamic/roles/icon_morph.vmt")
end

function ROLE:PreInitialize()
  self.color = Color(216, 24, 89, 255)

  self.abbr = "morph" -- abbreviation
  self.score.surviveBonusMultiplier = 0.5 -- bonus multiplier for every survive while another player was killed
  self.score.killsMultiplier = 5 -- multiplier for kill of player of another team
  self.score.teamKillsMultiplier = -16 -- multiplier for teamkill
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

if SERVER then
  local function Cleanup(ply)
    if not ply.morphLoadout then return end
    ply.morphLoadout = nil
    ply.morphNextRequest = nil
    ply:StripWeapon("weapon_ttt_morph_disguise")
    ply:DeactivateDisguiserTarget()
    ply:UpdateStoredDisguiserTarget(NULL)
  end

  function ROLE:GiveRoleLoadout(ply)
    if not ply:IsTerror() or not ply:Alive() or ply:GetSubRole() ~= ROLE_MORPHLING then return end
    local state = ply.morphLoadout
    if not state then
      state = {}
      ply.morphLoadout = state
      ply:DeactivateDisguiserTarget()
      ply:UpdateStoredDisguiserTarget(NULL)
    end
    if ply:HasWeapon("weapon_ttt_morph_disguise") then return end
    -- Let the base manage retries; a failed carry check may return without a callback.
    ply:GiveEquipmentWeapon("weapon_ttt_morph_disguise", function(owner, _, wep)
      if owner.morphLoadout ~= state or owner:GetSubRole() ~= ROLE_MORPHLING
          or not owner:IsTerror() or not owner:Alive() then wep:Remove() end
    end)
  end

  function ROLE:RemoveRoleLoadout(ply, isRoleChange)
    if isRoleChange and ply:GetSubRole() == ROLE_MORPHLING then return end
    Cleanup(ply)
  end

  -- Cleanup before the next role's loadout can establish its own disguise.
  hook.Add("TTT2UpdateSubrole", "MorphlingCleanup", function(ply, oldRole, newRole)
    if oldRole == ROLE_MORPHLING and oldRole ~= newRole then Cleanup(ply) end
  end)
  -- Silent deaths bypass RemoveRoleLoadout in the default base.
  hook.Add("PostPlayerDeath", "MorphlingDeathCleanup", Cleanup)
  hook.Add("TTTPrepareRound", "MorphlingReset", function()
    for _, ply in ipairs(player.GetAll()) do Cleanup(ply) end
  end)
end
