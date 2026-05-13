-- private variables
local shop2_EXTENTED_OPCODE = 207

shop2 = nil
transferWindow2 = nil
local otcv8shop22 = false
local shop2Button = nil
local msgWindow2 = nil
local browsingHistory2 = false
local transferValue2 = 0

-- for classic store
local storeUrl2 = ""
local coinsPacketSize2 = 0

local CATEGORIES = {}
local HISTORY = {}
local STATUS = {}
local AD = {}

local selectedOffer = {}

local function sendAction(action, data)
  if not g_game.getFeature(GameExtendedOpcode) then
    return
  end
  
  local protocolGame = g_game.getProtocolGame()
  if data == nil then
    data = {}
  end
  if protocolGame then
    protocolGame:sendExtendedJSONOpcode(shop2_EXTENTED_OPCODE, {action = action, data = data})
  end  
end

-- public functions
function init()
  connect(g_game, {
    onGameStart = check, 
    onGameEnd = hide,
    onStoreInit = onStoreInit,
    onStoreCategories = onStoreCategories,
    onStoreOffers = onStoreOffers,
    onStoreTransactionHistory = onStoreTransactionHistory,    
    onStorePurchase = onStorePurchase,
    onStoreError = onStoreError,
    onCoinBalance = onCoinBalance    
  })

  ProtocolGame.registerExtendedJSONOpcode(shop2_EXTENTED_OPCODE, onExtendedJSONOpcode)
  
  if g_game.isOnline() then
    check()
  end
  createshop2()
  createtransferWindow2()
end

function terminate()
  disconnect(g_game, {
    onGameStart = check, 
    onGameEnd = hide,
    onStoreInit = onStoreInit,
    onStoreCategories = onStoreCategories,
    onStoreOffers = onStoreOffers,
    onStoreTransactionHistory = onStoreTransactionHistory,    
    onStorePurchase = onStorePurchase,
    onStoreError = onStoreError,
    onCoinBalance = onCoinBalance    
  })

  ProtocolGame.unregisterExtendedJSONOpcode(shop2_EXTENTED_OPCODE, onExtendedJSONOpcode)
  
  if shop2Button then
    shop2Button:destroy()
    shop2Button = nil
  end
  if shop2 then
    disconnect(shop2.categories, { onChildFocusChange = changeCategory })
    shop2:destroy()
    shop2 = nil
  end
  if msgWindow2 then
    msgWindow2:destroy()
  end
end

function check()
  otcv8shop22 = false
  sendAction("init")
end

function hide()
  if not shop2 then
    return
  end
  shop2:hide()
end

function show()
  if not shop2 or not shop2Button then
    return
  end
  if g_game.getFeature(GameIngameStore) then
    g_game.openStore(0)
  end
  
  shop2:show()
  shop2:raise()
  shop2:focus()
end

function softHide()
  if not transferWindow2 then return end

  transferWindow2:hide()
  shop2:show()
end

function showTransfer()
  if not shop2 or not transferWindow2 then return end

  hide()
  transferWindow2:show()
  transferWindow2:raise()
  transferWindow2:focus()
end

function hideTransfer()
  if not shop2 or not transferWindow2 then return end

  transferWindow2:hide()
  show()
end

function toggle()
  if not shop2 then
    return
  end
  if shop2:isVisible() then
    return hide()
  end
  show()
  check()
end

function createshop2()
  if shop2 then return end
  shop2 = g_ui.displayUI('shop2')
  shop2:hide()
  shop2Button = modules.client_topmenu.addRightGameToggleButton('shop2Button', tr('Shop Event points'), '/images/topbuttons/shop', toggle, false, 4)
  connect(shop2.categories, { onChildFocusChange = changeCategory })
end

function createtransferWindow2()
  if transferWindow2 then return end
  transferWindow2 = g_ui.displayUI('transfer2')
  transferWindow2:hide()
end

function onStoreInit(url, coins)
  if otcv8shop22 then return end
  storeUrl2 = url
  if storeUrl2:len() > 0 then
    if storeUrl2:sub(storeUrl2:len(), storeUrl2:len()) ~= "/" then
      storeUrl2 = storeUrl2 .. "/"
    end
    storeUrl2 = storeUrl2 .. "64/"
    if storeUrl2:sub(1, 4):lower() ~= "http" then
      storeUrl2 = "http://" .. storeUrl2
    end
  end
  coinsPacketSize2 = coins
  createshop2()
  createtransferWindow2()
