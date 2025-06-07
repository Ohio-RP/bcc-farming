-- =======================================
-- BCC-Farming v2.5.0 NUI Integration System
-- Plant Status Display with Proximity Detection
-- =======================================

local NUIActive = false
local NearbyPlants = {}
local CurrentPlant = nil
local ProximityRange = 3.0  -- Distance to show NUI
local UpdateInterval = 1000  -- 1 second

-- =======================================
-- NUI MANAGEMENT FUNCTIONS
-- =======================================

local function ShowPlantNUI(plantData)
    if not plantData then return end
    
    -- Calculate growth percentage within current stage
    local stageProgress = 0
    if plantData.growthStage == 1 then
        stageProgress = (plantData.growthProgress / 30) * 100
    elseif plantData.growthStage == 2 then
        stageProgress = ((plantData.growthProgress - 30) / 30) * 100
    elseif plantData.growthStage == 3 then
        stageProgress = ((plantData.growthProgress - 60) / 40) * 100
    end
    
    -- Calculate watering efficiency
    local waterEfficiency = 0
    if plantData.maxWaterTimes and plantData.maxWaterTimes > 0 then
        waterEfficiency = (plantData.waterCount / plantData.maxWaterTimes) * 100
    end
    
    -- Determine if ready for harvest
    local isReady = plantData.growthProgress >= 100 and plantData.timeLeft <= 0
    
    -- Stage names
    local stageNames = {
        [1] = "Seedling",
        [2] = "Young Plant", 
        [3] = "Mature Plant"
    }
    
    -- Send data to NUI
    SendNUIMessage({
        action = "showPlantStatus",
        plantData = {
            plantName = plantData.plantName or "Unknown Plant",
            plantType = plantData.plantType or plantData.seedName or "unknown",
            stageName = stageNames[plantData.growthStage] or "Unknown",
            stageNumber = plantData.growthStage or 1,
            stageProgress = math.floor(stageProgress),
            overallProgress = math.floor(plantData.growthProgress or 0),
            waterCount = plantData.waterCount or 0,
            maxWaterTimes = plantData.maxWaterTimes or 1,
            waterEfficiency = math.floor(waterEfficiency),
            baseFertilized = plantData.baseFertilized or false,
            requiresBaseFertilizer = plantData.requiresBaseFertilizer or false,
            timeLeft = plantData.timeLeft or 0,
            timeToGrow = plantData.timeToGrow or 1200,
            isReady = isReady,
            fertilizerType = plantData.fertilizerType,
            rewards = plantData.rewards or {}
        }
    })
    
    SetNuiFocus(false, false)
    NUIActive = true
end

local function HidePlantNUI()
    if not NUIActive then return end
    
    SendNUIMessage({
        action = "hidePlantStatus"
    })
    
    SetNuiFocus(false, false)
    NUIActive = false
    CurrentPlant = nil
end

-- =======================================
-- PLANT DETECTION SYSTEM
-- =======================================

local function GetNearbyPlantData(plantId)
    -- Request plant data from server
    local promise = promise.new()
    
    VORPcore.Callback.TriggerAsync('bcc-farming:GetPlantData', function(result)
        promise:resolve(result)
    end, plantId)
    
    return Citizen.Await(promise)
end

