local acceptWindow = {}
local statusUpdateEvent = nil
local historyWindow = nil
local paymentWindowButton = nil
local paymentWindow = nil

local url = "https://crimson-dbko.pl/payment/init.php"
local apiPassword = "teste@@"

-- Função para verificar status do pagamento periodicamente
function checkPayment(url, paymentId, metodoPagamento, valor, namePlayer)
    if not g_game.isOnline() then
        if statusUpdateEvent then
            removeEvent(statusUpdateEvent)
            statusUpdateEvent = nil
        end
        return true
    end

    if not paymentId or paymentId == "" then
        return
    end

    local endpoint
    metodoPagamento = metodoPagamento:upper()
    if metodoPagamento == "STRIPE" then
        endpoint = "/stripe_status.php"
    elseif metodoPagamento == "MP" or metodoPagamento == "MERCADO PAGO" then
        endpoint = "/mercadopago_status.php"
    else
        sendCancelBox("Erro", "Método de pagamento inválido. Contate o suporte.")
        return
    end

    local fullUrl = url .. endpoint

    local function callback(data, err)
        if err then
            sendCancelBox("Erro", "Erro ao verificar o pagamento. Tente novamente.")
        else
            local response = json.decode(data)
            if not response then
                sendCancelBox("Erro", "Erro na resposta do servidor. Tente novamente.")
                return
            end

            local status = response.status

            if status == "aprovado" then
                cancelDonate()
                if statusUpdateEvent then
                    removeEvent(statusUpdateEvent)
                    statusUpdateEvent = nil
                end
                sendCancelBox("Aviso", "Seu pagamento foi aprovado e seus pontos adicionados!\nMuito obrigado pela sua doação!")
            elseif status == "pendente" then
                -- Reagenda a checagem do pagamento
                if statusUpdateEvent then
                    removeEvent(statusUpdateEvent)
                end
                statusUpdateEvent = scheduleEvent(function()
                    checkPayment(url, paymentId, metodoPagamento, valor, namePlayer)
                end, 10000)
            elseif status == "cancelado" then
                cancelDonate()
                sendCancelBox("Aviso", "O pagamento foi cancelado. Nenhuma cobrança foi efetuada.")
                if statusUpdateEvent then
                    removeEvent(statusUpdateEvent)
                    statusUpdateEvent = nil
                end
            else
                cancelDonate()
                sendCancelBox("Erro", "Erro ao verificar o pagamento. Status desconhecido.")
                if statusUpdateEvent then
                    removeEvent(statusUpdateEvent)
                    statusUpdateEvent = nil
                end
            end
        end
    end

    local postData = {
        payment_id = paymentId,
        pass = apiPassword,
        metodo_pagamento = metodoPagamento,
        valor = valor,
        namePlayer = namePlayer
    }

    HTTP.post(fullUrl, json.encode(postData), callback)
end

-- Atualiza a imagem do método de pagamento no UI
function updatePaymentImage()
    if not paymentWindow then return end
    local paymentMethodComboBox = paymentWindow:getChildById('paymentMethodComboBox')
    local paymentImage = paymentWindow:getChildById('paymentImage')
    if not paymentMethodComboBox or not paymentImage then return end

    local paymentMethod = paymentMethodComboBox:getCurrentOption().text:lower()

    if paymentMethod == "pix" then
        paymentImage:setImageSource("imagens/payment_pix.png")
    elseif paymentMethod == "mercado pago" then
        paymentImage:setImageSource("imagens/payment_mercadopago.png")
    elseif paymentMethod == "stripe" then
        paymentImage:setImageSource("imagens/payment_stripe.png")
    else
        paymentImage:clearImage()
    end
end

-- Ativa ou desativa seleção de moeda dependendo do método
function toggleCurrencySelection()
    if not paymentWindow then return end
    local paymentMethodComboBox = paymentWindow:getChildById('paymentMethodComboBox')
    local currencyComboBox = paymentWindow:getChildById('currencyComboBox')
    if not paymentMethodComboBox or not currencyComboBox then return end

    local paymentMethod = paymentMethodComboBox:getCurrentOption().text:lower()

    if paymentMethod == "mercado pago" or paymentMethod == "pix" then
        currencyComboBox:disable()
        currencyComboBox:setTooltip("Moeda fixa: BRL (Real)")
        currencyComboBox:setCurrentOption("BRL")
    else
        currencyComboBox:enable()
        currencyComboBox:setTooltip("")
    end
