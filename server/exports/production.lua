-- server/exports/production.lua
-- FASE 1 - Dia 5: Estimativas de Produção

-- Export para estimar produção em um período de tempo
exports('GetEstimatedProduction', function(hours)
    hours = hours or 24 -- Default 24 horas
    local maxTime = hours * 3600 -- Converter para segundos
    
    local success, result = pcall(function()
        return MySQL.query.await([[
            SELECT 
                plant_type, 
                COUNT(*) as plants_ready,
                AVG(CAST(time_left AS UNSIGNED)) as avg_time_left,
                MIN(CAST(time_left AS UNSIGNED)) as min_time,
                MAX(CAST(time_left AS UNSIGNED)) as max_time
            FROM `bcc_farming` 
            WHERE CAST(time_left AS UNSIGNED) <= ? 
              AND CAST(time_left AS UNSIGNED) > 0
              AND plant_watered = 'true'
            GROUP BY plant_type
            ORDER BY avg_time_left ASC
        ]], { maxTime })
    end)
    
    if not success then
        return { 
            success = false, 
            error = "Database error", 
            timestamp = os.time() 
        }
    end
    
    local productionEstimate = {}
    local totalEstimatedValue = 0
    
    if result then
        for _, production in pairs(result) do
            local plantType = production.plant_type
            local plantsReady = production.plants_ready
            
            -- Encontrar configuração da planta no Plants config
            local plantConfig = nil
            for _, plant in pairs(Plants) do
                if plant.seedName == plantType then
                    plantConfig = plant
                    break
                end
            end
            
            if plantConfig then
                local estimatedItems = {}
                local totalItemValue = 0
                
                -- Calcular items estimados baseado nas rewards
                for _, reward in pairs(plantConfig.rewards) do
                    local totalAmount = reward.amount * plantsReady
                    estimatedItems[reward.itemName] = {
                        itemName = reward.itemName,
                        itemLabel = reward.itemLabel,
                        amountPerPlant = reward.amount,
                        totalAmount = totalAmount,
                        plants = plantsReady
                    }
                    
                    -- Estimar valor (pode ser customizado depois)
                    local estimatedItemValue = totalAmount * 1 -- Base value 1, pode ser configurável
                    totalItemValue = totalItemValue + estimatedItemValue
                end
                
                totalEstimatedValue = totalEstimatedValue + totalItemValue
                
                table.insert(productionEstimate, {
                    plantType = plantType,
                    plantName = plantConfig.plantName,
                    plantsReady = plantsReady,
                    avgTimeLeft = math.floor(production.avg_time_left),
                    minTimeLeft = production.min_time,
                    maxTimeLeft = production.max_time,
                    avgTimeLeftHours = math.floor(production.avg_time_left / 3600 * 100) / 100,
                    estimatedItems = estimatedItems,
                    estimatedValue = totalItemValue
                })
            end
        end
    end
    
    -- Ordenar por tempo médio restante
    table.sort(productionEstimate, function(a, b) return a.avgTimeLeft < b.avgTimeLeft end)
    
    return { 
        success = true, 
        data = productionEstimate,
        summary = {
            totalPlants = #productionEstimate > 0 and 
                (function()
                    local total = 0
                    for _, prod in pairs(productionEstimate) do
                        total = total + prod.plantsReady
                    end
                    return total
                end)() or 0,
            totalTypes = #productionEstimate,
            estimatedValue = totalEstimatedValue,
            timeframeHours = hours
        },
        timeframe_hours = hours,
        timestamp = os.time() 
    }
end)

