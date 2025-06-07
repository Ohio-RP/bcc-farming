-- Removed fertilizer prompts - fertilizers are now manual usable items

local PlantingProcess = false
local CurrentPlants = 0

RegisterNetEvent('bcc-farming:MaxPlantsAmount', function(number)
    if number == 1 then
        CurrentPlants = CurrentPlants + 1
    elseif number == -1 then
        CurrentPlants = CurrentPlants - 1
    end
end)

-- Fertilizer prompt functions removed - fertilizers are now manual usable items

-- Enhanced planting animation with trowel prop
local function PlayEnhancedPlantingAnimation(playerPed)
    -- Load trowel prop
    local trowelHash = GetHashKey('p_trowel01x')
    RequestModel(trowelHash)
    
    local attempts = 0
    while not HasModelLoaded(trowelHash) and attempts < 100 do
        Wait(10)
        attempts = attempts + 1
    end
    
    if not HasModelLoaded(trowelHash) then
        print("^1[BCC-Farming]^7 Failed to load trowel model, using fallback animation")
        PlayAnim('amb_work@world_human_farmer_rake@male_a@idle_a', 'idle_a', 16000, true, true)
        return
    end
    
    -- Create trowel prop
    local trowelProp = CreateObject(trowelHash, 0.0, 0.0, 0.0, true, true, false)
    
    if trowelProp and DoesEntityExist(trowelProp) then
        -- Attach trowel to right hand (SKEL_R_HAND bone)
        local boneIndex = GetEntityBoneIndexByName(playerPed, 'SKEL_R_HAND')
        if boneIndex == -1 then
            boneIndex = GetPedBoneIndex(playerPed, 57005)
        end
        
        AttachEntityToEntity(trowelProp, playerPed, boneIndex, 
            0.09, 0.03, -0.02,  -- position
            -87.5, 25, 4,       -- rotation
            false, false, false, false, 2, true)
        
        -- Load animation dictionaries
        local animDicts = {
            'amb_camp@world_camp_jack_plant@enter',
            'amb_camp@world_camp_jack_plant@base',
            'amb_camp@world_camp_jack_plant@idle_a',
            'amb_camp@world_camp_jack_plant@exit'
        }
        
        -- Load all animation dictionaries
        for _, dict in pairs(animDicts) do
            RequestAnimDict(dict)
            while not HasAnimDictLoaded(dict) do
                Wait(10)
            end
        end
        
        -- Execute animation sequence
        SendClientFarmingNotification('Preparando terreno...')
        
        -- 1. Enter animation
        TaskPlayAnim(playerPed, 'amb_camp@world_camp_jack_plant@enter', 'enter', 8.0, -8.0, -1, 1, 0.0, false, false, false)
        local startTime = GetGameTimer()
        while GetGameTimer() - startTime < 2000 and not IsEntityDead(playerPed) do
            Wait(100)
        end
        
        if IsEntityDead(playerPed) then
            print("^3[BCC-Farming]^7 Player died during planting animation, cleaning up")
            if DoesEntityExist(trowelProp) then DeleteEntity(trowelProp) end
            return
        end
        
        -- 2. Base animation
        TaskPlayAnim(playerPed, 'amb_camp@world_camp_jack_plant@base', 'base', 8.0, -8.0, -1, 1, 0.0, false, false, false)
        startTime = GetGameTimer()
        while GetGameTimer() - startTime < 2000 and not IsEntityDead(playerPed) do
            Wait(100)
        end
        
        if IsEntityDead(playerPed) then
            if DoesEntityExist(trowelProp) then DeleteEntity(trowelProp) end
            return
        end
        
        SendClientFarmingNotification('Cavando buraco para semente...')
        
        -- 3. Idle sequence (digging motions)
        local idleAnims = {'idle_c', 'idle_b', 'idle_a'}
        for i, idleAnim in pairs(idleAnims) do
            if IsEntityDead(playerPed) then
                if DoesEntityExist(trowelProp) then DeleteEntity(trowelProp) end
                return
            end
            
            TaskPlayAnim(playerPed, 'amb_camp@world_camp_jack_plant@idle_a', idleAnim, 8.0, -8.0, -1, 1, 0.0, false, false, false)
            startTime = GetGameTimer()
            while GetGameTimer() - startTime < 3000 and not IsEntityDead(playerPed) do
                Wait(100)
            end
            
            -- Progress feedback
            if i == 2 then
                SendClientFarmingNotification('Posicionando semente no buraco...')
            end
        end
        
        if IsEntityDead(playerPed) then
            if DoesEntityExist(trowelProp) then DeleteEntity(trowelProp) end
            return
        end
        
        SendClientFarmingNotification('Finalizando plantio...')
        
        -- 4. Exit animation
        TaskPlayAnim(playerPed, 'amb_camp@world_camp_jack_plant@exit', 'exit', 8.0, -8.0, -1, 1, 0.0, false, false, false)
        startTime = GetGameTimer()
        while GetGameTimer() - startTime < 2000 and not IsEntityDead(playerPed) do
            Wait(100)
        end
        
        -- Clean up
        ClearPedTasks(playerPed)
        
        -- Remove trowel prop
        if DoesEntityExist(trowelProp) then
            DeleteEntity(trowelProp)
        end
        
        -- Release animation dictionaries
        for _, dict in pairs(animDicts) do
            RemoveAnimDict(dict)
        end
        
        SetModelAsNoLongerNeeded(trowelHash)
        
        print("^2[BCC-Farming]^7 Enhanced planting animation completed")
    else
        print("^1[BCC-Farming]^7 Failed to create trowel prop, using fallback animation")
        PlayAnim('amb_work@world_human_farmer_rake@male_a@idle_a', 'idle_a', 16000, true, true)
    end
