local WaterPrompt, DestroyPromptWG
local WaterGroup = GetRandomIntInRange(0, 0xffffff)

local HarvestPrompt, DestroyPromptHG
local HarvestGroup = GetRandomIntInRange(0, 0xffffff)

local PromptsStarted = false
local Crops = {}

local function StartPrompts()
    WaterPrompt = PromptRegisterBegin()
    PromptSetControlAction(WaterPrompt, Config.keys.water)
    PromptSetText(WaterPrompt, CreateVarString(10, 'LITERAL_STRING', _U('useBucket')))
    PromptSetVisible(WaterPrompt, true)
    PromptSetEnabled(WaterPrompt, true)
    PromptSetHoldMode(WaterPrompt, 2000)
    PromptSetGroup(WaterPrompt, WaterGroup, 0)
    PromptRegisterEnd(WaterPrompt)

    DestroyPromptWG = PromptRegisterBegin()
    PromptSetControlAction(DestroyPromptWG, Config.keys.destroy)
    PromptSetText(DestroyPromptWG, CreateVarString(10, 'LITERAL_STRING', _U('destroyPlant')))
    PromptSetVisible(DestroyPromptWG, true)
    PromptSetEnabled(DestroyPromptWG, true)
    PromptSetHoldMode(DestroyPromptWG, 2000)
    PromptSetGroup(DestroyPromptWG, WaterGroup, 0)
    PromptRegisterEnd(DestroyPromptWG)

    HarvestPrompt = PromptRegisterBegin()
    PromptSetControlAction(HarvestPrompt, Config.keys.harvest)
    PromptSetText(HarvestPrompt, CreateVarString(10, 'LITERAL_STRING', _U('harvest')))
    PromptSetVisible(HarvestPrompt, true)
    PromptSetEnabled(HarvestPrompt, true)
    PromptSetHoldMode(HarvestPrompt, 2000)
    PromptSetGroup(HarvestPrompt, HarvestGroup, 0)
    PromptRegisterEnd(HarvestPrompt)

    DestroyPromptHG = PromptRegisterBegin()
    PromptSetControlAction(DestroyPromptHG, Config.keys.destroy)
    PromptSetText(DestroyPromptHG, CreateVarString(10, 'LITERAL_STRING', _U('destroyPlant')))
    PromptSetVisible(DestroyPromptHG, true)
    PromptSetEnabled(DestroyPromptHG, true)
    PromptSetHoldMode(DestroyPromptHG, 2000)
    PromptSetGroup(DestroyPromptHG, HarvestGroup, 0)
    PromptRegisterEnd(DestroyPromptHG)

    PromptsStarted = true
end

local function LoadModel(model, modelName)
    if not IsModelValid(model) then
        print('Invalid model:', modelName)
        return
    end

    if HasModelLoaded(model) then return end

    RequestModel(model, false)
    local timeout = 10000
    local startTime = GetGameTimer()

    while not HasModelLoaded(model) do
        if GetGameTimer() - startTime > timeout then
            print('Failed to load model:', modelName)
            return
        end
        Wait(10)
    end
end

