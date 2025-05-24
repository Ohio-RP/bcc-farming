-- server/exports/notifications.lua
-- Sistema de notificações avançado para BCC-Farming

-- Detectar sistema de notificação disponível
local function GetNotificationSystem()
    if GetResourceState('bln_notify') == 'started' then
        return 'bln_notify'
    elseif GetResourceState('vorp_core') == 'started' then
        return 'vorp_core'
    else
        return 'chat'
    end
end

-- Função helper para enviar notificações
local function SendNotification(src, notifyData)
    local notificationSystem = GetNotificationSystem()
    
    if notificationSystem == 'bln_notify' then
        -- Usar BLN Notify se disponível
        TriggerClientEvent("bln_notify:send", src, {
            title = notifyData.title or "BCC Farming",
            description = notifyData.description,
            icon = notifyData.icon or "generic_list",
            placement = notifyData.placement or "middle-right",
            duration = notifyData.duration or 5000,
            useBackground = true,
            contentAlignment = "start"
        }, notifyData.template)
    elseif notificationSystem == 'vorp_core' then
        -- Fallback para VORP Core
        if notifyData.type == 'tip' then
            VORPcore.NotifyRightTip(src, notifyData.description, notifyData.duration or 5000)
        else
            VORPcore.NotifyLeft(src, notifyData.title or "BCC Farming", notifyData.description, 
                "generic_textures", notifyData.icon or "tick", notifyData.duration or 5000, "COLOR_WHITE")
        end
    else
        -- Fallback para chat
        TriggerClientEvent('chat:addMessage', src, {
            color = { 255, 255, 255 },
            multiline = false,
            args = { "[BCC Farming]", notifyData.description }
        })
    end
end

-- Export para notificar sobre plantas prontas para colheita
exports('NotifyReadyPlants', function(playerId, timeThreshold)
    timeThreshold = timeThreshold or 300 -- 5 minutos default
    
    local user = VORPcore.getUser(playerId)
    if not user then return end
    
    local character = user.getUsedCharacter
    if not character then return end
    
    local charId = character.charIdentifier
    
    -- Buscar plantas do jogador prontas em breve
    local readyPlants = MySQL.query.await([[
        SELECT plant_type, COUNT(*) as count, MIN(CAST(time_left AS UNSIGNED)) as min_time
        FROM `bcc_farming` 
        WHERE plant_owner = ? 
          AND CAST(time_left AS UNSIGNED) <= ?
          AND CAST(time_left AS UNSIGNED) > 0
          AND plant_watered = 'true'
        GROUP BY plant_type
    ]], { charId, timeThreshold })
    
    if not readyPlants or #readyPlants == 0 then
        return { success = false, message = "No plants ready soon" }
    end
    
    local totalReady = 0
    local plantNames = {}
    
    for _, plant in pairs(readyPlants) do
        totalReady = totalReady + plant.count
        
        -- Encontrar nome da planta
        for _, plantConfig in pairs(Plants) do
            if plantConfig.seedName == plant.plant_type then
                table.insert(plantNames, string.format("%dx %s (%dm)", 
                    plant.count, plantConfig.plantName, math.ceil(plant.min_time / 60)))
                break
            end
        end
    end
    
    local description = string.format("Você tem %d plantas prontas em breve:\\n%s", 
        totalReady, table.concat(plantNames, "\\n"))
    
    SendNotification(playerId, {
        title = "🌱 Plantas Prontas",
        description = description,
        icon = "plant",
        template = "INFO",
        duration = 8000
    })
    
    return { 
        success = true, 
        plantsFound = totalReady,
        plantTypes = #readyPlants 
    }
end)

