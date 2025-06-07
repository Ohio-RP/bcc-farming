-- =======================================
-- BCC-Farming Enhanced Exports v2.5.0
-- Basic Export Functions with Multi-Stage Growth Support
-- =======================================

-- Growth calculations functions will be available globally

-- =======================================
-- ENHANCED BASIC EXPORTS
-- =======================================

-- Export para obter contagem total de plantas no servidor
exports('GetGlobalPlantCount', function()
    local success, result = pcall(function()
        return MySQL.scalar.await('SELECT COUNT(*) FROM `bcc_farming`')
    end)
    
    if not success then
        return { 
            success = false, 
            error = "Database error", 
            data = nil, 
            timestamp = os.time() 
        }
    end
    
    return { 
        success = true, 
        data = result or 0, 
        timestamp = os.time() 
    }
end)

-- Export para obter contagem de plantas por tipo com informações de estágio
exports('GetGlobalPlantsByType', function()
    local success, result = pcall(function()
        return MySQL.query.await([[
            SELECT 
                plant_type, 
                COUNT(*) as count,
                AVG(growth_progress) as avg_progress,
                AVG(growth_stage) as avg_stage,
                SUM(CASE WHEN growth_progress >= 100 THEN 1 ELSE 0 END) as ready_count,
                SUM(CASE WHEN base_fertilized = 1 THEN 1 ELSE 0 END) as fertilized_count,
                AVG(water_count) as avg_water_count
            FROM `bcc_farming` 
            GROUP BY plant_type
            ORDER BY count DESC
        ]])
    end)
    
    if not success then
        return { 
            success = false, 
            error = "Database error", 
            data = {}, 
            timestamp = os.time() 
        }
    end
    
    -- Adicionar nome da planta e informações de configuração aos resultados
    if result then
        for _, plantData in pairs(result) do
            -- Encontrar configuração da planta
            for _, plantConfig in pairs(Plants) do
                if plantConfig.seedName == plantData.plant_type then
                    plantData.plant_name = plantConfig.plantName
                    plantData.water_times = plantConfig.waterTimes or 1
                    plantData.requires_base_fertilizer = plantConfig.requiresBaseFertilizer or false
                    
                    -- Calcular eficiência média de irrigação
                    local avgWaterEfficiency = 0
                    if plantData.avg_water_count and plantConfig.waterTimes then
                        avgWaterEfficiency = math.min(100, (plantData.avg_water_count / plantConfig.waterTimes) * 100)
                    end
                    plantData.avg_water_efficiency = math.floor(avgWaterEfficiency)
                    
                    break
                end
            end
            
            -- Calcular percentuais
            plantData.ready_percentage = math.floor((plantData.ready_count / plantData.count) * 100)
            plantData.fertilized_percentage = math.floor((plantData.fertilized_count / plantData.count) * 100)
            plantData.avg_progress = math.floor(plantData.avg_progress or 0)
            plantData.avg_stage = math.floor(plantData.avg_stage or 1)
        end
    end
    
    return { 
        success = true, 
        data = result or {}, 
        timestamp = os.time() 
    }
end)

-- Export para obter plantas próximas da colheita (atualizado para v2.5.0)
exports('GetNearHarvestPlants', function(timeThreshold)
    timeThreshold = timeThreshold or 300 -- 5 minutos default
    
    local success, result = pcall(function()
        return MySQL.query.await([[
            SELECT 
                plant_type, 
                COUNT(*) as count, 
                AVG(CAST(time_left AS UNSIGNED)) as avg_time_left,
                MIN(CAST(time_left AS UNSIGNED)) as min_time,
                MAX(CAST(time_left AS UNSIGNED)) as max_time,
                AVG(growth_progress) as avg_progress,
                AVG(growth_stage) as avg_stage,
                SUM(CASE WHEN base_fertilized = 1 THEN 1 ELSE 0 END) as fertilized_count,
                AVG(water_count) as avg_water_count
            FROM `bcc_farming` 
            WHERE CAST(time_left AS UNSIGNED) <= ? 
              AND CAST(time_left AS UNSIGNED) > 0
              AND growth_progress >= 95
            GROUP BY plant_type
            ORDER BY avg_time_left ASC
        ]], { timeThreshold })
    end)
    
    if not success then
        return { 
            success = false, 
            error = "Database error", 
            data = {}, 
            timestamp = os.time() 
        }
    end
    
    -- Formatar os dados para melhor legibilidade
    local formattedData = {}
    if result then
        for _, plant in pairs(result) do
            -- Buscar configuração da planta
            local plantConfig = nil
            for _, config in pairs(Plants) do
                if config.seedName == plant.plant_type then
                    plantConfig = config
                    break
                end
            end
            
            -- Calcular eficiência de irrigação
            local waterEfficiency = 0
            if plantConfig and plant.avg_water_count then
                waterEfficiency = math.min(100, (plant.avg_water_count / (plantConfig.waterTimes or 1)) * 100)
            end
            
            table.insert(formattedData, {
                plantType = plant.plant_type,
                plantName = plantConfig and plantConfig.plantName or plant.plant_type,
                count = plant.count,
                avgTimeLeft = math.floor(plant.avg_time_left or 0),
                minTimeLeft = plant.min_time,
                maxTimeLeft = plant.max_time,
                readyInMinutes = math.floor((plant.avg_time_left or 0) / 60),
                avgProgress = math.floor(plant.avg_progress or 0),
                avgStage = math.floor(plant.avg_stage or 1),
                fertilizedCount = plant.fertilized_count,
                fertilizedPercentage = math.floor((plant.fertilized_count / plant.count) * 100),
                avgWaterEfficiency = math.floor(waterEfficiency)
            })
        end
    end
    
    return { 
        success = true, 
        data = formattedData, 
        threshold_seconds = timeThreshold,
        threshold_minutes = math.floor(timeThreshold / 60),
        timestamp = os.time() 
    }
end)