local function FindNearbyPlants()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local foundPlants = {}
    
    -- Check for plants using configured props
    if Plants then
        for _, plantConfig in pairs(Plants) do
            local propsToCheck = {}
            
            -- Add single prop if exists
            if plantConfig.plantProp then
                table.insert(propsToCheck, plantConfig.plantProp)
            end
            
            -- Add multi-stage props if exists
            if plantConfig.plantProps then
                if plantConfig.plantProps.stage1 then table.insert(propsToCheck, plantConfig.plantProps.stage1) end
                if plantConfig.plantProps.stage2 then table.insert(propsToCheck, plantConfig.plantProps.stage2) end
                if plantConfig.plantProps.stage3 then table.insert(propsToCheck, plantConfig.plantProps.stage3) end
            end
            
            -- Check each prop type
            for _, propName in pairs(propsToCheck) do
                local plantObject = GetClosestObjectOfType(playerCoords.x, playerCoords.y, playerCoords.z, ProximityRange, joaat(propName), false, false, false)
                
                if plantObject and plantObject ~= 0 then
                    local plantCoords = GetEntityCoords(plantObject)
                    local distance = #(playerCoords - plantCoords)
                    
                    if distance <= ProximityRange then
                        table.insert(foundPlants, {
                            object = plantObject,
                            coords = plantCoords,
                            distance = distance,
                            propName = propName,
                            plantConfig = plantConfig
                        })
                    end
                end
            end
        end
    end
    
    return foundPlants
end

-- =======================================
-- MAIN PROXIMITY LOOP
-- =======================================

CreateThread(function()
    while true do
        Wait(UpdateInterval)
        
        local nearbyPlants = FindNearbyPlants()
        
        if #nearbyPlants > 0 then
            -- Find closest plant
            local closestPlant = nil
            local closestDistance = ProximityRange + 1
            
            for _, plant in pairs(nearbyPlants) do
                if plant.distance < closestDistance then
                    closestDistance = plant.distance
                    closestPlant = plant
                end
            end
            
            if closestPlant then
                -- If this is a new plant or we don't have NUI active
                if not CurrentPlant or not NUIActive then
                    -- Try to get plant data from server
                    local plantCoords = closestPlant.coords
                    
                    VORPcore.Callback.TriggerAsync('bcc-farming:GetPlantByCoords', function(plantData)
                        if plantData and plantData.success then
                            -- Store complete plant data including database plantId
                            CurrentPlant = {
                                object = closestPlant.object,
                                coords = closestPlant.coords,
                                distance = closestPlant.distance,
                                propName = closestPlant.propName,
                                plantConfig = closestPlant.plantConfig,
                                plantId = plantData.data.plantId,  -- Add missing plantId from server
                                plantData = plantData.data  -- Store complete plant data
                            }
                            
                            print(string.format("^6[BCC-Farming NUI Debug]^7 Plant ID %d detected, showing NUI", plantData.data.plantId))
                            ShowPlantNUI(plantData.data)
                        else
                            print("^3[BCC-Farming NUI Debug]^7 Failed to get plant data from server")
                        end
                    end, plantCoords)
                end
            end
        else
            -- No plants nearby, hide NUI
            if NUIActive then
                HidePlantNUI()
            end
        end
    end
end)

-- =======================================
-- NUI CALLBACKS
-- =======================================

RegisterNUICallback('closePlantStatus', function(data, cb)
    HidePlantNUI()
    cb('ok')
end)

-- =======================================
-- COMMANDS FOR TESTING
-- =======================================

RegisterCommand('test-plant-nui', function()
    -- Test NUI with dummy data
    local testData = {
        plantName = "Árvore de Maçã",
        plantType = "apple_seed",
        stageName = "Young Plant",
        stageNumber = 2,
        stageProgress = 75,
        overallProgress = 55,
        waterCount = 1,
        maxWaterTimes = 3,
        waterEfficiency = 33,
        baseFertilized = true,
        requiresBaseFertilizer = true,
        timeLeft = 1200,
        timeToGrow = 1800,
        isReady = false,
        fertilizerType = "Fertilizante Básico",
        rewards = {
            { itemName = "apple", itemLabel = "Maçã", amount = 3 },
            { itemName = "apple_seed", itemLabel = "Semente de Maçã", amount = 1 }
        }
    }
    
    SendNUIMessage({
        action = "showPlantStatus",
        plantData = testData
    })
    
    NUIActive = true
    print("^2[BCC-Farming]^7 Test NUI displayed!")
end, false)

