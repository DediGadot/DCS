--[[
air_to_air_score.lua
Air-to-air score tracking for DCS World human groups.
Load this script through Mission Editor: Triggers -> DO SCRIPT FILE.
--]]

----------------------- CONFIGURATION -----------------------
local Score = {}

-- user flag to trigger scoreboard display
Score.flagShowBoard = "show_scoreboard"

Score.broadcastInterval = 60

--------------------------- STATE ---------------------------
Score.groups = {}
local menuGroups = {}

------------------------- UTILITIES -------------------------
local function getGroupName(unit)
  local group = unit:getGroup()
  return group and group:getName() or 'Unknown'
end

local function getGroupData(name)
  local data = Score.groups[name]
  if not data then
    data = { kills = 0, ff = 0 }
    Score.groups[name] = data
  end
  return data
end

---------------------- EVENT HANDLER ------------------------
local scoreHandler = {}
function scoreHandler:onEvent(event)
  local unit = event.initiator
  if not unit or not unit:getPlayerName() then return end

  local gName = getGroupName(unit)
  local data = getGroupData(gName)

  if event.id == world.event.S_EVENT_BIRTH then
    local gid = unit:getGroup():getID()
    if not menuGroups[gid] then
      local sub = missionCommands.addSubMenuForGroup(gid, 'Scoreboard')
      missionCommands.addCommandForGroup(gid, 'Show scores', sub, function()
        trigger.action.setUserFlag(Score.flagShowBoard, 1)
      end)
      menuGroups[gid] = sub
    end

  elseif event.id == world.event.S_EVENT_KILL then
    if event.target and Unit.isExist(event.target) then
      local cat = event.target:getDesc().category
      if cat == Unit.Category.AIRPLANE or cat == Unit.Category.HELICOPTER then
        if event.target:getCoalition() == unit:getCoalition() then
          data.ff = data.ff + 1
        else
          data.kills = data.kills + 1
        end
      end
    end
  end
end
world.addEventHandler(scoreHandler)

------------------------- BROADCAST -------------------------
local function formatScores()
  local lines = {}
  for gname, d in pairs(Score.groups) do
    table.insert(lines, string.format('[%s] A2A kills:%d  FF:%d', gname, d.kills, d.ff))
  end
  return table.concat(lines, '\n')
end

function Score.broadcast()
  if trigger.misc.getUserFlag(Score.flagShowBoard) == 1 then
    trigger.action.outText(formatScores(), 30)
    trigger.action.setUserFlag(Score.flagShowBoard, 0)
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
trigger.action.setUserFlag('show_scoreboard', 1)
Score.broadcast()
--]]