-- Export para obter estatísticas gerais do farming (atualizado para v2.5.0)
exports('GetFarmingOverview', function()
    local totalPlantsData = exports['bcc-farming']:GetGlobalPlantCount()
    local plantsByTypeData = exports['bcc-farming']:GetGlobalPlantsByType()
    local nearHarvestData = exports['bcc-farming']:GetNearHarvestPlants(3600) -- 1 hora
    
    if not totalPlantsData.success or not plantsByTypeData.success or not nearHarvestData.success then
        return {
            success = false,
            error = "Failed to gather overview data",
            timestamp = os.time()
        }
    end
    
    -- Calcular estatísticas adicionais para v2.5.0
    local totalPlants = totalPlantsData.data
    local totalTypes = #plantsByTypeData.data
    local readySoon = 0
    local totalFertilized = 0
    local totalWaterEfficiency = 0
    local stageDistribution = {stage1 = 0, stage2 = 0, stage3 = 0}
    
    for _, plant in pairs(nearHarvestData.data) do
        readySoon = readySoon + plant.count
    end
    
    for _, plant in pairs(plantsByTypeData.data) do
        totalFertilized = totalFertilized + plant.fertilized_count
        totalWaterEfficiency = totalWaterEfficiency + (plant.avg_water_efficiency * plant.count)
        
        -- Distribuição de estágios baseada no estágio médio
        if plant.avg_stage <= 1.5 then
            stageDistribution.stage1 = stageDistribution.stage1 + plant.count
        elseif plant.avg_stage <= 2.5 then
            stageDistribution.stage2 = stageDistribution.stage2 + plant.count
        else
            stageDistribution.stage3 = stageDistribution.stage3 + plant.count
        end
    end
    
    -- Encontrar tipo mais comum
    local mostCommon = nil
    local maxCount = 0
    for _, plant in pairs(plantsByTypeData.data) do
        if plant.count > maxCount then
            maxCount = plant.count
            mostCommon = plant.plant_type
        end
    end
    
    -- Calcular percentuais globais
    local globalFertilizedPercentage = totalPlants > 0 and math.floor((totalFertilized / totalPlants) * 100) or 0
    local globalWaterEfficiency = totalPlants > 0 and math.floor(totalWaterEfficiency / totalPlants) or 0
    
    return {
        success = true,
        data = {
            -- Estatísticas básicas
            totalPlants = totalPlants,
            totalTypes = totalTypes,
            plantsReadySoon = readySoon,
            mostCommonPlant = mostCommon,
            mostCommonCount = maxCount,
            
            -- Estatísticas do sistema v2.5.0
            systemStats = {
                totalFertilized = totalFertilized,
                fertilizedPercentage = globalFertilizedPercentage,
                avgWaterEfficiency = globalWaterEfficiency,
                stageDistribution = stageDistribution,
                stagePercentages = {
                    stage1 = totalPlants > 0 and math.floor((stageDistribution.stage1 / totalPlants) * 100) or 0,
                    stage2 = totalPlants > 0 and math.floor((stageDistribution.stage2 / totalPlants) * 100) or 0,
                    stage3 = totalPlants > 0 and math.floor((stageDistribution.stage3 / totalPlants) * 100) or 0
                }
            },
            
            -- Dados detalhados
            plantsByType = plantsByTypeData.data,
            upcomingHarvests = nearHarvestData.data
        },
        timestamp = os.time()
    }
end)

