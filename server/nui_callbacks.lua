-- =======================================
-- BCC-Farming v2.5.0 NUI Server Callbacks
-- Provides plant data for NUI display
-- =======================================

-- =======================================
-- HELPER FUNCTIONS
-- =======================================

local function GetPlantConfigByType(plantType)
    if not Plants then return nil end
    
    for _, plantConfig in pairs(Plants) do
        if plantConfig.seedName == plantType then
            return plantConfig
        end
    end
    return nil
end

local function FormatPlantDataForNUI(plantRow, plantConfig)
    if not plantRow then return nil end
    
    -- Parse coordinates
    local coords = nil
    local parseSuccess, parsedCoords = pcall(function()
        return json.decode(plantRow.plant_coords)
    end)
    
    if parseSuccess then
        coords = parsedCoords
    end
    
    -- Calculate time values
    local timeLeft = tonumber(plantRow.time_left) or 0
    local growthProgress = tonumber(plantRow.growth_progress) or 0
    local growthStage = tonumber(plantRow.growth_stage) or 1
    local waterCount = tonumber(plantRow.water_count) or 0
    local maxWaterTimes = tonumber(plantRow.max_water_times) or 1
    local baseFertilized = plantRow.base_fertilized == 1
    
    -- Get plant configuration info
    local requiresBaseFertilizer = false
    local plantName = plantRow.plant_type
    
    if plantConfig then
        requiresBaseFertilizer = plantConfig.requiresBaseFertilizer or false
        plantName = plantConfig.plantName or plantRow.plant_type
    end
    
    -- Calculate derived values
    local isReady = growthProgress >= 100 and timeLeft <= 0
    local waterEfficiency = maxWaterTimes > 0 and (waterCount / maxWaterTimes) or 0
    
    -- Calculate overall progress from time elapsed
    local totalGrowthTime = plantConfig and plantConfig.timeToGrow or 1200
    local elapsedTime = totalGrowthTime - timeLeft
    local overallProgress = math.min(100, (elapsedTime / totalGrowthTime) * 100)
    
    -- Determine stage name
    local stageName = "Seedling"
    local stageNumber = growthStage
    if growthStage == 3 then
        stageName = "Mature Plant"
    elseif growthStage == 2 then
        stageName = "Young Plant"
    end
    
    return {
        plantId = plantRow.plant_id,
        plantType = plantRow.plant_type,
        seedName = plantRow.plant_type,  -- Alias for compatibility
        plantName = plantName,
        coords = coords,
        timeLeft = timeLeft,
        timeToGrow = totalGrowthTime,
        growthStage = growthStage,
        stageNumber = stageNumber,
        stageName = stageName,
        growthProgress = growthProgress,
        overallProgress = overallProgress,
        waterCount = waterCount,
        maxWaterTimes = maxWaterTimes,
        baseFertilized = baseFertilized,
        requiresBaseFertilizer = requiresBaseFertilizer,
        fertilizerType = plantRow.fertilizer_type,
        isWatered = plantRow.plant_watered == 'true',
        plantOwner = plantRow.plant_owner,
        plantTime = plantRow.plant_time,
        isReady = isReady,
        waterEfficiency = waterEfficiency * 100,
        rewards = plantConfig and plantConfig.rewards or {}
    }
end

-- =======================================
-- NUI CALLBACKS
-- =======================================

-- Get plant data by plant ID
VORPcore.Callback.Register('bcc-farming:GetPlantData', function(source, cb, plantId)
    if not plantId then
        cb({ success = false, error = "Plant ID required" })
        return
    end
    
    local success, result = pcall(function()
        return MySQL.query.await([[
            SELECT 
                plant_id, plant_type, plant_coords, 
                CAST(time_left AS UNSIGNED) as time_left, 
                plant_watered, plant_owner, plant_time,
                growth_stage, growth_progress, water_count, 
                max_water_times, base_fertilized, fertilizer_type
            FROM `bcc_farming` 
            WHERE plant_id = ?
        ]], { plantId })
    end)
    
    if not success or not result or #result == 0 then
        cb({ success = false, error = "Plant not found" })
        return
    end
    
    local plantRow = result[1]
    local plantConfig = GetPlantConfigByType(plantRow.plant_type)
    local formattedData = FormatPlantDataForNUI(plantRow, plantConfig)
    
    cb({ 
        success = true, 
        data = formattedData,
        timestamp = os.time()
    })
end)

