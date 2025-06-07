-- BCC-Farming Enhanced Plant Interactions v2.0
-- Multi-Watering, Fertilizer, and Growth Stage Interactions

-- PropManager functions will be available globally

local PlantInteractions = {}

-- Prompt variables
local WaterPrompt, FertilizerPrompt, HarvestPrompt, DestroyPrompt, InspectPrompt
local PromptGroup = GetRandomIntInRange(0, 0xffffff)
local PromptsStarted = false

-- Current interaction state
local CurrentPlant = nil
local NearPlant = false
local InteractionRange = 2.5

-- ===========================================
-- PROMPT SYSTEM
-- ===========================================

local function StartPrompts()
    if PromptsStarted then return end
    
    -- Water Prompt
    WaterPrompt = PromptRegisterBegin()
    PromptSetControlAction(WaterPrompt, Config.keys.water)
    PromptSetText(WaterPrompt, CreateVarString(10, 'LITERAL_STRING', 'Water Plant'))
    PromptSetVisible(WaterPrompt, false)
    PromptSetEnabled(WaterPrompt, false)
    PromptSetHoldMode(WaterPrompt, 2000)
    PromptSetGroup(WaterPrompt, PromptGroup, 0)
    PromptRegisterEnd(WaterPrompt)
    
    -- Fertilizer Prompt  
    FertilizerPrompt = PromptRegisterBegin()
    PromptSetControlAction(FertilizerPrompt, Config.keys.fertYes)
    PromptSetText(FertilizerPrompt, CreateVarString(10, 'LITERAL_STRING', 'Apply Fertilizer'))
    PromptSetVisible(FertilizerPrompt, false)
    PromptSetEnabled(FertilizerPrompt, false)
    PromptSetHoldMode(FertilizerPrompt, 2000)
    PromptSetGroup(FertilizerPrompt, PromptGroup, 0)
    PromptRegisterEnd(FertilizerPrompt)
    
    -- Harvest Prompt
    HarvestPrompt = PromptRegisterBegin()
    PromptSetControlAction(HarvestPrompt, Config.keys.harvest)
    PromptSetText(HarvestPrompt, CreateVarString(10, 'LITERAL_STRING', 'Harvest Plant'))
    PromptSetVisible(HarvestPrompt, false)
    PromptSetEnabled(HarvestPrompt, false)
    PromptSetHoldMode(HarvestPrompt, 2000)
    PromptSetGroup(HarvestPrompt, PromptGroup, 0)
    PromptRegisterEnd(HarvestPrompt)
    
    -- Destroy Prompt
    DestroyPrompt = PromptRegisterBegin()
    PromptSetControlAction(DestroyPrompt, Config.keys.destroy)
    PromptSetText(DestroyPrompt, CreateVarString(10, 'LITERAL_STRING', 'Destroy Plant'))
    PromptSetVisible(DestroyPrompt, false)
    PromptSetEnabled(DestroyPrompt, false)
    PromptSetHoldMode(DestroyPrompt, 2000)
    PromptSetGroup(DestroyPrompt, PromptGroup, 0)
    PromptRegisterEnd(DestroyPrompt)
    
    -- Inspect Prompt
    InspectPrompt = PromptRegisterBegin()
    PromptSetControlAction(InspectPrompt, 0x8FFC75D6) -- Tab key
    PromptSetText(InspectPrompt, CreateVarString(10, 'LITERAL_STRING', 'Inspect Plant'))
    PromptSetVisible(InspectPrompt, false)
    PromptSetEnabled(InspectPrompt, false)
    PromptSetHoldMode(InspectPrompt, 500)
    PromptSetGroup(InspectPrompt, PromptGroup, 0)
    PromptRegisterEnd(InspectPrompt)
    
    PromptsStarted = true
end

