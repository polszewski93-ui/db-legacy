local acceptWindow = {}
local statusUpdateEvent = nil
local qrCodeWindow = nil
local url = "https://crimson-dbko.pl/payment/paymentpix.php"
local apiPassword = "teste@@"

Pix = {}

function pixInit()
end

function pixTerminate()
    if statusUpdateEvent then
        removeEvent(statusUpdateEvent)
        statusUpdateEvent = nil
    end
    if qrCodeWindow then
        qrCodeWindow:destroy()
        qrCodeWindow = nil
    end
end

function Pix.checkPayment(url, paymentId)
    if not g_game.isOnline() then
        removeEvent(statusUpdateEvent)
        return true
    end

    if not paymentId or paymentId == "" then
        return
    end

    local function callback(data, err)
        if not err then
            local response = json.decode(data)
            if response then
                local status = response.status

                -- L�gica baseada no status retornado
                if status == "aprovado" then
                    cancelDonate()
                    removeEvent(statusUpdateEvent)
                    if qrCodeWindow then
                        qrCodeWindow:hide()
                        qrCodeWindow = nil
                    end
                    sendCancelBox("Aviso", "Seu pagamento foi confirmado e seus pontos adicionados!")
                elseif status == "pendente" then
                    if qrCodeWindow and qrCodeWindow:getChildById('Loading') then
                        qrCodeWindow:getChildById('Loading'):show()
                    end
                    statusUpdateEvent = scheduleEvent(function()
                        Pix.checkPayment(url, paymentId)
                    end, 10000)
                elseif status == "cancelado" then
                    cancelDonate()
                    removeEvent(statusUpdateEvent)
                    if qrCodeWindow then
                        qrCodeWindow:hide()
                        qrCodeWindow = nil
                    end
                    sendCancelBox("Aviso", "O pagamento foi cancelado. Nenhuma cobran�a foi efetuada.")
                else
                    cancelDonate()
                    removeEvent(statusUpdateEvent)
                    if qrCodeWindow then
                        qrCodeWindow:hide()
                        qrCodeWindow = nil
                    end
                    sendCancelBox("Erro", "Erro ao verificar o pagamento. Status desconhecido.")
                end
            else
                sendCancelBox("Erro", "Erro na resposta do servidor. Tente novamente.")
            end
        else
            sendCancelBox("Erro", "Erro ao verificar o pagamento. Tente novamente.")
        end
    end

    local postData = {
        ["payment_id"] = paymentId,
        ["pass"] = apiPassword
    }

    HTTP.post(url, json.encode(postData), callback)
end


function Pix.returnQr(data, valor)
    local response = json.decode(data)
    if not response then
        sendCancelBox("Erro", "Erro ao processar a resposta da API.")
        return true
    end

    local base64 = response["qr_code_base64"]
    local copiaecola = response["qr_code"]
    local paymentId = response["payment_id"]

    if not base64 or not paymentId or not copiaecola then
        sendCancelBox("Aviso", "Dados incompletos na transação. Tente novamente mais tarde.")
        return true
    end

    Pix.currentPaymentId = paymentId

    if not qrCodeWindow then
        qrCodeWindow = g_ui.displayUI('qrcodePix')
    end

    local qrCode = qrCodeWindow:getChildById('qrCode')
    local loading = qrCodeWindow:getChildById('Loading')

    qrCode:setImageSourceBase64(base64)
    loading:hide()

    qrCode.onClick = function()
        g_window.setClipboardText(copiaecola)
        sendCancelBox("Aviso", "C�digo Pix copiado para a Área de transferência.")
    end

    qrCodeWindow:show()
    qrCodeWindow:raise()
    qrCodeWindow:focus()

    Pix.checkPayment(url, paymentId)
end

function Pix.sendPost(valor, playerAccount, playerCharacter)
    valor = tonumber(valor) -- Converte valor para número, caso seja uma string

    if not valor or valor <= 0 then
        sendCancelBox("Erro", "Valor inválido.")
        return
    end

    local postData = {
        ["nameAccount"] = playerAccount,
        ["valor"] = valor,
        ["namePlayer"] = playerCharacter,
        ["pass"] = apiPassword,
        ["metodo_pagamento"] = "PIX"
    }

    local function callback(data, err)
        if not err then
            Pix.returnQr(data, valor)
        else
            print("[PIX] Erro ao iniciar pagamento:", err)
            sendCancelBox("Erro", "Erro ao iniciar pagamento Pix.\nDetalhes: " .. tostring(err))
        end
    end

    print("Post Data:", json.encode(postData))
    HTTP.post(url, json.encode(postData), callback)
end



function onCancelPix()
    print("[Pix] Iniciando cancelamento da transa��o.")

    if qrCodeWindow then
        print("[Pix] Exibindo indicador de carregamento na janela do QR Code.")
        qrCodeWindow:getChildById('Loading'):show()
    end

    if statusUpdateEvent then
        print("[Pix] Removendo evento de atualização de status.")
        removeEvent(statusUpdateEvent)
        statusUpdateEvent = nil
    end

    if not Pix.currentPaymentId or Pix.currentPaymentId == "" then
        print("[Pix] Erro: ID da transação não definido.")
        sendCancelBox("Erro", "Nenhuma transação ativa para cancelar.")
        return
    end

    print("[Pix] ID da transa��o a ser cancelada: " .. Pix.currentPaymentId)

    local postData = {
        ["payment_id"] = Pix.currentPaymentId,
        ["pass"] = apiPassword,
        ["cancel_pix"] = true
    }
    

    print("[Pix] Dados enviados para cancelamento: " .. json.encode(postData))

    local function callback(data, err)
        if qrCodeWindow then
            print("[Pix] Ocultando indicador de carregamento.")
            qrCodeWindow:getChildById('Loading'):hide()
        end

        if not err then
            print("[Pix] Resposta recebida do servidor: " .. (data or "Nenhuma resposta"))
            local response = json.decode(data)
            if response and response.status == "cancelado" then
                print("[Pix] Transação pendente foi cancelada com sucesso.")
                if qrCodeWindow then
                    qrCodeWindow:hide()
                    qrCodeWindow = nil
                end
                sendCancelBox("Aviso", "A transação foi cancelada com sucesso.")
            elseif response and response.status == "erro" then
                print("[Pix] Erro ao cancelar transação: " .. (response.message or "Nenhuma mensagem"))
                sendCancelBox("Erro", response.message or "Erro ao cancelar a transação.")
            else
                print("[Pix] Erro: Resposta inesperada do servidor.")
                sendCancelBox("Erro", "Erro ao cancelar a transação.")
            end
        else
            print("[Pix] Erro de comunicação com a API: " .. (err or "Nenhum erro informado"))
            sendCancelBox("Erro", "Erro ao comunicar-se com a API para cancelar a transação.")
        end
    end

    print("[Pix] Enviando solicitação para cancelar a transação para o servidor.")
    HTTP.post(url, json.encode(postData), callback)
end

_G.onCancelPix = onCancelPix
