Iconsp = {}
Iconsp[1] = { tooltip = tr('You are poisoned'), path = '/game_healthinfo/icons/poisoned.png', id = 'condition_poisoned' }
Iconsp[2] = { tooltip = tr('You are burning'), path = '/game_healthinfo/icons/burning.png', id = 'condition_burning' }
Iconsp[4] = { tooltip = tr('You are electrified'), path = '/game_healthinfo/icons/electrified.png', id = 'condition_electrified' }
Iconsp[8] = { tooltip = tr('You are drunk'), path = '/game_healthinfo/icons/drunk.png', id = 'condition_drunk' }
Iconsp[16] = { tooltip = tr('You are protected by a magic shield'), path = '/game_healthinfo/icons/magic_shield.png', id = 'condition_magic_shield' }
Iconsp[32] = { tooltip = tr('You are paralysed'), path = '/game_healthinfo/icons/slowed.png', id = 'condition_slowed' }
Iconsp[64] = { tooltip = tr('You are hasted'), path = '/game_healthinfo/icons/haste.png', id = 'condition_haste' }
Iconsp[128] = { tooltip = tr('You may not logout during a fight'), path = '/game_healthinfo/icons/logout_block.png', id = 'condition_logout_block' }
Iconsp[256] = { tooltip = tr('You are drowing'), path = '/game_healthinfo/icons/drowning.png', id = 'condition_drowning' }
Iconsp[512] = { tooltip = tr('You are freezing'), path = '/game_healthinfo/icons/freezing.png', id = 'condition_freezing' }
Iconsp[1024] = { tooltip = tr('You are dazzled'), path = '/game_healthinfo/icons/dazzled.png', id = 'condition_dazzled' }
Iconsp[2048] = { tooltip = tr('You are cursed'), path = '/game_healthinfo/icons/cursed.png', id = 'condition_cursed' }
Iconsp[4096] = { tooltip = tr('Você está strengthened'), path = '/game_healthinfo/icons/strengthened.png', id = 'condition_strengthened' }
Iconsp[8192] = { tooltip = tr('You may not logout or enter a protection zone'), path = '/game_healthinfo/icons/protection_zone_block.png', id = 'condition_protection_zone_block' }
Iconsp[16384] = { tooltip = tr('You are within a protection zone'), path = '/game_healthinfo/icons/protection_zone.png', id = 'condition_protection_zone' }
Iconsp[32768] = { tooltip = tr('You are bleeding'), path = '/game_healthinfo/icons/bleeding.png', id = 'condition_bleeding' }
Iconsp[65536] = { tooltip = tr('You are hungry'), path = '/game_healthinfo/icons/hungry.png', id = 'condition_hungry' }

healthInfo2Window = nil
nameLabel = nil
outfitBox = nil
healthBar = nil
healthLabel = nil
levelLabel = nil

manaBar = nil
manaLabel = nil


function init()
	connect(g_game, { onGameEnd   = offline, onGameStart = refresh })
	connect(LocalPlayer, { onHealthChange = onHealthChange,
						   onManaChange = onManaChange })
						   


	healthInfo2Window = g_ui.displayUI('health.otui')
	healthInfo2Window:hide()
	
	healthInfo2Button = modules.client_topmenu.addRightGameToggleButton('healthInfo2Button', tr('Health Information'), '/images/topbuttons/healthDV', toggle) 
	
	
	outfitBox   = healthInfo2Window:getChildById('outfitBox')
	healthBar   = healthInfo2Window:getChildById('healthBar')
	healthLabel = healthInfo2Window:getChildById('healthLabel')

	manaBar   = healthInfo2Window:getChildById('manaBar')
	manaLabel = healthInfo2Window:getChildById('manaLabel')
	nameLabel   = healthInfo2Window:getChildById('nameLabel')




	
	if g_game.isOnline() then
		onStatesChange(g_game.getLocalPlayer(), g_game.getLocalPlayer():getStates(), 0)
		-- healthInfo2Window:show()
	end
	-- connect(LocalPlayer, { healthInfo2Window:show() })
	refresh()
end

function terminate()
	disconnect(g_game, { onGameEnd   = offline, onGameStart = refresh })
	disconnect(LocalPlayer, { onHealthChange = onHealthChange,
						      onManaChange = onManaChange })

  disconnect(g_game, { onGameEnd = offline })



  healthInfo2Window:destroy()
  healthInfo2Button:destroy()
end

function toggle()
  if healthInfo2Window:isVisible() then
    healthInfo2Window:hide()
  else
    healthInfo2Window:show()
	refresh()
  end
end

function offline()
	healthInfo2Window:hide()
	healthInfo2Window:recursiveGetChildById('panelCondition'):destroyChildren()
end

function refresh()
if g_game.isOnline() then
healthInfo2Window:show()
		local localPlayer = g_game.getLocalPlayer()
		nameLabel:setText(localPlayer:getName())
		local function updatePlayerOutfit()
			local player = g_game.getLocalPlayer()
				local currentOutfit = player:getOutfit()
				local outfit = {
				type = currentOutfit.type
				}
				outfitBox:setOutfit(outfit)
			scheduleEvent(updatePlayerOutfit, 500)
		end
		updatePlayerOutfit()
		onHealthChange(localPlayer, localPlayer:getHealth(), localPlayer:getMaxHealth())
		onManaChange(localPlayer, localPlayer:getMana(), localPlayer:getMaxMana())

		
	end
end


function setOutfitBox(outfit)
	outfitBox:setOutfit(outfit)
end

function onHealthChange(localPlayer, health, maxHealth)
  healthBar:setValue(health, 0, maxHealth)
  healthBar:setText(health .. ' / ' .. maxHealth)
 -- healthBar:setTooltip(tr(healthTooltip, health, maxHealth))
end

function onManaChange(localPlayer, mana, maxMana)
  manaBar:setValue(mana, 0, maxMana)
  manaBar:setText(mana .. ' / ' .. maxMana)
--  manaBar:setTooltip(tr(manaTooltip, mana, maxMana))
end



function onStatesChange(localPlayer, now, old)
  if now == old then return end
  local bitsChanged = bit32.bxor(now, old)
  for i = 1, 32 do
    local pow = math.pow(2, i-1)
    if pow > bitsChanged then break end
    local bitChanged = bit32.band(bitsChanged, pow)
    if bitChanged ~= 0 then
      toggleIcon(bitChanged)
    end
  end
end

function toggleIcon(bitChanged)
  local content = healthInfo2Window:recursiveGetChildById('panelCondition')

  local icon = content:getChildById(Iconsp[bitChanged].id)
  if icon then
    icon:destroy()
  else
    icon = loadIcon(bitChanged)
    icon:setParent(content)
  end
end

function loadIcon(bitChanged)
  local icon = g_ui.createWidget('ConditionWidget', content)
  icon:setId(Iconsp[bitChanged].id)
  icon:setImageSource(Iconsp[bitChanged].path)
  icon:setTooltip(Iconsp[bitChanged].tooltip)
  return icon
end