-- Update prompt visibility based on plant state
local function UpdatePrompts(plantData, plantStatus)
    if not plantData or not plantStatus then
        PromptSetVisible(WaterPrompt, false)
        PromptSetVisible(FertilizerPrompt, false)
        PromptSetVisible(HarvestPrompt, false)
        PromptSetVisible(DestroyPrompt, false)
        PromptSetVisible(InspectPrompt, false)
        return
    end
    
    -- Always show inspect
    PromptSetVisible(InspectPrompt, true)
    PromptSetEnabled(InspectPrompt, true)
    
    -- Water prompt - show if plant can be watered
    local canWater = plantStatus.canWater or false
    PromptSetVisible(WaterPrompt, canWater)
    PromptSetEnabled(WaterPrompt, canWater)
    
    if canWater then
        local waterText = string.format("Water Plant (%d/%d)", 
            plantStatus.waterCount or 0, plantStatus.maxWaterTimes or 1)
        PromptSetText(WaterPrompt, CreateVarString(10, 'LITERAL_STRING', waterText))
    end
    
    -- Fertilizer prompt - show if plant needs base fertilizer or can use enhanced fertilizer
    local needsFertilizer = plantStatus.requiresFertilizer and not plantStatus.baseFertilized
    local canFertilize = needsFertilizer or (plantStatus.baseFertilized and not plantStatus.fertilizerType)
    PromptSetVisible(FertilizerPrompt, canFertilize)
    PromptSetEnabled(FertilizerPrompt, canFertilize)
    
    if canFertilize then
        local fertText = needsFertilizer and "Apply Base Fertilizer" or "Apply Enhanced Fertilizer"
        PromptSetText(FertilizerPrompt, CreateVarString(10, 'LITERAL_STRING', fertText))
    end
    
    -- Harvest prompt - show if plant is ready
    local isReady = plantStatus.isReady or false
    PromptSetVisible(HarvestPrompt, isReady)
    PromptSetEnabled(HarvestPrompt, isReady)
    
    -- Destroy prompt - always available
    PromptSetVisible(DestroyPrompt, true)
    PromptSetEnabled(DestroyPrompt, true)
end

-- ===========================================
-- INTERACTION FUNCTIONS
-- ===========================================

-- Handle watering interaction
local function HandleWateringInteraction(plantId, plantData, plantStatus)
    if not plantStatus.canWater then
        VORPcore.NotifyRightTip("This plant doesn't need watering right now", 4000)
        return
    end
    
    -- Play watering animation
    PlayAnim('script_re@plants@plant_water', 'plant_water', 5000, false, false)
    
    -- Call server to handle watering
    VORPcore.Callback.TriggerAwait('bcc-farming:ManagePlantWateredStatus', function(result)
        if result.success then
            VORPcore.NotifyRightTip(result.message, 4000)
            
            -- Request updated plant status
            TriggerServerEvent('bcc-farming:RequestPlantStatus', plantId)
        else
            VORPcore.NotifyRightTip(result.message, 4000)
        end
    end, plantId)
end

-- Handle fertilizer interaction
local function HandleFertilizerInteraction(plantId, plantData, plantStatus)
    -- Determine which fertilizer to use
    local fertilizerToUse = nil
    
    if plantStatus.requiresFertilizer and not plantStatus.baseFertilized then
        -- Need base fertilizer (simplified)
        fertilizerToUse = 'fertilizer'
    else
        -- Can use enhanced fertilizer - show selection menu
        ShowFertilizerSelectionMenu(plantId)
        return
    end
    
    -- Check if player has the fertilizer
    -- This would typically be checked server-side, but we'll trigger the server event
    TriggerServerEvent('bcc-farming:ApplyFertilizer', plantId, fertilizerToUse)
end

