-- =======================================
-- BCC-Farming Stage Debug Commands
-- =======================================

-- Command to test stage progression
RegisterCommand('teststage', function(source, args, rawCommand)
    local plantId = tonumber(args[1]) or 1
    local newStage = tonumber(args[2]) or 2
    
    if not plantId or not newStage then
        print("Usage: /teststage [plantId] [stage]")
        return
    end
    
    print(string.format("^3[Debug]^7 Testing stage update for plant %d to stage %d", plantId, newStage))
    
    -- Simulate server stage update with appropriate progress
    local progress = 0
    if newStage == 1 then progress = 20
    elseif newStage == 2 then progress = 50  
    elseif newStage == 3 then progress = 85
    end
    
    TriggerEvent('bcc-farming:UpdatePlantStageData', plantId, newStage, progress)
end, false)

-- Command to force growth progress (server-side test)
RegisterCommand('forceprogress', function(source, args, rawCommand)
    local src = source
    local plantId = tonumber(args[1]) or 1
    local progress = tonumber(args[2]) or 50
    
    if src == 0 then return end -- Only from players
    
    print(string.format("^3[Debug Server]^7 Forcing progress %d%% for plant %d", progress, plantId))
    
    -- Calculate stage based on progress
    local stage = 1
    if progress >= 66.67 then stage = 3
    elseif progress >= 33.33 then stage = 2
    end
    
    -- Update database directly for testing
    MySQL.update('UPDATE `bcc_farming` SET `growth_stage` = ?, `growth_progress` = ? WHERE `plant_id` = ?', 
        { stage, progress, plantId }, function(rowsChanged)
            if rowsChanged > 0 then
                print(string.format("^2[Debug Server]^7 Plant %d updated to stage %d with %.1f%% progress", plantId, stage, progress))
                TriggerClientEvent('bcc-farming:UpdatePlantStageData', -1, plantId, stage, progress)
            else
                print(string.format("^1[Debug Server]^7 Failed to update plant %d", plantId))
            end
        end)
end, false)

-- Command to check prop management status
RegisterCommand('checkprops', function()
    if PropManager then
        local stats = PropManager.GetPropStats()
        print("^3=== PropManager Status ===^7")
        print(string.format("PropManager Available: ^2YES^7"))
        print(string.format("Total Props: %d", stats.totalProps))
        print(string.format("Valid Props: %d", stats.validProps))
        print(string.format("Invalid Props: %d", stats.invalidProps))
        print(string.format("Stage 1: %d | Stage 2: %d | Stage 3: %d", 
            stats.propsByStage.stage1, stats.propsByStage.stage2, stats.propsByStage.stage3))
    else
        print("^1PropManager NOT AVAILABLE^7")
    end
end, false)

-- Command to force a stage update for nearest plant
RegisterCommand('forcestage', function(source, args, rawCommand)
    local newStage = tonumber(args[1]) or 2
    
    if PropManager then
        local nearest = PropManager.GetNearestPlant(5.0)
        if nearest then
            print(string.format("^3[Debug]^7 Forcing stage %d for nearest plant %d", newStage, nearest.plantId))
            
            if nearest.propData and nearest.propData.plantConfig then
                local success = PropManager.UpdatePlantStage(nearest.plantId, newStage, nearest.propData.plantConfig)
                if success then
                    print(string.format("^2[Debug]^7 Successfully updated plant %d to stage %d", nearest.plantId, newStage))
                else
                    print(string.format("^1[Debug]^7 Failed to update plant %d to stage %d", nearest.plantId, newStage))
                end
            else
                print("^1[Debug]^7 No plant config found for nearest plant")
            end
        else
            print("^1[Debug]^7 No plants found nearby")
        end
    else
        print("^1[Debug]^7 PropManager not available")
    end
end, false)

