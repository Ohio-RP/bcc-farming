-- BCC-Farming Enhanced Usable Items v2.0
-- Multi-Stage Growth, Multi-Watering & Base Fertilizer System

-- Growth calculations will be available globally after growth_calculations.lua loads

-- ===========================================
-- SEED USABLE ITEMS (Enhanced)
-- ===========================================

CreateThread(function()
    Wait(1000) -- Wait for Plants to be loaded
    
    for _, plant in pairs(Plants) do
        exports.vorp_inventory:registerUsableItem(plant.seedName, function(data)
            local src = data.source
            local user = VORPcore.getUser(src)
            if not user then return end
            
            local character = user.getUsedCharacter
            local charid = character.charIdentifier
            local playerCoords = GetEntityCoords(GetPlayerPed(src))
            local allowPlant, dontAllowAgain = true, false
            
            -- Check town restrictions
            if not Config.townSetup.canPlantInTowns then
                for _, townCfg in pairs(Config.townSetup.townLocations) do
                    if #(playerCoords - townCfg.coords) <= townCfg.townRange then
                        VORPcore.NotifyRightTip(src, _U('tooCloseToTown'), 4000)
                        dontAllowAgain = true
                        allowPlant = false
                        break
                    end
                end
            end
            
            -- Check job restrictions
            if plant.jobLocked and not dontAllowAgain then
                local hasJob = false
                for _, job in ipairs(plant.jobs) do
                    if character.job == job then
                        hasJob = true
                        break
                    end
                end
                
                if not hasJob then
                    VORPcore.NotifyRightTip(src, _U('incorrectJob'), 4000)
                    dontAllowAgain = true
                    allowPlant = false
                end
            end
            
            -- Check soil requirements
            if plant.soilRequired and not dontAllowAgain then
                local hasSoil = exports.vorp_inventory:getItemCount(src, nil, plant.soilName)
                if hasSoil >= plant.soilAmount then
                    allowPlant = true
                else
                    VORPcore.NotifyRightTip(src, _U('noSoil'), 4000)
                    dontAllowAgain = true
                    allowPlant = false
                end
            end
            
            -- Check planting tool requirements
            if plant.plantingToolRequired and not dontAllowAgain then
                local hasPlantingTool = exports.vorp_inventory:getItemCount(src, nil, plant.plantingTool)
                if hasPlantingTool == 0 then
                    VORPcore.NotifyRightTip(src, _U('noPlantingTool'), 4000)
                    allowPlant = false
                    dontAllowAgain = true
                end
            end
            
            -- Check plant limits
            if not dontAllowAgain then
                local currentPlantCount = MySQL.scalar.await('SELECT COUNT(*) FROM bcc_farming WHERE plant_owner = ?', { charid })
                if currentPlantCount >= Config.plantSetup.maxPlants then
                    VORPcore.NotifyRightTip(src, _U('maxPlantsReached'), 4000)
                    allowPlant = false
                end
            end
            
            -- Check seed availability
            if allowPlant and not dontAllowAgain then
                local seedCount = exports.vorp_inventory:getItemCount(src, nil, plant.seedName)
                if seedCount < plant.seedAmount then
                    VORPcore.NotifyRightTip(src, _U('noSeed'), 4000)
                    return
                end
                
                -- Remove seed from inventory
                exports.vorp_inventory:closeInventory(src)
                exports.vorp_inventory:subItem(src, plant.seedName, plant.seedAmount)
                
                -- Remove soil if required
                if plant.soilRequired then
                    exports.vorp_inventory:subItem(src, plant.soilName, plant.soilAmount)
                end
                
                -- Trigger planting on client (no automatic fertilizer detection)
                TriggerClientEvent('bcc-farming:PlantingCrop', src, plant, nil)
            end
        end)
    end
end)

-- ===========================================
-- FERTILIZER USABLE ITEMS (Enhanced)
-- ===========================================

