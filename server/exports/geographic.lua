-- server/exports/geographic.lua
-- FASE 1 - Dia 6-10: Sistema de Coordenadas e Análises Geográficas

-- Função helper para calcular distância entre duas coordenadas
local function CalculateDistance(coord1, coord2)
    if not coord1 or not coord2 then return 999999 end
    if not coord1.x or not coord1.y or not coord1.z or not coord2.x or not coord2.y or not coord2.z then
        return 999999
    end
    
    local x = coord1.x - coord2.x
    local y = coord1.y - coord2.y
    local z = coord1.z - coord2.z
    return math.sqrt(x*x + y*y + z*z)
end

-- Export para obter plantas em um raio específico
exports('GetPlantsInRadius', function(coords, radius)
    if not coords or not coords.x or not coords.y or not coords.z then
        return { 
            success = false, 
            error = "Invalid coordinates. Expected {x, y, z}", 
            timestamp = os.time() 
        }
    end
    
    radius = radius or 1000 -- Default 1km
    
    local success, allPlants = pcall(function()
        return MySQL.query.await('SELECT * FROM `bcc_farming`')
    end)
    
    if not success then
        return { 
            success = false, 
            error = "Database error", 
            timestamp = os.time() 
        }
    end
    
    local plantsInRadius = {}
    
    if allPlants then
        for _, plant in pairs(allPlants) do
            local parseSuccess, plantCoords = pcall(function()
                return json.decode(plant.plant_coords)
            end)
            
            if parseSuccess and plantCoords then
                local distance = CalculateDistance(coords, plantCoords)
                
                if distance <= radius then
                    table.insert(plantsInRadius, {
                        plantId = plant.plant_id,
                        plantType = plant.plant_type,
                        coords = plantCoords,
                        distance = math.floor(distance * 100) / 100, -- 2 casas decimais
                        timeLeft = tonumber(plant.time_left) or 0,
                        watered = plant.plant_watered == 'true',
                        owner = plant.plant_owner,
                        plantedAt = plant.plant_time,
                        status = (tonumber(plant.time_left) or 0) <= 0 and plant.plant_watered == 'true' and "ready" or
                                plant.plant_watered == 'false' and "needs_water" or "growing"
                    })
                end
            end
        end
    end
    
    -- Ordenar por distância
    table.sort(plantsInRadius, function(a, b) return a.distance < b.distance end)
    
    return { 
        success = true, 
        data = plantsInRadius, 
        searchCenter = coords,
        searchRadius = radius,
        totalFound = #plantsInRadius,
        timestamp = os.time() 
    }
end)

-- Export para calcular densidade de plantas em uma área
exports('GetPlantDensity', function(coords, radius)
    local plantsData = exports['bcc-farming']:GetPlantsInRadius(coords, radius)
    if not plantsData.success then
        return plantsData
    end
    
    local areaKm2 = (math.pi * (radius/1000)^2) -- Área em km²
    local plantCount = #plantsData.data
    local density = areaKm2 > 0 and (plantCount / areaKm2) or 0
    
    -- Classificar densidade
    local classification = "Unknown"
    if density >= 50 then
        classification = "Very High"
    elseif density >= 20 then
        classification = "High"
    elseif density >= 10 then
        classification = "Medium"
    elseif density >= 5 then
        classification = "Low"
    else
        classification = "Very Low"
    end
    
    return {
        success = true,
        data = {
            plantsCount = plantCount,
            areaKm2 = math.floor(areaKm2 * 1000) / 1000, -- 3 casas decimais
            areaM2 = math.floor(math.pi * radius^2),
            density = math.floor(density * 100) / 100, -- 2 casas decimais
            densityPerKm2 = density,
            classification = classification,
            searchRadius = radius
        },
        searchCenter = coords,
        timestamp = os.time()
    }
end)