-- Command to list plants with stage info
RegisterCommand('listplants', function()
    if not Crops then
        print("^1[Debug]^7 Crops table not available")
        return
    end
    
    local count = 0
    print("^3=== Plant Status ===^7")
    
    for plantId, cropData in pairs(Crops) do
        if cropData and not cropData.removePlant then
            count = count + 1
            local stage = cropData.currentStage or 1
            local progress = cropData.growthProgress or 0
            
            print(string.format("Plant %d: Stage %d, Progress %.1f%%", plantId, stage, progress))
            
            -- Check PropManager data
            if PropManager then
                local propData = PropManager.GetPlantPropData(plantId)
                if propData then
                    print(string.format("  - Prop: %s (Stage %d)", propData.propName, propData.stage))
                else
                    print("  - No PropManager data")
                end
            end
        end
    end
    
    if count == 0 then
        print("No plants found")
    end
end, false)

-- Command to test prop cleanup
RegisterCommand('testcleanup', function(source, args, rawCommand)
    if PropManager then
        local nearest = PropManager.GetNearestPlant(5.0)
        if nearest then
            print(string.format("^3[Debug]^7 Testing prop cleanup for plant %d", nearest.plantId))
            
            -- Force removal and recreation
            PropManager.RemovePlantProp(nearest.plantId)
            
            Wait(1000) -- Wait 1 second
            
            -- Recreate at stage 1
            if nearest.plantData and nearest.plantData.plantConfig then
                local newProp = PropManager.CreatePlantProp(nearest.plantId, nearest.plantData.plantConfig, nearest.coords, 1)
                if newProp then
                    print(string.format("^2[Debug]^7 Successfully recreated plant %d", nearest.plantId))
                else
                    print(string.format("^1[Debug]^7 Failed to recreate plant %d", nearest.plantId))
                end
            end
        else
            print("^1[Debug]^7 No plants found nearby")
        end
    else
        print("^1[Debug]^7 PropManager not available")
    end
end, false)

-- Command to clean up scenario props manually
RegisterCommand('cleanprops', function(source, args, rawCommand)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local radius = tonumber(args[1]) or 5.0
    
    print(string.format("^3[Debug]^7 Cleaning scenario props in %.1f radius around player", radius))
    
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
        local prop = GetClosestObjectOfType(playerCoords.x, playerCoords.y, playerCoords.z, radius, propHash, false, false, false)
        while prop and prop ~= 0 and DoesEntityExist(prop) do
            if not IsEntityAMissionEntity(prop) then
                SetEntityAsMissionEntity(prop, false, true)
                DeleteEntity(prop)
                propsDeleted = propsDeleted + 1
                print(string.format("^2[Debug]^7 Deleted prop: %s", propHash))
            else
                -- Mission entity, try DeleteObject
                DeleteObject(prop)
                propsDeleted = propsDeleted + 1
                print(string.format("^2[Debug]^7 Force deleted mission prop: %s", propHash))
            end
            
            -- Check for another prop of same type
            prop = GetClosestObjectOfType(playerCoords.x, playerCoords.y, playerCoords.z, radius, propHash, false, false, false)
        end
    end
    
    if propsDeleted > 0 then
        print(string.format("^2[Debug]^7 Cleaned up %d scenario props", propsDeleted))
    else
        print("^3[Debug]^7 No scenario props found to clean")
    end
end, false)

-- Command to test enhanced planting animation
RegisterCommand('testplantanim', function(source, args, rawCommand)
    local playerPed = PlayerPedId()
    
    if IsPedInAnyVehicle(playerPed, false) then
        print("^1[Debug]^7 Cannot test planting animation while in vehicle")
        return
    end
    
    print("^3[Debug]^7 Testing enhanced planting animation with trowel...")
    
    -- Call the enhanced planting animation function
    TriggerEvent('bcc-farming:TestPlantingAnimation')
end, false)

