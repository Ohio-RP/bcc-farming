-- BCC-Farming Enhanced Prop Management System v2.0
-- Multi-Stage Growth Prop System

local PropManager = {}

-- Store all plant props and their data
local PlantProps = {}
local PlantData = {}

-- ===========================================
-- PROP MANAGEMENT FUNCTIONS
-- ===========================================

-- Get the appropriate prop for plant stage
function PropManager.GetStageProp(plantConfig, stage)
    if not plantConfig.plantProps then
        -- Fallback to old system
        return plantConfig.plantProp or 'p_plant_generic_01'
    end
    
    local stageKey = 'stage' .. (stage or 1)
    return plantConfig.plantProps[stageKey] or plantConfig.plantProps.stage1 or plantConfig.plantProp or 'p_plant_generic_01'
end

-- Create plant prop at specific stage with enhanced ground placement
function PropManager.CreatePlantProp(plantId, plantConfig, coords, stage, offset)
    stage = stage or 1
    offset = offset or plantConfig.plantOffset or 0
    
    -- Get the prop for this stage
    local propName = PropManager.GetStageProp(plantConfig, stage)
    
    -- Enhanced ground Z calculation for RedM
    local finalZ = coords.z + offset
    
    -- Try multiple ground detection methods for better accuracy
    local hit, groundZ, groundNormal = GetGroundZAndNormalFor_3dCoord(coords.x, coords.y, coords.z + 20.0)
    if hit and groundZ then
        finalZ = groundZ + offset
        print(string.format("^6[BCC-Farming]^7 Ground detected at Z: %.2f for plant %d", groundZ, plantId))
    else
        -- Fallback: Use raycast to find ground
        local rayHandle = StartShapeTestRay(coords.x, coords.y, coords.z + 10.0, coords.x, coords.y, coords.z - 10.0, 1, 0, 0)
        local retval, hit2, endCoords, surfaceNormal, entityHit = GetShapeTestResult(rayHandle)
        
        if hit2 and endCoords then
            finalZ = endCoords.z + offset
            print(string.format("^6[BCC-Farming]^7 Raycast ground found at Z: %.2f for plant %d", endCoords.z, plantId))
        else
            -- Final fallback: Lower the original coords slightly
            finalZ = coords.z - 0.5 + offset
            print(string.format("^3[BCC-Farming]^7 Using fallback Z: %.2f for plant %d", finalZ, plantId))
        end
    end
    
    -- Load the model
    local propHash = GetHashKey(propName)
    RequestModel(propHash)
    
    local attempts = 0
    while not HasModelLoaded(propHash) and attempts < 100 do
        Wait(10)
        attempts = attempts + 1
    end
    
    if not HasModelLoaded(propHash) then
        print("^1[BCC-Farming]^7 Failed to load model: " .. propName)
        -- Fallback to a basic prop
        propHash = GetHashKey('p_plant_generic_01')
        RequestModel(propHash)
        local fallbackAttempts = 0
        while not HasModelLoaded(propHash) and fallbackAttempts < 50 do
            Wait(10)
            fallbackAttempts = fallbackAttempts + 1
        end
    end
    
    -- Create the prop
    local prop = CreateObject(propHash, coords.x, coords.y, finalZ, false, false, false)
    
    if prop and DoesEntityExist(prop) then
        -- Set prop properties for ground placement
        SetEntityAsMissionEntity(prop, true, true)
        FreezeEntityPosition(prop, true)
        SetEntityCollision(prop, false, false)
        
        -- Additional ground placement verification
        PlaceObjectOnGroundProperly(prop)
        
        -- Wait a frame for physics to settle
        Wait(0)
        
        -- Get final position after ground placement
        local finalPosition = GetEntityCoords(prop)
        
        -- Store prop reference with actual final coordinates
        PlantProps[plantId] = {
            entity = prop,
            stage = stage,
            propName = propName,
            coords = {x = finalPosition.x, y = finalPosition.y, z = finalPosition.z},
            plantConfig = plantConfig,
            networkId = NetworkGetNetworkIdFromEntity(prop) -- Store network ID for better tracking
        }
        
        print(string.format("^2[BCC-Farming]^7 Created plant %d prop '%s' at Z: %.2f (stage %d)", plantId, propName, finalPosition.z, stage))
        
        SetModelAsNoLongerNeeded(propHash)
        return prop
    else
        print("^1[BCC-Farming]^7 Failed to create prop: " .. propName)
        SetModelAsNoLongerNeeded(propHash)
        return nil
    end
end

