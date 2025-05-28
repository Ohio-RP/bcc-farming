local IrrigationAlerts = {
    config = {
        alertThreshold = 0.7, -- 70% das plantas sem água
        checkInterval = 300000, -- 5 minutos
        enabled = true
    }
}

-- Sistema de monitoramento de irrigação
CreateThread(function()
    while true do
        Wait(IrrigationAlerts.config.checkInterval)
        
        if not IrrigationAlerts.config.enabled then
            goto continue
        end
        
        -- Verificar status de irrigação global
        local wateringStatus = exports['bcc-farming']:GetWateringStatus()
        
        if wateringStatus.success then
            local totalPlants = wateringStatus.data.total
            local notWateredCount = wateringStatus.data.notWatered.count
            local percentageNeedWater = totalPlants > 0 and (notWateredCount / totalPlants) or 0
            
            -- Se mais de 70% das plantas precisam de água
            if percentageNeedWater > IrrigationAlerts.config.alertThreshold then
                -- Notificar todos os jogadores online
                local players = GetPlayers()
                for _, playerId in ipairs(players) do
                    local src = tonumber(playerId)
                    if src then
                        -- Verificar se jogador tem plantas
                        local playerPlants = exports['bcc-farming']:GetPlayerPlantCount(src)
                        if playerPlants.success and playerPlants.data > 0 then
                            -- Verificar se jogador tem plantas não regadas
                            exports['bcc-farming']:NotifyPlantsNeedWater(src)
                        end
                    end
                end
                
                print(string.format("^3[BCC-Farming Alert]^7 %d%% das plantas globais precisam de água (%d/%d)", 
                    math.floor(percentageNeedWater * 100), notWateredCount, totalPlants))
            end
        end
        
        ::continue::
    end
end)

-- Comando para configurar alertas de irrigação
RegisterCommand('farming-irrigation-config', function(source, args)
    if source ~= 0 then return end
    
    local action = args[1]
    local value = args[2]
    
    if action == "enable" then
        IrrigationAlerts.config.enabled = true
        print("^2[BCC-Farming]^7 Alertas de irrigação ativados")
    elseif action == "disable" then
        IrrigationAlerts.config.enabled = false
        print("^1[BCC-Farming]^7 Alertas de irrigação desativados")
    elseif action == "threshold" and value then
        local threshold = tonumber(value)
        if threshold and threshold > 0 and threshold <= 1 then
            IrrigationAlerts.config.alertThreshold = threshold
            print(string.format("^2[BCC-Farming]^7 Threshold de alerta definido para %d%%", 
                math.floor(threshold * 100)))
        else
            print("^1[BCC-Farming]^7 Threshold deve ser entre 0.1 e 1.0")
        end
    elseif action == "interval" and value then
        local interval = tonumber(value)
        if interval and interval >= 60000 then -- Mínimo 1 minuto
            IrrigationAlerts.config.checkInterval = interval
            print(string.format("^2[BCC-Farming]^7 Intervalo definido para %ds", interval / 1000))
        else
            print("^1[BCC-Farming]^7 Intervalo deve ser no mínimo 60000ms (1 minuto)")
        end
    else
        print("^3[BCC-Farming]^7 Uso: farming-irrigation-config [enable|disable|threshold|interval] [valor]")
    end
end)