-- Export para notificar sobre plantas que precisam de água
exports('NotifyPlantsNeedWater', function(playerId)
    local user = VORPcore.getUser(playerId)
    if not user then return end
    
    local character = user.getUsedCharacter
    if not character then return end
    
    local charId = character.charIdentifier
    
    -- Buscar plantas do jogador que precisam de água
    local thirstyPlants = MySQL.query.await([[
        SELECT plant_type, COUNT(*) as count
        FROM `bcc_farming` 
        WHERE plant_owner = ? 
          AND plant_watered = 'false'
        GROUP BY plant_type
    ]], { charId })
    
    if not thirstyPlants or #thirstyPlants == 0 then
        return { success = false, message = "No plants need water" }
    end
    
    local totalThirsty = 0
    local plantNames = {}
    
    for _, plant in pairs(thirstyPlants) do
        totalThirsty = totalThirsty + plant.count
        
        -- Encontrar nome da planta
        for _, plantConfig in pairs(Plants) do
            if plantConfig.seedName == plant.plant_type then
                table.insert(plantNames, string.format("%dx %s", plant.count, plantConfig.plantName))
                break
            end
        end
    end
    
    local description = string.format("Você tem %d plantas que precisam de água:\\n%s", 
        totalThirsty, table.concat(plantNames, "\\n"))
    
    SendNotification(playerId, {
        title = "💧 Plantas Precisam de Água",
        description = description,
        icon = "water_bucket",
        template = "ERROR",
        duration = 6000
    })
    
    return { 
        success = true, 
        plantsFound = totalThirsty,
        plantTypes = #thirstyPlants 
    }
end)

-- Export para notificar sobre limites de plantas
exports('NotifyPlantLimits', function(playerId)
    local capacityData = exports['bcc-farming']:CanPlayerPlantMore(playerId)
    
    if not capacityData.success then
        return capacityData
    end
    
    local data = capacityData.data
    local usagePercentage = data.usagePercentage
    
    local title, description, template, icon
    
    if usagePercentage >= 100 then
        title = "🚫 Limite Atingido"
        description = string.format("Você atingiu o limite máximo de %d plantas. Colha algumas para plantar mais.", data.maxSlots)
        template = "ERROR"
        icon = "warning"
    elseif usagePercentage >= 80 then
        title = "⚠️ Quase no Limite"
        description = string.format("Você está usando %d de %d slots (%d%%). Apenas %d slots disponíveis.", 
            data.slotsUsed, data.maxSlots, usagePercentage, data.availableSlots)
        template = "REWARD_MONEY"
        icon = "warning"
    else
        title = "✅ Capacidade OK"
        description = string.format("Você está usando %d de %d slots (%d%%). %d slots disponíveis.", 
            data.slotsUsed, data.maxSlots, usagePercentage, data.availableSlots)
        template = "SUCCESS"
        icon = "tick"
    end
    
    SendNotification(playerId, {
        title = title,
        description = description,
        template = template,
        icon = icon,
        duration = 5000
    })
    
    return {
        success = true,
        data = data,
        notificationSent = true
    }
end)

-- Export para notificar eventos de farming
exports('NotifyFarmingEvent', function(playerId, eventType, eventData)
    local title, description, template, icon, duration
    
    if eventType == 'plant_grown' then
        title = "🌾 Planta Cresceu"
        description = string.format("Sua %s está pronta para colheita!", eventData.plantName or "planta")
        template = "SUCCESS"
        icon = "plant"
        duration = 7000
        
    elseif eventType == 'plant_planted' then
        title = "🌱 Planta Plantada"
        description = string.format("Você plantou %s com sucesso!", eventData.plantName or "uma planta")
        template = "SUCCESS"
        icon = "tick"
        duration = 4000
        
    elseif eventType == 'plant_harvested' then
        title = "🌾 Planta Colhida"
        description = string.format("Você colheu %s!", eventData.plantName or "uma planta")
        template = "REWARD_MONEY"
        icon = "satchel"
        duration = 4000
        
    elseif eventType == 'plant_watered' then
        title = "💧 Planta Regada"
        description = string.format("Você regou sua %s.", eventData.plantName or "planta")
        template = "TIP"
        icon = "water_bucket"
        duration = 3000
        
    elseif eventType == 'fertilizer_used' then
        title = "🧪 Fertilizante Aplicado"
        description = string.format("Fertilizante aplicado! Tempo de crescimento reduzido em %d%%.", 
            math.floor((eventData.reduction or 0) * 100))
        template = "INFO"
        icon = "info"
        duration = 5000
        
    elseif eventType == 'error' then
        title = "❌ Erro"
        description = eventData.message or "Ocorreu um erro durante a operação."
        template = "ERROR"
        icon = "warning"
        duration = 5000
        
    else
        title = "📢 BCC Farming"
        description = eventData.message or "Evento de farming"
        template = "INFO"
        icon = "generic_list"
        duration = 4000
    end
    
    SendNotification(playerId, {
        title = title,
        description = description,
        template = template,
        icon = icon,
        duration = duration
    })
    
    return { success = true, eventType = eventType }
end)