-- Show fertilizer selection menu
function ShowFertilizerSelectionMenu(plantId)
    local fertilizerOptions = {}
    
    -- Add enhanced fertilizers from config
    if FertilizerConfig and FertilizerConfig.enhancedFertilizers then
        for _, fertilizer in pairs(FertilizerConfig.enhancedFertilizers) do
            table.insert(fertilizerOptions, {
                label = fertilizer.label .. string.format(" (-%d%% time)", math.floor(fertilizer.fertTimeReduction * 100)),
                value = fertilizer.fertName,
                reduction = fertilizer.fertTimeReduction
            })
        end
    end
    
    -- Simple menu system (you might want to use your preferred menu system)
    local selectedFertilizer = nil
    
    -- For now, just use the first available enhanced fertilizer
    if #fertilizerOptions > 0 then
        selectedFertilizer = fertilizerOptions[1].value
        TriggerServerEvent('bcc-farming:ApplyFertilizer', plantId, selectedFertilizer)
    else
        VORPcore.NotifyRightTip("No enhanced fertilizers available", 4000)
    end
end

-- Handle harvest interaction
local function HandleHarvestInteraction(plantId, plantData, plantStatus)
    if not plantStatus.isReady then
        VORPcore.NotifyRightTip("Plant is not ready for harvest", 4000)
        return
    end
    
    -- Play harvesting animation
    PlayAnim('script_re@plants@plant_gather', 'plant_gather', 5000, false, false)
    
    -- Call server to handle harvesting
    VORPcore.Callback.TriggerAwait('bcc-farming:HarvestCheck', function(result)
        if result.success then
            VORPcore.NotifyRightTip("Plant harvested successfully!", 4000)
        else
            VORPcore.NotifyRightTip(result.message, 4000)
        end
    end, plantId, false)
end

-- Handle destroy interaction
local function HandleDestroyInteraction(plantId, plantData, plantStatus)
    -- Confirmation prompt
    VORPcore.NotifyRightTip("Hold to confirm plant destruction...", 2000)
    
    Wait(2000) -- Simple confirmation delay
    
    -- Play destruction animation
    PlayAnim('script_re@plants@plant_destroy', 'plant_destroy', 3000, false, false)
    
    -- Call server to handle destruction
    VORPcore.Callback.TriggerAwait('bcc-farming:HarvestCheck', function(result)
        if result.success then
            VORPcore.NotifyRightTip("Plant destroyed", 4000)
        else
            VORPcore.NotifyRightTip("Failed to destroy plant", 4000)
        end
    end, plantId, true)
end

-- Handle inspect interaction
local function HandleInspectInteraction(plantId, plantData, plantStatus)
    if not plantStatus then
        VORPcore.NotifyRightTip("Unable to inspect plant", 4000)
        return
    end
    
    -- Format inspection message
    local inspectMessage = string.format(
        "🌱 %s (Stage %d: %s)\n" ..
        "📈 Growth: %.1f%%\n" ..
        "💧 Watering: %d/%d (%d%%)\n" ..
        "🧪 Fertilizer: %s\n" ..
        "🎯 Expected Yield: %d items\n" ..
        "⏱️ Time Left: %s",
        plantStatus.plantName,
        plantStatus.growthStage,
        plantStatus.stageName,
        plantStatus.growthProgress,
        plantStatus.waterCount,
        plantStatus.maxWaterTimes,
        plantStatus.wateringEfficiency,
        plantStatus.baseFertilized and "Applied" or "Needed",
        plantStatus.expectedReward,
        FormatTimeRemaining(plantStatus.timeLeft)
    )
    
    VORPcore.NotifyRightTip(inspectMessage, 8000)
end

-- ===========================================
-- UTILITY FUNCTIONS
-- ===========================================

-- Format time remaining in readable format
function FormatTimeRemaining(seconds)
    if seconds <= 0 then
        return "Ready"
    end
    
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    
    if hours > 0 then
        return string.format("%dh %dm", hours, minutes)
    elseif minutes > 0 then
        return string.format("%dm %ds", minutes, secs)
    else
        return string.format("%ds", secs)
    end
end

-- ===========================================
-- MAIN INTERACTION LOOP
-- ===========================================