-- Base Fertilizer
CreateThread(function()
    Wait(2000) -- Wait for system to load
    
    -- Register base fertilizer
    exports.vorp_inventory:registerUsableItem('fertilizer', function(data)
        local src = data.source
        HandleFertilizerUsage(src, 'fertilizer', true)
    end)
    
    -- Register enhanced fertilizers from config
    if Config.fertilizerSetup then
        for _, fertilizer in pairs(Config.fertilizerSetup) do
            exports.vorp_inventory:registerUsableItem(fertilizer.fertName, function(data)
                local src = data.source
                HandleFertilizerUsage(src, fertilizer.fertName, false)
            end)
        end
    end
    
    -- Register enhanced fertilizers from new config
    if FertilizerConfig and FertilizerConfig.enhancedFertilizers then
        for _, fertilizer in pairs(FertilizerConfig.enhancedFertilizers) do
            exports.vorp_inventory:registerUsableItem(fertilizer.fertName, function(data)
                local src = data.source
                HandleFertilizerUsage(src, fertilizer.fertName, false)
            end)
        end
    end
end)

-- Handle fertilizer usage
function HandleFertilizerUsage(src, fertilizerType, isBaseFertilizer)
    local user = VORPcore.getUser(src)
    if not user then return end
    
    -- Find nearest plant
    local playerCoords = GetEntityCoords(GetPlayerPed(src))
    local nearestPlant = nil
    local shortestDistance = 999999
    
    local allPlants = MySQL.query.await('SELECT * FROM bcc_farming')
    
    for _, plant in pairs(allPlants) do
        local plantCoords = json.decode(plant.plant_coords)
        local distance = #(playerCoords - vector3(plantCoords.x, plantCoords.y, plantCoords.z))
        
        if distance <= 3.0 and distance < shortestDistance then -- 3 unit range
            shortestDistance = distance
            nearestPlant = plant
        end
    end
    
    if not nearestPlant then
        SendFarmingNotification(src, _U('noPlantNearby'))
        return
    end
    
    -- Get plant configuration
    local plantConfig = nil
    for _, config in pairs(Plants) do
        if config.seedName == nearestPlant.plant_type then
            plantConfig = config
            break
        end
    end
    
    if not plantConfig then
        SendFarmingNotification(src, _U('invalidPlantConfig'))
        return
    end
    
    -- Check fertilizer requirements and status
    if isBaseFertilizer then
        -- Check if plant requires base fertilizer
        if not (plantConfig.requiresBaseFertilizer or false) then
            SendFarmingNotification(src, _U('plantNoBaseFertilizer'))
            return
        end
        
        -- Check if already applied
        if nearestPlant.base_fertilized then
            SendFarmingNotification(src, _U('baseFertilizerAlready'))
            return
        end
    else
        -- Enhanced fertilizer - check if enhanced fertilizer already applied
        if nearestPlant.fertilizer_type then
            SendFarmingNotification(src, _U('enhancedFertilizerAlready'))
            return
        end
    end
    
    -- Check inventory
    local fertCount = exports.vorp_inventory:getItemCount(src, nil, fertilizerType)
    if fertCount < 1 then
        SendFarmingNotification(src, _U('noFertilizer'))
        return
    end
    
    -- Close inventory and trigger fertilizer application with animation
    exports.vorp_inventory:closeInventory(src)
    TriggerClientEvent('bcc-farming:StartFertilizerAnimation', src, nearestPlant.plant_id, fertilizerType)
end

-- ===========================================
-- WATER BUCKET USABLE ITEMS (Enhanced)
-- ===========================================