-- Update plant prop to new stage with enhanced cleanup
function PropManager.UpdatePlantStage(plantId, newStage, plantConfig)
    local currentProp = PlantProps[plantId]
    if not currentProp then
        print("^3[BCC-Farming]^7 No prop found for plant ID: " .. plantId)
        return false
    end
    
    -- Check if stage actually changed
    if currentProp.stage == newStage then
        return true -- No change needed
    end
    
    local coords = currentProp.coords
    local offset = plantConfig.plantOffset or 0
    
    -- Get new prop name for the stage
    local newPropName = PropManager.GetStageProp(plantConfig, newStage)
    
    -- Check if prop actually changes
    local currentPropName = currentProp.propName
    if newPropName == currentPropName then
        -- Just update stage info, no visual change
        PlantProps[plantId].stage = newStage
        return true
    end
    
    -- Enhanced old prop cleanup with multiple deletion attempts
    if DoesEntityExist(currentProp.entity) then
        local entityToDelete = currentProp.entity
        local networkId = currentProp.networkId
        
        print(string.format("^3[BCC-Farming]^7 Removing old prop for plant %d (Stage %d -> %d)", plantId, currentProp.stage, newStage))
        
        -- Method 1: Standard deletion
        SetEntityAsMissionEntity(entityToDelete, false, true)
        DeleteEntity(entityToDelete)
        
        -- Wait for deletion to process
        Wait(100)
        
        -- Method 2: Force deletion if still exists
        if DoesEntityExist(entityToDelete) then
            print(string.format("^3[BCC-Farming]^7 Prop %d still exists, attempting force deletion", plantId))
            DeleteObject(entityToDelete)
            Wait(50)
        end
        
        -- Method 3: Network deletion if we have network ID
        if networkId and DoesEntityExist(entityToDelete) then
            print(string.format("^3[BCC-Farming]^7 Attempting network deletion for prop %d", plantId))
            local netEntity = NetworkGetEntityFromNetworkId(networkId)
            if netEntity and DoesEntityExist(netEntity) then
                SetEntityAsMissionEntity(netEntity, false, true)
                DeleteEntity(netEntity)
                Wait(50)
            end
        end
        
        -- Final verification
        if DoesEntityExist(entityToDelete) then
            print(string.format("^1[BCC-Farming]^7 Warning: Old prop %d still exists after all deletion attempts", plantId))
        else
            print(string.format("^2[BCC-Farming]^7 Old prop for plant %d successfully removed", plantId))
        end
    end
    
    -- Clear old prop data before creating new one
    PlantProps[plantId] = nil
    
    -- Wait additional frame for cleanup
    Wait(0)
    
    -- Create new prop with enhanced ground placement
    local newProp = PropManager.CreatePlantProp(plantId, plantConfig, coords, newStage, offset)
    
    if newProp then
        print(string.format("^2[BCC-Farming]^7 Plant %d transitioned from stage %d to %d (%s -> %s)", 
            plantId, currentProp.stage, newStage, currentPropName, newPropName))
        return true
    else
        print("^1[BCC-Farming]^7 Failed to update plant stage for ID: " .. plantId)
        return false
    end
end

-- Remove plant prop with enhanced cleanup
function PropManager.RemovePlantProp(plantId)
    local prop = PlantProps[plantId]
    if prop then
        if DoesEntityExist(prop.entity) then
            local entityToDelete = prop.entity
            local networkId = prop.networkId
            
            print(string.format("^3[BCC-Farming]^7 Removing plant prop %d completely", plantId))
            
            -- Method 1: Standard deletion
            SetEntityAsMissionEntity(entityToDelete, false, true)
            DeleteEntity(entityToDelete)
            
            -- Wait for deletion to process
            Wait(100)
            
            -- Method 2: Force deletion if still exists
            if DoesEntityExist(entityToDelete) then
                print(string.format("^3[BCC-Farming]^7 Plant prop %d still exists, attempting force deletion", plantId))
                DeleteObject(entityToDelete)
                Wait(50)
            end
            
            -- Method 3: Network deletion if we have network ID
            if networkId and DoesEntityExist(entityToDelete) then
                print(string.format("^3[BCC-Farming]^7 Attempting network deletion for plant prop %d", plantId))
                local netEntity = NetworkGetEntityFromNetworkId(networkId)
                if netEntity and DoesEntityExist(netEntity) then
                    SetEntityAsMissionEntity(netEntity, false, true)
                    DeleteEntity(netEntity)
                    Wait(50)
                end
            end
            
            -- Final verification
            if DoesEntityExist(entityToDelete) then
                print(string.format("^1[BCC-Farming]^7 Warning: Plant prop %d still exists after all deletion attempts", plantId))
            else
                print(string.format("^2[BCC-Farming]^7 Plant prop %d successfully removed", plantId))
            end
        end
        
        -- Clear all data for this plant
        PlantProps[plantId] = nil
        PlantData[plantId] = nil
        
        -- Wait additional frame for cleanup
        Wait(0)
        
        return true
    end
    
    print(string.format("^3[BCC-Farming]^7 No prop found to remove for plant %d", plantId))
    return false
