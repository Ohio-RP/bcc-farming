-- server/exports/economy.lua
-- FASE 2 - Sistema de Economia Dinâmica

local Economy = {
    priceHistory = {},
    marketEvents = {},
    lastUpdate = 0,
    config = {
        volatility = 0.3,
        update_interval = 1800, -- 30 minutos
        price_change_threshold = 0.1, -- 10%
        max_price_multiplier = 3.0,
        min_price_multiplier = 0.2
    }
}

-- Função para obter configuração econômica
local function GetEconomyConfig(key, default)
    local success, result = pcall(function()
        return MySQL.scalar.await('SELECT config_value FROM bcc_farming_config WHERE config_key = ?', { key })
    end)
    
    if success and result then
        return tonumber(result) or default
    end
    return default
end

-- Atualizar configurações da economia
local function UpdateEconomyConfig()
    Economy.config.volatility = GetEconomyConfig('market_volatility', 0.3)
    Economy.config.update_interval = GetEconomyConfig('price_update_interval', 1800)
end

-- Registrar evento de mercado
local function RegisterMarketEvent(plantType, eventType, impact, description)
    local event = {
        plantType = plantType,
        eventType = eventType,
        impact = impact,
        description = description,
        timestamp = os.time()
    }
    
    table.insert(Economy.marketEvents, event)
    
    -- Manter apenas últimos 100 eventos
    if #Economy.marketEvents > 100 then
        table.remove(Economy.marketEvents, 1)
    end
    
    -- Salvar no histórico do banco
    CreateThread(function()
        pcall(function()
            MySQL.insert('INSERT INTO bcc_farming_history (plant_type, action, quantity, player_id, extra_data) VALUES (?, ?, ?, ?, ?)',
                { plantType, 'market_event', 1, 0, json.encode(event) })
        end)
    end)
end

-- Calcular índice de escassez
exports('GetPlantScarcityIndex', function(plantType)
    local cacheKey = "economy:scarcity:" .. plantType
    local cached = nil
    if cached then return cached end
    
    local success, data = pcall(function()
        return MySQL.query.await([[
            SELECT 
                (SELECT COUNT(*) FROM bcc_farming WHERE plant_type = ?) as active_supply,
                (SELECT COUNT(*) FROM bcc_farming_history 
                 WHERE plant_type = ? AND action = 'harvested' 
                 AND timestamp > DATE_SUB(NOW(), INTERVAL 24 HOUR)) as recent_demand,
                (SELECT AVG(daily_count) FROM (
                    SELECT COUNT(*) as daily_count
                    FROM bcc_farming_history 
                    WHERE plant_type = ? AND action = 'planted'
                    AND timestamp > DATE_SUB(NOW(), INTERVAL 7 DAY)
                    GROUP BY DATE(timestamp)
                ) as daily_stats) as baseline_avg
        ]], { plantType, plantType, plantType })
    end)
    
    if not success or not data or #data == 0 then
        return { 
            success = false, 
            error = "Database error calculating scarcity",
            timestamp = os.time() 
        }
    end
    
    local stats = data[1]
    local activeSupply = stats.active_supply or 0
    local recentDemand = stats.recent_demand or 0
    local baseline = stats.baseline_avg or 10
    
    -- Fórmula de escassez aprimorada
    local supplyRatio = baseline > 0 and (activeSupply / baseline) or 1
    local demandRatio = baseline > 0 and (recentDemand / (baseline * 0.7)) or 1
    
    -- Calcular escassez: 0.0 = abundante, 1.0 = muito escasso
    local supplyRatio = tonumber(supplyRatio) or 0
    local demandRatio = tonumber(demandRatio) or 0
    local scarcityIndex = math.max(0, math.min(1, 
        0.5 - (supplyRatio * 0.35) + (demandRatio * 0.35)
    ))
    
    -- Classificação da escassez
    local classification
    if scarcityIndex >= 0.8 then
        classification = "Critical"
    elseif scarcityIndex >= 0.6 then
        classification = "Very High"
    elseif scarcityIndex >= 0.4 then
        classification = "High"
    elseif scarcityIndex >= 0.2 then
        classification = "Medium"
    else
        classification = "Low"
    end
    
    local result = {
        success = true,
        data = {
            plantType = plantType,
            scarcityIndex = math.floor(scarcityIndex * 100) / 100,
            classification = classification,
            activeSupply = activeSupply,
            recentDemand = recentDemand,
            baseline = baseline,
            supplyRatio = math.floor(supplyRatio * 100) / 100,
            demandRatio = math.floor(demandRatio * 100) / 100,
            marketCondition = scarcityIndex > 0.6 and "Sellers Market" or 
                            scarcityIndex < 0.3 and "Buyers Market" or "Balanced"
        },
        timestamp = os.time()
    }
    
    -- Cache por 10 minutos
    if Cache then
        Cache:Set(cacheKey, result, 600)
    end
    
    return result
end)