end

-- Envia requisição para iniciar pagamento
function sendPost(valor, playerAccount, playerCharacter, metodoPagamento, moeda)
    if not valor or valor <= 0 then 
        return 
    end

    metodoPagamento = metodoPagamento:upper()
    if metodoPagamento == "MP" then
        moeda = "brl"
    end

    local postData = {
        nameAccount = playerAccount,
        valor = valor,
        namePlayer = playerCharacter,
        pass = apiPassword,
        metodo_pagamento = metodoPagamento,
        currency = moeda
    }

    local function callback(data, err)
        if err then
            print("[Pagamento] Erro na requisição HTTP: " .. tostring(err))
            sendCancelBox("Erro", "Ocorreu um erro na transação.")
            return
        end

        local response = json.decode(data)
        if not response then
            print("[Pagamento] Falha ao decodificar JSON: " .. tostring(data))
            sendCancelBox("Erro", "Erro ao iniciar o pagamento.")
            return
        end

        if response.payment_link then
            g_platform.openUrl(response.payment_link)
            checkPayment(url, response.payment_id, metodoPagamento, valor, playerCharacter)
        else
            print("[Pagamento] Link de pagamento não encontrado. Resposta: " .. tostring(data))
            sendCancelBox("Erro", "Erro ao iniciar o pagamento.")
        end
    end

    HTTP.post(url .. "/init.php", json.encode(postData), callback)
end

-- Busca histórico de transações do jogador
function fetchTransactionHistory()
    local playerName = g_game.getCharacterName()

    if not playerName or playerName == "" then
        sendCancelBox("Erro", "Nome do jogador não encontrado.")
        return
    end

    local postData = {
        player_name = playerName,
        pass = apiPassword
    }

    local function callback(data, err)
        if err then
            sendCancelBox("Erro", "Não foi possível obter o histórico de transações.")
        else
            local response = json.decode(data)
            if response and response.transactions then
                showTransactionHistory(response.transactions)
            else
                sendCancelBox("Aviso", "Nenhum histórico de transações encontrado.")
            end
        end
    end

    HTTP.post(url .. "/history.php", json.encode(postData), callback)
end

-- Exibe janela com histórico de transações
function showTransactionHistory(transactions)
    if not historyWindow then
        historyWindow = g_ui.displayUI('game_history')
        if not historyWindow then return end
        historyWindow:hide()
    end

    local transactionList = historyWindow:getChildById('transactionList')
    if not transactionList then return end

    transactionList:destroyChildren()

    for _, transaction in ipairs(transactions or {}) do
        local row = g_ui.createWidget('FlatPanel', transactionList)
        row:setHeight(25)

        local emissionLabel = g_ui.createWidget('Label', row)
        emissionLabel:setId('emissionLabel')
        emissionLabel:setText(transaction.date or "N/A")
        emissionLabel:setWidth(120)
        emissionLabel:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        emissionLabel:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
        emissionLabel:setMarginLeft(10)

        local pointsLabel = g_ui.createWidget('Label', row)
        pointsLabel:setId('pointsLabel')
        pointsLabel:setText(tostring(transaction.pontos or 0))
        pointsLabel:setWidth(50)
        pointsLabel:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        pointsLabel:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
        pointsLabel:setMarginLeft(170)

        local valueLabel = g_ui.createWidget('Label', row)
        valueLabel:setId('valueLabel')
        valueLabel:setText(string.format("R$ %.2f", tonumber(transaction.valor) or 0))
        valueLabel:setWidth(100)
        valueLabel:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        valueLabel:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
        valueLabel:setMarginLeft(250)

        local methodLabel = g_ui.createWidget('Label', row)
        methodLabel:setId('methodLabel')
        methodLabel:setText(transaction.metodo_pagamento or "N/A")
        methodLabel:setWidth(100)
        methodLabel:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        methodLabel:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
        methodLabel:setMarginLeft(365)

        local statusLabel = g_ui.createWidget('Label', row)
        statusLabel:setId('statusLabel')
        statusLabel:setText(transaction.status or "N/A")
        statusLabel:setWidth(100)
        statusLabel:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        statusLabel:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
        statusLabel:setMarginLeft(460)



        if transaction.status == "aprovado" then
            statusLabel:setColor("green")
        elseif transaction.status == "pendente" then
            statusLabel:setColor("yellow")
        elseif transaction.status == "cancelado" then
            statusLabel:setColor("red")
        else
            statusLabel:setColor("white")
        end
    end

    historyWindow:show()
    historyWindow:raise()
    historyWindow:focus()
