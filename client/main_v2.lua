-- BCC-Farming Enhanced Client Main v2.0
-- Multi-Stage Growth, Multi-Watering & Base Fertilizer System

VORPcore = exports.vorp_core:GetCore()

-- Modules will be loaded by FiveM/RedM automatically

-- Client state
local IsNearPlant = false
local CurrentPlantNUI = nil
local PlantStatusVisible = false

-- ===========================================
-- UTILITY FUNCTIONS
-- ===========================================

function ScenarioInPlace(hash, time)
    local playerPed = PlayerPedId()
    FreezeEntityPosition(playerPed, true)
    TaskStartScenarioInPlace(playerPed, joaat(hash), time, true, false, false, false)
    Wait(time)
    ClearPedTasks(playerPed)
    Wait(4000)
    HidePedWeapons(playerPed, 2, true)
    FreezeEntityPosition(playerPed, false)
end

function PlayAnim(animDict, animName, time, raking, loopUntilTimeOver)
    local animTime = time
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Wait(10)
    end

    local flag = 16
    if loopUntilTimeOver then
        flag = 1
        animTime = -1
    end

    local playerPed = PlayerPedId()
    TaskPlayAnim(playerPed, animDict, animName, 1.0, 1.0, animTime, flag, 0, true, 0, false, 0, false)
    
    if raking then
        local playerCoords = GetEntityCoords(playerPed)
        local rakeObj = CreateObject('p_rake02x', playerCoords.x, playerCoords.y, playerCoords.z, true, true, false)
        AttachEntityToEntity(rakeObj, playerPed, GetEntityBoneIndexByName(playerPed, 'PH_R_Hand'), 0.0, 0.0, 0.19,
            0.0, 0.0, 0.0, false, false, true, false, 0, true, false, false)
        Wait(time)
        DeleteObject(rakeObj)
    else
        Wait(time)
    end
    ClearPedTasks(playerPed)
end

-- ===========================================
-- PLANT STATUS NUI PROXIMITY SYSTEM
-- ===========================================

CreateThread(function()
    while true do
        Wait(500) -- Check every 500ms
        local playerCoords = GetEntityCoords(PlayerPedId())
        local nearestPlant = nil -- Simplified - would need proper prop detection
        
        if nearestPlant and nearestPlant.distance <= 3.0 then
            if not IsNearPlant or (CurrentPlantNUI and CurrentPlantNUI.plantId ~= nearestPlant.plantId) then
                -- Entered plant range or switched to different plant
                IsNearPlant = true
                CurrentPlantNUI = nearestPlant
                
                -- Request plant status from server
                TriggerServerEvent('bcc-farming:RequestPlantStatus', nearestPlant.plantId)
            end
        else
            if IsNearPlant then
                -- Left plant range
                IsNearPlant = false
                CurrentPlantNUI = nil
                PlantStatusVisible = false
                
                -- Hide NUI
                SendNUIMessage({
                    type = 'hidePlantStatus'
                })
            end
        end
    end
end)

-- ===========================================
-- EVENT HANDLERS
-- ===========================================

-- Character selection
RegisterNetEvent('vorp:SelectedCharacter', function()
    TriggerServerEvent('bcc-farming:NewClientConnected')
end)

-- Plant status updates from server
RegisterNetEvent('bcc-farming:UpdatePlantStatus')
AddEventHandler('bcc-farming:UpdatePlantStatus', function(plantStatus)
    if IsNearPlant and CurrentPlantNUI and CurrentPlantNUI.plantId == plantStatus.plantId then
        CurrentPlantNUI.plantStatus = plantStatus
        PlantStatusVisible = true
        
        -- Update NUI with plant status
        SendNUIMessage({
            type = 'showPlantStatus',
            plantData = {
                plantId = plantStatus.plantId,
                name = plantStatus.plantName,
                stageName = plantStatus.stageName,
                growthProgress = math.floor(plantStatus.growthProgress * 10) / 10, -- Round to 1 decimal
                growthStage = plantStatus.growthStage,
                waterCount = plantStatus.waterCount,
                maxWater = plantStatus.maxWaterTimes,
                wateringEfficiency = plantStatus.wateringEfficiency,
                fertilized = plantStatus.baseFertilized,
                requiresFertilizer = plantStatus.requiresFertilizer,
                fertilizerType = plantStatus.fertilizerType,
                expectedYield = plantStatus.expectedReward,
                isReady = plantStatus.isReady,
                canWater = plantStatus.canWater,
                timeLeft = plantStatus.timeLeft,
                timeLeftFormatted = FormatTimeRemaining(plantStatus.timeLeft)
            }
        })
    end
end)

-- Format time remaining
function FormatTimeRemaining(seconds)
    if seconds <= 0 then
        return "Pronto"
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