-- Export para encontrar o tipo de planta dominante em uma área
exports('GetDominantPlantInArea', function(coords, radius)
    -- Validate inputs
    if type(coords) ~= "table" or type(radius) ~= "number" or radius < 0 then
        return {
            success = false,
            data = { message = "Invalid coordinates or radius" },
            timestamp = os.time()
        }
    end

    -- Call external function to get plants
    local plantsData = exports['bcc-farming']:GetPlantsInRadius(coords, radius)
    if not plantsData or not plantsData.success then
        return plantsData or {
            success = false,
            data = { message = "Failed to retrieve plants data" },
            timestamp = os.time()
        }
    end

    -- Check if no plants found
    if #plantsData.data == 0 then
        return {
            success = true,
            data = {
                dominantPlant = nil,
                message = "No plants found in area"
            },
            timestamp = os.time()
        }
    end

    local plantCounts = {}
    local statusCounts = {}

    -- Count plant types and statuses
    for _, plant in ipairs(plantsData.data) do
        plantCounts[plant.plantType] = (plantCounts[plant.plantType] or 0) + 1
        statusCounts[plant.status] = (statusCounts[plant.status] or 0) + 1
    end

    -- Find dominant plant
    local dominantPlant = nil
    local maxCount = 0
    for plantType, count in pairs(plantCounts) do
        if count > maxCount then
            maxCount = count
            dominantPlant = plantType
        end
    end

    -- Map seedName to plantName (assuming Plants is a global table)
    local dominantPlantName = dominantPlant
    if Plants then
        for _, plantConfig in pairs(Plants) do
            if plantConfig.seedName == dominantPlant then
                dominantPlantName = plantConfig.plantName
                break
            end
        end
    end

    -- Calculate metrics
    local totalPlants = #plantsData.data
    local dominantPercentage = totalPlants > 0 and math.floor((maxCount / totalPlants) * 100) or 0

    -- Calculate diversity
    local typeCount = 0
    for _ in pairs(plantCounts) do
        typeCount = typeCount + 1
    end

    return {
        success = true,
        data = {
            dominantPlant = dominantPlant and {
                type = dominantPlant,
                name = dominantPlantName,
                count = maxCount,
                percentage = dominantPercentage
            } or nil,
            diversity = {
                totalTypes = typeCount,
                allTypes = plantCounts,
                isDiverse = typeCount >= 3
            },
            status = {
                ready = statusCounts.ready or statusCounts.Ready or 0,
                growing = statusCounts.growing or statusCounts.Growing or 0,
                needsWater = statusCounts.needs_water or statusCounts.NeedsWater or 0
            },
            totalPlants = totalPlants,
            area = {
                center = coords,
                radius = radius
            }
        },
        timestamp = os.time()
    }
end)

-- Export para validar se uma localização é válida para plantio
exports('IsValidPlantLocation', function(coords, plantType)
    if not coords or not coords.x or not coords.y or not coords.z then
        return { 
            success = false, 
            error = "Invalid coordinates", 
            timestamp = os.time() 
        }
    end
    
    -- Verificar distância de outras plantas
    local nearbyPlants = exports['bcc-farming']:GetPlantsInRadius(coords, 2.0)
    if not nearbyPlants.success then
        return {
            success = false,
            error = "Failed to check nearby plants",
            timestamp = os.time()
        }
    end
    
    if #nearbyPlants.data > 0 then
        return { 
            success = true, 
            data = { 
                isValid = false, 
                reason = "distance", 
                message = "Too close to another plant",
                nearbyCount = #nearbyPlants.data,
                closestDistance = nearbyPlants.data[1] and nearbyPlants.data[1].distance or 0
            },
            timestamp = os.time()
        }
    end
    
    -- Verificar distância de cidades (usar config existente)
    for _, townCfg in pairs(Config.townSetup.townLocations) do
        local distance = CalculateDistance(coords, townCfg.coords)
        if distance <= townCfg.townRange and not Config.townSetup.canPlantInTowns then
            return { 
                success = true, 
                data = { 
                    isValid = false, 
                    reason = "town", 
                    message = "Too close to town",
                    distance = math.floor(distance * 100) / 100,
                    townRange = townCfg.townRange,
                    townCoords = townCfg.coords
                },
                timestamp = os.time()
            }
        end
    end
    
    -- Verificar se o tipo de planta existe na configuração
    local plantExists = false
    if plantType then
        for _, plantConfig in pairs(Plants) do
            if plantConfig.seedName == plantType then
                plantExists = true
                break
            end
        end
    end
    
    return { 
        success = true, 
        data = { 
            isValid = true, 
            reason = "valid_location",
            message = "Location is valid for planting",
            plantTypeValid = plantType and plantExists or true
        },
        timestamp = os.time() 
    }
end)