end

function onStoreCategories(categories)
  if not shop2 or otcv8shop22 then return end
  local correctCategories = {}
  for i, category in ipairs(categories) do
    local image = ""
    if category.icon:len() > 0 then
      image = storeUrl2 .. category.icon
    end
    table.insert(correctCategories, {
      type = "image",
      image = image,
      name = category.name,
      offers = {}
    })
  end
  processCategories(correctCategories)
end

function onStoreOffers(categoryName, offers)
  if not shop2 or otcv8shop22 then return end
  local updated = false
    
  for i, category in ipairs(CATEGORIES) do
    if category.name == categoryName then
      if #category.offers ~= #offers then
        updated = true
      end
      for i=1,#category.offers do
        if category.offers[i].title ~= offers[i].name or category.offers[i].id ~= offers[i].id or category.offers[i].cost ~= offers[i].price then
          updated = true
        end
      end
      if updated then    
        for offer in pairs(category.offers) do
          category.offers[offer] = nil
        end
        for i, offer in ipairs(offers) do
          local image = ""
          if offer.icon:len() > 0 then
            image = storeUrl2 .. offer.icon
          end
          table.insert(category.offers, {
            id=offer.id,
            type="image",
            image=image,
            cost=offer.price,
            title=offer.name,
            description=offer.description        
          })
        end
      end
    end
  end
  if not updated then
    return
  end
  
  local activeCategory = shop2.categories:getFocusedChild()
  changeCategory(activeCategory, activeCategory)
end

function onStoreTransactionHistory(currentPage, hasNextPage, offers)
  if not shop2 or otcv8shop22 then return end
  HISTORY = {}
  for i, offer in ipairs(offers) do
    table.insert(HISTORY, {
      id=offer.id,
      type="image",
      image=storeUrl2 .. offer.icon,
      cost=offer.price,
      title=offer.name,
      description=offer.description        
    })
  end
  
  if not browsingHistory2 then return end  
  clearOffers()
  shop2.categories:focusChild(nil)
  for i, transaction in ipairs(HISTORY) do
    addOffer(0, transaction)
  end
end

function onStorePurchase(message)
  if not shop2 or otcv8shop22 then return end
  if not transferWindow2:isVisible() then
    processMessage2({title="Successful shop2 purchase", msg=message})
  else
    processMessage2({title="Successfuly gifted coins", msg=message})
    softHide()
  end
end

function onStoreError(errorType, message)
  if not shop2 or otcv8shop22 then return end
  if not transferWindow2:isVisible() then
    processMessage2({title="shop2 Error", msg=message})
  else
    processMessage2({title="Gift coins error", msg=message})
  end
end

function onCoinBalance(coins, transferableCoins)
  if not shop2 or otcv8shop22 then return end
  shop2.infoPanel.points2:setText(tr("") .. " " .. coins)
  transferWindow2.coinsBalance:setText(tr('Transferable Tibia Coins: ') .. coins)
  transferWindow2.coinsAmount:setMaximum(coins)
  shop2.infoPanel.buy:hide()
  shop2.infoPanel:setHeight(20)
end

function transferCoins()
  if not transferWindow2 then return end
  local amount = 0
  amount = transferWindow2.coinsAmount:getValue()
  local recipient = transferWindow2.recipient:getText()

  g_game.transferCoins(recipient, amount)
  transferWindow2.recipient:setText('')
  transferWindow2.coinsAmount:setValue(0)
end

function onExtendedJSONOpcode(protocol, code, json_data)
  createshop2()
  createtransferWindow2()

  local action = json_data['action']
  local data = json_data['data']
  local status = json_data['status']
  if not action or not data then
    return false
  end
  
  otcv8shop22 = true
  if action == 'categories' then
    processCategories(data)
  elseif action == 'history' then
    processHistory(data)
  elseif action == 'message' then
    processMessage2(data)
  end

  if status then
    processStatus(status)
  end
end

function clearOffers()
  while shop2.offers:getChildCount() > 0 do
    local child = shop2.offers:getLastChild()
    shop2.offers:destroyChildren(child)
  end
end

function clearCategories()
  CATEGORIES = {}
  clearOffers()
  while shop2.categories:getChildCount() > 0 do
    local child = shop2.categories:getLastChild()
    shop2.categories:destroyChildren(child)
  end
end

function clearHistory()
  HISTORY = {}
  if browsingHistory2 then
    clearOffers()
  end