-- Calcular preço dinâmico
exports('CalculateDynamicPrice', function(plantType, basePrice)
    basePrice = basePrice or 1.0
    
    local scarcityData = exports['bcc-farming']:GetPlantScarcityIndex(plantType)
    if not scarcityData.success then
        return { 
            success = false, 
            error = "Could not calculate scarcity for pricing",
            timestamp = os.time()
        }
    end
    
    local scarcity = scarcityData.data.scarcityIndex
    
    -- Buscar multiplicador atual do banco
    local success, currentMultiplier = pcall(function()
        return MySQL.scalar.await([[
            SELECT current_price_multiplier FROM bcc_farming_market_stats 
            WHERE plant_type = ?
        ]], { plantType })
    end)
    
    currentMultiplier = (success and currentMultiplier) or 1.0
    
    -- Fórmula de preço dinâmico aprimorada
    -- Base: 0.5x a 2.5x do preço base dependendo da escassez
    local targetMultiplier = 0.5 + (scarcity * 2.0)
    
    -- Adicionar volatilidade baseada em eventos de mercado
    local volatilityFactor = 1.0
    for _, event in pairs(Economy.marketEvents) do
        if event.plantType == plantType and (os.time() - event.timestamp) < 3600 then -- Eventos da última hora
            volatilityFactor = volatilityFactor + (event.impact * Economy.config.volatility)
        end
    end
    
    targetMultiplier = targetMultiplier * volatilityFactor
    
    -- Suavizar mudanças de preço (25% da diferença por atualização)
    local newMultiplier = currentMultiplier + ((targetMultiplier - currentMultiplier) * 0.25)
    
    -- Aplicar limites
    newMultiplier = math.max(Economy.config.min_price_multiplier, 
                    math.min(Economy.config.max_price_multiplier, newMultiplier))
    
    local dynamicPrice = math.floor(basePrice * newMultiplier * 100) / 100
    local priceChange = math.floor(((newMultiplier - currentMultiplier) / currentMultiplier) * 100)
    
    -- Salvar novo multiplicador no banco
    CreateThread(function()
        pcall(function()
            MySQL.execute([[
                UPDATE bcc_farming_market_stats 
                SET current_price_multiplier = ?, base_price = ?
                WHERE plant_type = ?
            ]], { newMultiplier, basePrice, plantType })
        end)
    end)
    
    -- Registrar mudança significativa como evento
    if math.abs(priceChange) >= (Economy.config.price_change_threshold * 100) then
        local eventDescription = string.format("Price %s by %d%% due to market conditions", 
            priceChange > 0 and "increased" or "decreased", math.abs(priceChange))
        RegisterMarketEvent(plantType, "price_change", priceChange / 100, eventDescription)
        
        -- Notificar jogadores interessados
        TriggerEvent('bcc-farming:NotifyPriceChange', plantType, priceChange, newMultiplier)
    end
    
    return {
        success = true,
        data = {
            plantType = plantType,
            basePrice = basePrice,
            dynamicPrice = dynamicPrice,
            priceMultiplier = math.floor(newMultiplier * 100) / 100,
            previousMultiplier = math.floor(currentMultiplier * 100) / 100,
            scarcityIndex = scarcity,
            priceChange = priceChange,
            priceChangeDirection = priceChange > 0 and "up" or priceChange < 0 and "down" or "stable",
            marketCondition = scarcityData.data.marketCondition,
            volatilityFactor = math.floor(volatilityFactor * 100) / 100
        },
        timestamp = os.time()
    }
end)

