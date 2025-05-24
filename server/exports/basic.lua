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
            SELECT plant_type, COUNT(*) as count 
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
    
    return { 
        success = true, 
        data = result or {}, 
        timestamp = os.time() 
    }
end)

-- Export para obter plantas próximas da colheita
exports('GetNearHarvestPlants', function(timeThreshold)
    timeThreshold = timeThreshold or 300 -- 5 minutos default
    
    local success, result = pcall(function()
        return MySQL.query.await([[
            SELECT 
                plant_type, 
                COUNT(*) as count, 
                AVG(CAST(time_left AS UNSIGNED)) as avg_time_left,
                MIN(CAST(time_left AS UNSIGNED)) as min_time,
                MAX(CAST(time_left AS UNSIGNED)) as max_time
            FROM `bcc_farming` 
            WHERE CAST(time_left AS UNSIGNED) <= ? 
              AND CAST(time_left AS UNSIGNED) > 0
              AND plant_watered = 'true'
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
            table.insert(formattedData, {
                plantType = plant.plant_type,
                count = plant.count,
                avgTimeLeft = math.floor(plant.avg_time_left or 0),
                minTimeLeft = plant.min_time,
                maxTimeLeft = plant.max_time,
                readyInMinutes = math.floor((plant.avg_time_left or 0) / 60)
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

-- Export para obter estatísticas gerais do farming
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
    
    -- Calcular estatísticas adicionais
    local totalPlants = totalPlantsData.data
    local totalTypes = #plantsByTypeData.data
    local readySoon = 0
    
    for _, plant in pairs(nearHarvestData.data) do
        readySoon = readySoon + plant.count
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
    
    return {
        success = true,
        data = {
            totalPlants = totalPlants,
            totalTypes = totalTypes,
            plantsReadySoon = readySoon,
            mostCommonPlant = mostCommon,
            mostCommonCount = maxCount,
            plantsByType = plantsByTypeData.data,
            upcomingHarvests = nearHarvestData.data
        },
        timestamp = os.time()
    }
end)

-- Export para verificar status de plantas regadas vs não regadas
exports('GetWateringStatus', function()
    local success, result = pcall(function()
        return MySQL.query.await([[
            SELECT 
                plant_watered,
                COUNT(*) as count,
                AVG(CAST(time_left AS UNSIGNED)) as avg_time_left
            FROM `bcc_farming` 
            GROUP BY plant_watered
        ]])
    end)
    
    if not success then
        return { 
            success = false, 
            error = "Database error", 
            timestamp = os.time() 
        }
    end
    
    local watered = 0
    local notWatered = 0
    local wateredAvgTime = 0
    local notWateredAvgTime = 0
    
    if result then
        for _, status in pairs(result) do
            if status.plant_watered == 'true' then
                watered = status.count
                wateredAvgTime = math.floor(status.avg_time_left or 0)
            else
                notWatered = status.count
                notWateredAvgTime = math.floor(status.avg_time_left or 0)
            end
        end
    end
    
    local total = watered + notWatered
    local wateredPercentage = total > 0 and math.floor((watered / total) * 100) or 0
    
    return {
        success = true,
        data = {
            watered = {
                count = watered,
                avgTimeLeft = wateredAvgTime,
                percentage = wateredPercentage
            },
            notWatered = {
                count = notWatered,
                avgTimeLeft = notWateredAvgTime,
                percentage = 100 - wateredPercentage
            },
            total = total
        },
        timestamp = os.time()
    }
end)