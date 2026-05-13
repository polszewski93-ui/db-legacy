local areas = {
  {
    from = {x = 644, y = 409, z = 7}, 
    to = {x = 683, y = 441, z = 7}, 
    name = "WELCOME TO DRAGON BALL UNIVERSE"
  },
  -- Add other areas as needed
}

local currentArea = ""

local window = nil
local nameLabel = nil
local fadeOutEvent = nil

function init()
  connect(
    g_game,
    {
      onGameStart = create,
      onGameEnd = destroy
    }
  )

  if g_game.isOnline() then
    create()
  end
end

function create()
  if window then
    return
  end
  
  window = g_ui.loadUI('areas', modules.game_interface.getMapPanel()) 
  window:setOpacity(1)  -- Set opacity to a non-zero value
  nameLabel = window:getChildById('nameLabel')

  connect(LocalPlayer, { onPositionChange = onPositionChange })
end

local interval = 7
local lastArea = {
    name = nil,
    timestamp = 0,
    event = nil
}

function isInArea(position, fromPos, toPos)
    local x, y = position.x, position.y
    return x >= fromPos.x and x <= toPos.x and y >= fromPos.y and y <= toPos.y
end

function fadeOut()
    if not lastArea.event then
        return
    end
 
    removeEvent(lastArea.event)
    g_effects.fadeOut(window, 750)
    lastArea.event = nil
end

function onPositionChange(player, newPos, oldPos)
    local currentArea = nil
    for _, area in ipairs(areas) do
        if isInArea(newPos, area.from, area.to) then
            currentArea = area
        end
    end
   
    if not currentArea then
        lastArea.name = nil
        return
    end

    local timeNow = os.time()
    if currentArea.name == lastArea.name
    or (currentArea.name ~= lastArea.name and timeNow < lastArea.timestamp + interval) then
        return
    end

    nameLabel:setText(currentArea.name)
    nameLabel:unlock()
    g_effects.fadeIn(window, 750)

    lastArea = {
        name = currentArea.name,
        timestamp = timeNow,
        event = scheduleEvent(fadeOut, 3000)
    }
end

function terminate()
  disconnect(
    g_game,
    {
      onGameStart = create,
      onGameEnd = destroy
    }
  )
  
  if window then
    destroy()
  end
end

function destroy()
  disconnect(LocalPlayer, { onPositionChange = onPositionChange })

  if window then
    window:destroy()
    window = nil
  end

  nameLabel = nil
  fadeOutEvent = nil
  currentArea = ""
end