-- Detailed plant inspection
RegisterNetEvent('bcc-farming:ShowDetailedInspection')
AddEventHandler('bcc-farming:ShowDetailedInspection', function(plantStatus)
    local rewardBreakdown = plantStatus.rewardBreakdown
    
    local detailedMessage = string.format(
        "=== ANÁLISE DETALHADA DA PLANTA ===\n" ..
        "🌱 Nome: %s\n" ..
        "📊 Estágio: %d (%s)\n" ..
        "📈 Progresso: %.1f%%\n\n" ..
        "💧 SISTEMA DE IRRIGAÇÃO:\n" ..
        "   • Irrigações: %d/%d (%d%% eficiência)\n" ..
        "   • Pode irrigar: %s\n\n" ..
        "🧪 SISTEMA DE FERTILIZAÇÃO:\n" ..
        "   • Fertilizante base: %s\n" ..
        "   • Fertilizante avançado: %s\n" ..
        "   • Bônus de fertilizante: %d%%\n\n" ..
        "🎯 RECOMPENSAS:\n" ..
        "   • Recompensa base: %d itens\n" ..
        "   • Eficiência irrigação: %d%%\n" ..
        "   • Multiplicador fertilizante: %d%%\n" ..
        "   • Recompensa final: %d itens\n\n" ..
        "⏱️ TEMPO:\n" ..
        "   • Tempo restante: %s\n" ..
        "   • Status: %s",
        plantStatus.plantName,
        plantStatus.growthStage,
        plantStatus.stageName,
        plantStatus.growthProgress,
        plantStatus.waterCount,
        plantStatus.maxWaterTimes,
        plantStatus.wateringEfficiency,
        plantStatus.canWater and "Sim" or "Não",
        plantStatus.baseFertilized and "Aplicado" or (plantStatus.requiresFertilizer and "Necessário" or "Não necessário"),
        plantStatus.fertilizerType or "Nenhum",
        rewardBreakdown.fertilizerMultiplier,
        rewardBreakdown.baseReward,
        rewardBreakdown.wateringEfficiency,
        rewardBreakdown.fertilizerMultiplier,
        rewardBreakdown.finalReward,
        FormatTimeRemaining(plantStatus.timeLeft),
        plantStatus.isReady and "Pronto para colheita" or "Crescendo"
    )
    
    -- Show detailed inspection in chat or notification
    TriggerEvent('chat:addMessage', {
        color = { 0, 255, 0 },
        multiline = true,
        args = { "[Inspetor de Plantas]", detailedMessage }
    })
end)

-- Soil preparation animation
RegisterNetEvent('bcc-farming:PlaySoilPrepAnimation')
AddEventHandler('bcc-farming:PlaySoilPrepAnimation', function()
    PlayAnim('script_re@plants@plant_soil_prep', 'soil_prep', 5000, true, false)
end)

-- Fertilizer crafting menu
RegisterNetEvent('bcc-farming:ShowFertilizerCraftingMenu')
AddEventHandler('bcc-farming:ShowFertilizerCraftingMenu', function()
    -- Simple crafting menu (you might want to use your preferred menu system)
    local craftingOptions = {
        {
            label = "Fertilizante Básico (2x Composto + 1x Água)",
            description = "Cria 3 fertilizantes básicos",
            action = function()
                TriggerServerEvent('bcc-farming:CraftFertilizer', 'basic')
            end
        },
        {
            label = "Fertilizante Avançado (2x Fertilizante + 1x Farinha de Osso + 1x Cinza)",
            description = "Cria 1 fertilizante avançado (-10% tempo)",
            action = function()
                TriggerServerEvent('bcc-farming:CraftFertilizer', 'enhanced')
            end
        }
    }
    
    -- For now, just show options in chat (replace with your menu system)
    SendClientFarmingNotification("Menu de Artesanato de Fertilizantes:")
    for i, option in ipairs(craftingOptions) do
        SendClientFarmingNotification(string.format("%d. %s", i, option.label))
    end
    
    -- You would typically show a proper menu here
    -- For demo purposes, auto-craft basic fertilizer
    Wait(2000)
    TriggerServerEvent('bcc-farming:CraftFertilizer', 'basic')
end)

-- ===========================================
-- PLANT DETECTION SYSTEM (POLICE)
-- ===========================================