-- Obter tendência de plantio
exports('GetPlantingTrend', function(plantType, days)
    days = days or 7
    
    local cacheKey = "economy:trend:" .. plantType .. ":" .. days
    local cached = nil
    if cached then return cached end
    
    local success, dailyStats = pcall(function()
        return MySQL.query.await([[
            SELECT 
                DATE(timestamp) as date,
                SUM(CASE WHEN action = 'planted' THEN quantity ELSE 0 END) as planted,
                SUM(CASE WHEN action = 'harvested' THEN quantity ELSE 0 END) as harvested,
                SUM(CASE WHEN action = 'destroyed' THEN quantity ELSE 0 END) as destroyed
            FROM bcc_farming_history 
            WHERE plant_type = ? 
            AND timestamp > DATE_SUB(NOW(), INTERVAL ? DAY)
            GROUP BY DATE(timestamp)
            ORDER BY date
        ]], { plantType, days })
    end)
    
    if not success or not dailyStats then
        return {
            success = false,
            error = "Database error calculating trend",
            timestamp = os.time()
        }
    end
    
    if #dailyStats < 3 then
        return {
            success = true,
            data = {
                plantType = plantType,
                trend = "insufficient_data",
                trendDirection = "unknown",
                trendStrength = 0,
                growthRate = 0,
                dailyStats = dailyStats,
                period = days
            },
            timestamp = os.time()
        }
    end
    
    -- Calcular tendência usando regressão linear
    local n = #dailyStats
    local sumX, sumY, sumXY, sumX2 = 0, 0, 0, 0
    
    for i, stat in ipairs(dailyStats) do
        local x = i
        local y = stat.planted
        sumX = sumX + x
        sumY = sumY + y
        sumXY = sumXY + (x * y)
        sumX2 = sumX2 + (x * x)
    end
    
    local slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX)
    local avgPlanted = sumY / n
    
    local trendPercentage = avgPlanted > 0 and ((slope / avgPlanted) * 100) or 0
    
    -- Classificar tendência
    local trend, trendDirection, trendStrength
    if math.abs(trendPercentage) < 5 then
        trend = "stable"
        trendDirection = "flat"
        trendStrength = math.abs(trendPercentage) / 5
    elseif trendPercentage > 0 then
        trend = "growing"
        trendDirection = "up"
        trendStrength = math.min(trendPercentage / 20, 1.0) -- Max 1.0 para 20%+
    else
        trend = "declining" 
        trendDirection = "down"
        trendStrength = math.min(math.abs(trendPercentage) / 20, 1.0)
    end
    
    -- Calcular estatísticas adicionais
    local totalPlanted = 0
    local totalHarvested = 0
    local totalDestroyed = 0
    
    for _, stat in pairs(dailyStats) do
        totalPlanted = totalPlanted + stat.planted
        totalHarvested = totalHarvested + stat.harvested
        totalDestroyed = totalDestroyed + stat.destroyed
    end
    
    local harvestRate = totalPlanted > 0 and (totalHarvested / totalPlanted) or 0
    local lossRate = totalPlanted > 0 and (totalDestroyed / totalPlanted) or 0
    
    local result = {
        success = true,
        data = {
            plantType = plantType,
            trend = trend,
            trendDirection = trendDirection,
            trendStrength = math.floor(trendStrength * 100) / 100,
            growthRate = math.floor(trendPercentage * 100) / 100,
            avgDaily = math.floor(avgPlanted * 100) / 100,
            period = days,
            statistics = {
                totalPlanted = totalPlanted,
                totalHarvested = totalHarvested,
                totalDestroyed = totalDestroyed,
                harvestRate = math.floor(harvestRate * 100) / 100,
                lossRate = math.floor(lossRate * 100) / 100,
                efficiency = math.floor((harvestRate - lossRate) * 100) / 100
            },
            dailyStats = dailyStats
        },
        timestamp = os.time()
    }
    
    -- Cache por 30 minutos
    if Cache then
        Cache:Set(cacheKey, result, 1800)
    end
    
    return result
end)

-- Obter relatório de mercado completo
exports('GetMarketReport', function()
    local cacheKey = "economy:market_report"
    local cached = nil
    if cached then return cached end
    
    -- Buscar todas as plantas ativas
    local plantTypes = {}
    local success, plants = pcall(function()
        return MySQL.query.await('SELECT DISTINCT plant_type FROM bcc_farming')
    end)
    
    if success and plants then
        for _, plant in pairs(plants) do
            table.insert(plantTypes, plant.plant_type)
        end
    end
    
    local marketData = {}
    local summary = {
        totalMarkets = #plantTypes,
        bullishMarkets = 0,
        bearishMarkets = 0,
        stableMarkets = 0,
        averageScarcity = 0,
        averagePriceMultiplier = 0,
        marketVolatility = Economy.config.volatility
    }
    
    for _, plantType in pairs(plantTypes) do
        local scarcityData = exports['bcc-farming']:GetPlantScarcityIndex(plantType)
        local priceData = exports['bcc-farming']:CalculateDynamicPrice(plantType, 1.0)
        local trendData = exports['bcc-farming']:GetPlantingTrend(plantType, 7)
        
        if scarcityData.success and priceData.success and trendData.success then
            local marketCondition = "neutral"
            if trendData.data.trendDirection == "up" and scarcityData.data.scarcityIndex < 0.4 then
                marketCondition = "bullish"
                summary.bullishMarkets = summary.bullishMarkets + 1
            elseif trendData.data.trendDirection == "down" or scarcityData.data.scarcityIndex > 0.6 then
                marketCondition = "bearish"
                summary.bearishMarkets = summary.bearishMarkets + 1
            else
                summary.stableMarkets = summary.stableMarkets + 1
            end
            
            table.insert(marketData, {
                plantType = plantType,
                scarcityIndex = scarcityData.data.scarcityIndex,
                scarcityClassification = scarcityData.data.classification,
                priceMultiplier = priceData.data.priceMultiplier,
                priceChange = priceData.data.priceChange,
                trend = trendData.data.trend,
                trendStrength = trendData.data.trendStrength,
                marketCondition = marketCondition,
                recommendation = marketCondition == "bullish" and "BUY" or 
                               marketCondition == "bearish" and "SELL" or "HOLD"
            })
            
            summary.averageScarcity = summary.averageScarcity + scarcityData.data.scarcityIndex
            summary.averagePriceMultiplier = summary.averagePriceMultiplier + priceData.data.priceMultiplier
        end
    end
    
    if #marketData > 0 then
        summary.averageScarcity = summary.averageScarcity / #marketData
        summary.averagePriceMultiplier = summary.averagePriceMultiplier / #marketData
    end
    
    -- Classificar por índice de escassez
    table.sort(marketData, function(a, b) return a.scarcityIndex > b.scarcityIndex end)
    
    local result = {
        success = true,
        data = {
            markets = marketData,
            summary = summary,
            recentEvents = Economy.marketEvents,
            lastUpdate = os.time()
        },
        timestamp = os.time()
    }
    
    -- Cache por 15 minutos
    if Cache then
        Cache:Set(cacheKey, result, 900)
    end
    
    return result
end)