-- Export para relatório diário de farming
exports('SendDailyFarmingReport', function(playerId)
    local playerStats = exports['bcc-farming']:GetPlayerFarmingStats(playerId)
    local playerComparison = exports['bcc-farming']:GetPlayerComparison(playerId)
    
    if not playerStats.success or not playerComparison.success then
        return { success = false, error = "Could not generate report" }
    end
    
    local stats = playerStats.data
    local comparison = playerComparison.data
    
    local description = string.format(
        "📊 RELATÓRIO DIÁRIO DE FARMING\\n\\n" ..
        "🌱 Total de Plantas: %d\\n" ..
        "🌾 Prontas para Colheita: %d\\n" ..
        "💧 Precisam de Água: %d\\n" ..
        "📈 Eficiência: %d%%\\n\\n" ..
        "🏆 Ranking: %s\\n" ..
        "📍 Você tem %d%% das plantas globais",
        stats.farming.totalPlants,
        stats.farming.readyToHarvest,
        stats.farming.needsWater,
        stats.summary.efficiency,
        comparison.comparison.rank == "above_average" and "Acima da Média" or
        comparison.comparison.rank == "average" and "Na Média" or "Abaixo da Média",
        comparison.comparison.percentageOfGlobal
    )
    
    SendNotification(playerId, {
        title = "📊 Relatório Diário",
        description = description,
        template = "INFO",
        icon = "info",
        duration = 12000
    })
    
    return { 
        success = true, 
        stats = stats,
        comparison = comparison 
    }
end)

-- Export para notificar sobre plantas descobertas (smelling)
exports('NotifyPlantSmelled', function(playerId, plantData)
    local description = string.format("Você detectou o cheiro de %s suspeitas na área!", 
        plantData.count and plantData.count > 1 and "plantas" or "uma planta")
    
    SendNotification(playerId, {
        title = "👃 Planta Detectada",
        description = description,
        template = "ERROR",
        icon = "warning",
        duration = 6000
    })
    
    return { success = true, plantsDetected = plantData.count or 1 }
end)

-- Comando para testar notificações
RegisterCommand('farmnotify', function(source, args)
    if source == 0 then return end -- Console only
    
    local testType = args[1] or 'ready'
    
    if testType == 'ready' then
        exports['bcc-farming']:NotifyReadyPlants(source, 600)
    elseif testType == 'water' then
        exports['bcc-farming']:NotifyPlantsNeedWater(source)
    elseif testType == 'limits' then
        exports['bcc-farming']:NotifyPlantLimits(source)
    elseif testType == 'report' then
        exports['bcc-farming']:SendDailyFarmingReport(source)
    elseif testType == 'event' then
        exports['bcc-farming']:NotifyFarmingEvent(source, 'plant_grown', { plantName = "Milho Teste" })
    else
        VORPcore.NotifyRightTip(source, "Use: /farmnotify [ready|water|limits|report|event]", 5000)
    end
end)

-- Sistema automático de notificações
CreateThread(function()
    while true do
        Wait(300000) -- A cada 5 minutos
        
        -- Notificar todos os jogadores online sobre plantas prontas
        for _, playerId in ipairs(GetPlayers()) do
            local src = tonumber(playerId)
            if src then
                exports['bcc-farming']:NotifyReadyPlants(src, 600) -- 10 minutos
            end
        end
    end
end)

-- Relatório diário automático (a cada 24 horas)
CreateThread(function()
    while true do
        Wait(86400000) -- 24 horas
        
        -- Enviar relatório diário para todos os jogadores que têm plantas
        for _, playerId in ipairs(GetPlayers()) do
            local src = tonumber(playerId)
            if src then
                local playerPlants = exports['bcc-farming']:GetPlayerPlantCount(src)
                if playerPlants.success and playerPlants.data > 0 then
                    exports['bcc-farming']:SendDailyFarmingReport(src)
                end
            end
        end
    end
end)