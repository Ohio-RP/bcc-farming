-- server/exports/event_hooks.lua
-- FASE 2 - Hooks nos eventos existentes para histórico e economia

-- Sistema de hooks para eventos do farming
local EventHooks = {
    enabled = true,
    stats = {
        plantsPlanted = 0,
        plantsHarvested = 0,
        plantsDestroyed = 0,
        plantsWatered = 0,
        fertilizerUsed = 0
    }
}

-- Função para adicionar entrada no histórico
local function AddToHistory(plantType, action, playerId, coords, extraData)
    if not EventHooks.enabled then return end
    
    local quantity = 1
    if extraData and extraData.quantity then
        quantity = extraData.quantity
    end
    
    CreateThread(function()
        local success = pcall(function()
            MySQL.insert([[
                INSERT INTO bcc_farming_history 
                (plant_type, action, quantity, player_id, coords_x, coords_y, coords_z, extra_data) 
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ]], { 
                plantType, 
                action, 
                quantity, 
                playerId, 
                coords and coords.x or 0, 
                coords and coords.y or 0, 
                coords and coords.z or 0, 
                extraData and json.encode(extraData) or nil 
            })
        end)
        
        if success then
            -- Invalidar cache relacionado
            TriggerEvent('bcc-farming:InvalidateCache', 'global')
            TriggerEvent('bcc-farming:InvalidateCache', 'player', playerId)
            
            -- Atualizar estatísticas
            EventHooks.stats[action .. 's'] = (EventHooks.stats[action .. 's'] or 0) + 1
        end
    end)
end

-- Função para obter dados do jogador
local function GetPlayerData(src)
    local user = VORPcore.getUser(src)
    if not user then return nil end
    
    local character = user.getUsedCharacter
    if not character then return nil end
    
    return {
        charId = character.charIdentifier,
        name = character.firstname .. " " .. character.lastname,
        job = character.job
    }
end

-- Hook no evento de plantio
RegisterNetEvent('bcc-farming:OnPlantPlanted')
AddEventHandler('bcc-farming:OnPlantPlanted', function(plantData, plantCoords)
    local src = source
    local playerData = GetPlayerData(src)
    if not playerData then return end
    
    -- Encontrar nome da planta
    local plantName = plantData.seedName
    for _, plantConfig in pairs(Plants) do
        if plantConfig.seedName == plantData.seedName then
            plantName = plantConfig.plantName
            break
        end
    end
    
    -- Adicionar ao histórico
    AddToHistory(plantData.seedName, 'planted', playerData.charId, plantCoords, {
        plantName = plantName,
        playerName = playerData.name,
        playerJob = playerData.job,
        timeToGrow = plantData.timeToGrow,
        toolUsed = plantData.plantingTool,
        soilRequired = plantData.soilRequired
    })
    
    -- Notificar evento de plantio
    exports['bcc-farming']:NotifyFarmingEvent(src, 'plant_planted', {
        plantName = plantName
    })
    
    print(string.format("^2[BCC-Farming]^7 %s planted %s at %s", 
        playerData.name, plantName, 
        string.format("%.1f, %.1f, %.1f", plantCoords.x, plantCoords.y, plantCoords.z)))
end)

-- Hook no evento de colheita
RegisterNetEvent('bcc-farming:OnPlantHarvested')
AddEventHandler('bcc-farming:OnPlantHarvested', function(plantId, plantData, isDestroyed)
    local src = source
    local playerData = GetPlayerData(src)
    if not playerData then return end
    
    -- Buscar dados da planta no banco
    local success, plantInfo = pcall(function()
        return MySQL.query.await('SELECT * FROM bcc_farming WHERE plant_id = ?', { plantId })
    end)
    
    if not success or not plantInfo or #plantInfo == 0 then return end
    
    local plant = plantInfo[1]
    local coords = json.decode(plant.plant_coords)
    
    -- Encontrar nome da planta
    local plantName = plantData.seedName
    for _, plantConfig in pairs(Plants) do
        if plantConfig.seedName == plantData.seedName then
            plantName = plantConfig.plantName
            break
        end
    end
    
    local action = isDestroyed and 'destroyed' or 'harvested'
    local rewardItems = {}
    
    if not isDestroyed and plantData.rewards then
        for _, reward in pairs(plantData.rewards) do
            table.insert(rewardItems, {
                itemName = reward.itemName,
                itemLabel = reward.itemLabel,
                amount = reward.amount
            })
        end
    end
    
    -- Adicionar ao histórico
    AddToHistory(plantData.seedName, action, playerData.charId, coords, {
        plantId = plantId,
        plantName = plantName,
        playerName = playerData.name,
        playerJob = playerData.job,
        wasWatered = plant.plant_watered == 'true',
        timeLeft = plant.time_left,
        rewards = rewardItems,
        plantedAt = plant.plant_time
    })
    
    -- Notificar evento
    if isDestroyed then
        exports['bcc-farming']:NotifyFarmingEvent(src, 'plant_destroyed', {
            plantName = plantName
        })
    else
        exports['bcc-farming']:NotifyFarmingEvent(src, 'plant_harvested', {
            plantName = plantName,
            rewards = rewardItems
        })
    end
    
    print(string.format("^2[BCC-Farming]^7 %s %s %s", 
        playerData.name, action, plantName))
end)