-- Event para notificar mudanças de preço
RegisterNetEvent('bcc-farming:NotifyPriceChange')
AddEventHandler('bcc-farming:NotifyPriceChange', function(plantType, priceChange, newMultiplier)
    -- Notificar todos os jogadores online que têm essa planta
    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        if src then
            local playerPlants = exports['bcc-farming']:GetPlayerPlants(src)
            if playerPlants.success then
                local hasPlant = false
                for _, plant in pairs(playerPlants.data) do
                    if plant.plantType == plantType then
                        hasPlant = true
                        break
                    end
                end
                
                if hasPlant then
                    -- Encontrar nome da planta
                    local plantName = plantType
                    for _, plantConfig in pairs(Plants) do
                        if plantConfig.seedName == plantType then
                            plantName = plantConfig.plantName
                            break
                        end
                    end
                    
                    local message = string.format("Preço de %s %s %d%% (×%.2f)", 
                        plantName,
                        priceChange > 0 and "subiu" or "caiu",
                        math.abs(priceChange),
                        newMultiplier
                    )
                    
                    exports['bcc-farming']:NotifyFarmingEvent(src, 'market_change', {
                        plantName = plantName,
                        priceChange = priceChange,
                        multiplier = newMultiplier,
                        message = message
                    })
                end
            end
        end
    end
end)

-- Sistema de atualização automática de preços
CreateThread(function()
    while true do
        Wait(Economy.config.update_interval * 1000)
        
        -- Atualizar configurações
        UpdateEconomyConfig()
        
        -- Atualizar preços de todas as plantas
        local success, plantTypes = pcall(function()
            return MySQL.query.await('SELECT DISTINCT plant_type FROM bcc_farming')
        end)
        
        if success and plantTypes then
            local updated = 0
            for _, plant in pairs(plantTypes) do
                local result = exports['bcc-farming']:CalculateDynamicPrice(plant.plant_type, 1.0)
                if result.success then
                    updated = updated + 1
                end
            end
            
            print(string.format("^2[BCC-Farming Economy]^7 Preços atualizados para %d tipos de plantas", updated))
            
            -- Invalidar cache relacionado à economia
            if Cache then
                Cache:Invalidate("economy:")
            end
        end
        
        Economy.lastUpdate = os.time()
    end
end)

-- Comando para relatório de mercado
RegisterCommand('farming-market', function(source)
    if source ~= 0 then return end -- Apenas console
    
    local report = exports['bcc-farming']:GetMarketReport()
    if report.success then
        print("^3=== BCC-Farming Market Report ===^7")
        print(string.format("Total Markets: %d", report.data.summary.totalMarkets))
        print(string.format("Bullish: %d | Bearish: %d | Stable: %d", 
            report.data.summary.bullishMarkets,
            report.data.summary.bearishMarkets,
            report.data.summary.stableMarkets))
        print(string.format("Average Scarcity: %.2f", report.data.summary.averageScarcity))
        print(string.format("Average Price Multiplier: %.2fx", report.data.summary.averagePriceMultiplier))
        
        print("\n^3Top 5 Most Scarce:^7")
        for i = 1, math.min(5, #report.data.markets) do
            local market = report.data.markets[i]
            print(string.format("  %s: %.2f (%s) - %s", 
                market.plantType, market.scarcityIndex, market.scarcityClassification, market.recommendation))
        end
    end
end)