RegisterCommand('hide-plant-nui', function()
    HidePlantNUI()
    print("^2[BCC-Farming]^7 Plant NUI hidden!")
end, false)

RegisterCommand('debug-current-plant', function()
    if CurrentPlant then
        print("^3=== CurrentPlant Debug Info ===^7")
        print(string.format("plantId: %s", tostring(CurrentPlant.plantId)))
        print(string.format("coords: X=%.2f, Y=%.2f, Z=%.2f", CurrentPlant.coords.x, CurrentPlant.coords.y, CurrentPlant.coords.z))
        print(string.format("propName: %s", tostring(CurrentPlant.propName)))
        print(string.format("distance: %.2f", CurrentPlant.distance or 0))
        print(string.format("NUIActive: %s", tostring(NUIActive)))
        if CurrentPlant.plantData then
            print(string.format("plantData.plantName: %s", tostring(CurrentPlant.plantData.plantName)))
            print(string.format("plantData.growthStage: %s", tostring(CurrentPlant.plantData.growthStage)))
        else
            print("plantData: nil")
        end
    else
        print("^1[Debug]^7 CurrentPlant is nil")
    end
end, false)

-- =======================================
-- EVENTS
-- =======================================

RegisterNetEvent('bcc-farming:RefreshNUI', function()
    if CurrentPlant and NUIActive and CurrentPlant.plantId then
        -- Refresh current plant data
        local plantCoords = CurrentPlant.coords
        VORPcore.Callback.TriggerAsync('bcc-farming:GetPlantByCoords', function(plantData)
            if plantData and plantData.success then
                -- Update stored plant data
                CurrentPlant.plantData = plantData.data
                ShowPlantNUI(plantData.data)
                print(string.format("^6[BCC-Farming NUI Debug]^7 Refreshed NUI for plant %d", plantData.data.plantId))
            else
                print("^3[BCC-Farming NUI Debug]^7 Failed to refresh plant data")
            end
        end, plantCoords)
    else
        print("^3[BCC-Farming NUI Debug]^7 Cannot refresh NUI - missing CurrentPlant or plantId")
    end
end)

-- Listen for stage updates and refresh NUI if showing this plant
RegisterNetEvent('bcc-farming:UpdatePlantStageData', function(plantId, newStage, growthProgress)
    if CurrentPlant and NUIActive and CurrentPlant.plantId then
        -- Check if this is the plant we're currently viewing
        local currentPlantId = CurrentPlant.plantId
        if currentPlantId == plantId then
            -- Update NUI with new stage data
            print(string.format("^6[BCC-Farming NUI]^7 Updating displayed plant %d to stage %d", plantId, newStage))
            
            -- Refresh the NUI data
            TriggerEvent('bcc-farming:RefreshNUI')
        end
    else
        if CurrentPlant and NUIActive and not CurrentPlant.plantId then
            print("^3[BCC-Farming NUI Debug]^7 CurrentPlant missing plantId, cannot update stage data")
        end
    end
end)

-- Listen for watering updates and refresh NUI
RegisterNetEvent('bcc-farming:UpdateClientPlantWateredStatus', function(plantId, newWaterCount, maxWaterTimes, isFullyWatered)
    if CurrentPlant and NUIActive and CurrentPlant.plantId then
        local currentPlantId = CurrentPlant.plantId
        if currentPlantId == plantId then
            print(string.format("^6[BCC-Farming NUI]^7 Updating watering status for plant %d (%d/%d)", plantId, newWaterCount, maxWaterTimes))
            TriggerEvent('bcc-farming:RefreshNUI')
        end
    else
        if CurrentPlant and NUIActive and not CurrentPlant.plantId then
            print("^3[BCC-Farming NUI Debug]^7 CurrentPlant missing plantId, cannot update watering status")
        end
    end
end)

print("^2[BCC-Farming]^7 NUI Integration system loaded!")
print("^2[BCC-Farming]^7 Commands: /test-plant-nui, /hide-plant-nui, /debug-current-plant")