end

-- Get plant prop entity
function PropManager.GetPlantProp(plantId)
    local prop = PlantProps[plantId]
    return prop and prop.entity or nil
end

-- Get plant prop data
function PropManager.GetPlantPropData(plantId)
    return PlantProps[plantId]
end

-- Check if plant prop exists
function PropManager.PlantPropExists(plantId)
    local prop = PlantProps[plantId]
    return prop and DoesEntityExist(prop.entity) or false
end

-- Update plant data (for NUI and status tracking)
function PropManager.UpdatePlantData(plantId, data)
    PlantData[plantId] = data
end

-- Get plant data
function PropManager.GetPlantData(plantId)
    return PlantData[plantId]
end

-- ===========================================
-- PLANT INTERACTION FUNCTIONS
-- ===========================================

-- Get nearest plant to player
function PropManager.GetNearestPlant(maxDistance)
    maxDistance = maxDistance or 3.0
    local playerCoords = GetEntityCoords(PlayerPedId())
    local closestPlant = nil
    local closestDistance = maxDistance
    
    for plantId, propData in pairs(PlantProps) do
        if DoesEntityExist(propData.entity) then
            local distance = #(playerCoords - vector3(propData.coords.x, propData.coords.y, propData.coords.z))
            
            if distance < closestDistance then
                closestDistance = distance
                closestPlant = {
                    plantId = plantId,
                    distance = distance,
                    coords = propData.coords,
                    stage = propData.stage,
                    propData = propData,
                    plantData = PlantData[plantId]
                }
            end
        end
    end
    
    return closestPlant
end

-- Get all plants within radius
function PropManager.GetPlantsInRadius(centerCoords, radius)
    local plantsInRadius = {}
    
    for plantId, propData in pairs(PlantProps) do
        if DoesEntityExist(propData.entity) then
            local distance = #(centerCoords - vector3(propData.coords.x, propData.coords.y, propData.coords.z))
            
            if distance <= radius then
                table.insert(plantsInRadius, {
                    plantId = plantId,
                    distance = distance,
                    coords = propData.coords,
                    stage = propData.stage,
                    propData = propData,
                    plantData = PlantData[plantId]
                })
            end
        end
    end
    
    -- Sort by distance
    table.sort(plantsInRadius, function(a, b) return a.distance < b.distance end)
    
    return plantsInRadius
end

-- ===========================================
-- VISUAL EFFECTS FUNCTIONS
-- ===========================================

-- Add growth effect when stage transitions
function PropManager.PlayGrowthEffect(plantId)
    local prop = PlantProps[plantId]
    if not prop or not DoesEntityExist(prop.entity) then return end
    
    local coords = prop.coords
    
    -- Play particle effect (if available)
    -- RequestNamedPtfxAsset("core")
    -- while not HasNamedPtfxAssetLoaded("core") do Wait(10) end
    -- UseParticleFxAssetNextCall("core")
    -- StartParticleFxNonLoopedAtCoord("ent_sht_steam", coords.x, coords.y, coords.z + 0.5, 0.0, 0.0, 0.0, 0.3, false, false, false)
    
    -- Play simple growth feedback (no sound in RedM due to native limitations)
    print(string.format("^2[BCC-Farming]^7 🌱 Plant %d grew! New stage active.", plantId))
end

-- Add watering effect
function PropManager.PlayWateringEffect(plantId)
    local prop = PlantProps[plantId]
    if not prop or not DoesEntityExist(prop.entity) then return end
    
    local coords = prop.coords
    
    -- Play simple watering feedback (no sound in RedM due to native limitations)
    print(string.format("^6[BCC-Farming]^7 💧 Plant %d watered! Growth progress continues.", plantId))
end

-- ===========================================
-- MAINTENANCE FUNCTIONS
-- ===========================================