-- Get plant data by coordinates (for proximity detection)
VORPcore.Callback.Register('bcc-farming:GetPlantByCoords', function(source, cb, coords)
    if not coords or not coords.x or not coords.y or not coords.z then
        cb({ success = false, error = "Invalid coordinates" })
        return
    end
    
    local success, result = pcall(function()
        return MySQL.query.await([[
            SELECT 
                plant_id, plant_type, plant_coords, 
                CAST(time_left AS UNSIGNED) as time_left, 
                plant_watered, plant_owner, plant_time,
                growth_stage, growth_progress, water_count, 
                max_water_times, base_fertilized, fertilizer_type
            FROM `bcc_farming`
        ]])
    end)
    
    if not success or not result then
        cb({ success = false, error = "Database error" })
        return
    end
    
    -- Find plant with matching coordinates (within small tolerance)
    local tolerance = 1.0  -- 1 meter tolerance
    local matchedPlant = nil
    
    for _, plantRow in pairs(result) do
        local plantCoords = nil
        local parseSuccess, parsedCoords = pcall(function()
            return json.decode(plantRow.plant_coords)
        end)
        
        if parseSuccess and parsedCoords then
            local distance = math.sqrt(
                (coords.x - parsedCoords.x)^2 + 
                (coords.y - parsedCoords.y)^2 + 
                (coords.z - parsedCoords.z)^2
            )
            
            if distance <= tolerance then
                matchedPlant = plantRow
                break
            end
        end
    end
    
    if not matchedPlant then
        cb({ success = false, error = "No plant found at coordinates" })
        return
    end
    
    local plantConfig = GetPlantConfigByType(matchedPlant.plant_type)
    local formattedData = FormatPlantDataForNUI(matchedPlant, plantConfig)
    
    cb({ 
        success = true, 
        data = formattedData,
        timestamp = os.time()
    })
end)

-- Get multiple plants near coordinates
VORPcore.Callback.Register('bcc-farming:GetNearbyPlants', function(source, cb, coords, radius)
    if not coords or not coords.x or not coords.y or not coords.z then
        cb({ success = false, error = "Invalid coordinates" })
        return
    end
    
    radius = radius or 5.0  -- Default 5 meter radius
    
    local success, result = pcall(function()
        return MySQL.query.await([[
            SELECT 
                plant_id, plant_type, plant_coords, 
                CAST(time_left AS UNSIGNED) as time_left, 
                plant_watered, plant_owner, plant_time,
                growth_stage, growth_progress, water_count, 
                max_water_times, base_fertilized, fertilizer_type
            FROM `bcc_farming`
        ]])
    end)
    
    if not success or not result then
        cb({ success = false, error = "Database error" })
        return
    end
    
    -- Find plants within radius
    local nearbyPlants = {}
    
    for _, plantRow in pairs(result) do
        local plantCoords = nil
        local parseSuccess, parsedCoords = pcall(function()
            return json.decode(plantRow.plant_coords)
        end)
        
        if parseSuccess and parsedCoords then
            local distance = math.sqrt(
                (coords.x - parsedCoords.x)^2 + 
                (coords.y - parsedCoords.y)^2 + 
                (coords.z - parsedCoords.z)^2
            )
            
            if distance <= radius then
                local plantConfig = GetPlantConfigByType(plantRow.plant_type)
                local formattedData = FormatPlantDataForNUI(plantRow, plantConfig)
                
                if formattedData then
                    formattedData.distance = distance
                    table.insert(nearbyPlants, formattedData)
                end
            end
        end
    end
    
    -- Sort by distance
    table.sort(nearbyPlants, function(a, b) return a.distance < b.distance end)
    
    cb({ 
        success = true, 
        data = nearbyPlants,
        count = #nearbyPlants,
        searchRadius = radius,
        timestamp = os.time()
    })
end)

-- =======================================
-- UTILITY CALLBACKS FOR TESTING
-- =======================================

-- Get all plants for a player (for testing)
VORPcore.Callback.Register('bcc-farming:GetPlayerPlantsForNUI', function(source, cb, playerId)
    playerId = playerId or source
    
    local user = VORPcore.getUser(playerId)
    if not user then
        cb({ success = false, error = "Player not found" })
        return
    end
    
    local character = user.getUsedCharacter
    if not character then
        cb({ success = false, error = "Character not found" })
        return
    end
    
    local charId = character.charIdentifier
    
    local success, result = pcall(function()
        return MySQL.query.await([[
            SELECT 
                plant_id, plant_type, plant_coords, 
                CAST(time_left AS UNSIGNED) as time_left, 
                plant_watered, plant_owner, plant_time,
                growth_stage, growth_progress, water_count, 
                max_water_times, base_fertilized, fertilizer_type
            FROM `bcc_farming` 
            WHERE plant_owner = ?
            ORDER BY plant_time DESC
        ]], { charId })
    end)
    
    if not success or not result then
        cb({ success = false, error = "Database error" })
        return
    end
    
    local formattedPlants = {}
    for _, plantRow in pairs(result) do
        local plantConfig = GetPlantConfigByType(plantRow.plant_type)
        local formattedData = FormatPlantDataForNUI(plantRow, plantConfig)
        
        if formattedData then
            table.insert(formattedPlants, formattedData)
        end
    end
    
    cb({ 
        success = true, 
        data = formattedPlants,
        count = #formattedPlants,
        timestamp = os.time()
    })
end)

print("^2[BCC-Farming]^7 NUI server callbacks loaded!")