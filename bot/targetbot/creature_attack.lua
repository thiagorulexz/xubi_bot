local targetBotLure = false
local targetCount = 0 
local delayValue = 0
local lureMax = 0
local anchorPosition = nil
local lastCall = now
local delayFrom = nil
local dynamicLureDelay = false

function getWalkableTilesCount(position)
  local count = 0

  for i, tile in pairs(getNearTiles(position)) do
      if tile:isWalkable() or tile:hasCreature() then
          count = count + 1
      end
  end

  return count
end

function rePosition(minTiles)
  minTiles = minTiles or 8
  if now - (lastCall or 0) < 500 then return end
  local pPos = player:getPosition()
  if not pPos then return end
  local tiles = getNearTiles(pPos)
  local playerTilesCount = getWalkableTilesCount(pPos)
  local tilesTable = {}

  if playerTilesCount > minTiles then return end
  for i, tile in ipairs(tiles) do
      tilesTable[tile] = not tile:hasCreature() and tile:isWalkable() and getWalkableTilesCount(tile:getPosition()) or nil
  end

  local best = 0
  local target = nil
  for k,v in pairs(tilesTable) do
      if v > best and v > playerTilesCount then
          best = v
          target = k:getPosition()
      end
  end

  if target then
      lastCall = now
      return CaveBot.GoTo(target, 0)
  end
end

TargetBot.Creature.attack = function(params, targets, isLooting) -- params {config, creature, danger, priority}
  if player:isWalking() then
    lastWalk = now
  end

  if not params then return end
  local config = params.config or {}
  local creature = params.creature
  if not creature then return end
  
  if not modules.game_bot.ensureAttackTarget(creature, isLooting) then
    return
  end

  if not isLooting then -- walk only when not looting
    TargetBot.Creature.walk(creature, config, targets)
  end

  -- attacks
  local mana = player:getMana() or 0
  if config.useGroupAttack and config.groupAttackSpell and config.groupAttackSpell:len() > 1 and mana > (tonumber(config.minManaGroup) or 0) then
    local radius = tonumber(config.groupAttackRadius) or 3
    local creatures = g_map.getSpectatorsInRange(player:getPosition(), false, radius, radius)
    local playersAround = false
    local monsters = 0
    for _, creature in ipairs(creatures) do
      if not creature:isLocalPlayer() and creature:isPlayer() and (not config.groupAttackIgnoreParty or (creature:getShield() or 0) <= 2) then
        playersAround = true
      elseif creature:isMonster() then
        monsters = monsters + 1
      end
    end
    if monsters >= (tonumber(config.groupAttackTargets) or 1) and (not playersAround or config.groupAttackIgnorePlayers) then
      if TargetBot.sayAttackSpell(config.groupAttackSpell, tonumber(config.groupAttackDelay) or 1000) then
        return
      end
    end
  end

  if config.useGroupAttackRune and (tonumber(config.groupAttackRune) or 0) > 100 then
    local radius = tonumber(config.groupRuneAttackRadius) or 3
    local creatures = g_map.getSpectatorsInRange(creature:getPosition(), false, radius, radius)
    local playersAround = false
    local monsters = 0
    for _, creature in ipairs(creatures) do
      if not creature:isLocalPlayer() and creature:isPlayer() and (not config.groupAttackIgnoreParty or (creature:getShield() or 0) <= 2) then
        playersAround = true
      elseif creature:isMonster() then
        monsters = monsters + 1
      end
    end
    if monsters >= (tonumber(config.groupRuneAttackTargets) or 1) and (not playersAround or config.groupAttackIgnorePlayers) then
      if TargetBot.useAttackItem(config.groupAttackRune, 0, creature, tonumber(config.groupRuneAttackDelay) or 1000) then
        return
      end
    end
  end
  if config.useSpellAttack and config.attackSpell and config.attackSpell:len() > 1 and mana > (tonumber(config.minMana) or 0) then
    if TargetBot.sayAttackSpell(config.attackSpell, tonumber(config.attackSpellDelay) or 1000) then
      return
    end
  end
  if config.useRuneAttack and (tonumber(config.attackRune) or 0) > 100 then
    if TargetBot.useAttackItem(config.attackRune, 0, creature, tonumber(config.attackRuneDelay) or 1000) then
      return
    end
  end
end