-- Clean up invalid props with enhanced verification
function PropManager.CleanupInvalidProps()
    local cleaned = 0
    local propsToRemove = {}
    
    -- First pass: identify invalid props
    for plantId, propData in pairs(PlantProps) do
        if not propData or not propData.entity or not DoesEntityExist(propData.entity) then
            table.insert(propsToRemove, plantId)
            cleaned = cleaned + 1
        end
    end
    
    -- Second pass: clean up invalid props
    for _, plantId in pairs(propsToRemove) do
        local propData = PlantProps[plantId]
        if propData and propData.entity then
            -- Try to force delete if entity still exists
            if DoesEntityExist(propData.entity) then
                SetEntityAsMissionEntity(propData.entity, false, true)
                DeleteEntity(propData.entity)
                
                -- Also try network deletion if available
                if propData.networkId then
                    local netEntity = NetworkGetEntityFromNetworkId(propData.networkId)
                    if netEntity and DoesEntityExist(netEntity) then
                        SetEntityAsMissionEntity(netEntity, false, true)
                        DeleteEntity(netEntity)
                    end
                end
            end
        end
        
        -- Clear references
        PlantProps[plantId] = nil
        PlantData[plantId] = nil
    end
    
    if cleaned > 0 then
        print(string.format("^3[BCC-Farming]^7 Cleaned up %d invalid props", cleaned))
    end
    
    return cleaned
end

-- Get prop statistics
function PropManager.GetPropStats()
    local stats = {
        totalProps = 0,
        propsByStage = {stage1 = 0, stage2 = 0, stage3 = 0},
        validProps = 0,
        invalidProps = 0
    }
    
    for plantId, propData in pairs(PlantProps) do
        stats.totalProps = stats.totalProps + 1
        
        if DoesEntityExist(propData.entity) then
            stats.validProps = stats.validProps + 1
            local stageKey = 'stage' .. (propData.stage or 1)
            stats.propsByStage[stageKey] = stats.propsByStage[stageKey] + 1
        else
            stats.invalidProps = stats.invalidProps + 1
        end
    end
    
    return stats
end

-- ===========================================
-- EVENT HANDLERS
-- ===========================================

-- Handle plant planted event
RegisterNetEvent('bcc-farming:PlantPlanted')
AddEventHandler('bcc-farming:PlantPlanted', function(plantId, plantConfig, plantCoords, timeLeft, watered, source)
    if not plantId or not plantConfig or not plantCoords then return end
    
    local stage = 1 -- New plants always start at stage 1
    
    -- Create comprehensive plant data for storage
    local plantData = {
        plantId = plantId,
        plantConfig = plantConfig,
        plantCoords = plantCoords,
        timeLeft = timeLeft,
        watered = watered,
        growthStage = stage,
        growthProgress = 0
    }
    
    -- Store plant data
    PropManager.UpdatePlantData(plantId, plantData)
    
    -- Create prop for the plant
    local prop = PropManager.CreatePlantProp(plantId, plantConfig, plantCoords, stage)
    
    if prop then
        print(string.format("^2[BCC-Farming]^7 Plant %d created at stage %d", plantId, stage))
    else
        print(string.format("^1[BCC-Farming]^7 Failed to create plant %d", plantId))
    end
end)

-- Handle plant stage update (legacy format with table)
RegisterNetEvent('bcc-farming:UpdatePlantStage')
AddEventHandler('bcc-farming:UpdatePlantStage', function(updateData)
    if not updateData or not updateData.plantId then return end
    
    local plantId = updateData.plantId
    local newStage = updateData.newStage
    local plantData = PlantData[plantId]
    
    if plantData and plantData.plantConfig then
        local success = PropManager.UpdatePlantStage(plantId, newStage, plantData.plantConfig)
        
        if success then
            -- Update stored data
            if plantData then
                plantData.growthStage = newStage
                plantData.growthProgress = updateData.progress
            end
            
            -- Play growth effect
            PropManager.PlayGrowthEffect(plantId)
        end
    end
end)

-- Handle plant stage data update (server format with individual parameters)
RegisterNetEvent('bcc-farming:UpdatePlantStageData')
AddEventHandler('bcc-farming:UpdatePlantStageData', function(plantId, newStage, growthProgress)
    if not plantId or not newStage then return end
    
    local plantData = PlantData[plantId]
    
    if plantData and plantData.plantConfig then
        local success = PropManager.UpdatePlantStage(plantId, newStage, plantData.plantConfig)
        
        if success then
            -- Update stored data
            plantData.growthStage = newStage
            plantData.growthProgress = growthProgress or 0
            
            print(string.format("^6[BCC-Farming PropManager]^7 Plant %d updated to stage %d (%.1f%% progress)", 
                plantId, newStage, growthProgress or 0))
            
            -- Play growth effect
            PropManager.PlayGrowthEffect(plantId)
        end
    else
        print(string.format("^3[BCC-Farming PropManager]^7 No plant data found for plant %d (stage update)", plantId))
    end
end)

