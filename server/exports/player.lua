-- server/exports/player.lua
-- FASE 1 - Exports de Jogadores (VERSÃO FINAL CORRIGIDA)

-- Função helper para validar jogador
local function ValidatePlayer(playerId)
    if not playerId then
        return nil, "Player ID is required"
    end
    
    local user = VORPcore.getUser(playerId)
    if not user then 
        return nil, "Player not found"
    end
    
    local character = user.getUsedCharacter
    if not character then
        return nil, "Character not found"
    end
    
    return character, nil
end

-- Export para obter contagem de plantas de um jogador específico
exports('GetPlayerPlantCount', function(playerId)
    if not playerId then
        return { success = false, error = "Player ID is required" }
    end
    
    local user = VORPcore.getUser(playerId)
    if not user then 
        return { success = false, error = "Player not found" }
    end
    
    local character = user.getUsedCharacter
    if not character then
        return { success = false, error = "Character not found" }
    end
    
    local charId = character.charIdentifier
    
    local success, count = pcall(function()
        return MySQL.scalar.await('SELECT COUNT(*) FROM `bcc_farming` WHERE `plant_owner` = ?', { charId })
    end)
    
    if not success then
        return { success = false, error = "Database error" }
    end
    
    return { 
        success = true, 
        data = count or 0, 
        maxPlants = Config.plantSetup.maxPlants,
        canPlantMore = (count or 0) < Config.plantSetup.maxPlants,
        playerId = playerId,
        charId = charId,
        timestamp = os.time()
    }
end)

-- Export para obter todas as plantas de um jogador
exports('GetPlayerPlants', function(playerId)
    local character, error = ValidatePlayer(playerId)
    if not character then
        return { 
            success = false, 
            error = error,
            playerId = playerId,
            timestamp = os.time()
        }
    end
    
    local charId = character.charIdentifier
    
    local success, plants = pcall(function()
        return MySQL.query.await([[
            SELECT 
                plant_id, 
                plant_type, 
                plant_coords, 
                CAST(time_left AS UNSIGNED) as time_left, 
                plant_watered, 
                plant_time
            FROM `bcc_farming` 
            WHERE `plant_owner` = ?
            ORDER BY plant_time DESC
        ]], { charId })
    end)
    
    if not success then
        return { 
            success = false, 
            error = "Database error",
            playerId = playerId,
            timestamp = os.time()
        }
    end
    
    -- Parse coordinates e adicionar informações úteis
    local formattedPlants = {}
    if plants then
        for _, plant in pairs(plants) do
            local coords = nil
            local parseSuccess, parsedCoords = pcall(function()
                return json.decode(plant.plant_coords)
            end)
            
            if parseSuccess then
                coords = parsedCoords
            end
            
            -- Calcular status da planta
            local timeLeft = plant.time_left or 0
            local isWatered = plant.plant_watered == 'true'
            local isReady = timeLeft <= 0 and isWatered
            local needsWater = not isWatered
            
            -- Estimar tempo até a colheita
            local hoursToHarvest = math.ceil(timeLeft / 3600)
            local minutesToHarvest = math.ceil(timeLeft / 60)
            
            -- Processar plant_time corretamente
            local plantedAt = plant.plant_time
            -- Se plant_time é uma string de data MySQL, converter para timestamp
            if type(plantedAt) == "string" then
                local year, month, day, hour, min, sec = plantedAt:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
                if year then
                    plantedAt = os.time({
                        year = tonumber(year), 
                        month = tonumber(month), 
                        day = tonumber(day), 
                        hour = tonumber(hour), 
                        min = tonumber(min), 
                        sec = tonumber(sec)
                    })
                end
            end
            
            table.insert(formattedPlants, {
                plantId = plant.plant_id,
                plantType = plant.plant_type,
                coords = coords,
                timeLeft = timeLeft,
                isWatered = isWatered,
                isReady = isReady,
                needsWater = needsWater,
                plantedAt = plantedAt,
                status = isReady and "ready" or needsWater and "needs_water" or "growing",
                estimatedHarvest = {
                    hours = hoursToHarvest,
                    minutes = minutesToHarvest,
                    seconds = timeLeft
                }
            })
        end
    end
    
    return { 
        success = true, 
        data = formattedPlants, 
        count = #formattedPlants,
        playerId = playerId,
        charId = charId,
        timestamp = os.time() 
    }
end)

-- Export para verificar se o jogador pode plantar mais
exports('CanPlayerPlantMore', function(playerId)
    local playerData = exports['bcc-farming']:GetPlayerPlantCount(playerId)
    if not playerData.success then
        return playerData
    end
    
    local slotsUsed = playerData.data
    local maxSlots = playerData.maxPlants
    local availableSlots = maxSlots - slotsUsed
    
    return {
        success = true,
        data = {
            canPlant = availableSlots > 0,
            slotsUsed = slotsUsed,
            maxSlots = maxSlots,
            availableSlots = availableSlots,
            usagePercentage = math.floor((slotsUsed / maxSlots) * 100)
        },
        playerId = playerId,
        timestamp = os.time()
    }
end)