-- Export para obter produção total possível (todas as plantas)
exports('GetTotalProductionPotential', function()
    local success, result = pcall(function()
        return MySQL.query.await([[
            SELECT 
                plant_type, 
                COUNT(*) as total_plants,
                SUM(CASE WHEN plant_watered = 'true' THEN 1 ELSE 0 END) as watered_plants,
                SUM(CASE WHEN CAST(time_left AS UNSIGNED) <= 0 AND plant_watered = 'true' THEN 1 ELSE 0 END) as ready_plants,
                AVG(CASE WHEN plant_watered = 'true' THEN CAST(time_left AS UNSIGNED) ELSE NULL END) as avg_time_left
            FROM `bcc_farming` 
            GROUP BY plant_type
            ORDER BY total_plants DESC
        ]])
    end)
    
    if not success then
        return { 
            success = false, 
            error = "Database error", 
            timestamp = os.time() 
        }
    end
    
    local potentialProduction = {}
    local totals = {
        totalPlants = 0,
        wateredPlants = 0,
        readyPlants = 0,
        estimatedTotalItems = 0
    }
    
    if result then
        for _, data in pairs(result) do
            local plantType = data.plant_type
            
            -- Encontrar configuração da planta
            local plantConfig = nil
            for _, plant in pairs(Plants) do
                if plant.seedName == plantType then
                    plantConfig = plant
                    break
                end
            end
            
            if plantConfig then
                local potentialItems = {}
                local totalPotentialValue = 0
                
                -- Calcular potencial total baseado em todas as plantas
                for _, reward in pairs(plantConfig.rewards) do
                    local potentialAmount = reward.amount * data.total_plants
                    potentialItems[reward.itemName] = {
                        itemName = reward.itemName,
                        itemLabel = reward.itemLabel,
                        potentialTotal = potentialAmount,
                        readyNow = reward.amount * (data.ready_plants or 0),
                        whenAllReady = potentialAmount
                    }
                    totalPotentialValue = totalPotentialValue + potentialAmount
                end
                
                local avgHoursLeft = data.avg_time_left and math.floor((data.avg_time_left / 3600) * 100) / 100 or 0
                
                table.insert(potentialProduction, {
                    plantType = plantType,
                    plantName = plantConfig.plantName,
                    totalPlants = data.total_plants,
                    wateredPlants = data.watered_plants,
                    readyPlants = data.ready_plants or 0,
                    notWateredPlants = data.total_plants - data.watered_plants,
                    avgTimeLeftHours = avgHoursLeft,
                    potentialItems = potentialItems,
                    potentialValue = totalPotentialValue,
                    efficiency = data.total_plants > 0 and 
                        math.floor((data.watered_plants / data.total_plants) * 100) or 0
                })
                
                -- Atualizar totais
                totals.totalPlants = totals.totalPlants + data.total_plants
                totals.wateredPlants = totals.wateredPlants + data.watered_plants
                totals.readyPlants = totals.readyPlants + (data.ready_plants or 0)
                totals.estimatedTotalItems = totals.estimatedTotalItems + totalPotentialValue
            end
        end
    end
    
    return {
        success = true,
        data = potentialProduction,
        totals = totals,
        efficiency = {
            globalWateringRate = totals.totalPlants > 0 and 
                math.floor((totals.wateredPlants / totals.totalPlants) * 100) or 0,
            globalReadyRate = totals.wateredPlants > 0 and 
                math.floor((totals.readyPlants / totals.wateredPlants) * 100) or 0
        },
        timestamp = os.time()
    }
end)

