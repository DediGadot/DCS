--[[
formation_score_aa.lua
Score tracking for DCS World formations.
Load this script through Mission Editor: Triggers -> DO SCRIPT FILE.
--]]

----------------------- CONFIGURATION -----------------------
local Score = {}

-- display scoreboard when this flag is true
Score.show_message = true

Score.weights = {
  kill_air          = 100,
  kill_ground       = 50,
  kill_ship         = 150,
  sortie            = 10,
  refuel            = 5,
  csar_pickup       = 25,
  ordnance_bonus_kg = 0.2,
  friendly_fire_pen = 200
}

Score.broadcastInterval = 60

--------------------------- STATE ---------------------------
Score.sides = {}
local aircraftData = {}
local menuGroups = {}

------------------------- UTILITIES -------------------------
local function getFormationID(unit)
  local group = unit:getGroup()
  return group and group:getName() or 'Unknown'
end

local function getSideData(fid)
  local side = Score.sides[fid]
  if not side then
    side = {
      pts = 0,
      kills_air = 0,
      kills_ground = 0,
      kills_ship = 0,
      sorties = 0,
      refuels = 0,
      csar = 0,
      ff = 0,
      saved = 0
    }
    Score.sides[fid] = side
  end
  return side
end

local function ammoMass(ammo)
  local mass = 0
  if ammo then
    for _, slot in ipairs(ammo) do
      if slot.desc and slot.desc.mass then
        mass = mass + (slot.count or 0) * slot.desc.mass
      end
    end
  end
  return mass
end

---------------------- EVENT HANDLER ------------------------
local scoreHandler = {}
function scoreHandler:onEvent(event)
  local unit = event.initiator
  if not unit or not unit:getGroup() then return end
  local fid = getFormationID(unit)
  local uid = unit:getID()
  local side = getSideData(fid)
  local data = aircraftData[uid]

  if event.id == world.event.S_EVENT_BIRTH then
    aircraftData[uid] = { groupName = fid, airborne = false, coalition = unit:getCoalition() }
    if unit:getPlayerName() then
      local gid = unit:getGroup():getID()
      if not menuGroups[gid] then
        local sub = missionCommands.addSubMenuForGroup(gid, "Scoreboard")
        missionCommands.addCommandForGroup(gid, "Show scores", sub, function()
          Score.show_message = true
          Score.broadcast()
        end)
        menuGroups[gid] = sub
      end
    end

  elseif event.id == world.event.S_EVENT_TAKEOFF then
    aircraftData[uid] = aircraftData[uid] or { groupName = fid, coalition = unit:getCoalition() }
    data = aircraftData[uid]
    data.startAmmo = unit:getAmmo()
    data.airborne = true

  elseif event.id == world.event.S_EVENT_LAND then
    if data and data.airborne then
      local currentAmmo = unit:getAmmo()
      local leftover = ammoMass(currentAmmo)
      side.sorties = side.sorties + 1
      side.saved = side.saved + math.floor(leftover)
      side.pts = side.pts + Score.weights.sortie + leftover * Score.weights.ordnance_bonus_kg
      data.airborne = false
    end

  elseif event.id == world.event.S_EVENT_KILL then
    if event.target and Unit.isExist(event.target) then
      local cat = event.target:getDesc().category
      if cat == Unit.Category.AIRPLANE or cat == Unit.Category.HELICOPTER then
        side.kills_air = side.kills_air + 1
        side.pts = side.pts + Score.weights.kill_air
      elseif cat == Unit.Category.SHIP then
        side.kills_ship = side.kills_ship + 1
        side.pts = side.pts + Score.weights.kill_ship
      else
        side.kills_ground = side.kills_ground + 1
        side.pts = side.pts + Score.weights.kill_ground
      end
      if event.target:getCoalition() == unit:getCoalition() then
        side.ff = side.ff + 1
        side.pts = side.pts - Score.weights.friendly_fire_pen
      end
    end

  elseif event.id == world.event.S_EVENT_REFUELING then
    side.refuels = side.refuels + 1
    side.pts = side.pts + Score.weights.refuel

  elseif event.id == world.event.S_EVENT_PICKUP then
    side.csar = side.csar + 1
    side.pts = side.pts + Score.weights.csar_pickup
  end
end
world.addEventHandler(scoreHandler)

------------------------- BROADCAST -------------------------
local function formatScores()
  local lines = {}
  for fid, d in pairs(Score.sides) do
    local kills = d.kills_air + d.kills_ground + d.kills_ship
    table.insert(lines, string.format("[%s] Scoreboard: %d pts | Kills:%d FF:%d Sorties:%d Refuels:%d CSAR:%d Saved:%d kg", fid, d.pts, kills, d.ff, d.sorties, d.refuels, d.csar, d.saved))
  end
  return table.concat(lines, "\n")
end

function Score.broadcast()
  if Score.show_message then
    trigger.action.outText(formatScores(), 30)
    Score.show_message = false
  end
  return timer.getTime() + Score.broadcastInterval
end

timer.scheduleFunction(Score.broadcast, {}, timer.getTime() + Score.broadcastInterval)

-------------------------- RETURN ---------------------------
return Score

--[[
Quick self-test (not executed):

local blue = mist.cloneGroup('BLUE_PLANE', true)
local red  = mist.cloneGroup('RED_PLANE', true)
Unit.getByName('RED_PLANE-1'):destroy()
Score.show_message = true
Score.broadcast()
--]]
