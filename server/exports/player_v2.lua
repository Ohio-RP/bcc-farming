-- =======================================
-- BCC-Farming Enhanced Player Exports v2.5.0
-- Player-specific exports with Multi-Stage Growth Support
-- =======================================

-- Growth calculations functions will be available globally

-- =======================================
-- UTILITY FUNCTIONS
-- =======================================

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

-- =======================================
-- ENHANCED PLAYER EXPORTS
-- =======================================

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

-- Export para obter todas as plantas de um jogador (atualizado para v2.5.0)
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
                plant_time,
                growth_stage,
                growth_progress,
                water_count,
                max_water_times,
                base_fertilized,
                fertilizer_type
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
    
    -- Parse coordinates e adicionar informações úteis para v2.5.0
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
            
            -- Buscar configuração da planta
            local plantConfig = nil
            for _, config in pairs(Plants) do
                if config.seedName == plant.plant_type then
                    plantConfig = config
                    break
                end
            end
            
            -- Calcular status da planta usando as novas funções
            local timeLeft = plant.time_left or 0
            local growthProgress = plant.growth_progress or 0
            local waterCount = plant.water_count or 0
            local maxWaterTimes = plant.max_water_times or 1
            local baseFertilized = plant.base_fertilized == 1
            
            -- Calcular eficiência de irrigação
            local wateringEfficiency = math.min(100, (waterCount / maxWaterTimes) * 100)
            
            -- Determinar se está pronto para colheita
            local isReady = growthProgress >= 100 and timeLeft <= 0
            
            -- Determinar se pode ser regado
            local canWater = waterCount < maxWaterTimes and not isReady
            
            -- Determinar se precisa de fertilizante base
            local needsBaseFertilizer = plantConfig and plantConfig.requiresBaseFertilizer and not baseFertilized
            
            -- Calcular recompensa esperada (simplified)
            local expectedReward = 0
            if plantConfig and plantConfig.rewards and plantConfig.rewards.amount then
                local baseReward = plantConfig.rewards.amount
                local waterEfficiency = maxWaterTimes > 0 and (waterCount / maxWaterTimes) or 1
                local fertilizerMultiplier = baseFertilized and 1.0 or 0.7
                expectedReward = math.floor(baseReward * waterEfficiency * fertilizerMultiplier)
            end
            
            -- Determinar nome do estágio
            local stageName = "Seedling"
            if plant.growth_stage == 2 then
                stageName = "Young Plant"
            elseif plant.growth_stage == 3 then
                stageName = "Mature Plant"
            end
            
            -- Processar plant_time corretamente
            local plantedAt = plant.plant_time
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
            
            -- Determinar status geral
            local status = "growing"
            if isReady then
                status = "ready"
            elseif needsBaseFertilizer then
                status = "needs_fertilizer"
            elseif canWater then
                status = "needs_water"
            end
            
            table.insert(formattedPlants, {
                -- Informações básicas
                plantId = plant.plant_id,
                plantType = plant.plant_type,
                plantName = plantConfig and plantConfig.plantName or plant.plant_type,
                coords = coords,
                plantedAt = plantedAt,
                
                -- Informações de crescimento v2.5.0
                growthStage = plant.growth_stage,
                stageName = stageName,
                growthProgress = growthProgress,
                timeLeft = timeLeft,
                
                -- Informações de irrigação v2.5.0
                waterCount = waterCount,
                maxWaterTimes = maxWaterTimes,
                wateringEfficiency = math.floor(wateringEfficiency),
                canWater = canWater,
                
                -- Informações de fertilização v2.5.0
                baseFertilized = baseFertilized,
                fertilizerType = plant.fertilizer_type,
                needsBaseFertilizer = needsBaseFertilizer,
                requiresBaseFertilizer = plantConfig and plantConfig.requiresBaseFertilizer or false,
                
                -- Status e recompensas
                isReady = isReady,
                status = status,
                expectedReward = expectedReward,
                
                -- Estimativas de tempo
                estimatedHarvest = {
                    hours = math.ceil(timeLeft / 3600),
                    minutes = math.ceil(timeLeft / 60),
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

-- Export para obter estatísticas detalhadas do jogador (atualizado para v2.5.0)
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
        -- Contadores básicos
        totalPlants = #plants,
        readyToHarvest = 0,
        needsWater = 0,
        needsFertilizer = 0,
        growing = 0,
        
        -- Estatísticas v2.5.0
        stageDistribution = {stage1 = 0, stage2 = 0, stage3 = 0},
        averageProgress = 0,
        totalWaterEfficiency = 0,
        fullyFertilized = 0,
        totalExpectedReward = 0,
        
        -- Análises
        plantTypes = {},
        oldestPlant = nil,
        newestPlant = nil,
        averageGrowthTime = 0,
        bestPerformingPlant = nil,
        worstPerformingPlant = nil
    }
    
    local totalGrowthTime = 0
    local totalProgress = 0
    local totalWaterEfficiency = 0
    local oldestTime = 0
    local newestTime = os.time()
    local bestEfficiency = 0
    local worstEfficiency = 100
    
    for _, plant in pairs(plants) do
        -- Contar status
        if plant.status == "ready" then
            stats.readyToHarvest = stats.readyToHarvest + 1
        elseif plant.status == "needs_water" then
            stats.needsWater = stats.needsWater + 1
        elseif plant.status == "needs_fertilizer" then
            stats.needsFertilizer = stats.needsFertilizer + 1
        else
            stats.growing = stats.growing + 1
        end
        
        -- Contar distribuição de estágios
        if plant.growthStage == 1 then
            stats.stageDistribution.stage1 = stats.stageDistribution.stage1 + 1
        elseif plant.growthStage == 2 then
            stats.stageDistribution.stage2 = stats.stageDistribution.stage2 + 1
        else
            stats.stageDistribution.stage3 = stats.stageDistribution.stage3 + 1
        end
        
        -- Acumular estatísticas
        totalProgress = totalProgress + plant.growthProgress
        totalWaterEfficiency = totalWaterEfficiency + plant.wateringEfficiency
        stats.totalExpectedReward = stats.totalExpectedReward + plant.expectedReward
        
        if plant.baseFertilized then
            stats.fullyFertilized = stats.fullyFertilized + 1
        end
        
        -- Contar tipos
        stats.plantTypes[plant.plantType] = (stats.plantTypes[plant.plantType] or 0) + 1
        
        -- Calcular tempo de crescimento
        totalGrowthTime = totalGrowthTime + (plant.timeLeft or 0)
        
        -- Encontrar plantas com melhor e pior desempenho
        if plant.wateringEfficiency > bestEfficiency then
            bestEfficiency = plant.wateringEfficiency
            stats.bestPerformingPlant = plant
        end
        
        if plant.wateringEfficiency < worstEfficiency then
            worstEfficiency = plant.wateringEfficiency
            stats.worstPerformingPlant = plant
        end
        
        -- Encontrar plantas mais antigas e novas
        local plantTime = 0
        if plant.plantedAt then
            if type(plant.plantedAt) == "number" then
                plantTime = plant.plantedAt
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
    
    -- Calcular médias
    if #plants > 0 then
        stats.averageGrowthTime = math.floor(totalGrowthTime / #plants)
        stats.averageProgress = math.floor(totalProgress / #plants)
        stats.totalWaterEfficiency = math.floor(totalWaterEfficiency / #plants)
    end
    
    return {
        success = true,
        data = {
            farming = stats,
            capacity = capacityData.data,
            summary = {
                efficiency = #plants > 0 and math.floor((stats.readyToHarvest / #plants) * 100) or 0,
                wateringNeeded = stats.needsWater > 0,
                fertilizingNeeded = stats.needsFertilizer > 0,
                hasReadyPlants = stats.readyToHarvest > 0,
                isMaxCapacity = capacityData.data.availableSlots == 0,
                
                -- Estatísticas v2.5.0
                avgWaterEfficiency = stats.totalWaterEfficiency,
                fertilizedPercentage = #plants > 0 and math.floor((stats.fullyFertilized / #plants) * 100) or 0,
                stageDistributionText = string.format("Stage 1: %d, Stage 2: %d, Stage 3: %d", 
                    stats.stageDistribution.stage1, 
                    stats.stageDistribution.stage2, 
                    stats.stageDistribution.stage3),
                totalPotentialReward = stats.totalExpectedReward
            }
        },
        playerId = playerId,
        timestamp = os.time()
    }
end)

-- Export para comparar jogador com médias globais (atualizado para v2.5.0)
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
    local playerWaterEfficiency = playerStats.data.summary.avgWaterEfficiency
    local playerFertilizedPercentage = playerStats.data.summary.fertilizedPercentage
    local playerPotentialReward = playerStats.data.summary.totalPotentialReward
    
    local globalTotalPlants = globalOverview.data.totalPlants
    local globalWaterEfficiency = globalOverview.data.systemStats.avgWaterEfficiency
    local globalFertilizedPercentage = globalOverview.data.systemStats.fertilizedPercentage
    
    local totalPlayers = GetNumPlayerIndices()
    local globalAvgPerPlayer = totalPlayers > 0 and (globalTotalPlants / totalPlayers) or 0
    
    return {
        success = true,
        data = {
            player = {
                plantCount = playerPlantCount,
                readyPlants = playerStats.data.farming.readyToHarvest,
                efficiency = playerStats.data.summary.efficiency,
                
                -- Estatísticas v2.5.0
                waterEfficiency = playerWaterEfficiency,
                fertilizedPercentage = playerFertilizedPercentage,
                potentialReward = playerPotentialReward,
                stageDistribution = playerStats.data.farming.stageDistribution
            },
            global = {
                totalPlants = globalTotalPlants,
                avgPerPlayer = math.floor(globalAvgPerPlayer * 100) / 100,
                totalPlayers = totalPlayers,
                
                -- Estatísticas globais v2.5.0
                avgWaterEfficiency = globalWaterEfficiency,
                avgFertilizedPercentage = globalFertilizedPercentage,
                stageDistribution = globalOverview.data.systemStats.stageDistribution
            },
            comparison = {
                aboveAverage = playerPlantCount > globalAvgPerPlayer,
                percentageOfGlobal = globalTotalPlants > 0 and 
                    math.floor((playerPlantCount / globalTotalPlants) * 100) or 0,
                rank = playerPlantCount > globalAvgPerPlayer and "above_average" or 
                       playerPlantCount == globalAvgPerPlayer and "average" or "below_average",
                
                -- Comparações v2.5.0
                waterEfficiencyRank = playerWaterEfficiency > globalWaterEfficiency and "above_average" or 
                                     playerWaterEfficiency == globalWaterEfficiency and "average" or "below_average",
                fertilizationRank = playerFertilizedPercentage > globalFertilizedPercentage and "above_average" or 
                                   playerFertilizedPercentage == globalFertilizedPercentage and "average" or "below_average",
                
                performance = {
                    plantsVsAvg = playerPlantCount - globalAvgPerPlayer,
                    waterEfficiencyVsAvg = playerWaterEfficiency - globalWaterEfficiency,
                    fertilizationVsAvg = playerFertilizedPercentage - globalFertilizedPercentage
                }
            }
        },
        playerId = playerId,
        timestamp = os.time()
    }
end)

-- Export para obter estatísticas de eficiência de um jogador (NOVO para v2.5.0)
exports('GetPlayerEfficiencyReport', function(playerId)
    local plantsData = exports['bcc-farming']:GetPlayerPlants(playerId)
    
    if not plantsData.success then
        return plantsData
    end
    
    local plants = plantsData.data
    local report = {
        totalPlants = #plants,
        maxPossibleReward = 0,
        currentExpectedReward = 0,
        efficiencyLoss = 0,
        recommendations = {}
    }
    
    for _, plant in pairs(plants) do
        -- Buscar configuração da planta
        local plantConfig = nil
        for _, config in pairs(Plants) do
            if config.seedName == plant.plantType then
                plantConfig = config
                break
            end
        end
        
        if plantConfig then
            -- Calcular recompensa máxima possível (simplified)
            local maxReward = 0
            if plantConfig.rewards and plantConfig.rewards.amount then
                maxReward = plantConfig.rewards.amount -- Full efficiency assumed
            end
            
            report.maxPossibleReward = report.maxPossibleReward + maxReward
            report.currentExpectedReward = report.currentExpectedReward + plant.expectedReward
            
            -- Analisar perdas de eficiência
            if plant.wateringEfficiency < 100 then
                table.insert(report.recommendations, {
                    plantId = plant.plantId,
                    plantName = plant.plantName,
                    issue = "water_efficiency",
                    description = string.format("Plant needs more watering (%d%% efficiency)", plant.wateringEfficiency),
                    potentialGain = maxReward - plant.expectedReward
                })
            end
            
            if plant.needsBaseFertilizer then
                table.insert(report.recommendations, {
                    plantId = plant.plantId,
                    plantName = plant.plantName,
                    issue = "base_fertilizer",
                    description = "Plant needs base fertilizer",
                    potentialGain = math.floor(plant.expectedReward * 0.3) -- 30% boost
                })
            end
        end
    end
    
    report.efficiencyLoss = report.maxPossibleReward - report.currentExpectedReward
    report.efficiencyPercentage = report.maxPossibleReward > 0 and 
        math.floor((report.currentExpectedReward / report.maxPossibleReward) * 100) or 100
    
    return {
        success = true,
        data = report,
        playerId = playerId,
        timestamp = os.time()
    }
end)

print("^2[BCC-Farming]^7 Enhanced player exports v2.5.0 loaded!")