end

-- Utility function to clean up scenario props
local function CleanupScenarioProps(coords, radius)
    radius = radius or 3.0
    local propHashes = {
        GetHashKey('p_bucket02x'),
        GetHashKey('p_bucket01x'), 
        GetHashKey('p_feedbucket01x'),
        GetHashKey('p_bucket_metal01x'),
        GetHashKey('p_bucket_wood01x'),
        GetHashKey('p_bucket_water02x'),
        GetHashKey('p_bucket_water01x')
    }
    
    local propsDeleted = 0
    
    for _, propHash in pairs(propHashes) do
        local prop = GetClosestObjectOfType(coords.x, coords.y, coords.z, radius, propHash, false, false, false)
        if prop and prop ~= 0 and DoesEntityExist(prop) then
            -- Try multiple deletion methods for scenario props
            if not IsEntityAMissionEntity(prop) then
                -- Method 1: Standard deletion
                SetEntityAsMissionEntity(prop, false, true)
                DeleteEntity(prop)
                propsDeleted = propsDeleted + 1
                print(string.format("^3[BCC-Farming]^7 Cleaned scenario prop: %s", propHash))
            else
                -- Method 2: Force deletion for persistent props
                Citizen.InvokeNative(0x4CD38C78BD19136F, prop, true) -- SET_ENTITY_SHOULD_FREEZE_WAITING_ON_COLLISION
                SetEntityAsMissionEntity(prop, false, true)
                DeleteEntity(prop)
                
                -- Method 3: Fallback with DeleteObject
                if DoesEntityExist(prop) then
                    DeleteObject(prop)
                end
                
                propsDeleted = propsDeleted + 1
                print(string.format("^3[BCC-Farming]^7 Force cleaned persistent prop: %s", propHash))
            end
        end
    end
    
    return propsDeleted
end