-- Test event for planting animation
RegisterNetEvent('bcc-farming:TestPlantingAnimation', function()
    local playerPed = PlayerPedId()
    
    -- Load trowel prop
    local trowelHash = GetHashKey('p_trowel01x')
    RequestModel(trowelHash)
    
    local attempts = 0
    while not HasModelLoaded(trowelHash) and attempts < 100 do
        Wait(10)
        attempts = attempts + 1
    end
    
    if not HasModelLoaded(trowelHash) then
        print("^1[Debug]^7 Failed to load trowel model")
        return
    end
    
    -- Create trowel prop
    local trowelProp = CreateObject(trowelHash, 0.0, 0.0, 0.0, true, true, false)
    
    if trowelProp and DoesEntityExist(trowelProp) then
        -- Attach trowel to right hand
        local boneIndex = GetEntityBoneIndexByName(playerPed, 'SKEL_R_HAND')
        if boneIndex == -1 then
            boneIndex = GetPedBoneIndex(playerPed, 57005)
        end
        
        AttachEntityToEntity(trowelProp, playerPed, boneIndex, 
            0.09, 0.03, -0.02, -87.5, 25, 4, false, false, false, false, 2, true)
        
        print("^2[Debug]^7 Trowel attached, starting animation sequence...")
        
        -- Load animation dictionaries
        local animDicts = {
            'amb_camp@world_camp_jack_plant@enter',
            'amb_camp@world_camp_jack_plant@base',
            'amb_camp@world_camp_jack_plant@idle_a',
            'amb_camp@world_camp_jack_plant@exit'
        }
        
        for _, dict in pairs(animDicts) do
            RequestAnimDict(dict)
            while not HasAnimDictLoaded(dict) do
                Wait(10)
            end
        end
        
        -- Quick test sequence
        TaskPlayAnim(playerPed, 'amb_camp@world_camp_jack_plant@enter', 'enter', 8.0, -8.0, -1, 1, 0.0, false, false, false)
        Wait(2000)
        TaskPlayAnim(playerPed, 'amb_camp@world_camp_jack_plant@idle_a', 'idle_a', 8.0, -8.0, -1, 1, 0.0, false, false, false)
        Wait(3000)
        TaskPlayAnim(playerPed, 'amb_camp@world_camp_jack_plant@exit', 'exit', 8.0, -8.0, -1, 1, 0.0, false, false, false)
        Wait(2000)
        
        -- Clean up
        ClearPedTasks(playerPed)
        if DoesEntityExist(trowelProp) then
            DeleteEntity(trowelProp)
        end
        
        for _, dict in pairs(animDicts) do
            RemoveAnimDict(dict)
        end
        
        SetModelAsNoLongerNeeded(trowelHash)
        print("^2[Debug]^7 Planting animation test completed")
    else
        print("^1[Debug]^7 Failed to create trowel prop")
    end
end)

-- Command to test ground placement
RegisterCommand('testground', function(source, args, rawCommand)
    if PropManager then
        local nearest = PropManager.GetNearestPlant(5.0)
        if nearest then
            local entity = nearest.propData.entity
            if entity and DoesEntityExist(entity) then
                local oldPos = GetEntityCoords(entity)
                print(string.format("^3[Debug]^7 Plant %d current position: X=%.2f, Y=%.2f, Z=%.2f", 
                    nearest.plantId, oldPos.x, oldPos.y, oldPos.z))
                
                -- Test ground placement
                PlaceObjectOnGroundProperly(entity)
                Wait(100)
                
                local newPos = GetEntityCoords(entity)
                print(string.format("^2[Debug]^7 Plant %d new position: X=%.2f, Y=%.2f, Z=%.2f (ΔZ=%.2f)", 
                    nearest.plantId, newPos.x, newPos.y, newPos.z, newPos.z - oldPos.z))
                
                -- Update stored coordinates
                nearest.propData.coords = {x = newPos.x, y = newPos.y, z = newPos.z}
            else
                print("^1[Debug]^7 Nearest plant entity not found")
            end
        else
            print("^1[Debug]^7 No plants found nearby")
        end
    else
        print("^1[Debug]^7 PropManager not available")
    end
end, false)

print("^2[BCC-Farming]^7 Stage debug commands loaded!")
print("^2[BCC-Farming]^7 Commands: /teststage, /checkprops, /forcestage, /listplants, /testcleanup, /cleanprops [radius], /testplantanim, /testground")