end

function processCategories(data)
  if table.equal(CATEGORIES,data) then
    return
  end
  clearCategories()
  CATEGORIES = data
  for i, category in ipairs(data) do
    addCategory(category)
  end
  if not browsingHistory2 then
    local firstCategory = shop2.categories:getChildByIndex(1)
    if firstCategory then
      firstCategory:focus()
    end
  end
end

function processHistory(data)
  if table.equal(HISTORY,data) then
    return
  end
  HISTORY = data
  if browsingHistory2 then
    showHistory(true)
  end
end

function processMessage2(data)
  if msgWindow2 then
    msgWindow2:destroy()
  end
    
  local title = tr(data["title"])
  local msg = data["msg"]
  msgWindow2 = displayInfoBox(title, msg)
  msgWindow2.onDestroy = function(widget)
    if widget == msgWindow2 then
      msgWindow2 = nil
    end
  end
  msgWindow2:show()
  msgWindow2:raise()
  msgWindow2:focus()
end

function processStatus(data)
  if table.equal(STATUS,data) then
    return
  end
  STATUS = data

  if data['ad'] then 
    processAd(data['ad'])
  end
  if data['points'] then
    shop2.infoPanel.points2:setText(tr("") .. " " .. data['points'])
  end
  if data['buyUrl'] and data['buyUrl']:sub(1, 4):lower() == "http" then
    shop2.infoPanel.buy2:show()
    shop2.infoPanel.buy2.onMouseRelease = function() 
      scheduleEvent(function() g_platform.openUrl(data['buyUrl']) end, 50)
    end
  else
    shop2.infoPanel.buy:hide()
    shop2.infoPanel:setHeight(20)
  end
end

function processAd(data)
  if table.equal(AD,data) then
    return
  end
  AD = data
  
  if data['image'] and data['image']:sub(1, 4):lower() == "http" then
    HTTP.downloadImage(data['image'], function(path, err) 
      if err then g_logger.warning("HTTP error: " .. err .. " - " .. data['image']) return end
      shop2.adPanel:setHeight(shop2.infoPanel:getHeight())
      shop2.adPanel.ad:setText("")
      shop2.adPanel.ad:setImageSource(path)
      shop2.adPanel.ad:setImageFixedRatio(true)
      shop2.adPanel.ad:setImageAutoResize(true)
      shop2.adPanel.ad:setHeight(shop2.infoPanel:getHeight())
    end)
  elseif data['text'] and data['text']:len() > 0 then
      shop2.adPanel:setHeight(shop2.infoPanel:getHeight())
      shop2.adPanel.ad:setText(data['text'])
      shop2.adPanel.ad:setHeight(shop2.infoPanel:getHeight())
  else
      shop2.adPanel:setHeight(0)
  end
  if data['url'] and data['url']:sub(1, 4):lower() == "http" then
    shop2.adPanel.ad.onMouseRelease = function() 
      scheduleEvent(function() g_platform.openUrl(data['url']) end, 50)
    end
  else
    shop2.adPanel.ad.onMouseRelease = nil
  end
end

function addCategory(data)
  local category
  if data["type"] == "item" then
    category = g_ui.createWidget('shop2CategoryItem', shop2.categories)  
    category.item:setItemId(data["item"])
    category.item:setItemCount(data["count"])
    category.item:setShowCount(false)
  elseif data["type"] == "outfit" then
    category = g_ui.createWidget('shop2CategoryCreature', shop2.categories)
    category.creature:setOutfit(data["outfit"])
    if data["outfit"]["rotating"] then
      category.creature:setAutoRotating(true)
    end
  elseif data["type"] == "image" then
    category = g_ui.createWidget('shop2CategoryImage', shop2.categories)
    if data["image"] and data["image"]:sub(1, 4):lower() == "http" then
       HTTP.downloadImage(data['image'], function(path, err) 
        if err then g_logger.warning("HTTP error: " .. err .. " - " .. data["image"]) return end
        category.image:setImageSource(path)
      end)
    else
      category.image:setImageSource(data["image"])
    end
  else
    g_logger.error("Invalid shop2 category type: " .. tostring(data["type"]))
    return
  end
  category:setId("category_" .. shop2.categories:getChildCount())
  category.name:setText(data["name"])
end