CreateThread(function()
    while true do
        Wait(500)
        
        if not PromptsStarted then
            StartPrompts()
        end
        
        local playerCoords = GetEntityCoords(PlayerPedId())
        local nearestPlant = nil -- Simplified - prop detection disabled for now
        
        if nearestPlant then
            if not NearPlant or (CurrentPlant and CurrentPlant.plantId ~= nearestPlant.plantId) then
                -- Entered plant range or switched to different plant
                NearPlant = true
                CurrentPlant = nearestPlant
                
                -- Request plant status from server
                TriggerServerEvent('bcc-farming:RequestPlantStatus', nearestPlant.plantId)
            end
            
            -- Show prompt group
            local promptText = string.format("Plant Interactions - %s", nearestPlant.plantData and nearestPlant.plantData.plantName or "Unknown")
            PromptSetActiveGroupThisFrame(PromptGroup, CreateVarString(10, 'LITERAL_STRING', promptText), 0, 0, 0, 0)
            
            -- Handle prompt inputs
            if PromptHasHoldModeCompleted(WaterPrompt) then
                HandleWateringInteraction(nearestPlant.plantId, nearestPlant.plantData, nearestPlant.plantStatus)
            end
            
            if PromptHasHoldModeCompleted(FertilizerPrompt) then
                HandleFertilizerInteraction(nearestPlant.plantId, nearestPlant.plantData, nearestPlant.plantStatus)
            end
            
            if PromptHasHoldModeCompleted(HarvestPrompt) then
                HandleHarvestInteraction(nearestPlant.plantId, nearestPlant.plantData, nearestPlant.plantStatus)
            end
            
            if PromptHasHoldModeCompleted(DestroyPrompt) then
                HandleDestroyInteraction(nearestPlant.plantId, nearestPlant.plantData, nearestPlant.plantStatus)
            end
            
            if PromptHasHoldModeCompleted(InspectPrompt) then
                HandleInspectInteraction(nearestPlant.plantId, nearestPlant.plantData, nearestPlant.plantStatus)
            end
            
        else
            if NearPlant then
                -- Left plant range
                NearPlant = false
                CurrentPlant = nil
                
                -- Hide all prompts
                UpdatePrompts(nil, nil)
            end
        end
    end
end)

-- ===========================================
-- EVENT HANDLERS
-- ===========================================

-- Handle plant status updates from server
RegisterNetEvent('bcc-farming:UpdatePlantStatus')
AddEventHandler('bcc-farming:UpdatePlantStatus', function(plantStatus)
    if CurrentPlant and CurrentPlant.plantId == plantStatus.plantId then
        CurrentPlant.plantStatus = plantStatus
        
        -- Update the plant data (simplified)
        -- PropManager disabled for now
        
        -- Update prompts based on new status
        UpdatePrompts(CurrentPlant.plantData, plantStatus)
    end
end)

-- Handle plant watering updates
RegisterNetEvent('bcc-farming:UpdateClientPlantWateredStatus')
AddEventHandler('bcc-farming:UpdateClientPlantWateredStatus', function(updateData)
    -- Update local plant data (simplified)
    if type(updateData) == "table" and updateData.plantId then
        -- PropManager disabled for now
        
        -- If this is the current plant, request updated status
        if CurrentPlant and CurrentPlant.plantId == updateData.plantId then
            TriggerServerEvent('bcc-farming:RequestPlantStatus', updateData.plantId)
        end
    end
end)

-- Handle fertilizer updates
RegisterNetEvent('bcc-farming:UpdatePlantFertilizer')
AddEventHandler('bcc-farming:UpdatePlantFertilizer', function(updateData)
    if updateData and updateData.plantId then
        -- PropManager disabled for now
        
        -- If this is the current plant, request updated status
        if CurrentPlant and CurrentPlant.plantId == updateData.plantId then
            TriggerServerEvent('bcc-farming:RequestPlantStatus', updateData.plantId)
        end
    end
end)

-- Export the module
return PlantInteractions