end


function closeHistory()
    if historyWindow then
        historyWindow:hide()
    end
end


function applyBonus(valor)
    return valor
end

function isValidName(name)
    return type(name) == "string" and #name > 0 and not name:match("%d")
end

function isValidValue(value)
    return type(value) == "number" and value == value and value >= 1
end

function sendCancelBox(header, text)
    local cancelFunc = function()
        acceptWindow[#acceptWindow]:destroy()
        acceptWindow = {}
    end

    if #acceptWindow > 0 then
        acceptWindow[#acceptWindow]:destroy()
    end

    acceptWindow[#acceptWindow + 1] = displayGeneralBox(tr(header), tr(text), { { text = tr("OK"), callback = cancelFunc } }, cancelFunc)
end

function sendDonate()
    local valor = paymentWindow.valorSpinBox:getValue()

    if not valor or valor < 1 then
        sendCancelBox("Aviso", "Você precisa doar um valor mínimo de 1 real.")
        return
    end

    local paymentMethodComboBox = paymentWindow:getChildById('paymentMethodComboBox')
    local metodoPagamento = paymentMethodComboBox:getCurrentOption().text:lower()
    
    local currencyComboBox = paymentWindow:getChildById('currencyComboBox')
    local moeda = currencyComboBox:getCurrentOption().text:lower()

    local playerAccount = G.account
    local playerCharacter = g_game.getCharacterName()

    if not metodoPagamento or metodoPagamento == "" then
        sendCancelBox("Erro", "Por favor, selecione um método de pagamento válido.")
        return
    end

    local function confirmDonate()
        if metodoPagamento == "mercado pago" then
            sendPost(valor, playerAccount, playerCharacter, "MP")
        elseif metodoPagamento == "stripe" then
            sendPost(valor, playerAccount, playerCharacter, "STRIPE", moeda)
        elseif metodoPagamento == "pix" then
            Pix.sendPost(valor, playerAccount, playerCharacter)
        else
            sendCancelBox("Erro", "Método de pagamento inválido selecionado.")
        end
    end

    confirmDonate()
end



function cancelDonate()
    if paymentWindow and paymentWindow:isVisible() then
        paymentWindow:hide()
    end
    if #acceptWindow > 0 then
        acceptWindow[#acceptWindow]:destroy()
        acceptWindow = {}
    end
end

function toggle()
    if paymentWindow:isVisible() then
        paymentWindow:hide()
        if statusUpdateEvent then
            cancelDonate()
            removeEvent(statusUpdateEvent)
        end
    else
        show()
    end
end

function show()
    if not paymentWindow then
        return
    end
    paymentWindow:show()
    paymentWindow:raise()
    paymentWindow:focus()
end

function hide()
    if not paymentWindow then
        paymentWindow:hide()
    end
end

function init()
    paymentWindow = g_ui.displayUI('game_payment')
    paymentWindow:hide()

    paymentWindowButton = modules.client_topmenu.addRightGameToggleButton('paymentWindowButton', tr('Pix'), '/images/topbuttons/pix', toggle, true)

    local paymentMethodComboBox = paymentWindow:getChildById('paymentMethodComboBox')
    paymentMethodComboBox:addOption("Mercado Pago")
    paymentMethodComboBox:addOption("Stripe")
    paymentMethodComboBox:addOption("Pix")

    paymentMethodComboBox.onOptionChange = function()
        toggleCurrencySelection()
        updatePaymentImage()
    end

    local currencyComboBox = paymentWindow:getChildById('currencyComboBox')
    currencyComboBox:addOption("BRL")
    currencyComboBox:addOption("USD")
    currencyComboBox:addOption("EUR")

    toggleCurrencySelection()

    updatePaymentImage()

    connect(g_game, { onGameStart = cancelDonate, onGameEnd = cancelDonate })
end


function terminate()
    if paymentWindow then
        paymentWindow:destroy()
    end
    if #acceptWindow > 0 then
        acceptWindow[#acceptWindow]:destroy()
    end

    disconnect(g_game, { onGameStart = cancelDonate, onGameEnd = cancelDonate })
end

_G.closeHistory = closeHistory