RegisterNetEvent('bcc-farming:PlantPlanted', function(plantId, plantData, plantCoords, timeLeft, watered, source)
    -- Use new prop management system
    local plantObj = nil
    
    -- Wait for PropManager to be available and create the plant prop
    SetTimeout(500, function()
        if PropManager then
            plantObj = PropManager.CreatePlantProp(plantId, plantData, plantCoords, 1) -- Start at stage 1
            
            if plantObj then
                print(string.format("^2[BCC-Farming]^7 Plant %d created using PropManager", plantId))
            else
                print(string.format("^1[BCC-Farming]^7 Failed to create plant %d using PropManager", plantId))
                -- Fallback to old system if PropManager fails
                local plantProp = plantData.plantProp
                local hash = joaat(plantProp)
                LoadModel(hash, plantProp)
                plantObj = CreateObject(hash, plantCoords.x, plantCoords.y, plantCoords.z - (plantData.plantOffset or 0), false, false, false, false, false)
                if plantObj and DoesEntityExist(plantObj) then
                    SetEntityHeading(plantObj, GetEntityHeading(PlayerPedId()))
                    PlaceObjectOnGroundProperly(plantObj, true)
                    Wait(100)
                    local hit, groundZ = GetGroundZAndNormalFor_3dCoord(plantCoords.x, plantCoords.y, plantCoords.z + 10.0)
                    if hit then
                        SetEntityCoords(plantObj, plantCoords.x, plantCoords.y, groundZ, false, false, false, false)
                    end
                    FreezeEntityPosition(plantObj, true)
                    print("^3[BCC-Farming]^7 Using fallback plant creation method")
                end
            end
        else
            print("^1[BCC-Farming]^7 PropManager not available, using fallback")
            -- Fallback to old system
            local plantProp = plantData.plantProp
            local hash = joaat(plantProp)
            LoadModel(hash, plantProp)
            plantObj = CreateObject(hash, plantCoords.x, plantCoords.y, plantCoords.z - (plantData.plantOffset or 0), false, false, false, false, false)
            if plantObj and DoesEntityExist(plantObj) then
                SetEntityHeading(plantObj, GetEntityHeading(PlayerPedId()))
                PlaceObjectOnGroundProperly(plantObj, true)
                Wait(100)
                local hit, groundZ = GetGroundZAndNormalFor_3dCoord(plantCoords.x, plantCoords.y, plantCoords.z + 10.0)
                if hit then
                    SetEntityCoords(plantObj, plantCoords.x, plantCoords.y, groundZ, false, false, false, false)
                end
                FreezeEntityPosition(plantObj, true)
            end
        end
    end)

    -- Initialize v2.5.0 crop tracking
    local initialWaterCount = 0
    local maxWaterTimes = plantData.waterTimes or 1
    local isFullyWatered = (initialWaterCount >= maxWaterTimes) or (tostring(watered) == 'true')
    
    Crops[plantId] = { 
        plantId = plantId, 
        removePlant = false, 
        watered = tostring(watered),
        waterCount = initialWaterCount,
        maxWaterTimes = maxWaterTimes,
        isFullyWatered = isFullyWatered,
        plantObject = plantObj,
        currentStage = 1,
        growthProgress = 0
    }
    
    print(string.format("^2[BCC-Farming Debug]^7 Plant %d initialized - waterCount: %d/%d, isFullyWatered: %s", 
        plantId, initialWaterCount, maxWaterTimes, tostring(isFullyWatered)))

    local blip = nil
    local blipCfg = plantData.blips
    if blipCfg.enabled then
        if GetPlayerServerId(PlayerId()) == source then -- Only show blip for planter not all clients
            blip = Citizen.InvokeNative(0x554d9d53f696d002, 1664425300, plantCoords.x, plantCoords.y, plantCoords.z) -- BlipAddForCoords
            SetBlipSprite(blip, joaat(blipCfg.sprite), true)
            Citizen.InvokeNative(0x9CB1A1623062F402, blip, blipCfg.name) -- SetBlipName
            Citizen.InvokeNative(0x662D364ABF16DE2F, blip, joaat(Config.BlipColors[blipCfg.color])) -- BlipAddModifier
        end
    end

    if not PromptsStarted then
        print("^2[BCC-Farming Debug]^7 Starting prompts...")
        StartPrompts()
        print("^2[BCC-Farming Debug]^7 Prompts started!")
    else
        print("^2[BCC-Farming Debug]^7 Prompts already started")
    end

    CreateThread(function() -- keep the time synced with the database
        while tonumber(timeLeft) > 0 and Crops[plantId] do
            if Crops[plantId].removePlant then break end
            if Crops[plantId].watered == 'true' then
                Wait(1000)
                timeLeft = timeLeft - 1
            else
                Wait(200)
            end
        end
    end)

    while true do
        local sleep = 1000

        if Crops[plantId].removePlant then
            if blip then
                RemoveBlip(blip)
            end
            if Crops[plantId].plantObject then
                DeleteObject(Crops[plantId].plantObject)
            end
            Crops[plantId] = false
            break
        end

        if tostring(Crops[plantId].watered) ~= tostring(watered) then
            watered = Crops[plantId].watered
        end

        local dist = #(GetEntityCoords(PlayerPedId()) - vector3(plantCoords.x, plantCoords.y, plantCoords.z))
        
        -- Debug: Check crop data
        if dist <= 1.5 and not Crops[plantId].debugShown then
            print(string.format("^3[BCC-Farming Debug]^7 Plant %d - waterCount: %d/%d, isFullyWatered: %s, watered: %s", 
                plantId, Crops[plantId].waterCount or 0, Crops[plantId].maxWaterTimes or 1, 
                tostring(Crops[plantId].isFullyWatered), tostring(Crops[plantId].watered)))
            Crops[plantId].debugShown = true
        end
        
        -- Check if plant is fully watered (v2.5.0 system)
        if Crops[plantId].isFullyWatered then
            if dist <= 1.5 then
                sleep = 0

                if tonumber(timeLeft) > 0 then
                    local minutes = math.floor(timeLeft / 60)
                    local seconds = timeLeft % 60
                    PromptSetEnabled(HarvestPrompt, false)
                    local noHarvest = _U('plant') .. ': ' .. plantData.plantName..' | ' .. _U('secondsUntilharvest')..string.format('%02d:%02d', minutes, seconds)
                    PromptSetActiveGroupThisFrame(HarvestGroup, CreateVarString(10, 'LITERAL_STRING', noHarvest), 1, 0, 0, 0)

                elseif tonumber(timeLeft) <= 0 then
                    PromptSetEnabled(HarvestPrompt, true)
                    local harvest = _U('plant') .. ': ' .. plantData.plantName..' ' .. _U('secondsUntilharvestOver')
                    PromptSetActiveGroupThisFrame(HarvestGroup, CreateVarString(10, 'LITERAL_STRING', harvest), 1, 0, 0, 0)

                    if Citizen.InvokeNative(0xE0F65F0640EF0617, HarvestPrompt) then  -- PromptHasHoldModeCompleted
                        local canHarvest = VORPcore.Callback.TriggerAwait('bcc-farming:HarvestCheck', plantId, plantData, false)
                        if canHarvest then
                            PlayAnim('mech_pickup@plant@berries', 'base', 2500)
                            if blip then
                                RemoveBlip(blip)
                            end
                        end
                    end
                end

                if Citizen.InvokeNative(0xE0F65F0640EF0617, DestroyPromptHG) then  -- PromptHasHoldModeCompleted
                    local canDestroy = VORPcore.Callback.TriggerAwait('bcc-farming:HarvestCheck', plantId, plantData, true)
                    if canDestroy then
                        PlayAnim('amb_camp@world_camp_fire@stomp@male_a@wip_base', 'wip_base', 8000)
                        if blip then
                            RemoveBlip(blip)
                        end
                    end
                end
            end

        else
            -- Plant needs more watering (v2.5.0 multi-watering system)
            if dist <= 1.5 then
                sleep = 0
                local isRaining = GetRainLevel()
                if isRaining > 0 then
                    TriggerServerEvent('bcc-farming:UpdatePlantWateredStatus', plantId)
                else
                    -- Create watering text with time remaining
                    local wateringText = _U('waterPlant') .. ' (' .. Crops[plantId].waterCount .. '/' .. Crops[plantId].maxWaterTimes .. ')'
                    
                    -- Add time remaining if plant has been watered (growth timer active)
                    if tonumber(timeLeft) > 0 and Crops[plantId].watered == 'true' then
                        local minutes = math.floor(timeLeft / 60)
                        local seconds = timeLeft % 60
                        wateringText = wateringText .. ' | ' .. _U('secondsUntilharvest') .. string.format('%02d:%02d', minutes, seconds)
                    end
                    
                    print(string.format("^5[BCC-Farming Debug]^7 Showing water prompt: %s", wateringText))
                    PromptSetActiveGroupThisFrame(WaterGroup, CreateVarString(10, 'LITERAL_STRING', wateringText), 1, 0, 0, 0)
                    
                    if Citizen.InvokeNative(0xE0F65F0640EF0617, WaterPrompt) then  -- PromptHasHoldModeCompleted
                        local canWater = VORPcore.Callback.TriggerAwait('bcc-farming:ManagePlantWateredStatus', plantId)
                        if canWater then
                            ScenarioInPlace('WORLD_HUMAN_BUCKET_POUR_LOW', 5000)
                        end
                        -- Note: Server already handles all error notifications (cooldown, no bucket, etc.)
                        -- No need for client-side notification here
                    end

                    if Citizen.InvokeNative(0xE0F65F0640EF0617, DestroyPromptWG) then  -- PromptHasHoldModeCompleted
                        local canDestroy = VORPcore.Callback.TriggerAwait('bcc-farming:HarvestCheck', plantId, plantData, true)
                        if canDestroy then
                            PlayAnim('amb_camp@world_camp_fire@stomp@male_a@wip_base', 'wip_base', 8000)
                            if blip then
                                RemoveBlip(blip)
                            end
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

RegisterNetEvent('bcc-farming:RemovePlantClient', function(plantId)
    if Crops[plantId] then
        Crops[plantId].removePlant = true
    end
    
    -- Also remove from PropManager if available
    if PropManager then
        PropManager.RemovePlantProp(plantId)
    end
end)

RegisterNetEvent('bcc-farming:UpdateClientPlantWateredStatus', function (plantId, newWaterCount, maxWaterTimes, isFullyWatered)
    if Crops[plantId] then
        if newWaterCount and maxWaterTimes then
            -- v2.5.0 multi-watering update
            Crops[plantId].waterCount = newWaterCount
            Crops[plantId].maxWaterTimes = maxWaterTimes
            Crops[plantId].isFullyWatered = isFullyWatered or false
            Crops[plantId].watered = isFullyWatered and 'true' or 'false'
        else
            -- Legacy update
            Crops[plantId].watered = 'true'
            Crops[plantId].isFullyWatered = true
        end
    end
end)

-- Handle plant stage data updates (with prop changes)
RegisterNetEvent('bcc-farming:UpdatePlantStageData', function(plantId, newStage, growthProgress)
    if Crops[plantId] then
        -- Update crop data with new stage information
        Crops[plantId].currentStage = newStage
        Crops[plantId].growthProgress = growthProgress
        
        print(string.format("^2[BCC-Farming Growth]^7 Plant %d: Stage %d, Progress %.1f%% (Client Updated)", 
            plantId, newStage, growthProgress))
        
        -- Update prop stage using PropManager if available
        if PropManager then
            local propData = PropManager.GetPlantPropData(plantId)
            if propData and propData.plantConfig then
                local success = PropManager.UpdatePlantStage(plantId, newStage, propData.plantConfig)
                if success then
                    print(string.format("^2[BCC-Farming Growth]^7 Plant %d prop updated to stage %d", plantId, newStage))
                else
                    print(string.format("^1[BCC-Farming Growth]^7 Failed to update plant %d prop to stage %d", plantId, newStage))
                end
            else
                print(string.format("^3[BCC-Farming Growth]^7 No prop data found for plant %d", plantId))
            end
        else
            print("^3[BCC-Farming Growth]^7 PropManager not available for stage update")
        end
    end
end)