-- Export para obter previsão de produção por hora
exports('GetHourlyProductionForecast', function(forecastHours)
    forecastHours = forecastHours or 12 -- Default 12 horas
    
    local hourlyForecast = {}
    
    -- Para cada hora nas próximas X horas
    for hour = 1, forecastHours do
        local timeThreshold = hour * 3600 -- Converter hora para segundos
        
        local success, result = pcall(function()
            return MySQL.query.await([[
                SELECT 
                    plant_type, 
                    COUNT(*) as plants_ready
                FROM `bcc_farming` 
                WHERE CAST(time_left AS UNSIGNED) <= ? 
                  AND CAST(time_left AS UNSIGNED) > ?
                  AND plant_watered = 'true'
                GROUP BY plant_type
            ]], { timeThreshold, timeThreshold - 3600 })
        end)
        
        if success and result then
            local hourData = {
                hour = hour,
                timeFromNow = hour .. "h",
                plants = {},
                totalPlants = 0,
                estimatedItems = {}
            }
            
            for _, data in pairs(result) do
                local plantType = data.plant_type
                local plantsReady = data.plants_ready
                
                -- Encontrar configuração da planta
                local plantConfig = nil
                for _, plant in pairs(Plants) do
                    if plant.seedName == plantType then
                        plantConfig = plant
                        break
                    end
                end
                
                if plantConfig then
                    hourData.plants[plantType] = {
                        plantName = plantConfig.plantName,
                        count = plantsReady
                    }
                    
                    hourData.totalPlants = hourData.totalPlants + plantsReady
                    
                    -- Calcular items que estarão prontos
                    for _, reward in pairs(plantConfig.rewards) do
                        if not hourData.estimatedItems[reward.itemName] then
                            hourData.estimatedItems[reward.itemName] = {
                                itemLabel = reward.itemLabel,
                                amount = 0
                            }
                        end
                        hourData.estimatedItems[reward.itemName].amount = 
                            hourData.estimatedItems[reward.itemName].amount + (reward.amount * plantsReady)
                    end
                end
            end
            
            table.insert(hourlyForecast, hourData)
        end
    end
    
    return {
        success = true,
        data = hourlyForecast,
        forecastHours = forecastHours,
        summary = {
            totalHours = #hourlyForecast,
            peakHour = #hourlyForecast > 0 and 
                (function()
                    local maxPlants = 0
                    local peakHour = 1
                    for _, hourData in pairs(hourlyForecast) do
                        if hourData.totalPlants > maxPlants then
                            maxPlants = hourData.totalPlants
                            peakHour = hourData.hour
                        end
                    end
                    return peakHour
                end)() or 0
        },
        timestamp = os.time()
    }
end)

-- Export para calcular eficiência de produção
exports('GetProductionEfficiency', function()
    local wateringStatus = exports['bcc-farming']:GetWateringStatus()
    local totalPotential = exports['bcc-farming']:GetTotalProductionPotential()
    
    if not wateringStatus.success or not totalPotential.success then
        return {
            success = false,
            error = "Failed to calculate efficiency",
            timestamp = os.time()
        }
    end
    
    local totalPlants = wateringStatus.data.total
    local wateredPlants = wateringStatus.data.watered.count
    local readyPlants = totalPotential.totals.readyPlants
    
    local wateringEfficiency = totalPlants > 0 and (wateredPlants / totalPlants) or 0
    local harvestingEfficiency = wateredPlants > 0 and (readyPlants / wateredPlants) or 0
    local overallEfficiency = (wateringEfficiency + harvestingEfficiency) / 2
    
    return {
        success = true,
        data = {
            watering = {
                efficiency = math.floor(wateringEfficiency * 100),
                wateredPlants = wateredPlants,
                totalPlants = totalPlants,
                notWateredPlants = totalPlants - wateredPlants
            },
            harvesting = {
                efficiency = math.floor(harvestingEfficiency * 100),
                readyPlants = readyPlants,
                wateredPlants = wateredPlants,
                stillGrowingPlants = wateredPlants - readyPlants
            },
            overall = {
                efficiency = math.floor(overallEfficiency * 100),
                grade = overallEfficiency >= 0.8 and "Excellent" or
                        overallEfficiency >= 0.6 and "Good" or
                        overallEfficiency >= 0.4 and "Average" or
                        overallEfficiency >= 0.2 and "Poor" or "Very Poor",
                recommendations = {
                    needsMoreWatering = wateringEfficiency < 0.7,
                    needsMoreHarvesting = harvestingEfficiency < 0.3,
                    isWellMaintained = overallEfficiency >= 0.7
                }
            }
        },
        timestamp = os.time()
    }
end)

