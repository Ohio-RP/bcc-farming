-- BCC-Farming Enhanced Server Main v2.0
-- Multi-Stage Growth, Multi-Watering & Base Fertilizer System

VORPcore = exports.vorp_core:GetCore()
BccUtils = exports['bcc-utils'].initiate()

-- Load the growth calculations module
local GrowthCalculations = require('server.services.growth_calculations')

local AllPlants = {} -- AllPlants will contain all the plants in the server

-- ===========================================
-- HELPER FUNCTIONS
-- ===========================================

local function CheckPlayerJob(src)
    local character = VORPcore.getUser(src).getUsedCharacter
    local playerJob = character.job
    for _, job in ipairs(Config.PoliceJobs) do
        if (playerJob == job) then
            return true
        end
    end
    return false
end

-- Get plant configuration by seed name
local function GetPlantConfig(seedName)
    for _, plantConfig in pairs(Plants) do
        if plantConfig.seedName == seedName then
            return plantConfig
        end
    end
    return nil
end

-- Validate if player can plant
local function CanPlayerPlant(src, plantConfig)
    local user = VORPcore.getUser(src)
    if not user then return false, "User not found" end
    
    local character = user.getUsedCharacter
    if not character then return false, "Character not found" end
    
    -- Check job restrictions
    if plantConfig.jobLocked and plantConfig.jobs then
        local hasJob = false
        for _, job in pairs(plantConfig.jobs) do
            if character.job == job then
                hasJob = true
                break
            end
        end
        if not hasJob then
            return false, "Job not allowed"
        end
    end
    
    -- Check plant limit
    local plantCount = MySQL.scalar.await('SELECT COUNT(*) FROM bcc_farming WHERE plant_owner = ?', { character.charIdentifier })
    if plantCount >= Config.plantSetup.maxPlants then
        return false, "Plant limit reached"
    end
    
    return true, "Can plant"
end

-- ===========================================
-- ENHANCED PLANT PLANTING SYSTEM
-- ===========================================