-- Export para obter estatísticas detalhadas do jogador
exports('GetPlayerFarmingStats', function(playerId)
    local plantsData = exports['bcc-farming']:GetPlayerPlants(playerId)
    local capacityData = exports['bcc-farming']:CanPlayerPlantMore(playerId)
    
    if not plantsData.success or not capacityData.success then
        return {
            success = false,
            error = "Failed to gather player stats",
            timestamp = os.time()
        }
    end
    
    local plants = plantsData.data
    local stats = {
        totalPlants = #plants,
        readyToHarvest = 0,
        needsWater = 0,
        growing = 0,
        plantTypes = {},
        oldestPlant = nil,
        newestPlant = nil,
        averageGrowthTime = 0
    }
    
    local totalGrowthTime = 0
    local oldestTime = 0
    local newestTime = os.time()
    
    for _, plant in pairs(plants) do
        -- Contar status
        if plant.status == "ready" then
            stats.readyToHarvest = stats.readyToHarvest + 1
        elseif plant.status == "needs_water" then
            stats.needsWater = stats.needsWater + 1
        else
            stats.growing = stats.growing + 1
        end
        
        -- Contar tipos
        stats.plantTypes[plant.plantType] = (stats.plantTypes[plant.plantType] or 0) + 1
        
        -- Calcular tempo de crescimento
        totalGrowthTime = totalGrowthTime + (plant.timeLeft or 0)
        
        -- Encontrar plantas mais antigas e novas - CORRIGIDO PARA EVITAR O BUG
        local plantTime = 0
        if plant.plantedAt then
            -- Se já é um número (timestamp), usar diretamente
            if type(plant.plantedAt) == "number" then
                plantTime = plant.plantedAt
            -- Se é string, tentar converter
            elseif type(plant.plantedAt) == "string" then
                local year, month, day, hour, min, sec = plant.plantedAt:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
                if year then
                    plantTime = os.time({
                        year = tonumber(year), 
                        month = tonumber(month), 
                        day = tonumber(day), 
                        hour = tonumber(hour), 
                        min = tonumber(min), 
                        sec = tonumber(sec)
                    })
                end
            end
        end
        
        if plantTime > oldestTime then
            oldestTime = plantTime
            stats.oldestPlant = plant
        end
        
        if plantTime < newestTime and plantTime > 0 then
            newestTime = plantTime
            stats.newestPlant = plant
        end
    end
    
    if #plants > 0 then
        stats.averageGrowthTime = math.floor(totalGrowthTime / #plants)
    end
    
    return {
        success = true,
        data = {
            farming = stats,
            capacity = capacityData.data,
            summary = {
                efficiency = #plants > 0 and math.floor((stats.readyToHarvest / #plants) * 100) or 0,
                wateringNeeded = stats.needsWater > 0,
                hasReadyPlants = stats.readyToHarvest > 0,
                isMaxCapacity = capacityData.data.availableSlots == 0
            }
        },
        playerId = playerId,
        timestamp = os.time()
    }
end)

-- Export para comparar jogador com médias globais
exports('GetPlayerComparison', function(playerId)
    local playerStats = exports['bcc-farming']:GetPlayerFarmingStats(playerId)
    local globalOverview = exports['bcc-farming']:GetFarmingOverview()
    
    if not playerStats.success or not globalOverview.success then
        return {
            success = false,
            error = "Failed to gather comparison data",
            timestamp = os.time()
        }
    end
    
    local playerPlantCount = playerStats.data.farming.totalPlants
    local globalTotalPlants = globalOverview.data.totalPlants
    local totalPlayers = GetNumPlayerIndices() -- Número atual de jogadores online
    
    local globalAvgPerPlayer = totalPlayers > 0 and (globalTotalPlants / totalPlayers) or 0
    
    return {
        success = true,
        data = {
            player = {
                plantCount = playerPlantCount,
                readyPlants = playerStats.data.farming.readyToHarvest,
                efficiency = playerStats.data.summary.efficiency
            },
            global = {
                totalPlants = globalTotalPlants,
                avgPerPlayer = math.floor(globalAvgPerPlayer * 100) / 100,
                totalPlayers = totalPlayers
            },
            comparison = {
                aboveAverage = playerPlantCount > globalAvgPerPlayer,
                percentageOfGlobal = globalTotalPlants > 0 and 
                    math.floor((playerPlantCount / globalTotalPlants) * 100) or 0,
                rank = playerPlantCount > globalAvgPerPlayer and "above_average" or 
                       playerPlantCount == globalAvgPerPlayer and "average" or "below_average"
            }
        },
        playerId = playerId,
        timestamp = os.time()
    }
end)