-- Export para encontrar as melhores áreas para plantio
exports('FindBestPlantingAreas', function(centerCoords, searchRadius, maxResults)
    centerCoords = centerCoords or {x = 0, y = 0, z = 0}
    searchRadius = searchRadius or 5000 -- 5km default
    maxResults = maxResults or 10
    
    local gridSize = 500 -- Verificar a cada 500 metros
    local bestAreas = {}
    
    -- Criar uma grade de pontos para verificar
    local halfRadius = searchRadius / 2
    local steps = math.floor(searchRadius / gridSize)
    
    for x = -steps, steps do
        for y = -steps, steps do
            local testCoords = {
                x = centerCoords.x + (x * gridSize),
                y = centerCoords.y + (y * gridSize),
                z = centerCoords.z
            }
            
            -- Verificar se está dentro do raio de busca
            local distanceFromCenter = CalculateDistance(centerCoords, testCoords)
            if distanceFromCenter <= searchRadius then
                
                local validLocation = exports['bcc-farming']:IsValidPlantLocation(testCoords)
                if validLocation.success and validLocation.data.isValid then
                    
                    -- Verificar densidade da área ao redor
                    local density = exports['bcc-farming']:GetPlantDensity(testCoords, 200) -- 200m radius
                    
                    if density.success then
                        table.insert(bestAreas, {
                            coords = testCoords,
                            distanceFromSearch = math.floor(distanceFromCenter),
                            density = density.data.density,
                            classification = density.data.classification,
                            nearbyPlants = density.data.plantsCount,
                            score = math.max(0, 100 - density.data.density - (distanceFromCenter / 100))
                        })
                    end
                end
            end
        end
    end
    
    -- Ordenar por score (melhor primeiro)
    table.sort(bestAreas, function(a, b) return a.score > b.score end)
    
    -- Limitar resultados
    if #bestAreas > maxResults then
        local limitedAreas = {}
        for i = 1, maxResults do
            table.insert(limitedAreas, bestAreas[i])
        end
        bestAreas = limitedAreas
    end
    
    return {
        success = true,
        data = bestAreas,
        searchParameters = {
            center = centerCoords,
            radius = searchRadius,
            gridSize = gridSize,
            maxResults = maxResults,
            totalChecked = math.pow(steps * 2 + 1, 2),
            validFound = #bestAreas
        },
        timestamp = os.time()
    }
end)

-- Export para análise de concentração de plantas por tipo
exports('GetPlantConcentrationMap', function(coords, radius, gridSize)
    radius = radius or 2000 -- 2km default
    gridSize = gridSize or 250 -- 250m grid
    
    local plantsInArea = exports['bcc-farming']:GetPlantsInRadius(coords, radius)
    if not plantsInArea.success then
        return plantsInArea
    end
    
    local concentrationMap = {}
    local steps = math.floor(radius / gridSize)
    
    -- Criar grade de concentração
    for x = -steps, steps do
        for y = -steps, steps do
            local gridCoords = {
                x = coords.x + (x * gridSize),
                y = coords.y + (y * gridSize),
                z = coords.z
            }
            
            local gridId = string.format("%d_%d", x, y)
            concentrationMap[gridId] = {
                coords = gridCoords,
                gridX = x,
                gridY = y,
                plantCount = 0,
                plantTypes = {},
                distanceFromCenter = CalculateDistance(coords, gridCoords)
            }
        end
    end
    
    -- Mapear plantas para a grade
    for _, plant in pairs(plantsInArea.data) do
        local gridX = math.floor((plant.coords.x - coords.x) / gridSize)
        local gridY = math.floor((plant.coords.y - coords.y) / gridSize)
        local gridId = string.format("%d_%d", gridX, gridY)
        
        if concentrationMap[gridId] then
            concentrationMap[gridId].plantCount = concentrationMap[gridId].plantCount + 1
            concentrationMap[gridId].plantTypes[plant.plantType] = 
                (concentrationMap[gridId].plantTypes[plant.plantType] or 0) + 1
        end
    end
    
    -- Converter para array e encontrar hotspots
    local gridArray = {}
    local maxConcentration = 0
    
    for _, grid in pairs(concentrationMap) do
        if grid.plantCount > 0 then
            table.insert(gridArray, grid)
            if grid.plantCount > maxConcentration then
                maxConcentration = grid.plantCount
            end
        end
    end
    
    -- Ordenar por concentração
    table.sort(gridArray, function(a, b) return a.plantCount > b.plantCount end)
    
    return {
        success = true,
        data = {
            concentrationGrid = gridArray,
            hotspots = #gridArray > 0 and {gridArray[1], gridArray[2], gridArray[3]} or {},
            statistics = {
                maxConcentration = maxConcentration,
                totalGridsWithPlants = #gridArray,
                avgPlantsPerGrid = #gridArray > 0 and 
                    (function()
                        local total = 0
                        for _, grid in pairs(gridArray) do
                            total = total + grid.plantCount
                        end
                        return math.floor((total / #gridArray) * 100) / 100
                    end)() or 0
            }
        },
        parameters = {
            center = coords,
            radius = radius,
            gridSize = gridSize,
            totalGrids = (steps * 2 + 1)^2
        },
        timestamp = os.time()
    }
end)