-- Export para verificar status de irrigação atualizado para v2.5.0
exports('GetWateringStatus', function()
    local success, result = pcall(function()
        return MySQL.query.await([[
            SELECT 
                CASE 
                    WHEN water_count >= max_water_times THEN 'fully_watered'
                    WHEN water_count > 0 THEN 'partially_watered'
                    ELSE 'not_watered'
                END as watering_status,
                COUNT(*) as count,
                AVG(CAST(time_left AS UNSIGNED)) as avg_time_left,
                AVG(growth_progress) as avg_progress,
                AVG((water_count / GREATEST(max_water_times, 1)) * 100) as avg_water_efficiency
            FROM `bcc_farming` 
            GROUP BY watering_status
        ]])
    end)
    
    if not success then
        return { 
            success = false, 
            error = "Database error", 
            timestamp = os.time() 
        }
    end
    
    local fullyWatered = {count = 0, avgTimeLeft = 0, avgProgress = 0, avgEfficiency = 0}
    local partiallyWatered = {count = 0, avgTimeLeft = 0, avgProgress = 0, avgEfficiency = 0}
    local notWatered = {count = 0, avgTimeLeft = 0, avgProgress = 0, avgEfficiency = 0}
    
    if result then
        for _, status in pairs(result) do
            local data = {
                count = status.count,
                avgTimeLeft = math.floor(status.avg_time_left or 0),
                avgProgress = math.floor(status.avg_progress or 0),
                avgEfficiency = math.floor(status.avg_water_efficiency or 0)
            }
            
            if status.watering_status == 'fully_watered' then
                fullyWatered = data
            elseif status.watering_status == 'partially_watered' then
                partiallyWatered = data
            else
                notWatered = data
            end
        end
    end
    
    local total = fullyWatered.count + partiallyWatered.count + notWatered.count
    
    return {
        success = true,
        data = {
            fullyWatered = {
                count = fullyWatered.count,
                avgTimeLeft = fullyWatered.avgTimeLeft,
                avgProgress = fullyWatered.avgProgress,
                avgEfficiency = fullyWatered.avgEfficiency,
                percentage = total > 0 and math.floor((fullyWatered.count / total) * 100) or 0
            },
            partiallyWatered = {
                count = partiallyWatered.count,
                avgTimeLeft = partiallyWatered.avgTimeLeft,
                avgProgress = partiallyWatered.avgProgress,
                avgEfficiency = partiallyWatered.avgEfficiency,
                percentage = total > 0 and math.floor((partiallyWatered.count / total) * 100) or 0
            },
            notWatered = {
                count = notWatered.count,
                avgTimeLeft = notWatered.avgTimeLeft,
                avgProgress = notWatered.avgProgress,
                avgEfficiency = notWatered.avgEfficiency,
                percentage = total > 0 and math.floor((notWatered.count / total) * 100) or 0
            },
            total = total,
            summary = {
                needsWatering = partiallyWatered.count + notWatered.count,
                fullyOptimized = fullyWatered.count,
                overallEfficiency = total > 0 and math.floor(
                    ((fullyWatered.avgEfficiency * fullyWatered.count) + 
                     (partiallyWatered.avgEfficiency * partiallyWatered.count) + 
                     (notWatered.avgEfficiency * notWatered.count)) / total
                ) or 0
            }
        },
        timestamp = os.time()
    }
end)

-- Export para obter estatísticas de crescimento por estágio (NOVO para v2.5.0)
exports('GetGrowthStageDistribution', function()
    local success, result = pcall(function()
        return MySQL.query.await([[
            SELECT 
                growth_stage,
                COUNT(*) as count,
                AVG(growth_progress) as avg_progress,
                AVG(CAST(time_left AS UNSIGNED)) as avg_time_left,
                SUM(CASE WHEN base_fertilized = 1 THEN 1 ELSE 0 END) as fertilized_count,
                AVG(water_count) as avg_water_count,
                AVG(max_water_times) as avg_max_water
            FROM `bcc_farming` 
            GROUP BY growth_stage
            ORDER BY growth_stage ASC
        ]])
    end)
    
    if not success then
        return { 
            success = false, 
            error = "Database error", 
            timestamp = os.time() 
        }
    end
    
    local stageData = {}
    local totalPlants = 0
    
    if result then
        for _, stage in pairs(result) do
            totalPlants = totalPlants + stage.count
            
            table.insert(stageData, {
                stage = stage.growth_stage,
                count = stage.count,
                avgProgress = math.floor(stage.avg_progress or 0),
                avgTimeLeft = math.floor(stage.avg_time_left or 0),
                fertilizedCount = stage.fertilized_count,
                avgWaterCount = math.floor(stage.avg_water_count or 0),
                avgMaxWater = math.floor(stage.avg_max_water or 1),
                waterEfficiency = stage.avg_max_water > 0 and 
                    math.floor((stage.avg_water_count / stage.avg_max_water) * 100) or 0
            })
        end
    end
    
    -- Adicionar percentuais
    for _, stage in pairs(stageData) do
        stage.percentage = totalPlants > 0 and math.floor((stage.count / totalPlants) * 100) or 0
        stage.fertilizedPercentage = stage.count > 0 and math.floor((stage.fertilizedCount / stage.count) * 100) or 0
    end
    
    return {
        success = true,
        data = {
            stages = stageData,
            totalPlants = totalPlants,
            summary = {
                mostCommonStage = stageData[1] and stageData[1].stage or 1,
                avgProgressAcrossStages = totalPlants > 0 and 
                    math.floor((stageData[1] and stageData[1].avgProgress or 0 +
                               stageData[2] and stageData[2].avgProgress or 0 +
                               stageData[3] and stageData[3].avgProgress or 0) / #stageData) or 0
            }
        },
        timestamp = os.time()
    }
end)

print("^2[BCC-Farming]^7 Enhanced basic exports v2.5.0 loaded!")