RegisterServerEvent('bcc-farming:AddPlant', function(plantData, plantCoords)
    local src = source
    local user = VORPcore.getUser(src)
    if not user then return end
    local character = user.getUsedCharacter
    
    -- Validate plant configuration
    local plantConfig = GetPlantConfig(plantData.seedName)
    if not plantConfig then
        VORPcore.NotifyRightTip(src, "Invalid plant type", 4000)
        return
    end
    
    -- Check if player can plant
    local canPlant, reason = CanPlayerPlant(src, plantConfig)
    if not canPlant then
        VORPcore.NotifyRightTip(src, reason, 4000)
        return
    end
    
    -- Calculate initial values for new system
    local timeToGrow = plantData.timeToGrow
    local waterTimes = plantConfig.waterTimes or 1
    local requiresBaseFertilizer = plantConfig.requiresBaseFertilizer or false
    
    -- Insert plant with enhanced data
    local plantId = MySQL.insert.await([[
        INSERT INTO `bcc_farming` (
            plant_coords, plant_type, plant_watered, time_left, plant_owner,
            growth_stage, growth_progress, water_count, max_water_times,
            base_fertilized, total_growth_time
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], { 
        json.encode(plantCoords), 
        plantData.seedName, 
        'false', 
        timeToGrow, 
        character.charIdentifier,
        1, -- Start at stage 1
        0.0, -- 0% progress
        0, -- No waterings yet
        waterTimes,
        false, -- Not fertilized
        timeToGrow -- Store original time
    })
    
    if plantId then
        -- Trigger plant planted event to clients
        local clientData = {
            plantId = plantId,
            plantData = plantData,
            plantCoords = plantCoords,
            timeToGrow = timeToGrow,
            watered = false,
            plantConfig = plantConfig,
            -- Enhanced data
            growthStage = 1,
            growthProgress = 0.0,
            waterCount = 0,
            maxWaterTimes = waterTimes,
            requiresBaseFertilizer = requiresBaseFertilizer
        }
        
        if Config.plantSetup.lockedToPlanter then
            TriggerClientEvent('bcc-farming:PlantPlanted', src, clientData)
        else
            TriggerClientEvent('bcc-farming:PlantPlanted', -1, clientData)
        end
        
        -- Log planting action
        if plantConfig.webhooked then
            -- Add webhook logic here if needed
        end
        
        VORPcore.NotifyRightTip(src, "Plant successfully planted!", 4000)
    else
        VORPcore.NotifyRightTip(src, "Failed to plant seed", 4000)
    end
end)

-- ===========================================
-- ENHANCED WATERING SYSTEM
-- ===========================================

VORPcore.Callback.Register('bcc-farming:ManagePlantWateredStatus', function(source, cb, plantId)
    local src = source
    local user = VORPcore.getUser(src)
    if not user then return cb({success = false, message = "User not found"}) end
    
    -- Get current plant data
    local plantData = MySQL.query.await('SELECT * FROM bcc_farming WHERE plant_id = ?', { plantId })
    if not plantData or #plantData == 0 then
        return cb({success = false, message = "Plant not found"})
    end
    
    local plant = plantData[1]
    
    -- Check if plant can be watered
    local canWater, reason = GrowthCalculations.CanWaterPlant(plant)
    if not canWater then
        VORPcore.NotifyRightTip(src, reason, 4000)
        return cb({success = false, message = reason})
    end
    
    -- Check for water bucket
    local fullWaterBucket = Config.fullWaterBucket
    local hasWater = false
    local usedWaterType = nil
    
    for _, item in ipairs(fullWaterBucket) do
        local itemCount = exports.vorp_inventory:getItemCount(src, nil, item)
        if itemCount >= 1 then
            exports.vorp_inventory:subItem(src, item, 1)
            exports.vorp_inventory:addItem(src, Config.emptyWaterBucket, 1)
            hasWater = true
            usedWaterType = item
            break
        end
    end
    
    if not hasWater then
        return cb({success = false, message = "No water available"})
    end
    
    -- Update plant watering status
    local newWaterCount = (plant.water_count or 0) + 1
    local currentTime = os.time()
    
    MySQL.execute.await([[
        UPDATE `bcc_farming` 
        SET water_count = ?, last_watered = FROM_UNIXTIME(?)
        WHERE plant_id = ?
    ]], { newWaterCount, currentTime, plantId })
    
    -- Log watering action
    MySQL.insert.await([[
        INSERT INTO bcc_farming_watering_log (plant_id, player_id, watered_at, water_type, growth_progress_at_time)
        VALUES (?, ?, FROM_UNIXTIME(?), ?, ?)
    ]], { plantId, src, currentTime, usedWaterType, plant.growth_progress or 0 })
    
    -- Update plant growth and check for stage transition
    GrowthCalculations.UpdatePlantGrowth(plantId)
    
    -- Notify clients of watering
    TriggerClientEvent('bcc-farming:UpdateClientPlantWateredStatus', -1, {
        plantId = plantId,
        waterCount = newWaterCount,
        maxWaterTimes = plant.max_water_times or 1
    })
    
    -- Notify player
    local wateringEfficiency = math.floor((newWaterCount / (plant.max_water_times or 1)) * 100)
    VORPcore.NotifyRightTip(src, string.format("Plant watered! (%d/%d - %d%%)", 
        newWaterCount, plant.max_water_times or 1, wateringEfficiency), 4000)
    
    return cb({
        success = true, 
        message = "Plant watered successfully",
        waterCount = newWaterCount,
        maxWaterTimes = plant.max_water_times or 1,
        efficiency = wateringEfficiency
    })
end)

-- ===========================================
-- ENHANCED FERTILIZER SYSTEM
-- ===========================================

RegisterServerEvent('bcc-farming:ApplyFertilizer', function(plantId, fertilizerType)
    local src = source
    local user = VORPcore.getUser(src)
    if not user then return end
    
    -- Get plant data
    local plantData = MySQL.query.await('SELECT * FROM bcc_farming WHERE plant_id = ?', { plantId })
    if not plantData or #plantData == 0 then
        VORPcore.NotifyRightTip(src, "Plant not found", 4000)
        return
    end
    
    local plant = plantData[1]
    local plantConfig = GetPlantConfig(plant.plant_type)
    if not plantConfig then
        VORPcore.NotifyRightTip(src, "Invalid plant configuration", 4000)
        return
    end
    
    -- Check fertilizer inventory
    local fertCount = exports.vorp_inventory:getItemCount(src, nil, fertilizerType)
    if fertCount < 1 then
        VORPcore.NotifyRightTip(src, "You don't have this fertilizer", 4000)
        return
    end
    
    -- Determine fertilizer type and effects
    local isBaseFertilizer = (fertilizerType == (plantConfig.baseFertilizerItem or 'fertilizer'))
    local timeReduction = GrowthCalculations.CalculateTimeReduction(fertilizerType)
    
    -- Check if base fertilizer is already applied
    if isBaseFertilizer and plant.base_fertilized then
        VORPcore.NotifyRightTip(src, "Base fertilizer already applied", 4000)
        return
    end
    
    -- Apply fertilizer
    exports.vorp_inventory:subItem(src, fertilizerType, 1)
    
    local currentTime = os.time()
    local newTimeLeft = plant.time_left
    
    if timeReduction > 0 then
        -- Apply time reduction for enhanced fertilizers
        newTimeLeft = math.floor(plant.time_left * (1 - timeReduction))
    end
    
    -- Update database
    if isBaseFertilizer then
        MySQL.execute.await([[
            UPDATE bcc_farming 
            SET base_fertilized = true, fertilized_at = FROM_UNIXTIME(?), time_left = ?
            WHERE plant_id = ?
        ]], { currentTime, newTimeLeft, plantId })
    else
        MySQL.execute.await([[
            UPDATE bcc_farming 
            SET fertilizer_type = ?, fertilizer_reduction = ?, time_left = ?
            WHERE plant_id = ?
        ]], { fertilizerType, timeReduction, newTimeLeft, plantId })
    end
    
    -- Log fertilizer application
    MySQL.insert.await([[
        INSERT INTO bcc_farming_fertilizer_log (plant_id, player_id, fertilizer_type, reduction_amount, applied_at, growth_progress_at_time)
        VALUES (?, ?, ?, ?, FROM_UNIXTIME(?), ?)
    ]], { plantId, src, fertilizerType, timeReduction, currentTime, plant.growth_progress or 0 })
    
    -- Update plant growth
    GrowthCalculations.UpdatePlantGrowth(plantId)
    
    -- Notify player
    if isBaseFertilizer then
        VORPcore.NotifyRightTip(src, "Base fertilizer applied! Plant will reach full potential.", 5000)
    else
        VORPcore.NotifyRightTip(src, string.format("Enhanced fertilizer applied! Growth time reduced by %d%%", 
            math.floor(timeReduction * 100)), 5000)
    end
    
    -- Notify clients
    TriggerClientEvent('bcc-farming:UpdatePlantFertilizer', -1, {
        plantId = plantId,
        fertilizerType = fertilizerType,
        isBaseFertilizer = isBaseFertilizer,
        timeReduction = timeReduction
    })
end)

-- ===========================================
-- ENHANCED HARVESTING SYSTEM
-- ===========================================

VORPcore.Callback.Register('bcc-farming:HarvestCheck', function(source, cb, plantId, destroy)
    local src = source
    local user = VORPcore.getUser(src)
    if not user then return cb({success = false, message = "User not found"}) end
    
    -- Get plant data
    local plantData = MySQL.query.await('SELECT * FROM bcc_farming WHERE plant_id = ?', { plantId })
    if not plantData or #plantData == 0 then
        return cb({success = false, message = "Plant not found"})
    end
    
    local plant = plantData[1]
    local plantConfig = GetPlantConfig(plant.plant_type)
    if not plantConfig then
        return cb({success = false, message = "Invalid plant configuration"})
    end
    
    -- Check if plant is ready
    local isReady = plant.growth_progress >= 100 or (tonumber(plant.time_left) <= 0 and plant.water_count > 0)
    if not isReady and not destroy then
        return cb({success = false, message = "Plant is not ready for harvest"})
    end
    
    if not destroy then
        -- Calculate final reward based on care quality
        local finalReward = GrowthCalculations.CalculateFinalReward(plantConfig, plant)
        local rewardBreakdown = GrowthCalculations.GetRewardBreakdown(plantConfig, plant)
        
        -- Check inventory space for all rewards
        local itemsToAdd = {}
        for _, reward in pairs(plantConfig.rewards) do
            local scaledAmount = math.floor((reward.amount / plantConfig.rewards[1].amount) * finalReward)
            if scaledAmount > 0 then
                local canCarry = exports.vorp_inventory:canCarryItem(src, reward.itemName, scaledAmount)
                if canCarry then
                    table.insert(itemsToAdd, { 
                        itemName = reward.itemName, 
                        itemLabel = reward.itemLabel, 
                        amount = scaledAmount 
                    })
                else
                    VORPcore.NotifyRightTip(src, "Cannot carry " .. reward.itemLabel, 4000)
                    return cb({success = false, message = "Inventory full"})
                end
            end
        end
        
        -- Add items to inventory
        for _, item in ipairs(itemsToAdd) do
            exports.vorp_inventory:addItem(src, item.itemName, item.amount)
            VORPcore.NotifyRightTip(src, string.format("Harvested %d %s", item.amount, item.itemLabel), 4000)
        end
        
        -- Show reward breakdown
        VORPcore.NotifyRightTip(src, string.format(
            "Harvest Summary: %d%% watering, %d%% fertilizer bonus = %d total items",
            rewardBreakdown.wateringEfficiency,
            rewardBreakdown.fertilizerMultiplier,
            finalReward
        ), 7000)
    end
    
    -- Remove plant from database
    MySQL.execute.await('DELETE FROM bcc_farming WHERE plant_id = ?', { plantId })
    
    -- Update client
    TriggerClientEvent('bcc-farming:MaxPlantsAmount', src, -1)
    TriggerClientEvent('bcc-farming:RemovePlantClient', -1, plantId)
    
    return cb({success = true, message = "Plant harvested successfully"})
end)

-- ===========================================
-- PLANT STATUS REQUEST SYSTEM
-- ===========================================

RegisterServerEvent('bcc-farming:RequestPlantStatus', function(plantId)
    local src = source
    local plantStatus = GrowthCalculations.GetPlantStatus(plantId)
    
    if plantStatus then
        TriggerClientEvent('bcc-farming:UpdatePlantStatus', src, plantStatus)
    end
end)

-- ===========================================
-- CLIENT CONNECTION MANAGEMENT
-- ===========================================

RegisterServerEvent('bcc-farming:NewClientConnected', function()
    local src = source
    local user = VORPcore.getUser(src)
    if not user then return end
    local character = user.getUsedCharacter
    local charid = character.charIdentifier
    
    if #AllPlants <= 0 then return end
    
    -- Send plants to connected client with enhanced data
    for _, currentPlant in pairs(AllPlants) do
        local plantConfig = GetPlantConfig(currentPlant.plant_type)
        if plantConfig then
            local plantStatus = GrowthCalculations.GetPlantStatus(currentPlant.plant_id)
            
            if not Config.plantSetup.lockedToPlanter or currentPlant.plant_owner == charid then
                if currentPlant.plant_owner == charid then
                    TriggerClientEvent('bcc-farming:MaxPlantsAmount', src, 1)
                end
                
                TriggerClientEvent('bcc-farming:PlantPlanted', src, {
                    plantId = currentPlant.plant_id,
                    plantData = plantConfig,
                    plantCoords = json.decode(currentPlant.plant_coords),
                    timeToGrow = currentPlant.total_growth_time or currentPlant.time_left,
                    watered = currentPlant.water_count > 0,
                    plantConfig = plantConfig,
                    -- Enhanced data
                    growthStage = currentPlant.growth_stage,
                    growthProgress = currentPlant.growth_progress,
                    waterCount = currentPlant.water_count,
                    maxWaterTimes = currentPlant.max_water_times,
                    baseFertilized = currentPlant.base_fertilized,
                    plantStatus = plantStatus
                })
            end
        end
    end
end)

-- ===========================================
-- ENHANCED GROWTH UPDATE SYSTEM
-- ===========================================

CreateThread(function()
    while true do
        Wait(1000) -- Update every second
        
        local allPlants = MySQL.query.await('SELECT * FROM bcc_farming')
        AllPlants = allPlants
        
        if #allPlants > 0 then
            for _, plant in pairs(allPlants) do
                local timeLeft = tonumber(plant.time_left) or 0
                local hasWater = (plant.water_count or 0) > 0
                
                -- Only grow if plant has been watered at least once
                if hasWater and timeLeft > 0 then
                    local newTime = math.max(0, timeLeft - 1)
                    
                    -- Update time and recalculate progress/stage
                    MySQL.execute('UPDATE bcc_farming SET time_left = ? WHERE plant_id = ?', 
                        { newTime, plant.plant_id })
                    
                    -- Update growth progress and stage every 10 seconds to reduce load
                    if timeLeft % 10 == 0 then
                        GrowthCalculations.UpdatePlantGrowth(plant.plant_id)
                        
                        -- Check for stage transitions and notify clients
                        local newProgress = GrowthCalculations.CalculateGrowthProgress(newTime, plant.total_growth_time)
                        local newStage = GrowthCalculations.GetGrowthStage(newProgress)
                        
                        if newStage ~= plant.growth_stage then
                            TriggerClientEvent('bcc-farming:UpdatePlantStage', -1, {
                                plantId = plant.plant_id,
                                newStage = newStage,
                                progress = newProgress
                            })
                        end
                    end
                end
            end
        end
    end
end)

-- ===========================================
-- PLANT DETECTION SYSTEM (POLICE)
-- ===========================================

RegisterNetEvent('bcc-farming:DetectSmellingPlants', function(playerCoords)
    local src = source
    
    if not CheckPlayerJob(src) then
        return -- Only police jobs can detect plants
    end
    
    local smellingPlants = {}
    
    for _, plant in pairs(AllPlants) do
        local plantConfig = GetPlantConfig(plant.plant_type)
        if plantConfig and plantConfig.smelling then
            local plantCoords = json.decode(plant.plant_coords)
            local distance = #(vector3(playerCoords.x, playerCoords.y, playerCoords.z) - 
                            vector3(plantCoords.x, plantCoords.y, plantCoords.z))
            
            if distance <= Config.SmellingDistance then
                table.insert(smellingPlants, {
                    plantId = plant.plant_id,
                    plantName = plantConfig.plantName,
                    coords = plantCoords,
                    distance = distance,
                    growthStage = plant.growth_stage
                })
            end
        end
    end
    
    if #smellingPlants > 0 then
        TriggerClientEvent('bcc-farming:ShowSmellingPlants', src, smellingPlants)
    end
end)

-- ===========================================
-- UTILITY FUNCTIONS
-- ===========================================

RegisterServerEvent('bcc-farming:RemoveFertilizer', function(fertilizerName)
    local src = source
    local user = VORPcore.getUser(src)
    if not user then return end
    
    local fertCount = exports.vorp_inventory:getItemCount(src, nil, fertilizerName)
    if fertCount >= 1 then
        exports.vorp_inventory:subItem(src, fertilizerName, 1)
    end
end)

RegisterNetEvent('bcc-farming:AddSeedToInventory', function(seedName, amount)
    local src = source
    local user = VORPcore.getUser(src)
    if not user then return end
    
    local canCarry = exports.vorp_inventory:canCarryItem(src, seedName, amount)
    if canCarry then
        exports.vorp_inventory:addItem(src, seedName, amount)
    end
end)

-- Tool usage function (unchanged)
RegisterServerEvent('bcc-farming:PlantToolUsage', function(plantData)
    local src = source
    local user = VORPcore.getUser(src)
    if not user then return end
    local toolItem = plantData.plantingTool
    local toolUsage = plantData.plantingToolUsage
    local tool = exports.vorp_inventory:getItem(src, toolItem)
    local toolMeta = tool and tool['metadata'] or {}

    if next(toolMeta) == nil then
        exports.vorp_inventory:subItem(src, toolItem, 1, {})
        exports.vorp_inventory:addItem(src, toolItem, 1, { 
            description = _U('UsageLeft') .. 100 - toolUsage, 
            durability = 100 - toolUsage 
        })
    else
        local durabilityValue = toolMeta.durability - toolUsage
        exports.vorp_inventory:subItem(src, toolItem, 1, toolMeta)

        if durabilityValue >= toolUsage then
            exports.vorp_inventory:addItem(src, toolItem, 1, { 
                description = _U('UsageLeft') .. durabilityValue, 
                durability = durabilityValue 
            })
        elseif durabilityValue < toolUsage then
            VORPcore.NotifyRightTip(src, _U('needNewTool'), 4000)
        end
    end
end)

print("^2[BCC-Farming]^7 Enhanced server main loaded with multi-stage growth system!")
print("^3[BCC-Farming]^7 Features: Multi-watering, base fertilizer, growth stages, enhanced rewards")