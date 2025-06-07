-- =======================================
-- BCC-Farming Simple Basic Exports v2.5.0
-- Simplified exports without module dependencies
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

-- Export para obter contagem de plantas por tipo
exports('GetGlobalPlantsByType', function()
    local success, result = pcall(function()
        return MySQL.query.await([[
            SELECT 
                plant_type, 
                COUNT(*) as count,
                COALESCE(AVG(growth_progress), 0) as avg_progress,
                COALESCE(AVG(growth_stage), 1) as avg_stage,
                SUM(CASE WHEN growth_progress >= 100 THEN 1 ELSE 0 END) as ready_count,
                SUM(CASE WHEN base_fertilized = 1 THEN 1 ELSE 0 END) as fertilized_count,
                COALESCE(AVG(water_count), 0) as avg_water_count
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
    
    -- Adicionar nome da planta aos resultados
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

-- Export para obter estatísticas gerais do farming
exports('GetFarmingOverview', function()
    local totalPlantsData = exports['bcc-farming']:GetGlobalPlantCount()
    local plantsByTypeData = exports['bcc-farming']:GetGlobalPlantsByType()
    
    if not totalPlantsData.success or not plantsByTypeData.success then
        return {
            success = false,
            error = "Failed to gather overview data",
            timestamp = os.time()
        }
    end
    
    -- Calcular estatísticas básicas
    local totalPlants = totalPlantsData.data
    local totalTypes = #plantsByTypeData.data
    
    -- Encontrar tipo mais comum
    local mostCommon = nil
    local maxCount = 0
    for _, plant in pairs(plantsByTypeData.data) do
        if plant.count > maxCount then
            maxCount = plant.count
            mostCommon = plant.plant_type
        end
    end
    
    return {
        success = true,
        data = {
            totalPlants = totalPlants,
            totalTypes = totalTypes,
            mostCommonPlant = mostCommon,
            mostCommonCount = maxCount,
            plantsByType = plantsByTypeData.data
        },
        timestamp = os.time()
    }
end)

-- Export para verificar status de irrigação
exports('GetWateringStatus', function()
    local success, result = pcall(function()
        return MySQL.query.await([[
            SELECT 
                CASE 
                    WHEN water_count >= COALESCE(max_water_times, 1) THEN 'fully_watered'
                    WHEN water_count > 0 THEN 'partially_watered'
                    ELSE 'not_watered'
                END as watering_status,
                COUNT(*) as count,
                COALESCE(AVG(CAST(time_left AS UNSIGNED)), 0) as avg_time_left,
                COALESCE(AVG(growth_progress), 0) as avg_progress
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
    
    local fullyWatered = {count = 0, avgTimeLeft = 0, avgProgress = 0}
    local partiallyWatered = {count = 0, avgTimeLeft = 0, avgProgress = 0}
    local notWatered = {count = 0, avgTimeLeft = 0, avgProgress = 0}
    
    if result then
        for _, status in pairs(result) do
            local data = {
                count = status.count,
                avgTimeLeft = math.floor(status.avg_time_left or 0),
                avgProgress = math.floor(status.avg_progress or 0)
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
                percentage = total > 0 and math.floor((fullyWatered.count / total) * 100) or 0
            },
            partiallyWatered = {
                count = partiallyWatered.count,
                avgTimeLeft = partiallyWatered.avgTimeLeft,
                avgProgress = partiallyWatered.avgProgress,
                percentage = total > 0 and math.floor((partiallyWatered.count / total) * 100) or 0
            },
            notWatered = {
                count = notWatered.count,
                avgTimeLeft = notWatered.avgTimeLeft,
                avgProgress = notWatered.avgProgress,
                percentage = total > 0 and math.floor((notWatered.count / total) * 100) or 0
            },
            total = total
        },
        timestamp = os.time()
    }
end)

-- Export para obter distribuição de estágios de crescimento
exports('GetGrowthStageDistribution', function()
    local success, result = pcall(function()
        return MySQL.query.await([[
            SELECT 
                growth_stage,
                COUNT(*) as count,
                COALESCE(AVG(growth_progress), 0) as avg_progress,
                COALESCE(AVG(CAST(time_left AS UNSIGNED)), 0) as avg_time_left,
                SUM(CASE WHEN base_fertilized = 1 THEN 1 ELSE 0 END) as fertilized_count,
                COALESCE(AVG(water_count), 0) as avg_water_count,
                COALESCE(AVG(max_water_times), 1) as avg_max_water
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
                avgMaxWater = math.floor(stage.avg_max_water or 1)
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
            totalPlants = totalPlants
        },
        timestamp = os.time()
    }
end)

print("^2[BCC-Farming]^7 Simple basic exports loaded successfully!")