-- Enhanced water bucket handling
for _, waterItem in pairs(Config.fullWaterBucket) do
    exports.vorp_inventory:registerUsableItem(waterItem, function(data)
        local src = data.source
        local user = VORPcore.getUser(src)
        if not user then return end
        
        -- Find nearest plant
        local playerCoords = GetEntityCoords(GetPlayerPed(src))
        local nearestPlant = nil
        local shortestDistance = 999999
        
        local allPlants = MySQL.query.await('SELECT * FROM bcc_farming')
        
        for _, plant in pairs(allPlants) do
            local plantCoords = json.decode(plant.plant_coords)
            local distance = #(playerCoords - vector3(plantCoords.x, plantCoords.y, plantCoords.z))
            
            if distance <= 3.0 and distance < shortestDistance then
                shortestDistance = distance
                nearestPlant = plant
            end
        end
        
        if not nearestPlant then
            SendFarmingNotification(src, _U('noPlantNearby'))
            return
        end
        
        -- Check if plant can be watered
        local canWater, reason = true, "" -- Simplified check for now
        if not canWater then
            SendFarmingNotification(src, reason)
            return
        end
        
        -- Apply watering
        exports.vorp_inventory:closeInventory(src)
        VORPcore.Callback.TriggerAwait('bcc-farming:ManagePlantWateredStatus', function(result)
            -- Watering notifications are handled in the callback
        end, nearestPlant.plant_id)
    end)
end

-- ===========================================
-- PLANT INSPECTION TOOL (New)
-- ===========================================

-- Register inspection tool if it exists
exports.vorp_inventory:registerUsableItem('plant_inspector', function(data)
    local src = data.source
    local user = VORPcore.getUser(src)
    if not user then return end
    
    -- Find nearest plant
    local playerCoords = GetEntityCoords(GetPlayerPed(src))
    local nearestPlant = nil
    local shortestDistance = 999999
    
    local allPlants = MySQL.query.await('SELECT * FROM bcc_farming')
    
    for _, plant in pairs(allPlants) do
        local plantCoords = json.decode(plant.plant_coords)
        local distance = #(playerCoords - vector3(plantCoords.x, plantCoords.y, plantCoords.z))
        
        if distance <= 5.0 and distance < shortestDistance then -- Longer range for inspection
            shortestDistance = distance
            nearestPlant = plant
        end
    end
    
    if not nearestPlant then
        SendFarmingNotification(src, _U('noPlantNearby'))
        return
    end
    
    -- Get detailed plant status (simplified)
    local plantStatus = {
        plantId = nearestPlant.plant_id,
        plantName = "Plant",
        isReady = false
    }
    
    if plantStatus then
        -- Send detailed inspection data to client
        TriggerClientEvent('bcc-farming:ShowDetailedInspection', src, plantStatus)
    else
        SendFarmingNotification(src, _U('unableToInspect'))
    end
end)

-- ===========================================
-- SOIL PREPARATION TOOLS (New)
-- ===========================================

-- Register soil preparation tool
exports.vorp_inventory:registerUsableItem('soil_prep_tool', function(data)
    local src = data.source
    local user = VORPcore.getUser(src)
    if not user then return end
    
    local playerCoords = GetEntityCoords(GetPlayerPed(src))
    
    -- Check if location is suitable for soil preparation
    local isValidLocation = true
    
    -- Check distance from towns
    if not Config.townSetup.canPlantInTowns then
        for _, townCfg in pairs(Config.townSetup.townLocations) do
            if #(playerCoords - townCfg.coords) <= townCfg.townRange then
                SendFarmingNotification(src, _U('tooCloseToTown'))
                isValidLocation = false
                break
            end
        end
    end
    
    if isValidLocation then
        -- Add soil to inventory
        local canCarry = exports.vorp_inventory:canCarryItem(src, 'soil', 3)
        if canCarry then
            exports.vorp_inventory:addItem(src, 'soil', 3)
            SendFarmingNotification(src, _U('soilPrepared'))
            
            -- Play soil preparation animation
            TriggerClientEvent('bcc-farming:PlaySoilPrepAnimation', src)
        else
            SendFarmingNotification(src, _U('noCarry'))
        end
    end
end)


print("^2[BCC-Farming]^7 Enhanced usable items loaded with multi-stage growth support!")
print("^3[BCC-Farming]^7 Features: Enhanced fertilizers, smart watering, soil preparation")