-- Hook no evento de rega
RegisterNetEvent('bcc-farming:OnPlantWatered')
AddEventHandler('bcc-farming:OnPlantWatered', function(plantId)
    local src = source
    local playerData = GetPlayerData(src)
    if not playerData then return end
    
    -- Buscar dados da planta
    local success, plantInfo = pcall(function()
        return MySQL.query.await('SELECT * FROM bcc_farming WHERE plant_id = ?', { plantId })
    end)
    
    if not success or not plantInfo or #plantInfo == 0 then return end
    
    local plant = plantInfo[1]
    local coords = json.decode(plant.plant_coords)
    
    -- Encontrar nome da planta
    local plantName = plant.plant_type
    for _, plantConfig in pairs(Plants) do
        if plantConfig.seedName == plant.plant_type then
            plantName = plantConfig.plantName
            break
        end
    end
    
    -- Adicionar ao histórico
    AddToHistory(plant.plant_type, 'watered', playerData.charId, coords, {
        plantId = plantId,
        plantName = plantName,
        playerName = playerData.name,
        timeLeft = plant.time_left,
        waterBucketUsed = true
    })
    
    -- Notificar evento
    exports['bcc-farming']:NotifyFarmingEvent(src, 'plant_watered', {
        plantName = plantName
    })
end)

-- Hook no evento de fertilização
RegisterNetEvent('bcc-farming:OnFertilizerUsed')
AddEventHandler('bcc-farming:OnFertilizerUsed', function(plantData, fertilizerData)
    local src = source
    local playerData = GetPlayerData(src)
    if not playerData then return end
    
    -- Encontrar nome da planta
    local plantName = plantData.seedName
    for _, plantConfig in pairs(Plants) do
        if plantConfig.seedName == plantData.seedName then
            plantName = plantConfig.plantName
            break
        end
    end
    
    -- Adicionar ao histórico
    AddToHistory(plantData.seedName, 'fertilized', playerData.charId, nil, {
        plantName = plantName,
        playerName = playerData.name,
        fertilizerName = fertilizerData.fertName,
        timeReduction = fertilizerData.fertTimeReduction,
        originalTime = plantData.timeToGrow,
        newTime = math.floor(plantData.timeToGrow - (fertilizerData.fertTimeReduction * plantData.timeToGrow))
    })
    
    -- Notificar evento
    exports['bcc-farming']:NotifyFarmingEvent(src, 'fertilizer_used', {
        plantName = plantName,
        reduction = fertilizerData.fertTimeReduction
    })
end)

-- Modificar server/main.lua para incluir os hooks
-- Estas modificações serão aplicadas automaticamente

-- Hook no AddPlant original
local originalAddPlant = RegisterServerEvent
RegisterServerEvent = function(eventName, handler)
    if eventName == 'bcc-farming:AddPlant' then
        return originalAddPlant(eventName, function(plantData, plantCoords)
            handler(plantData, plantCoords)
            -- Trigger nosso hook
            TriggerEvent('bcc-farming:OnPlantPlanted', plantData, plantCoords)
        end)
    end
    return originalAddPlant(eventName, handler)
end