RegisterNetEvent('bcc-farming:PlantingCrop', function(plantData)
    if CurrentPlants >= Config.plantSetup.maxPlants then
        SendClientFarmingNotification(_U('maxPlantsReached'))
        return
    end

    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local stop = false

    HidePedWeapons(playerPed, 2, true)

    -- Check distance using multi-stage props
    for _, plantCfg in pairs(Plants) do
        local checkProps = {}
        
        -- Check old single prop system
        if plantCfg.plantProp then
            table.insert(checkProps, plantCfg.plantProp)
        end
        
        -- Check new multi-stage prop system
        if plantCfg.plantProps then
            if plantCfg.plantProps.stage1 then table.insert(checkProps, plantCfg.plantProps.stage1) end
            if plantCfg.plantProps.stage2 then table.insert(checkProps, plantCfg.plantProps.stage2) end
            if plantCfg.plantProps.stage3 then table.insert(checkProps, plantCfg.plantProps.stage3) end
        end
        
        for _, propName in pairs(checkProps) do
            local entity = GetClosestObjectOfType(playerCoords.x, playerCoords.y, playerCoords.z, plantData.plantingDistance, joaat(propName), false, false, false)
            if entity ~= 0 then
                stop = true
                SendClientFarmingNotification(_U('tooCloseToAnotherPlant'))
                break
            end
        end
        
        if stop then break end
    end

    if stop then
        TriggerServerEvent('bcc-farming:AddSeedToInventory', plantData.seedName, plantData.seedAmount)
        return
    end

    if PlantingProcess then
        SendClientFarmingNotification(_U('FinishPlantingProcessFirst'))
        TriggerServerEvent('bcc-farming:AddSeedToInventory', plantData.seedName, plantData.seedAmount)
        return
    end

    PlantingProcess = true

    -- First, rake the area
    SendClientFarmingNotification(_U('raking'))
    PlayAnim('amb_work@world_human_farmer_rake@male_a@idle_a', 'idle_a', 8000, true, true)

    if IsEntityDead(playerPed) then
        SendClientFarmingNotification(_U('failed'))
        PlantingProcess = false
        TriggerServerEvent('bcc-farming:AddSeedToInventory', plantData.seedName, plantData.seedAmount)
        return
    end
    
    -- Then, enhanced planting animation with trowel
    PlayEnhancedPlantingAnimation(playerPed)

    if IsEntityDead(playerPed) then
        SendClientFarmingNotification(_U('failed'))
        PlantingProcess = false
        TriggerServerEvent('bcc-farming:AddSeedToInventory', plantData.seedName, plantData.seedAmount)
        return
    end

    if plantData.plantingToolRequired then
        TriggerServerEvent('bcc-farming:PlantToolUsage', plantData)
    end

    SendClientFarmingNotification(_U('plantingDone'))

    local x, y, z = table.unpack(GetOffsetFromEntityInWorldCoords(PlayerPedId(), 0.0, 0.75, 0.0))
    local plantCoords = vector3(x, y, z)

    -- Plant without automatic fertilizer - player can use fertilizers as usable items after planting
    TriggerServerEvent('bcc-farming:AddPlant', plantData, plantCoords, nil)
    TriggerEvent('bcc-farming:MaxPlantsAmount', 1)
    PlantingProcess = false
end)

-- Handle fertilizer animation and application
RegisterNetEvent('bcc-farming:StartFertilizerAnimation', function(plantId, fertilizerType)
    local playerPed = PlayerPedId()
    
    -- Hide weapon during fertilizer application
    HidePedWeapons(playerPed, 2, true)
    
    -- Play fertilizer application animation
    SendClientFarmingNotification('Aplicando fertilizante...')
    
    -- Store player position to find scenario props later
    local playerCoords = GetEntityCoords(playerPed)
    
    -- Start the WORLD_HUMAN_FEED_PIGS scenario
    ScenarioInPlace('WORLD_HUMAN_FEED_PIGS', 8000)
    
    -- Wait for animation to complete
    Wait(8000)
    
    -- Enhanced cleanup for scenario props
    ClearPedTasks(playerPed)
    ClearPedSecondaryTask(playerPed)
    
    -- Wait a frame for tasks to clear
    Wait(0)
    
    -- Clean up scenario props using utility function
    local propsDeleted = CleanupScenarioProps(playerCoords, 3.0)
    
    -- If props were found, do a second cleanup pass
    if propsDeleted > 0 then
        Wait(100) -- Give time for deletion
        CleanupScenarioProps(playerCoords, 3.0) -- Second pass
        print(string.format("^3[BCC-Farming]^7 Fertilizer scenario cleanup: %d props removed", propsDeleted))
    end
    
    -- Trigger server to apply fertilizer effect
    TriggerServerEvent('bcc-farming:ApplyFertilizer', plantId, fertilizerType)
    
    SendClientFarmingNotification('Fertilizante aplicado com sucesso!')
end)