-- Export para análise de crescimento de plantas
exports('GetGrowthAnalysis', function()
    local success, result = pcall(function()
        return MySQL.query.await([[
            SELECT 
                plant_type,
                COUNT(*) as total,
                AVG(CAST(time_left AS UNSIGNED)) as avg_time_left,
                SUM(CASE WHEN CAST(time_left AS UNSIGNED) <= 0 THEN 1 ELSE 0 END) as fully_grown,
                SUM(CASE WHEN plant_watered = 'true' THEN 1 ELSE 0 END) as watered,
                SUM(CASE WHEN CAST(time_left AS UNSIGNED) <= 1800 AND CAST(time_left AS UNSIGNED) > 0 THEN 1 ELSE 0 END) as almost_ready
            FROM `bcc_farming`
            GROUP BY plant_type
        ]])
    end)
    
    if not success then
        return { 
            success = false, 
            error = "Database error", 
            timestamp = os.time() 
        }
    end
    
    local growthData = {}
    local overallStats = {
        totalPlants = 0,
        totalFullyGrown = 0,
        totalWatered = 0,
        totalAlmostReady = 0
    }
    
    if result then
        for _, data in pairs(result) do
            local plantType = data.plant_type
            
            -- Encontrar configuração da planta
            local plantConfig = nil
            for _, plant in pairs(Plants) do
                if plant.seedName == plantType then
                    plantConfig = plant
                    break
                end
            end
            
            if plantConfig then
                local growthPercentage = data.total > 0 and 
                    math.floor(((data.total - (data.avg_time_left / plantConfig.timeToGrow)) / data.total) * 100) or 0
                
                table.insert(growthData, {
                    plantType = plantType,
                    plantName = plantConfig.plantName,
                    total = data.total,
                    fullyGrown = data.fully_grown,
                    watered = data.watered,
                    almostReady = data.almost_ready, -- 30 minutos ou menos
                    avgTimeLeftHours = math.floor((data.avg_time_left / 3600) * 100) / 100,
                    growthPercentage = math.max(0, math.min(100, growthPercentage)),
                    efficiency = {
                        wateringRate = math.floor((data.watered / data.total) * 100),
                        readyRate = math.floor((data.fully_grown / data.total) * 100),
                        nearReadyRate = math.floor((data.almost_ready / data.total) * 100)
                    }
                })
                
                -- Atualizar estatísticas gerais
                overallStats.totalPlants = overallStats.totalPlants + data.total
                overallStats.totalFullyGrown = overallStats.totalFullyGrown + data.fully_grown
                overallStats.totalWatered = overallStats.totalWatered + data.watered
                overallStats.totalAlmostReady = overallStats.totalAlmostReady + data.almost_ready
            end
        end
    end
    
    -- Calcular estatísticas gerais
    local overallEfficiency = {
        globalWateringRate = overallStats.totalPlants > 0 and 
            math.floor((overallStats.totalWatered / overallStats.totalPlants) * 100) or 0,
        globalReadyRate = overallStats.totalPlants > 0 and 
            math.floor((overallStats.totalFullyGrown / overallStats.totalPlants) * 100) or 0,
        globalNearReadyRate = overallStats.totalPlants > 0 and 
            math.floor((overallStats.totalAlmostReady / overallStats.totalPlants) * 100) or 0
    }
    
    return {
        success = true,
        data = growthData,
        overallStats = overallStats,
        overallEfficiency = overallEfficiency,
        insights = {
            mostEfficient = #growthData > 0 and 
                (function()
                    local best = growthData[1]
                    for _, plant in pairs(growthData) do
                        if plant.efficiency.wateringRate > best.efficiency.wateringRate then
                            best = plant
                        end
                    end
                    return best.plantName
                end)() or "None",
            needsAttention = #growthData > 0 and 
                (function()
                    local worst = growthData[1]
                    for _, plant in pairs(growthData) do
                        if plant.efficiency.wateringRate < worst.efficiency.wateringRate then
                            worst = plant
                        end
                    end
                    return worst.efficiency.wateringRate < 50 and worst.plantName or "None"
                end)() or "None"
        },
        timestamp = os.time()
    }
end)