-- Handle plant removal
RegisterNetEvent('bcc-farming:RemovePlantClient')
AddEventHandler('bcc-farming:RemovePlantClient', function(plantId)
    PropManager.RemovePlantProp(plantId)
end)

-- Handle watering status update
RegisterNetEvent('bcc-farming:UpdateClientPlantWateredStatus')
AddEventHandler('bcc-farming:UpdateClientPlantWateredStatus', function(plantId, waterCount, maxWaterTimes, isFullyWatered)
    if plantId then
        local plantData = PlantData[plantId]
        if plantData then
            -- Update plant water data
            plantData.waterCount = waterCount or 0
            plantData.maxWaterTimes = maxWaterTimes or 1
            plantData.watered = (waterCount and waterCount > 0) or isFullyWatered or false
        end
        
        -- Play watering effect
        PropManager.PlayWateringEffect(plantId)
    end
end)

-- Handle fertilizer update
RegisterNetEvent('bcc-farming:UpdatePlantFertilizer')
AddEventHandler('bcc-farming:UpdatePlantFertilizer', function(updateData)
    if not updateData or not updateData.plantId then return end
    
    local plantData = PlantData[updateData.plantId]
    if plantData then
        if updateData.isBaseFertilizer then
            plantData.baseFertilized = true
        end
        plantData.fertilizerType = updateData.fertilizerType
        plantData.timeReduction = updateData.timeReduction
    end
end)

-- ===========================================
-- CLEANUP THREAD
-- ===========================================

CreateThread(function()
    while true do
        Wait(30000) -- Every 30 seconds
        PropManager.CleanupInvalidProps()
    end
end)

-- Force ground placement for all props
function PropManager.ForceGroundPlacement()
    local fixed = 0
    
    for plantId, propData in pairs(PlantProps) do
        if propData and DoesEntityExist(propData.entity) then
            local entity = propData.entity
            
            -- Get current position
            local currentPos = GetEntityCoords(entity)
            
            -- Try to place on ground
            PlaceObjectOnGroundProperly(entity)
            
            -- Wait for physics
            Wait(50)
            
            -- Get new position and update stored coords
            local newPos = GetEntityCoords(entity)
            propData.coords = {x = newPos.x, y = newPos.y, z = newPos.z}
            
            if math.abs(currentPos.z - newPos.z) > 0.1 then
                fixed = fixed + 1
                print(string.format("^2[BCC-Farming]^7 Fixed ground placement for plant %d (Z: %.2f -> %.2f)", 
                    plantId, currentPos.z, newPos.z))
            end
        end
    end
    
    if fixed > 0 then
        print(string.format("^2[BCC-Farming]^7 Fixed ground placement for %d props", fixed))
    else
        print("^3[BCC-Farming]^7 All props already properly placed")
    end
    
    return fixed
end

-- ===========================================
-- DEBUG COMMANDS
-- ===========================================

RegisterCommand('farming-props-debug', function()
    local stats = PropManager.GetPropStats()
    print("^3=== BCC-Farming Prop Statistics ===^7")
    print(string.format("Total Props: %d", stats.totalProps))
    print(string.format("Valid Props: %d", stats.validProps))
    print(string.format("Invalid Props: %d", stats.invalidProps))
    print(string.format("Stage 1: %d | Stage 2: %d | Stage 3: %d", 
        stats.propsByStage.stage1, stats.propsByStage.stage2, stats.propsByStage.stage3))
    
    local nearest = PropManager.GetNearestPlant(10.0)
    if nearest then
        print(string.format("Nearest Plant: ID %d, Stage %d, Distance %.2fm, Z: %.2f", 
            nearest.plantId, nearest.stage, nearest.distance, nearest.coords.z))
    else
        print("No plants nearby")
    end
end)

-- Force ground placement for all props
RegisterCommand('farming-fix-ground', function()
    PropManager.ForceGroundPlacement()
end)

-- Clean up all props and force recreation
RegisterCommand('farming-reset-props', function()
    local cleaned = PropManager.CleanupInvalidProps()
    print(string.format("^2[BCC-Farming]^7 Reset completed: %d props cleaned", cleaned))
end)

-- ===========================================
-- GLOBAL ACCESS
-- ===========================================

-- Make PropManager globally accessible
_G.PropManager = PropManager

-- Export the module for require() usage
return PropManager