function showHistory(force)
  if browsingHistory2 and not force then
    return
  end

  if g_game.getFeature(GameIngameStore) and not otcv8shop22 then
    g_game.openTransactionHistory(100)
  end
  sendAction("history")

  browsingHistory2 = true
  clearOffers()
  shop2.categories:focusChild(nil)
  for i, transaction in ipairs(HISTORY) do
    addOffer(0, transaction)
  end
end

function addOffer(category, data)
  local offer
  if data["type"] == "item" then
    offer = g_ui.createWidget('shop2OfferItem', shop2.offers)  
    offer.item:setItemId(data["item"])
    offer.item:setItemCount(data["count"])
    offer.item:setShowCount(false)
  elseif data["type"] == "outfit" then
    offer = g_ui.createWidget('shop2OfferCreature', shop2.offers)
    offer.creature:setOutfit(data["outfit"])
    if data["outfit"]["rotating"] then
      offer.creature:setAutoRotating(true)
    end
  elseif data["type"] == "image" then
    offer = g_ui.createWidget('shop2OfferImage', shop2.offers)
    if data["image"] and data["image"]:sub(1, 4):lower() == "http" then
      HTTP.downloadImage(data['image'], function(path, err) 
        if err then g_logger.warning("HTTP error: " .. err .. " - " .. data['image']) return end
        if not offer.image then return end
        offer.image:setImageSource(path)
      end)
    elseif data["image"] and data["image"]:len() > 1 then
      offer.image:setImageSource(data["image"])
    end
  else
    g_logger.error("Invalid shop2 offer type: " .. tostring(data["type"]))
    return
  end
  offer:setId("offer_" .. category .. "_" .. shop2.offers:getChildCount())
  offer.title:setText(data["title"] .. " (" .. data["cost"] .. " Event Points)")
  offer.description:setText(data["description"])  
  offer.offerId = data["id"]
  if category ~= 0 then
    offer.onDoubleClick = buyOffer2
    offer.buyButton2.onClick = function() buyOffer2(offer) end
  else
    offer.buyButton2:hide()
  end
end


function changeCategory(widget, newCategory)
  if not newCategory then
    return
  end
  
  if g_game.getFeature(GameIngameStore) and widget ~= newCategory and not otcv8shop22 then
    local serviceType = 0
    if g_game.getFeature(GameTibia12Protocol) then
      serviceType = 2
    end
    g_game.requestStoreOffers(newCategory.name:getText(), serviceType)
  end
  
  browsingHistory2 = false
  local id = tonumber(newCategory:getId():split("_")[2])
  clearOffers()
  for i, offer in ipairs(CATEGORIES[id]["offers"]) do
    addOffer(id, offer)
  end
end

function buyOffer2(widget)
  if not widget then
    return
  end
  local split = widget:getId():split("_")
  if #split ~= 3 then
    return
  end
  local category = tonumber(split[2])  
  local offer = tonumber(split[3])  
  local item = CATEGORIES[category]["offers"][offer]
  if not item then
    return
  end
  
  selectedOffer = {category=category, offer=offer, title=item.title, cost=item.cost, id=widget.offerId}
  
  scheduleEvent(function()
      if msgWindow2 then
        msgWindow2:destroy()
      end
      
      local title = tr("Purchase Confirmation")
      local msg = "Você quer comprar " ..  item.title .. " por " .. item.cost .. " Event points?"
      msgWindow2 = displayGeneralBox(title, msg, {
          { text=tr('Yes'), callback=buyConfirmed },
          { text=tr('No'), callback=buyCanceled },
          anchor=AnchorHorizontalCenter}, buyConfirmed, buyCanceled)
      msgWindow2:show()
      msgWindow2:raise()
      msgWindow2:focus()
      msgWindow2:raise()
    end, 50)
end

function buyConfirmed()
  msgWindow2:destroy()
  msgWindow2 = nil
  sendAction("buy", selectedOffer)
  if g_game.getFeature(GameIngameStore) and selectedOffer.id and not otcv8shop22 then
    local offerName = selectedOffer.title:lower()
    if string.find(offerName, "name") and string.find(offerName, "change") and modules.client_textedit then
      modules.client_textedit.singlelineEditor("", function(newName)
        if newName:len() == 0 then
          return
        end
        g_game.buyStoreOffer(selectedOffer.id, 1, newName)        
      end)
    else
      g_game.buyStoreOffer(selectedOffer.id, 0, "")
    end
  end
end

function buyCanceled()
  msgWindow2:destroy()
  msgWindow2 = nil
  selectedOffer = {}
end