VORPcore = exports.vorp_core:GetCore()
BccUtils = exports['bcc-utils'].initiate()

local AllPlants = {} -- AllPlants will contain all the plants in the server

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

RegisterServerEvent('bcc-farming:AddPlant', function(plantData, plantCoords, fertilizerUsed)
    local src = source
    local user = VORPcore.getUser(src)
    if not user then return end
    local character = user.getUsedCharacter

    -- Initialize v2.5.0 values
    local growthStage = 1  -- Start at stage 1
    local growthProgress = 0.0  -- Start at 0%
    local waterCount = 0  -- No initial waterings
    local maxWaterTimes = plantData.waterTimes or 1  -- From plant config
    local baseFertilized = fertilizerUsed and 1 or 0  -- Whether fertilizer was used
    local fertilizerType = fertilizerUsed or NULL  -- Type of fertilizer used

    local plantId = MySQL.insert.await([[
        INSERT INTO `bcc_farming` (
            plant_coords, plant_type, plant_watered, time_left, plant_owner,
            growth_stage, growth_progress, water_count, max_water_times, 
            base_fertilized, fertilizer_type
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], { 
        json.encode(plantCoords), 
        plantData.seedName, 
        'false', 
        plantData.timeToGrow, 
        character.charIdentifier,
        growthStage,
        growthProgress,
        waterCount,
        maxWaterTimes,
        baseFertilized,
        fertilizerType
    })

    -- Use appropriate prop for stage 1
    local plantProp = plantData.plantProp
    if plantData.plantProps and plantData.plantProps.stage1 then
        plantProp = plantData.plantProps.stage1
    end
    
    -- Create a compatible plantData for the client
    local clientPlantData = {}
    for k, v in pairs(plantData) do
        clientPlantData[k] = v
    end
    clientPlantData.plantProp = plantProp

    if Config.plantSetup.lockedToPlanter then
        TriggerClientEvent('bcc-farming:PlantPlanted', src, plantId, clientPlantData, plantCoords, plantData.timeToGrow, false, src)
        -- Send initial stage data
        TriggerClientEvent('bcc-farming:UpdatePlantStageData', src, plantId, growthStage, growthProgress)
    else
        TriggerClientEvent('bcc-farming:PlantPlanted', -1, plantId, clientPlantData, plantCoords, plantData.timeToGrow, false, src)
        -- Send initial stage data to all clients
        TriggerClientEvent('bcc-farming:UpdatePlantStageData', -1, plantId, growthStage, growthProgress)
    end
end)

RegisterServerEvent('bcc-farming:PlantToolUsage',function (plantData)
    local src = source
    local user = VORPcore.getUser(src)
    if not user then return end
    local toolItem = plantData.plantingTool
    local toolUsage = plantData.plantingToolUsage
    local tool = exports.vorp_inventory:getItem(src, toolItem)
    local toolMeta = tool and tool['metadata'] or {}

    if next(toolMeta) == nil then
        exports.vorp_inventory:subItem(src, toolItem, 1, {})
        exports.vorp_inventory:addItem(src, toolItem, 1, { description = _U('UsageLeft') .. 100 - toolUsage, durability = 100 - toolUsage })
    else
        local durabilityValue = toolMeta.durability - toolUsage
        exports.vorp_inventory:subItem(src, toolItem, 1, toolMeta)

        if durabilityValue >= toolUsage then
            exports.vorp_inventory:addItem(src, toolItem, 1, { description = _U('UsageLeft') .. durabilityValue, durability = durabilityValue })
        elseif durabilityValue < toolUsage then
            SendFarmingNotification(src, _U('needNewTool'))
        end
    end
end)

RegisterServerEvent('bcc-farming:NewClientConnected', function()
    local src = source
    local user = VORPcore.getUser(src)
    if not user then return end
    local character = user.getUsedCharacter
    local charid = character.charIdentifier

    if #AllPlants <= 0 then return end

    if not Config.plantSetup.lockedToPlanter then
        for _, currentPlants in pairs(AllPlants) do
            if currentPlants.plant_owner == charid then
                TriggerClientEvent('bcc-farming:MaxPlantsAmount', src, 1)
            end
            for _, plantCfg in pairs(Plants) do
                if currentPlants.plant_type == plantCfg.seedName then
                    -- Create enhanced plant config with v2.5.0 data
                    local enhancedPlantCfg = {}
                    for k, v in pairs(plantCfg) do
                        enhancedPlantCfg[k] = v
                    end
                    
                    -- Set waterTimes from database or config
                    enhancedPlantCfg.waterTimes = tonumber(currentPlants.max_water_times) or plantCfg.waterTimes or 1
                    
                    -- Use appropriate stage prop
                    local stageNumber = tonumber(currentPlants.growth_stage) or 1
                    if plantCfg.plantProps then
                        if stageNumber == 1 and plantCfg.plantProps.stage1 then
                            enhancedPlantCfg.plantProp = plantCfg.plantProps.stage1
                        elseif stageNumber == 2 and plantCfg.plantProps.stage2 then
                            enhancedPlantCfg.plantProp = plantCfg.plantProps.stage2
                        elseif stageNumber == 3 and plantCfg.plantProps.stage3 then
                            enhancedPlantCfg.plantProp = plantCfg.plantProps.stage3
                        else
                            enhancedPlantCfg.plantProp = plantCfg.plantProp or plantCfg.plantProps.stage1
                        end
                    end
                    
                    TriggerClientEvent('bcc-farming:PlantPlanted',
                    src, currentPlants.plant_id, enhancedPlantCfg, json.decode(currentPlants.plant_coords), currentPlants.time_left, currentPlants.plant_watered, src)
                    
                    -- Send v2.5.0 watering data
                    local waterCount = tonumber(currentPlants.water_count) or 0
                    local maxWaterTimes = tonumber(currentPlants.max_water_times) or 1
                    local isFullyWatered = (waterCount >= maxWaterTimes)
                    TriggerClientEvent('bcc-farming:UpdateClientPlantWateredStatus', src, currentPlants.plant_id, waterCount, maxWaterTimes, isFullyWatered)
                    
                    -- Send v2.5.0 growth stage data
                    local growthStage = tonumber(currentPlants.growth_stage) or 1
                    local growthProgress = tonumber(currentPlants.growth_progress) or 0
                    TriggerClientEvent('bcc-farming:UpdatePlantStageData', src, currentPlants.plant_id, growthStage, growthProgress)
                    break
                end
            end
        end
    else
        for _, currentPlants in pairs(AllPlants) do
            if currentPlants.plant_owner == charid then
                TriggerClientEvent('bcc-farming:MaxPlantsAmount',src, 1)
                for _, plantCfg in pairs(Plants) do
                    if currentPlants.plant_type == plantCfg.seedName then
                        -- Create enhanced plant config with v2.5.0 data
                        local enhancedPlantCfg = {}
                        for k, v in pairs(plantCfg) do
                            enhancedPlantCfg[k] = v
                        end
                        
                        -- Set waterTimes from database or config
                        enhancedPlantCfg.waterTimes = tonumber(currentPlants.max_water_times) or plantCfg.waterTimes or 1
                        
                        -- Use appropriate stage prop
                        local stageNumber = tonumber(currentPlants.growth_stage) or 1
                        if plantCfg.plantProps then
                            if stageNumber == 1 and plantCfg.plantProps.stage1 then
                                enhancedPlantCfg.plantProp = plantCfg.plantProps.stage1
                            elseif stageNumber == 2 and plantCfg.plantProps.stage2 then
                                enhancedPlantCfg.plantProp = plantCfg.plantProps.stage2
                            elseif stageNumber == 3 and plantCfg.plantProps.stage3 then
                                enhancedPlantCfg.plantProp = plantCfg.plantProps.stage3
                            else
                                enhancedPlantCfg.plantProp = plantCfg.plantProp or plantCfg.plantProps.stage1
                            end
                        end
                        
                        TriggerClientEvent('bcc-farming:PlantPlanted',
                        src, currentPlants.plant_id, enhancedPlantCfg, json.decode(currentPlants.plant_coords), currentPlants.time_left, currentPlants.plant_watered, src)
                        
                        -- Send v2.5.0 watering data
                        local waterCount = tonumber(currentPlants.water_count) or 0
                        local maxWaterTimes = tonumber(currentPlants.max_water_times) or 1
                        local isFullyWatered = (waterCount >= maxWaterTimes)
                        TriggerClientEvent('bcc-farming:UpdateClientPlantWateredStatus', src, currentPlants.plant_id, waterCount, maxWaterTimes, isFullyWatered)
                        
                        -- Send v2.5.0 growth stage data
                        local growthStage = tonumber(currentPlants.growth_stage) or 1
                        local growthProgress = tonumber(currentPlants.growth_progress) or 0
                        TriggerClientEvent('bcc-farming:UpdatePlantStageData', src, currentPlants.plant_id, growthStage, growthProgress)
                        break
                    end
                end
            end
        end
    end
end)

VORPcore.Callback.Register('bcc-farming:ManagePlantWateredStatus', function(source, cb, plantId)
    local src = source
    local user = VORPcore.getUser(src)
    if not user then return cb(false) end

    -- Get current plant data with plant config info
    local plantRow = MySQL.query.await('SELECT * FROM `bcc_farming` WHERE `plant_id` = ?', { plantId })
    if not plantRow or #plantRow == 0 then 
        return cb(false) 
    end
    
    local plant = plantRow[1]
    local currentWaterCount = tonumber(plant.water_count) or 0
    local maxWaterTimes = tonumber(plant.max_water_times) or 1
    
    -- Check if plant can still be watered
    if currentWaterCount >= maxWaterTimes then
        SendFarmingNotification(src, _U('plantFullyWatered') or 'Plant is already fully watered!')
        return cb(false)
    end
    
    -- Get plant config to calculate watering timeout
    local plantConfig = nil
    for _, plantCfg in pairs(Plants) do
        if plantCfg.seedName == plant.plant_type then
            plantConfig = plantCfg
            break
        end
    end
    
    if not plantConfig then
        return cb(false)
    end
    
    -- Calculate watering timeout (growthTime / waterTimes)
    local totalGrowthTime = plantConfig.timeToGrow or 1200
    local wateringInterval = math.floor(totalGrowthTime / maxWaterTimes)
    
    -- Check if enough time has passed since last watering
    if plant.last_watered_time and currentWaterCount > 0 then
        local lastWateredTimestamp = MySQL.scalar.await('SELECT UNIX_TIMESTAMP(last_watered_time) FROM `bcc_farming` WHERE `plant_id` = ?', { plantId })
        local currentTime = os.time()
        local timeSinceLastWatering = currentTime - (lastWateredTimestamp or 0)
        
        if timeSinceLastWatering < wateringInterval then
            local remainingTime = wateringInterval - timeSinceLastWatering
            local minutes = math.floor(remainingTime / 60)
            local seconds = remainingTime % 60
            
            SendFarmingNotification(src, 
                (_U('wateringCooldown') or 'Must wait before next watering!') .. 
                string.format(' %dm %ds remaining', minutes, seconds)
            )
            return cb(false)
        end
    end

    local fullWaterBucket = Config.fullWaterBucket
    for _, item in ipairs(fullWaterBucket) do
        local itemCount = exports.vorp_inventory:getItemCount(src, nil, item)
        if itemCount >= 1 then
            exports.vorp_inventory:subItem(src, item, 1)
            exports.vorp_inventory:addItem(src, Config.emptyWaterBucket, 1)
            
            -- Update v2.5.0 watering system
            local newWaterCount = currentWaterCount + 1
            local isFullyWatered = (newWaterCount >= maxWaterTimes)
            
            MySQL.update.await([[
                UPDATE `bcc_farming` 
                SET `water_count` = ?, `plant_watered` = ?, `last_watered_time` = NOW() 
                WHERE `plant_id` = ?
            ]], { 
                newWaterCount, 
                'true',  -- Start growth timer on first watering
                plantId 
            })
            
            -- Notify about watering progress and growth status
            local wateringProgress = math.floor((newWaterCount / maxWaterTimes) * 100)
            local statusMessage = (_U('plantWatered') or 'Plant watered!') .. 
                ' (' .. newWaterCount .. '/' .. maxWaterTimes .. ' - ' .. wateringProgress .. '%)'
            
            -- Add growth status notification for first watering
            if newWaterCount == 1 then
                statusMessage = statusMessage .. ' - Growth timer started!'
            end
            
            SendFarmingNotification(src, statusMessage)
            
            TriggerClientEvent('bcc-farming:UpdateClientPlantWateredStatus', -1, plantId, newWaterCount, maxWaterTimes, isFullyWatered)
            return cb(true)
        end
    end

    -- If we reach here, player doesn't have water bucket
    SendFarmingNotification(src, _U('noWaterBucket') or 'No water bucket found!')
    cb(false)
end)

RegisterNetEvent('bcc-farming:UpdatePlantWateredStatus', function(plantId)
    local src = source
    local user = VORPcore.getUser(src)
    if not user then return end

    MySQL.update.await('UPDATE `bcc_farming` SET `plant_watered` = ? WHERE `plant_id` = ?', { 'true', plantId })
    TriggerClientEvent('bcc-farming:UpdateClientPlantWateredStatus', -1, plantId)
end)

VORPcore.Callback.Register('bcc-farming:HarvestCheck', function(source, cb, plantId, plantData, destroy)
    local src = source
    local user = VORPcore.getUser(src)
    if not user then return cb(false) end

    if not destroy then
        local itemsToAdd = {}

        -- Check if all items can be carried
        for _, reward in pairs(plantData.rewards) do
            local itemName = reward.itemName
            local itemLabel = reward.itemLabel
            local amount = reward.amount
            local canCarry = exports.vorp_inventory:canCarryItem(src, itemName, amount)
            if canCarry then
                table.insert(itemsToAdd, { itemName = itemName, itemLabel = itemLabel, amount = amount })
            else
                SendFarmingNotification(src, _U('noCarry') .. itemName)
                return cb(false) -- Exit early if any item cannot be carried
            end
        end

        -- Add items if all can be carried
        for _, item in ipairs(itemsToAdd) do
            exports.vorp_inventory:addItem(src, item.itemName, item.amount)
            SendFarmingNotification(src, _U('harvested') .. item.amount .. ' ' .. item.itemLabel)
        end
    end

    cb(true)

    -- Update plant status in database and remove plant from clients
    MySQL.query.await('DELETE FROM `bcc_farming` WHERE `plant_id` = ?', { plantId })
    TriggerClientEvent('bcc-farming:MaxPlantsAmount', src, -1)
    TriggerClientEvent('bcc-farming:RemovePlantClient', -1, plantId)
end)

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

CreateThread(function()
    while true do
        Wait(1000)
        local allPlants = MySQL.query.await('SELECT * FROM `bcc_farming`')
        AllPlants = allPlants
        if #allPlants > 0 then
            for _, plant in pairs(allPlants) do
                local timeLeft = tonumber(plant.time_left)
                if plant.plant_watered == 'true' and timeLeft > 0 then
                    local newTime = timeLeft - 1
                    MySQL.update('UPDATE `bcc_farming` SET `time_left` = ? WHERE `plant_id` = ?', { newTime, plant.plant_id }, function() end)
                    
                    -- Calculate growth progress and update stages
                    local plantConfig = nil
                    for _, plantCfg in pairs(Plants) do
                        if plantCfg.seedName == plant.plant_type then
                            plantConfig = plantCfg
                            break
                        end
                    end
                    
                    if plantConfig then
                        local totalGrowthTime = plantConfig.timeToGrow
                        local elapsedTime = totalGrowthTime - newTime
                        local growthProgress = math.min(100, (elapsedTime / totalGrowthTime) * 100)
                        
                        -- Determine growth stage based on progress
                        local newStage = 1
                        if growthProgress >= 66.67 then
                            newStage = 3
                        elseif growthProgress >= 33.33 then
                            newStage = 2
                        else
                            newStage = 1
                        end
                        
                        local currentStage = tonumber(plant.growth_stage) or 1
                        local currentProgress = tonumber(plant.growth_progress) or 0
                        
                        -- Update stage and progress if changed
                        if newStage ~= currentStage or math.abs(growthProgress - currentProgress) > 1 then
                            MySQL.update('UPDATE `bcc_farming` SET `growth_stage` = ?, `growth_progress` = ? WHERE `plant_id` = ?', 
                                { newStage, growthProgress, plant.plant_id }, function() end)
                            
                            print(string.format("^2[BCC-Farming Growth]^7 Plant %d: Stage %d->%d, Progress %.1f%% (Time: %d/%d)", 
                                plant.plant_id, currentStage, newStage, growthProgress, elapsedTime, totalGrowthTime))
                            
                            -- Only update clients if stage actually changed (avoid spam)
                            if newStage ~= currentStage then
                                print(string.format("^6[BCC-Farming]^7 Broadcasting stage change for plant %d: %d -> %d", 
                                    plant.plant_id, currentStage, newStage))
                                TriggerClientEvent('bcc-farming:UpdatePlantStageData', -1, plant.plant_id, newStage, growthProgress)
                            end
                        end
                    end
                end
            end
        end
    end
end)

RegisterNetEvent('bcc-farming:DetectSmellingPlants', function(playerCoords)
    local src = source
    local user = VORPcore.getUser(src)
    if not user then return end
    local character = user.getUsedCharacter
    local hasJob = CheckPlayerJob(src)
    if not hasJob then return end
    local smellingPlants = {}

    for _, allPlant in pairs(AllPlants) do
        for h, plant in pairs(Plants) do
            local plantData = AllPlants[allPlant.plant_type]
            if allPlant.plant_type == plant.seedName and plant.smelling then
                local plantCoords = json.decode(allPlant.plant_coords)
                local distance = #(vector3(plantCoords.x, plantCoords.y, plantCoords.z) - playerCoords)
                if distance <= Config.SmellingDistance then
                    table.insert(smellingPlants, { coords = plantCoords, plantName = plant.plantName })
                    TriggerClientEvent('bcc-farming:ShowSmellingPlants', src, smellingPlants)
                end
            end
        end
    end
end)

-- ===========================================
-- FERTILIZER APPLICATION SYSTEM
-- ===========================================

RegisterServerEvent('bcc-farming:ApplyFertilizer', function(plantId, fertilizerType)
    local src = source
    local user = VORPcore.getUser(src)
    if not user then return end
    
    -- Get plant data
    local plantData = MySQL.query.await('SELECT * FROM bcc_farming WHERE plant_id = ?', { plantId })
    if not plantData or #plantData == 0 then
        SendFarmingNotification(src, _U('plantNotFound'))
        return
    end
    
    local plant = plantData[1]
    
    -- Get plant configuration
    local plantConfig = nil
    for _, config in pairs(Plants) do
        if config.seedName == plant.plant_type then
            plantConfig = config
            break
        end
    end
    
    if not plantConfig then
        SendFarmingNotification(src, _U('invalidPlantConfig'))
        return
    end
    
    -- Check fertilizer inventory (double-check)
    local fertCount = exports.vorp_inventory:getItemCount(src, nil, fertilizerType)
    if fertCount < 1 then
        SendFarmingNotification(src, _U('noFertilizer'))
        return
    end
    
    -- Determine fertilizer type and effects
    local isBaseFertilizer = (fertilizerType == (plantConfig.baseFertilizerItem or 'fertilizer'))
    local timeReduction = 0
    
    -- Calculate time reduction based on fertilizer type
    if Config.fertilizerSetup then
        for _, fert in pairs(Config.fertilizerSetup) do
            if fert.fertName == fertilizerType then
                timeReduction = fert.fertTimeReduction
                break
            end
        end
    end
    
    -- Check if fertilizer already applied
    if isBaseFertilizer then
        if tonumber(plant.base_fertilized) == 1 then
            SendFarmingNotification(src, _U('baseFertilizerAlready'))
            return
        end
    else
        if plant.fertilizer_type and plant.fertilizer_type ~= 'NULL' then
            SendFarmingNotification(src, _U('enhancedFertilizerAlready'))
            return
        end
    end
    
    -- Remove fertilizer from inventory
    exports.vorp_inventory:subItem(src, fertilizerType, 1)
    
    -- Calculate new time left with reduction
    local currentTimeLeft = tonumber(plant.time_left) or 0
    local newTimeLeft = currentTimeLeft
    
    if timeReduction > 0 then
        newTimeLeft = math.floor(currentTimeLeft * (1 - timeReduction))
    end
    
    -- Update database
    if isBaseFertilizer then
        MySQL.update.await([[
            UPDATE bcc_farming 
            SET base_fertilized = 1, time_left = ?
            WHERE plant_id = ?
        ]], { newTimeLeft, plantId })
        
        SendFarmingNotification(src, _U('baseFertilizerApplied'))
    else
        MySQL.update.await([[
            UPDATE bcc_farming 
            SET fertilizer_type = ?, time_left = ?
            WHERE plant_id = ?
        ]], { fertilizerType, newTimeLeft, plantId })
        
        local reductionPercent = math.floor(timeReduction * 100)
        SendFarmingNotification(src, string.format(_U('enhancedFertilizerApplied'), reductionPercent))
    end
    
    print(string.format("^2[BCC-Farming]^7 Player %s applied %s to plant %d (reduction: %d%%)", 
        GetPlayerName(src), fertilizerType, plantId, math.floor(timeReduction * 100)))
end)

BccUtils.Versioner.checkFile(GetCurrentResourceName(), 'https://github.com/Ohio-RP/bcc-farming')

