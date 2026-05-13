--Lista de offsets para cada Outfit.
local OutfitOffsets = {
    [10010] = {
        [North] = {x = -58, y = -55},
        [East] = {x = -58, y = -55},
        [South] = {x = -58, y = -55},
        [West] = {x = -58, y = -55},
    }
}


local function translateDir(dir)
    if dir == NorthEast or dir == SouthEast then
        return East
    elseif dir == NorthWest or dir == SouthWest then
        return West
    end
    return dir
end

local function getOutfitInformationOffset(outfit, dir, creature)
     local offset = {x = -1, y = -20}  -- 55 com guild
    if OutfitOffsets[outfit] then
        offset = OutfitOffsets[outfit][translateDir(dir)]
    elseif (creature:isPlayer() and creature:isMounted()) then
        offset = {x = -35, y = -65}
    end


    return offset
end

local function onCreatureAppear(creature)
    local outfitType = creature:getOutfit().type

    if creature:isNpc() or creature:isMonster() and not OutfitOffsets[outfitType] then
        creature:setInformationOffset(0, 0)
    else 
        local Offset = getOutfitInformationOffset(outfitType, creature:getDirection(), creature)
        creature:setInformationOffset(Offset.x, Offset.y)
    end
end


local function onCreatureDirectionChange(creature, oldDirection, newDirection)
    local outfitType = creature:getOutfit().type

    if creature:isNpc() or creature:isMonster() and not OutfitOffsets[outfitType] then
        creature:setInformationOffset(0, 0)
    else 
        local Offset = getOutfitInformationOffset(outfitType, newDirection, creature)
        creature:setInformationOffset(Offset.x, Offset.y)
    end
end

local function onCreatureOutfitChange(creature, newOutfit, oldOutfit)
    local outfitType = creature:getOutfit().type

    if creature:isNpc() or creature:isMonster() and not OutfitOffsets[outfitType] then
        creature:setInformationOffset(0, 0)
    else 
        local Offset = getOutfitInformationOffset(outfitType, creature:getDirection(), creature)
        creature:setInformationOffset(Offset.x, Offset.y)
    end
end

function init()
    connect(LocalPlayer, {onOutfitChange = onCreatureOutfitChange})
    connect(Creature, {
        onAppear = onCreatureAppear,
        onDirectionChange = onCreatureDirectionChange,
        onOutfitChange = onCreatureOutfitChange
    })
end

function terminate()
    disconnect(LocalPlayer, {onOutfitChange = onCreatureOutfitChange})
    disconnect(Creature, {
        onAppear = onCreatureAppear,
        onDirectionChange = onCreatureDirectionChange,
        onOutfitChange = onCreatureOutfitChange
    })
end