-- Sistema de atualização de estatísticas de mercado
CreateThread(function()
    while true do
        Wait(300000) -- A cada 5 minutos
        
        -- Atualizar estatísticas de mercado para todos os tipos de plantas
        local success, plantTypes = pcall(function()
            return MySQL.query.await('SELECT DISTINCT plant_type FROM bcc_farming')
        end)
        
        if success and plantTypes then
            for _, plant in pairs(plantTypes) do
                local plantType = plant.plant_type
                
                -- Calcular estatísticas
                local activePlants = MySQL.scalar.await(
                    'SELECT COUNT(*) FROM bcc_farming WHERE plant_type = ?', 
                    { plantType }
                ) or 0
                
                local totalPlanted = MySQL.scalar.await(
                    'SELECT COUNT(*) FROM bcc_farming_history WHERE plant_type = ? AND action = "planted"',
                    { plantType }
                ) or 0
                
                local totalHarvested = MySQL.scalar.await(
                    'SELECT COUNT(*) FROM bcc_farming_history WHERE plant_type = ? AND action = "harvested"',
                    { plantType }
                ) or 0
                
                local totalDestroyed = MySQL.scalar.await(
                    'SELECT COUNT(*) FROM bcc_farming_history WHERE plant_type = ? AND action = "destroyed"',
                    { plantType }
                ) or 0
                
                -- Calcular tempo médio de crescimento
                local avgGrowthTime = MySQL.scalar.await([[
                    SELECT AVG(TIMESTAMPDIFF(SECOND, planted.timestamp, harvested.timestamp)) 
                    FROM bcc_farming_history planted
                    JOIN bcc_farming_history harvested ON planted.plant_type = harvested.plant_type
                    WHERE planted.action = 'planted' 
                      AND harvested.action = 'harvested'
                      AND planted.plant_type = ?
                      AND planted.timestamp < harvested.timestamp
                      AND planted.timestamp > DATE_SUB(NOW(), INTERVAL 7 DAY)
                ]], { plantType }) or 0
                
                -- Obter dados de escassez e tendência
                local scarcityData = exports['bcc-farming']:GetPlantScarcityIndex(plantType)
                local trendData = exports['bcc-farming']:GetPlantingTrend(plantType, 3)
                
                -- Atualizar banco de dados
                MySQL.execute([[
                    INSERT INTO bcc_farming_market_stats 
                    (plant_type, total_planted, total_harvested, total_destroyed, active_plants, avg_growth_time, scarcity_index, trend)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    ON DUPLICATE KEY UPDATE
                    total_planted = VALUES(total_planted),
                    total_harvested = VALUES(total_harvested),
                    total_destroyed = VALUES(total_destroyed),
                    active_plants = VALUES(active_plants),
                    avg_growth_time = VALUES(avg_growth_time),
                    scarcity_index = VALUES(scarcity_index),
                    trend = VALUES(trend)
                ]], { 
                    plantType, 
                    totalPlanted, 
                    totalHarvested, 
                    totalDestroyed,
                    activePlants,
                    avgGrowthTime,
                    scarcityData.success and scarcityData.data.scarcityIndex or 0.5,
                    trendData.success and trendData.data.trend or 'stable'
                })
            end
            
            print("^2[BCC-Farming]^7 Estatísticas de mercado atualizadas para " .. #plantTypes .. " tipos de plantas")
        end
    end
end)

-- Export para obter estatísticas dos eventos
exports('GetEventStats', function()
    return {
        success = true,
        data = EventHooks.stats,
        enabled = EventHooks.enabled,
        timestamp = os.time()
    }
end)

-- Export para habilitar/desabilitar hooks
exports('SetEventHooksEnabled', function(enabled)
    EventHooks.enabled = enabled
    print(string.format("^3[BCC-Farming]^7 Event hooks %s", enabled and "enabled" or "disabled"))
    return { success = true, enabled = enabled }
end)

-- Export para resetar estatísticas
exports('ResetEventStats', function()
    EventHooks.stats = {
        plantsPlanted = 0,
        plantsHarvested = 0,
        plantsDestroyed = 0,
        plantsWatered = 0,
        fertilizerUsed = 0
    }
    return { success = true, message = "Event statistics reset" }
end)

-- Export para obter histórico de um jogador
exports('GetPlayerHistory', function(playerId, days, action)
    days = days or 7
    
    local user = VORPcore.getUser(playerId)
    if not user then 
        return { success = false, error = "Player not found" }
    end
    
    local character = user.getUsedCharacter
    if not character then
        return { success = false, error = "Character not found" }
    end
    
    local charId = character.charIdentifier
    local whereClause = "WHERE player_id = ? AND timestamp > DATE_SUB(NOW(), INTERVAL ? DAY)"
    local params = { charId, days }
    
    if action then
        whereClause = whereClause .. " AND action = ?"
        table.insert(params, action)
    end
    
    local success, history = pcall(function()
        return MySQL.query.await(string.format([[
            SELECT plant_type, action, quantity, coords_x, coords_y, coords_z, extra_data, timestamp
            FROM bcc_farming_history 
            %s
            ORDER BY timestamp DESC
            LIMIT 100
        ]], whereClause), params)
    end)
    
    if not success then
        return { success = false, error = "Database error" }
    end
    
    -- Processar dados extras
    for _, entry in pairs(history or {}) do
        if entry.extra_data then
            local parseSuccess, extraData = pcall(function()
                return json.decode(entry.extra_data)
            end)
            if parseSuccess then
                entry.extra_data = extraData
            end
        end
    end
    
    return {
        success = true,
        data = history or {},
        playerId = playerId,
        charId = charId,
        period = days,
        filter = action,
        timestamp = os.time()
    }
end)

-- Export para obter histórico global
exports('GetGlobalHistory', function(days, plantType, action)
    days = days or 1
    
    local whereClause = "WHERE timestamp > DATE_SUB(NOW(), INTERVAL ? DAY)"
    local params = { days }
    
    if plantType then
        whereClause = whereClause .. " AND plant_type = ?"
        table.insert(params, plantType)
    end
    
    if action then
        whereClause = whereClause .. " AND action = ?"
        table.insert(params, action)
    end
    
    local success, history = pcall(function()
        return MySQL.query.await(string.format([[
            SELECT 
                plant_type, 
                action, 
                COUNT(*) as count,
                SUM(quantity) as total_quantity,
                DATE(timestamp) as date,
                HOUR(timestamp) as hour
            FROM bcc_farming_history 
            %s
            GROUP BY plant_type, action, DATE(timestamp), HOUR(timestamp)
            ORDER BY timestamp DESC
            LIMIT 500
        ]], whereClause), params)
    end)
    
    if not success then
        return { success = false, error = "Database error" }
    end
    
    return {
        success = true,
        data = history or {},
        period = days,
        plantType = plantType,
        action = action,
        timestamp = os.time()
    }
end)

-- Comando para visualizar estatísticas de eventos
RegisterCommand('farming-events', function(source)
    if source ~= 0 then return end -- Apenas console
    
    local stats = exports['bcc-farming']:GetEventStats()
    if stats.success then
        print("^3=== BCC-Farming Event Statistics ===^7")
        print(string.format("Plants Planted: %d", stats.data.plantsPlanted or 0))
        print(string.format("Plants Harvested: %d", stats.data.plantsHarvested or 0))
        print(string.format("Plants Destroyed: %d", stats.data.plantsDestroyed or 0))
        print(string.format("Plants Watered: %d", stats.data.plantsWatered or 0))
        print(string.format("Fertilizer Used: %d", stats.data.fertilizerUsed or 0))
        print(string.format("Event Hooks: %s", stats.enabled and "Enabled" or "Disabled"))
    end
end)

-- Sistema de alertas automáticos
CreateThread(function()
    while true do
        Wait(600000) -- A cada 10 minutos
        
        local autoNotifications = GetCacheConfig('auto_notifications', true)
        if not autoNotifications then
            goto continue
        end
        
        -- Verificar plantas prontas para todos os jogadores
        local readyThreshold = GetCacheConfig('notification_ready_threshold', 600)
        
        for _, playerId in ipairs(GetPlayers()) do
            local src = tonumber(playerId)
            if src then
                -- Notificar plantas prontas
                exports['bcc-farming']:NotifyReadyPlants(src, readyThreshold)
                
                -- Verificar se precisa de água (apenas uma vez por hora)
                if os.time() % 3600 < 600 then -- Primeiros 10 minutos de cada hora
                    exports['bcc-farming']:NotifyPlantsNeedWater(src)
                end
                
                -- Verificar limites (apenas se estiver próximo do limite)
                local capacity = exports['bcc-farming']:CanPlayerPlantMore(src)
                if capacity.success and capacity.data.usagePercentage >= 80 then
                    exports['bcc-farming']:NotifyPlantLimits(src)
                end
            end
        end
        
        ::continue::
    end
end)

-- Relatório diário automático
CreateThread(function()
    while true do
        Wait(86400000) -- 24 horas
        
        local dailyReportEnabled = GetCacheConfig('daily_report_enabled', true)
        if not dailyReportEnabled then
            goto continue
        end
        
        -- Enviar relatório diário para jogadores ativos
        for _, playerId in ipairs(GetPlayers()) do
            local src = tonumber(playerId)
            if src then
                local playerPlants = exports['bcc-farming']:GetPlayerPlantCount(src)
                if playerPlants.success and playerPlants.data > 0 then
                    exports['bcc-farming']:SendDailyFarmingReport(src)
                end
            end
        end
        
        ::continue::
    end
end)