TargetBot.Creature.walk = function(creature, config, targets)
  if not creature then return end
  config = config or {}
  targets = targets or 1
  local cpos = creature:getPosition()
  local pos = player:getPosition()
  if not cpos or not pos then return end
  
  local isTrapped = true
  local dirs = {{-1,1}, {0,1}, {1,1}, {-1, 0}, {1, 0}, {-1, -1}, {0, -1}, {1, -1}}
  for i=1,#dirs do
    local tile = g_map.getTile({x=pos.x-dirs[i][1],y=pos.y-dirs[i][2],z=pos.z})
    if tile and tile:isWalkable(false) then
      isTrapped = false
    end
  end

  -- data for external dynamic lure
  local lureMin = tonumber(config.lureMin)
  local lureMaxVal = tonumber(config.lureMax)
  if lureMin and lureMaxVal and config.dynamicLure then
    if lureMin >= targets then
      targetBotLure = true
    elseif targets >= lureMaxVal then
      targetBotLure = false
    end
  end
  targetCount = targets
  delayValue = tonumber(config.lureDelay) or 250

  if lureMaxVal then
    lureMax = lureMaxVal
  end

  dynamicLureDelay = config.dynamicLureDelay
  delayFrom = tonumber(config.delayFrom)

  -- luring
  if config.closeLure and (tonumber(config.closeLureAmount) or 3) <= (getMonsters(1) or 0) then
    return TargetBot.allowCaveBot(150)
  end

  local killUnder = (storage.extras and tonumber(storage.extras.killUnder)) or 1
  local creatureHp = creature:getHealthPercent() or 100
  if TargetBot.canLure() and (config.lure or config.lureCavebot or config.dynamicLure) and not (creatureHp < killUnder) and not isTrapped then
    if targetBotLure then
      anchorPosition = nil
      return TargetBot.allowCaveBot(150)
    else
      if targets < (tonumber(config.lureCount) or 1) then
        if config.lureCavebot then
          anchorPosition = nil
          return TargetBot.allowCaveBot(150)
        else
          local path = findPath(pos, cpos, 5, {ignoreNonPathable=true, precision=2})
          if path then
            return TargetBot.walkTo(cpos, 10, {marginMin=5, marginMax=6, ignoreNonPathable=true})
          end
        end
      end
    end
  end

  local currentDistance = findPath(pos, cpos, 10, {ignoreCreatures=true, ignoreNonPathable=true, ignoreCost=true})
  local distLen = (currentDistance and #currentDistance) or 10

  if (not config.chase or distLen == 1) and not config.avoidAttacks and not config.keepDistance and config.rePosition and (creatureHp >= killUnder) then
    return rePosition(config.rePositionAmount or 6)
  end
  if ((killUnder > 1 and (creatureHp < killUnder)) or config.chase) and not config.keepDistance then
    if distLen > 1 then
      return TargetBot.walkTo(cpos, 10, {ignoreNonPathable=true, precision=1})
    end
  elseif config.keepDistance then
    local anchorRange = tonumber(config.anchorRange) or 3
    local keepDistRange = tonumber(config.keepDistanceRange) or 1
    if not anchorPosition or (distanceFromPlayer(anchorPosition) or 0) > anchorRange then
      anchorPosition = pos
    end
    if distLen ~= keepDistRange and distLen ~= keepDistRange + 1 then
      if config.anchor and anchorPosition and (getDistanceBetween(pos, anchorPosition) or 0) <= anchorRange*2 then
        return TargetBot.walkTo(cpos, 10, {ignoreNonPathable=true, marginMin=keepDistRange, marginMax=keepDistRange + 1, maxDistanceFrom={anchorPosition, anchorRange}})
      else
        return TargetBot.walkTo(cpos, 10, {ignoreNonPathable=true, marginMin=keepDistRange, marginMax=keepDistRange + 1})
      end
    end
  end

  --target only movement
  if config.avoidAttacks then
    local diffx = cpos.x - pos.x
    local diffy = cpos.y - pos.y
    local candidates = {}
    if math.abs(diffx) == 1 and diffy == 0 then
      candidates = {{x=pos.x, y=pos.y-1, z=pos.z}, {x=pos.x, y=pos.y+1, z=pos.z}}
    elseif diffx == 0 and math.abs(diffy) == 1 then
      candidates = {{x=pos.x-1, y=pos.y, z=pos.z}, {x=pos.x+1, y=pos.y, z=pos.z}}
    end
    for _, candidate in ipairs(candidates) do
      local tile = g_map.getTile(candidate)
      if tile and tile:isWalkable() then
        return TargetBot.walkTo(candidate, 2, {ignoreNonPathable=true})
      end
    end
  elseif config.faceMonster then
    local diffx = cpos.x - pos.x
    local diffy = cpos.y - pos.y
    local candidates = {}
    if diffx == 1 and diffy == 1 then
      candidates = {{x=pos.x+1, y=pos.y, z=pos.z}, {x=pos.x, y=pos.y-1, z=pos.z}}
    elseif diffx == -1 and diffy == 1 then
      candidates = {{x=pos.x-1, y=pos.y, z=pos.z}, {x=pos.x, y=pos.y-1, z=pos.z}}
    elseif diffx == -1 and diffy == -1 then
      candidates = {{x=pos.x, y=pos.y-1, z=pos.z}, {x=pos.x-1, y=pos.y, z=pos.z}} 
    elseif diffx == 1 and diffy == -1 then
      candidates = {{x=pos.x, y=pos.y-1, z=pos.z}, {x=pos.x+1, y=pos.y, z=pos.z}}       
    else
      local dir = player:getDirection()
      if diffx == 1 and dir ~= 1 then turn(1)
      elseif diffx == -1 and dir ~= 3 then turn(3)
      elseif diffy == 1 and dir ~= 2 then turn(2)
      elseif diffy == -1 and dir ~= 0 then turn(0)
      end
    end
    for _, candidate in ipairs(candidates) do
      local tile = g_map.getTile(candidate)
      if tile and tile:isWalkable() then
        return TargetBot.walkTo(candidate, 2, {ignoreNonPathable=true})
      end
    end
  end
end

onPlayerPositionChange(function(newPos, oldPos)
  if CaveBot.isOff() then return end
  if TargetBot.isOff() then return end
  if not lureMax or lureMax == 0 then return end
  if storage.TargetBotDelayWhenPlayer then return end
  if not dynamicLureDelay then return end

  local threshold = delayFrom or (lureMax / 2)
  if (targetCount or 0) < (threshold or 0) or not target() then return end
  CaveBot.delay(delayValue or 0)
end)