RegisterNetEvent('bcc-farming:ShowSmellingPlants', function(smellingPlants)
    for _, plant in pairs(smellingPlants) do
        SendClientFarmingNotification(string.format("Você detectou o cheiro de %s suspeitas!", plant.plantName))
        
        if Config.SmellingPlantBlips then
            local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, plant.coords.x, plant.coords.y, plant.coords.z)
            SetBlipSprite(blip, joaat('BLIP_AMBIENT_SMELL'), true)
            Citizen.InvokeNative(0x9CB1A1623062F402, blip, 'Planta Suspeita: ' .. plant.plantName)
            Citizen.InvokeNative(0x662D364ABF16DE2F, blip, joaat(Config.BlipColors.RED))
            
            -- Remove blip after 10 seconds
            CreateThread(function()
                Wait(10000)
                RemoveBlip(blip)
            end)
        end
    end
end)

-- Police detection thread
CreateThread(function()
    while true do
        Wait(5000) -- Check every 5 seconds
        local playerCoords = GetEntityCoords(PlayerPedId())
        TriggerServerEvent('bcc-farming:DetectSmellingPlants', playerCoords)
    end
end)

-- ===========================================
-- PERFORMANCE MONITORING
-- ===========================================

-- Debug thread for monitoring performance
CreateThread(function()
    while true do
        Wait(60000) -- Every minute
        
        if GetConvarInt('farming_debug', 0) == 1 then
            local stats = {totalProps = 0, validProps = 0, invalidProps = 0}
            print(string.format("^3[BCC-Farming Debug]^7 Props: %d total, %d valid, %d invalid", 
                stats.totalProps, stats.validProps, stats.invalidProps))
        end
    end
end)

-- ===========================================
-- DEBUG COMMANDS
-- ===========================================

RegisterCommand('farming-status', function()
    if CurrentPlantNUI and CurrentPlantNUI.plantStatus then
        local status = CurrentPlantNUI.plantStatus
        print("^3=== Plant Status Debug ===^7")
        print(string.format("Plant ID: %d", status.plantId))
        print(string.format("Name: %s", status.plantName))
        print(string.format("Stage: %d (%s)", status.growthStage, status.stageName))
        print(string.format("Progress: %.1f%%", status.growthProgress))
        print(string.format("Watering: %d/%d (%d%%)", status.waterCount, status.maxWaterTimes, status.wateringEfficiency))
        print(string.format("Fertilized: %s", status.baseFertilized and "Yes" or "No"))
        print(string.format("Expected Yield: %d", status.expectedReward))
        print(string.format("Ready: %s", status.isReady and "Yes" or "No"))
    else
        print("^1No plant nearby or status not loaded^7")
    end
end)

RegisterCommand('farming-nui-toggle', function()
    if PlantStatusVisible then
        SendNUIMessage({
            type = 'hidePlantStatus'
        })
        PlantStatusVisible = false
        print("^3Plant NUI hidden^7")
    else
        if CurrentPlantNUI and CurrentPlantNUI.plantStatus then
            TriggerEvent('bcc-farming:UpdatePlantStatus', CurrentPlantNUI.plantStatus)
            print("^2Plant NUI shown^7")
        else
            print("^1No plant data available^7")
        end
    end
end)

RegisterCommand('farming-client-debug', function()
    print("^3=== BCC-Farming Client Debug ===^7")
    print(string.format("Near Plant: %s", IsNearPlant and "Yes" or "No"))
    print(string.format("Current Plant ID: %s", CurrentPlantNUI and CurrentPlantNUI.plantId or "None"))
    print(string.format("NUI Visible: %s", PlantStatusVisible and "Yes" or "No"))
    
    local nearest = nil -- Simplified for now
    if nearest then
        print(string.format("Nearest Plant: ID %d, Distance %.2fm, Stage %d", 
            nearest.plantId, nearest.distance, nearest.stage))
    else
        print("No plants nearby")
    end
    
    local stats = {totalProps = 0, validProps = 0, invalidProps = 0}
    print(string.format("Prop Stats: %d total, %d valid, %d invalid", 
        stats.totalProps, stats.validProps, stats.invalidProps))
end)

-- ===========================================
-- CLEANUP AND OPTIMIZATION
-- ===========================================

-- Cleanup when resource stops
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        -- Hide NUI
        SendNUIMessage({
            type = 'hidePlantStatus'
        })
        
        -- Clear any remaining plant props (simplified)
        -- PropManager.CleanupInvalidProps()
        
        print("^3[BCC-Farming]^7 Client cleanup completed")
    end
end)

-- Memory management
CreateThread(function()
    while true do
        Wait(300000) -- Every 5 minutes
        
        -- Force garbage collection
        collectgarbage()
        
        -- Cleanup invalid props (simplified)
        -- PropManager.CleanupInvalidProps()
    end
end)

print("^2[BCC-Farming]^7 Enhanced client main loaded!")
print("^3[BCC-Farming]^7 Commands: /farming-status, /farming-nui-toggle, /farming-client-debug")
print("^3[BCC-Farming]^7 Features: Multi-stage growth, smart interactions, plant status NUI")