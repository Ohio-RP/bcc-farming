# 📚 BCC-Farming: Documentação Completa do Sistema de Cultivo

## 🌱 Visão Geral do Sistema

O BCC-Farming v2.5.0 é um sistema completo de agricultura para RedM que implementa:
- **Sistema de crescimento em 3 estágios visuais**
- **Sistema de irrigação múltipla (1-3 regas)**
- **Sistema de fertilização avançado**
- **Cronômetro de crescimento que inicia na primeira rega**
- **Interface NUI em tempo real**
- **Sistema de colheita automática**

---

## 🌿 ETAPA 1: PLANTAÇÃO

### 1.1 Preparação e Verificações Iniciais

**Arquivo:** `server/services/usableItems_v2.lua:14-134`

Quando o jogador usa uma semente (item usável), o sistema executa as seguintes verificações:

#### ✅ Verificações de Localização
```lua
-- Verificação de proximidade com cidades
if not Config.townSetup.canPlantInTowns then
    for _, townCfg in pairs(Config.townSetup.townLocations) do
        if #(playerCoords - townCfg.coords) <= townCfg.townRange then
            VORPcore.NotifyRightTip(src, _U('tooCloseToTown'), 4000)
            -- Bloqueia plantação
        end
    end
end
```

#### ✅ Verificações de Trabalho (Job)
```lua
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
        -- Bloqueia plantação
    end
end
```

#### ✅ Verificações de Recursos
- **Solo necessário:** Verifica se o jogador tem solo suficiente
- **Ferramenta de plantio:** Verifica se tem enxada ou ferramenta necessária
- **Limite de plantas:** Verifica se não excedeu o máximo (Config.plantSetup.maxPlants)
- **Quantidade de sementes:** Verifica se tem sementes suficientes

### 1.2 Processo de Plantação

**Arquivo:** `client/services/planting.lua:38-157`

#### 🎯 Verificação de Proximidade
```lua
-- Verifica se não há plantas muito próximas (todos os estágios visuais)
for _, plantCfg in pairs(Plants) do
    local checkProps = {}
    
    -- Sistema antigo (prop único)
    if plantCfg.plantProp then
        table.insert(checkProps, plantCfg.plantProp)
    end
    
    -- Sistema novo (props multi-estágio)
    if plantCfg.plantProps then
        if plantCfg.plantProps.stage1 then table.insert(checkProps, plantCfg.plantProps.stage1) end
        if plantCfg.plantProps.stage2 then table.insert(checkProps, plantCfg.plantProps.stage2) end
        if plantCfg.plantProps.stage3 then table.insert(checkProps, plantCfg.plantProps.stage3) end
    end
    
    for _, propName in pairs(checkProps) do
        local entity = GetClosestObjectOfType(playerCoords.x, playerCoords.y, playerCoords.z, 
                                           plantData.plantingDistance, joaat(propName), false, false, false)
        if entity ~= 0 then
            -- Muito próximo de outra planta
            SendClientFarmingNotification(_U('tooCloseToAnotherPlant'))
            return
        end
    end
end
```

#### 🎬 Animação Melhorada de Plantio
O sistema utiliza uma sequência de animações em duas fases:

**Fase 1: Preparação do Terreno (8 segundos)**
```lua
SendClientFarmingNotification(_U('raking'))
PlayAnim('amb_work@world_human_farmer_rake@male_a@idle_a', 'idle_a', 8000, true, true)
```

**Fase 2: Plantio com Trowel (13 segundos)**
```lua
-- Carrega e anexa prop p_trowel01x à mão direita (SKEL_R_HAND)
local trowelProp = CreateObject(GetHashKey('p_trowel01x'), 0.0, 0.0, 0.0, true, true, false)
local boneIndex = GetEntityBoneIndexByName(playerPed, 'SKEL_R_HAND')
if boneIndex == -1 then
    boneIndex = GetPedBoneIndex(playerPed, 57005) -- Fallback bone
end

AttachEntityToEntity(trowelProp, playerPed, boneIndex, 
    0.09, 0.03, -0.02,  -- position
    -87.5, 25, 4,       -- rotation
    false, false, false, false, 2, true)

-- Sequência de animações Jack Plant:
1. 'amb_camp@world_camp_jack_plant@enter' → 'enter' (2s) - "Preparando terreno..."
2. 'amb_camp@world_camp_jack_plant@base' → 'base' (2s)
3. 'amb_camp@world_camp_jack_plant@idle_a' → 'idle_c' (3s) - "Cavando buraco para semente..."
4. 'amb_camp@world_camp_jack_plant@idle_a' → 'idle_b' (3s) - "Posicionando semente no buraco..."
5. 'amb_camp@world_camp_jack_plant@idle_a' → 'idle_a' (3s)
6. 'amb_camp@world_camp_jack_plant@exit' → 'exit' (2s) - "Finalizando plantio..."

-- Remove trowel e limpa recursos
DeleteEntity(trowelProp)
```

#### 🧪 Sistema de Fertilização Inteligente
O sistema verifica automaticamente os fertilizantes disponíveis:

```lua
-- Verificação de fertilizante básico
local baseFertilizerItem = plant.baseFertilizerItem or 'fertilizer'
local hasBaseFertilizer = exports.vorp_inventory:getItemCount(src, nil, baseFertilizerItem) > 0

-- Verificação de fertilizantes aprimorados
local bestEnhancedFertilizer = nil
if Config.fertilizerSetup then
    for _, fert in pairs(Config.fertilizerSetup) do
        local fertCount = exports.vorp_inventory:getItemCount(src, nil, fert.fertName)
        if fertCount > 0 then
            if not bestEnhancedFertilizer or fert.fertTimeReduction > bestEnhancedFertilizer.fertTimeReduction then
                bestEnhancedFertilizer = fert -- Escolhe o melhor fertilizante
            end
        end
    end
end
```

#### 🧪 Sistema de Fertilização Manual
O sistema de fertilização não é mais automático durante o plantio. Os jogadores podem usar qualquer fertilizante do inventário como item usável independentemente, escolhendo qual aplicar conforme sua estratégia.

### 1.3 Criação da Planta no Servidor

**Arquivo:** `server/main.lua:17-73`

```lua
RegisterServerEvent('bcc-farming:AddPlant', function(plantData, plantCoords, fertilizerUsed)
    -- Inicializa valores v2.5.0
    local growthStage = 1  -- Sempre começa no estágio 1
    local growthProgress = 0.0  -- 0% de progresso
    local waterCount = 0  -- Nenhuma rega inicial
    local maxWaterTimes = plantData.waterTimes or 1  -- Configuração da planta
    local baseFertilized = fertilizerUsed and 1 or 0  -- Se fertilizante foi usado
    local fertilizerType = fertilizerUsed or NULL  -- Tipo de fertilizante
    
    -- Inserção no banco de dados
    local plantId = MySQL.insert.await([[
        INSERT INTO `bcc_farming` (
            plant_coords, plant_type, plant_watered, time_left, plant_owner,
            growth_stage, growth_progress, water_count, max_water_times, 
            base_fertilized, fertilizer_type
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], { 
        json.encode(plantCoords), 
        plantData.seedName, 
        'false',  -- Não regada inicialmente
        plantData.timeToGrow, 
        character.charIdentifier,
        growthStage,
        growthProgress,
        waterCount,
        maxWaterTimes,
        baseFertilized,
        fertilizerType
    })
    
    -- Usa prop do estágio 1
    local plantProp = plantData.plantProp
    if plantData.plantProps and plantData.plantProps.stage1 then
        plantProp = plantData.plantProps.stage1
    end
    
    -- Envia para cliente(s)
    if Config.plantSetup.lockedToPlanter then
        TriggerClientEvent('bcc-farming:PlantPlanted', src, plantId, clientPlantData, plantCoords, plantData.timeToGrow, false, src)
        TriggerClientEvent('bcc-farming:UpdatePlantStageData', src, plantId, growthStage, growthProgress)
    else
        TriggerClientEvent('bcc-farming:PlantPlanted', -1, plantId, clientPlantData, plantCoords, plantData.timeToGrow, false, src)
        TriggerClientEvent('bcc-farming:UpdatePlantStageData', -1, plantId, growthStage, growthProgress)
    end
end)
```

### 1.4 Criação do Prop Visual

**Arquivo:** `client/services/prop_management.lua:26-82`

```lua
function PropManager.CreatePlantProp(plantId, plantConfig, coords, stage, offset)
    stage = stage or 1
    offset = offset or plantConfig.plantOffset or 0
    
    -- Obtém o prop para este estágio
    local propName = PropManager.GetStageProp(plantConfig, stage)
    
    -- Calcula posição no solo
    local hit, groundZ = GetGroundZAndNormalFor_3dCoord(coords.x, coords.y, coords.z + 10.0)
    local finalZ = (hit and groundZ or coords.z) + offset
    
    -- Carrega o modelo
    local propHash = GetHashKey(propName)
    RequestModel(propHash)
    
    -- Aguarda carregamento
    while not HasModelLoaded(propHash) and attempts < 100 do
        Wait(10)
        attempts = attempts + 1
    end
    
    -- Cria o prop
    local prop = CreateObject(propHash, coords.x, coords.y, finalZ, false, false, false)
    
    if prop and DoesEntityExist(prop) then
        -- Configura propriedades do prop
        SetEntityAsMissionEntity(prop, true, true)
        FreezeEntityPosition(prop, true)
        SetEntityCollision(prop, false, false)
        
        -- Armazena dados do prop
        PlantProps[plantId] = {
            entity = prop,
            propName = propName,
            coords = {x = coords.x, y = coords.y, z = finalZ},
            stage = stage,
            plantConfig = plantConfig
        }
        
        return prop
    end
    
    return nil
end
```

---

## 💧 ETAPA 2: IRRIGAÇÃO (WATERING)

### 2.1 Sistema de Irrigação Múltipla

**Mudança Importante v2.5.0:** O cronômetro de crescimento agora inicia na **primeira rega** em vez de após todas as regas.

#### 🚰 Uso do Balde de Água
**Arquivo:** `server/services/usableItems_v2.lua:256-301`

```lua
for _, waterItem in pairs(Config.fullWaterBucket) do
    exports.vorp_inventory:registerUsableItem(waterItem, function(data)
        local src = data.source
        
        -- Encontra planta mais próxima
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
        
        if nearestPlant then
            exports.vorp_inventory:closeInventory(src)
            VORPcore.Callback.TriggerAwait('bcc-farming:ManagePlantWateredStatus', function(result)
                -- Resultado da rega
            end, nearestPlant.plant_id)
        end
    end)
end
```

### 2.2 Lógica de Controle de Irrigação

**Arquivo:** `server/main.lua:205-298`

```lua
VORPcore.Callback.Register('bcc-farming:ManagePlantWateredStatus', function(source, cb, plantId)
    -- Obtém dados atuais da planta
    local plantRow = MySQL.query.await('SELECT * FROM `bcc_farming` WHERE `plant_id` = ?', { plantId })
    local plant = plantRow[1]
    local currentWaterCount = tonumber(plant.water_count) or 0
    local maxWaterTimes = tonumber(plant.max_water_times) or 1
    
    -- ✅ Verifica se pode ser regada
    if currentWaterCount >= maxWaterTimes then
        SendFarmingNotification(src, _U('plantFullyWatered') or 'Plant is already fully watered!')
        return cb(false)
    end
    
    -- 🕐 Calcula intervalo de irrigação
    local plantConfig = GetPlantConfigByType(plant.plant_type)
    local totalGrowthTime = plantConfig.timeToGrow or 1200
    local wateringInterval = math.floor(totalGrowthTime / maxWaterTimes)
    
    -- ⏰ Verifica cooldown entre regas
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
    
    -- 🪣 Verifica inventário de balde de água
    local fullWaterBucket = Config.fullWaterBucket
    for _, item in ipairs(fullWaterBucket) do
        local itemCount = exports.vorp_inventory:getItemCount(src, nil, item)
        if itemCount >= 1 then
            exports.vorp_inventory:subItem(src, item, 1)
            exports.vorp_inventory:addItem(src, Config.emptyWaterBucket, 1)
            
            -- 💧 Atualiza sistema de irrigação v2.5.0
            local newWaterCount = currentWaterCount + 1
            local isFullyWatered = (newWaterCount >= maxWaterTimes)
            
            MySQL.update.await([[
                UPDATE `bcc_farming` 
                SET `water_count` = ?, `plant_watered` = ?, `last_watered_time` = NOW() 
                WHERE `plant_id` = ?
            ]], { 
                newWaterCount, 
                'true',  -- ⭐ MUDANÇA v2.5.0: Cronômetro inicia na primeira rega
                plantId 
            })
            
            -- 📢 Notificação com status especial para primeira rega
            local wateringProgress = math.floor((newWaterCount / maxWaterTimes) * 100)
            local statusMessage = (_U('plantWatered') or 'Plant watered!') .. 
                ' (' .. newWaterCount .. '/' .. maxWaterTimes .. ' - ' .. wateringProgress .. '%)'
            
            if newWaterCount == 1 then
                statusMessage = statusMessage .. ' - Growth timer started!' -- 🌱 Cronômetro iniciado
            end
            
            SendFarmingNotification(src, statusMessage)
            
            -- 📡 Atualiza clientes
            TriggerClientEvent('bcc-farming:UpdateClientPlantWateredStatus', -1, plantId, newWaterCount, maxWaterTimes, isFullyWatered)
            return cb(true)
        end
    end
    
    -- ❌ Não tem balde de água
    SendFarmingNotification(src, _U('noWaterBucket') or 'No water bucket found!')
    cb(false)
end)
```

### 2.3 Sistema de Crescimento em Tempo Real

**Arquivo:** `server/main.lua:368-427`

```lua
CreateThread(function()
    while true do
        Wait(1000) -- A cada segundo
        local allPlants = MySQL.query.await('SELECT * FROM `bcc_farming`')
        
        if #allPlants > 0 then
            for _, plant in pairs(allPlants) do
                local timeLeft = tonumber(plant.time_left)
                
                -- ⭐ MUDANÇA v2.5.0: Cronômetro ativo após primeira rega
                if plant.plant_watered == 'true' and timeLeft > 0 then
                    local newTime = timeLeft - 1
                    MySQL.update('UPDATE `bcc_farming` SET `time_left` = ? WHERE `plant_id` = ?', { newTime, plant.plant_id })
                    
                    -- 📊 Calcula progresso e estágios
                    local plantConfig = GetPlantConfigByType(plant.plant_type)
                    if plantConfig then
                        local totalGrowthTime = plantConfig.timeToGrow
                        local elapsedTime = totalGrowthTime - newTime
                        local growthProgress = math.min(100, (elapsedTime / totalGrowthTime) * 100)
                        
                        -- 🌱 Determina estágio baseado no progresso
                        local newStage = 1
                        if growthProgress >= 66.67 then
                            newStage = 3      -- Estágio 3: 66.67% - 100%
                        elseif growthProgress >= 33.33 then
                            newStage = 2      -- Estágio 2: 33.33% - 66.66%
                        else
                            newStage = 1      -- Estágio 1: 0% - 33.32%
                        end
                        
                        local currentStage = tonumber(plant.growth_stage) or 1
                        
                        -- 🔄 Atualiza estágio se mudou
                        if newStage ~= currentStage or math.abs(growthProgress - currentProgress) > 1 then
                            MySQL.update('UPDATE `bcc_farming` SET `growth_stage` = ?, `growth_progress` = ? WHERE `plant_id` = ?', 
                                { newStage, growthProgress, plant.plant_id })
                            
                            print(string.format("^2[BCC-Farming Growth]^7 Plant %d: Stage %d->%d, Progress %.1f%% (Time: %d/%d)", 
                                plant.plant_id, currentStage, newStage, growthProgress, elapsedTime, totalGrowthTime))
                            
                            -- 📡 Notifica clientes apenas se estágio mudou (evita spam)
                            if newStage ~= currentStage then
                                TriggerClientEvent('bcc-farming:UpdatePlantStageData', -1, plant.plant_id, newStage, growthProgress)
                            end
                        end
                    end
                end
            end
        end
    end
end)
```

---

## 🧪 ETAPA 3: SISTEMA DE FERTILIZANTES

### 3.1 Tipos de Fertilizantes

**Arquivo:** `configs/config.lua:23-64`

#### 📋 Configuração dos Fertilizantes
```lua
fertilizerSetup = {
    {
        fertName = 'fertilizer',        -- Fertilizante Básico
        fertTimeReduction = 0.10,       -- 10% de redução no tempo
    },
    {
        fertName = 'fertilizersw',      -- Fertilizante com Madeira Macia
        fertTimeReduction = 0.20,       -- 20% de redução no tempo
    },
    {
        fertName = 'fertilizerpro',     -- Fertilizante com Produtos
        fertTimeReduction = 0.30,       -- 30% de redução no tempo
    },
    {
        fertName = 'fertilizeregg',     -- Fertilizante com Ovos
        fertTimeReduction = 0.40,       -- 40% de redução no tempo
    },
    {
        fertName = 'fertilizersq',      -- Fertilizante com Esquilo
        fertTimeReduction = 0.50,       -- 50% de redução no tempo
    },
    {
        fertName = 'fertilizerpulpsap', -- Fertilizante com Polpa/Seiva
        fertTimeReduction = 0.60,       -- 60% de redução no tempo
    },
    {
        fertName = 'fertilizerbless',   -- Fertilizante Abençoado
        fertTimeReduction = 0.70,       -- 70% de redução no tempo
    },
    {
        fertName = 'fertilizersn',      -- Fertilizante com Cobra
        fertTimeReduction = 0.80,       -- 80% de redução no tempo
    },
    {
        fertName = 'fertilizersyn',     -- Fertilizante Pecaminoso
        fertTimeReduction = 0.85,       -- 85% de redução no tempo
    },
    {
        fertName = 'fertilizerwoj',     -- Fertilizante com Wojape
        fertTimeReduction = 0.90,       -- 90% de redução no tempo
    },
},
```

### 3.2 Aplicação Manual de Fertilizantes

**Arquivo:** `server/services/usableItems_v2.lua:172-215`

#### 🎯 Uso de Fertilizante como Item Usável
```lua
exports.vorp_inventory:registerUsableItem(fertilizer.fertName, function(data)
    local src = data.source
    HandleFertilizerUsage(src, fertilizer.fertName, false) -- false = fertilizante aprimorado
end)

function HandleFertilizerUsage(src, fertilizerType, isBaseFertilizer)
    -- 📍 Encontra planta mais próxima (até 3.0 unidades)
    local playerCoords = GetEntityCoords(GetPlayerPed(src))
    local nearestPlant = nil
    local shortestDistance = 999999
    
    for _, plant in pairs(allPlants) do
        local plantCoords = json.decode(plant.plant_coords)
        local distance = #(playerCoords - vector3(plantCoords.x, plantCoords.y, plantCoords.z))
        
        if distance <= 3.0 and distance < shortestDistance then
            shortestDistance = distance
            nearestPlant = plant
        end
    end
    
    if not nearestPlant then
        VORPcore.NotifyRightTip(src, "No plant nearby to fertilize", 4000)
        return
    end
    
    -- ✅ Verificações de aplicação
    if isBaseFertilizer then
        if nearestPlant.base_fertilized then
            VORPcore.NotifyRightTip(src, "Base fertilizer already applied to this plant", 4000)
            return
        end
    else
        if nearestPlant.fertilizer_type then
            VORPcore.NotifyRightTip(src, "Enhanced fertilizer already applied to this plant", 4000)
            return
        end
    end
    
    -- 🎒 Verifica inventário
    local fertCount = exports.vorp_inventory:getItemCount(src, nil, fertilizerType)
    if fertCount < 1 then
        VORPcore.NotifyRightTip(src, "You don't have this fertilizer", 4000)
        return
    end
    
    -- 🎬 Inicia animação e aplicação
    exports.vorp_inventory:closeInventory(src)
    TriggerClientEvent('bcc-farming:StartFertilizerAnimation', src, nearestPlant.plant_id, fertilizerType)
end
```

#### 🎭 Animação de Aplicação de Fertilizante

**Arquivo:** `client/services/planting.lua:116-139`

```lua
RegisterNetEvent('bcc-farming:StartFertilizerAnimation', function(plantId, fertilizerType)
    local playerPed = PlayerPedId()
    
    -- Esconde armas durante aplicação
    HidePedWeapons(playerPed, 2, true)
    
    -- Notifica início da aplicação
    SendClientFarmingNotification('Aplicando fertilizante...')
    
    -- Inicia cenário WORLD_HUMAN_FEED_PIGS por 8 segundos (versão otimizada)
    ScenarioInPlace('WORLD_HUMAN_FEED_PIGS', 8000)
    
    -- Aguarda animação completar
    Wait(8000)
    
    -- Limpa tarefas e props de cenário
    ClearPedTasks(playerPed)
    ClearPedSecondaryTask(playerPed)
    
    -- Sistema avançado de limpeza de props de cenário (baldes, etc.)
    local propsDeleted = CleanupScenarioProps(playerCoords, 3.0)
    if propsDeleted > 0 then
        Wait(100) -- Aguarda deleção
        CleanupScenarioProps(playerCoords, 3.0) -- Segunda passada
    end
    
    -- Envia para servidor aplicar efeito do fertilizante
    TriggerServerEvent('bcc-farming:ApplyFertilizer', plantId, fertilizerType)
    
    SendClientFarmingNotification('Fertilizante aplicado com sucesso!')
end)
```

### 3.3 Processamento de Fertilizantes no Servidor

**Arquivo:** `server/main.lua:462-557`

```lua
RegisterServerEvent('bcc-farming:ApplyFertilizer', function(plantId, fertilizerType)
    local src = source
    local user = VORPcore.getUser(src)
    if not user then return end
    
    -- 📊 Obtém dados da planta
    local plantData = MySQL.query.await('SELECT * FROM bcc_farming WHERE plant_id = ?', { plantId })
    if not plantData or #plantData == 0 then
        SendFarmingNotification(src, "Plant not found")
        return
    end
    
    local plant = plantData[1]
    
    -- 🌱 Obtém configuração da planta
    local plantConfig = nil
    for _, config in pairs(Plants) do
        if config.seedName == plant.plant_type then
            plantConfig = config
            break
        end
    end
    
    -- 📈 Calcula redução de tempo baseada na configuração
    local isBaseFertilizer = (fertilizerType == (plantConfig.baseFertilizerItem or 'fertilizer'))
    local timeReduction = 0
    
    if Config.fertilizerSetup then
        for _, fert in pairs(Config.fertilizerSetup) do
            if fert.fertName == fertilizerType then
                timeReduction = fert.fertTimeReduction
                break
            end
        end
    end
    
    -- ✅ Verifica se fertilizante já foi aplicado
    if isBaseFertilizer then
        if tonumber(plant.base_fertilized) == 1 then
            SendFarmingNotification(src, "Base fertilizer already applied")
            return
        end
    else
        if plant.fertilizer_type and plant.fertilizer_type ~= 'NULL' then
            SendFarmingNotification(src, "Enhanced fertilizer already applied")
            return
        end
    end
    
    -- 💳 Remove fertilizante do inventário
    exports.vorp_inventory:subItem(src, fertilizerType, 1)
    
    -- 🕐 Calcula novo tempo com redução
    local currentTimeLeft = tonumber(plant.time_left) or 0
    local newTimeLeft = currentTimeLeft
    
    if timeReduction > 0 then
        newTimeLeft = math.floor(currentTimeLeft * (1 - timeReduction))
    end
    
    -- 🗃️ Atualiza banco de dados
    if isBaseFertilizer then
        MySQL.update.await('UPDATE bcc_farming SET base_fertilized = 1, time_left = ? WHERE plant_id = ?', 
            { newTimeLeft, plantId })
        SendFarmingNotification(src, "Base fertilizer applied successfully!")
    else
        MySQL.update.await('UPDATE bcc_farming SET fertilizer_type = ?, time_left = ? WHERE plant_id = ?', 
            { fertilizerType, newTimeLeft, plantId })
        
        local reductionPercent = math.floor(timeReduction * 100)
        SendFarmingNotification(src, string.format("Enhanced fertilizer applied! Growth time reduced by %d%%", reductionPercent))
    end
    
    print(string.format("^2[BCC-Farming]^7 Player %s applied %s to plant %d (reduction: %d%%)", 
        GetPlayerName(src), fertilizerType, plantId, math.floor(timeReduction * 100)))
end)
```

---

## 🌾 ETAPA 4: COLHEITA

### 4.1 Verificação de Prontidão

**Arquivo:** `client/services/planted.lua:harvest_check`

```lua
-- Verifica se a planta está pronta para colheita
local function IsPlantReady(cropData)
    if not cropData then return false end
    
    local timeLeft = tonumber(cropData.timeLeft) or 0
    local isWatered = cropData.watered == 'true' or cropData.watered == true
    local stage = tonumber(cropData.currentStage) or 1
    local progress = tonumber(cropData.growthProgress) or 0
    
    -- Planta está pronta se:
    -- 1. Foi regada pelo menos uma vez
    -- 2. Tempo chegou a zero OU progresso chegou a 100%
    -- 3. Está no estágio 3 (opcional para plantas avançadas)
    return isWatered and (timeLeft <= 0 or progress >= 100) and stage >= 1
end
```

### 4.2 Prompt de Colheita

**Arquivo:** `client/services/planted.lua:harvest_prompt`

```lua
CreateThread(function()
    while true do
        Wait(0)
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        
        for plantId, cropData in pairs(Crops) do
            if cropData and not cropData.removePlant then
                local plantCoords = vector3(cropData.x, cropData.y, cropData.z)
                local distance = #(playerCoords - plantCoords)
                
                if distance <= 2.0 then -- Distância de interação
                    if IsPlantReady(cropData) then
                        -- 🌾 Mostra prompt de colheita
                        PromptSetActiveGroupThisFrame(HarvestGroup, CreateVarString(10, 'LITERAL_STRING', _U('harvestPlant')), 1, 0, 0, 0)
                        
                        if Citizen.InvokeNative(0xE0F65F0640EF0617, HarvestPrompt) then -- PromptHasHoldModeCompleted
                            -- Chama sistema de colheita
                            TriggerHarvest(plantId, cropData)
                        end
                    else
                        -- 💧 Mostra prompt de rega (se necessário)
                        PromptSetActiveGroupThisFrame(WaterGroup, CreateVarString(10, 'LITERAL_STRING', _U('waterPlant')), 1, 0, 0, 0)
                        
                        if Citizen.InvokeNative(0xE0F65F0640EF0617, WaterPrompt) then
                            TriggerWatering(plantId)
                        end
                    end
                end
            end
        end
    end
end)
```

### 4.3 Sistema de Colheita no Servidor

**Arquivo:** `server/main.lua:309-344`

```lua
VORPcore.Callback.Register('bcc-farming:HarvestCheck', function(source, cb, plantId, plantData, destroy)
    local src = source
    local user = VORPcore.getUser(src)
    if not user then return cb(false) end

    if not destroy then
        local itemsToAdd = {}

        -- ✅ Verifica se pode carregar todos os itens
        for _, reward in pairs(plantData.rewards) do
            local itemName = reward.itemName
            local itemLabel = reward.itemLabel
            local amount = reward.amount
            local canCarry = exports.vorp_inventory:canCarryItem(src, itemName, amount)
            if canCarry then
                table.insert(itemsToAdd, { itemName = itemName, itemLabel = itemLabel, amount = amount })
            else
                SendFarmingNotification(src, _U('noCarry') .. itemName)
                return cb(false) -- Sai antecipadamente se algum item não pode ser carregado
            end
        end

        -- 🎁 Adiciona itens se todos podem ser carregados
        for _, item in ipairs(itemsToAdd) do
            exports.vorp_inventory:addItem(src, item.itemName, item.amount)
            SendFarmingNotification(src, _U('harvested') .. item.amount .. ' ' .. item.itemLabel)
        end
    end

    cb(true)

    -- 🗑️ Remove planta do banco de dados e notifica clientes
    MySQL.query.await('DELETE FROM `bcc_farming` WHERE `plant_id` = ?', { plantId })
    TriggerClientEvent('bcc-farming:MaxPlantsAmount', src, -1) -- Reduz contador de plantas
    TriggerClientEvent('bcc-farming:RemovePlantClient', -1, plantId) -- Remove prop visual
end)
```

### 4.4 Cálculo de Rendimento

**Arquivo:** `ui/plant-status.js:282-314`

```javascript
// Calcula rendimento esperado baseado em vários fatores
function calculateExpectedYield(plantData) {
    if (!plantData.rewards || !Array.isArray(plantData.rewards)) {
        return 1; // Rendimento padrão
    }
    
    let baseYield = 0;
    
    // Soma todas as quantidades de recompensa
    plantData.rewards.forEach(reward => {
        baseYield += reward.amount || 1;
    });
    
    // 🧪 Aplica bônus de fertilizante (normalmente 10-20% de aumento)
    if (plantData.baseFertilized) {
        baseYield = Math.floor(baseYield * 1.15); // 15% de bônus
    }
    
    // 💧 Aplica bônus de eficiência de irrigação
    if (plantData.waterCount && plantData.maxWaterTimes) {
        const waterEfficiency = plantData.waterCount / plantData.maxWaterTimes;
        if (waterEfficiency >= 1.0) {
            baseYield = Math.floor(baseYield * 1.1); // 10% de bônus para irrigação completa
        }
    }
    
    // 🌱 Aplica bônus de estágio de crescimento
    const currentStage = plantData.stageNumber || plantData.growthStage || 1;
    if (currentStage >= 3) {
        baseYield = Math.floor(baseYield * 1.05); // 5% de bônus para crescimento completo
    }
    
    return Math.max(1, baseYield); // Mínimo 1 item
}
```

---

## 📊 SISTEMA DE ESTÁGIOS VISUAIS

### 4.1 Configuração de Props Multi-Estágio

**Arquivo:** `configs/plants.lua` (exemplo)

```lua
{
    plantName = 'Milho',
    seedName = 'seed_corn',
    -- Sistema antigo (prop único)
    plantProp = 'p_plant_corn_01',
    
    -- Sistema novo (props multi-estágio)
    plantProps = {
        stage1 = 'p_plant_corn_seed_01',     -- 0% - 33.32%
        stage2 = 'p_plant_corn_young_01',    -- 33.33% - 66.66%
        stage3 = 'p_plant_corn_mature_01'    -- 66.67% - 100%
    },
    
    timeToGrow = 1800, -- 30 minutos
    waterTimes = 3,    -- Precisa de 3 regas
    rewards = {
        {
            itemName = 'corn',
            itemLabel = 'Milho',
            amount = 4
        },
        {
            itemName = 'seed_corn',
            itemLabel = 'Semente de Milho',
            amount = 2
        }
    }
}
```

### 4.2 Transição de Estágios

**Arquivo:** `client/services/prop_management.lua:85-127`

```lua
function PropManager.UpdatePlantStage(plantId, newStage, plantConfig)
    local currentProp = PlantProps[plantId]
    if not currentProp then
        print("^3[BCC-Farming]^7 No prop found for plant ID: " .. plantId)
        return false
    end
    
    -- Verifica se o estágio realmente mudou
    if currentProp.stage == newStage then
        return true -- Nenhuma mudança necessária
    end
    
    local coords = currentProp.coords
    local offset = plantConfig.plantOffset or 0
    
    -- Obtém novo nome do prop para o estágio
    local newPropName = PropManager.GetStageProp(plantConfig, newStage)
    local currentPropName = currentProp.propName
    
    if newPropName == currentPropName then
        -- Apenas atualiza informação do estágio, sem mudança visual
        PlantProps[plantId].stage = newStage
        return true
    end
    
    -- 🗑️ Remove prop antigo com limpeza aprimorada
    if DoesEntityExist(currentProp.entity) then
        SetEntityAsMissionEntity(currentProp.entity, false, true)
        DeleteEntity(currentProp.entity)
        
        Wait(0) -- Aguarda um frame para garantir deleção
        
        if DoesEntityExist(currentProp.entity) then
            print(string.format("^3[BCC-Farming]^7 Warning: Old prop %d still exists after deletion attempt", plantId))
        else
            print(string.format("^2[BCC-Farming]^7 Old prop for plant %d successfully removed", plantId))
        end
    end
    
    -- 🆕 Cria novo prop
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
```

---

## 🎮 INTERFACE NUI EM TEMPO REAL

### 4.1 Sistema de Proximidade

**Arquivo:** `client/nui_integration.lua:149-189`

```lua
CreateThread(function()
    while true do
        Wait(UpdateInterval) -- 1000ms
        
        local nearbyPlants = FindNearbyPlants()
        
        if #nearbyPlants > 0 then
            -- Encontra planta mais próxima
            local closestPlant = nil
            local closestDistance = ProximityRange + 1
            
            for _, plant in pairs(nearbyPlants) do
                if plant.distance < closestDistance then
                    closestDistance = plant.distance
                    closestPlant = plant
                end
            end
            
            if closestPlant then
                -- Se esta é uma nova planta ou não temos NUI ativo
                if not CurrentPlant or not NUIActive then
                    local plantCoords = closestPlant.coords
                    
                    VORPcore.Callback.TriggerAsync('bcc-farming:GetPlantByCoords', function(plantData)
                        if plantData and plantData.success then
                            CurrentPlant = closestPlant
                            ShowPlantNUI(plantData.data) -- Mostra interface
                        end
                    end, plantCoords)
                end
            end
        else
            -- Nenhuma planta próxima, esconde NUI
            if NUIActive then
                HidePlantNUI()
            end
        end
    end
end)
```

### 4.2 Dados Exibidos na NUI

**Arquivo:** `ui/plant-status.js:97-147`

```javascript
function updateNotebookDisplay(plantData) {
    console.log('📝 Updating notebook with plant data:', plantData);
    
    // 🌱 Atualiza nome da planta
    if (plantName) {
        plantName.textContent = plantData.plantName || 'Planta Desconhecida';
    }
    
    // 🖼️ Atualiza imagem da planta usando primeiro item de recompensa
    if (plantImage && plantData.rewards && plantData.rewards.length > 0) {
        const firstReward = plantData.rewards[0];
        const itemName = firstReward.itemName || firstReward.itemLabel;
        const imageUrl = `https://cfx-nui-vorp_inventory/html/img/items/${itemName.toLowerCase()}.png`;
        
        plantImage.src = imageUrl;
        plantImage.style.display = 'block';
    }
    
    // ✅ Atualiza checkboxes de crescimento (3 estágios)
    updateGrowthCheckboxes(plantData.stageNumber || plantData.growthStage || 1);
    
    // ⏰ Atualiza checkboxes de tempo (5 períodos de 20% cada)
    updateTimeCheckboxes(plantData);
    
    // 🧪 Atualiza checkbox de fertilizante (1 checkbox)
    updateFertilizerCheckboxes(plantData.baseFertilized || false);
    
    // 💧 Atualiza checkboxes de água (baseado em waterCount/maxWaterTimes)
    updateWaterCheckboxes(plantData.waterCount || 0, plantData.maxWaterTimes || 1);
    
    // 🌾 Atualiza quantidade de colheita
    updateHarvestAmount(plantData);
    
    // 📝 Atualiza seção de notas
    updateNotesSection(plantData);
}
```

---

## 🔧 COMANDOS DE DEBUG

### 4.1 Comandos Disponíveis

**Arquivo:** `testing/debug_stages.lua`

```lua
-- 🧪 Testar progressão de estágio
/teststage [plantId] [stage]

-- 📊 Verificar status do PropManager
/checkprops

-- 🎯 Forçar estágio para planta mais próxima
/forcestage [stage]

-- 📋 Listar plantas com informações de estágio
/listplants

-- 🧹 Testar limpeza de props
/testcleanup

-- 🔧 Forçar progresso de crescimento
/forceprogress [plantId] [progress]

-- 🗑️ Limpar props de cenário manualmente
/cleanprops [radius]

-- 🎬 Testar animação de plantio aprimorada
/testplantanim
```

### 4.2 Exemplo de Uso dos Comandos

```lua
-- Força planta ID 1 para estágio 2 com 50% de progresso
/teststage 1 2

-- Verifica quantos props estão ativos
/checkprops
-- Output: "PropManager Available: YES, Total Props: 5, Valid Props: 4, Stage 1: 2 | Stage 2: 2 | Stage 3: 0"

-- Lista todas as plantas ativas
/listplants
-- Output: "Plant 1: Stage 1, Progress 15.2%, Plant 2: Stage 2, Progress 45.8%"

-- Força planta mais próxima para estágio 3
/forcestage 3

-- Limpa props de cenário (baldes) em raio de 10 unidades
/cleanprops 10

-- Testa animação completa de plantio com trowel
/testplantanim
```

---

## 📈 FLUXO COMPLETO DE EXEMPLO

### Cenário: Plantando Milho com Fertilizante

1. **🌱 Plantação:**
   - Jogador usa "seed_corn"
   - Sistema verifica localização, job, recursos
   - **Fase 1**: Animação de rake por 8 segundos
   - **Fase 2**: Animação aprimorada com trowel por 13 segundos
     - Prop `p_trowel01x` anexado à mão direita
     - Sequência de 6 animações Jack Plant
     - Notificações de progresso detalhadas
   - Planta criada: `timeToGrow = 1800 segundos` (30 minutos)
   - Prop stage1 aparece: `p_plant_corn_seed_01`

1b. **🧪 Aplicação Manual de Fertilizante:**
   - Jogador usa "fertilizersq" (50% redução) do inventário próximo à planta
   - **Animação otimizada**: `ScenarioInPlace('WORLD_HUMAN_FEED_PIGS', 8000)`
   - **Sistema de cleanup aprimorado**: Remove props de balde automaticamente
   - Sistema aplica: `timeToGrow = 1800 * 0.5 = 900 segundos` (15 minutos)
   - Notificação: "Enhanced fertilizer applied! Growth time reduced by 50%"

2. **💧 Primeira Rega:**
   - Jogador usa "wateringcan" próximo à planta
   - Sistema: `water_count = 1, plant_watered = 'true'`
   - Notificação: "Plant watered! (1/3 - 33%) - Growth timer started!"
   - **Cronômetro de crescimento INICIA**

3. **⏰ Crescimento:**
   - A cada segundo: `time_left` diminui
   - 0-300s (0-33%): Permanece stage1
   - 300s: `progress = 33.33%` → Transição para stage2
   - Prop muda: `p_plant_corn_seed_01` → `p_plant_corn_young_01`

4. **💧 Segunda Rega (após 300s):**
   - Jogador usa "wateringcan" novamente
   - Sistema: `water_count = 2`
   - Notificação: "Plant watered! (2/3 - 67%)"

5. **🌱 Crescimento Continua:**
   - 600s: `progress = 66.67%` → Transição para stage3
   - Prop muda: `p_plant_corn_young_01` → `p_plant_corn_mature_01`

6. **💧 Terceira Rega (após 600s):**
   - Sistema: `water_count = 3, maxWaterTimes = 3`
   - Notificação: "Plant watered! (3/3 - 100%)"

7. **🌾 Colheita (após 900s):**
   - `time_left = 0, progress = 100%`
   - Prompt de colheita aparece
   - Jogador colhe: Recebe 4x milho + 2x sementes
   - Planta é removida do banco e prop deletado

---

## 🗂️ ESTRUTURA DE ARQUIVOS

```
bcc-farming/
├── client/
│   ├── main.lua                    # Cliente principal
│   ├── services/
│   │   ├── planting.lua           # Sistema de plantação
│   │   ├── planted.lua            # Gerenciamento de plantas plantadas
│   │   └── prop_management.lua    # Sistema de props multi-estágio
│   └── nui_integration.lua        # Interface NUI em tempo real
├── server/
│   ├── main.lua                   # Servidor principal
│   ├── services/
│   │   └── usableItems_v2.lua     # Itens usáveis avançados
│   └── database/
│       └── setup.lua              # Configuração do banco
├── configs/
│   ├── config.lua                 # Configurações gerais
│   └── plants.lua                 # Configurações de plantas
├── ui/
│   ├── index.html                 # Interface NUI
│   ├── plant-status.css           # Estilos da interface
│   └── plant-status.js            # Lógica da interface
├── utils/
│   └── bln_notify.lua             # Sistema de notificações
└── testing/
    └── debug_stages.lua           # Comandos de debug
```

---

## 📊 TABELA DO BANCO DE DADOS

```sql
CREATE TABLE IF NOT EXISTS `bcc_farming` (
    `plant_id` INT(11) AUTO_INCREMENT PRIMARY KEY,
    `plant_coords` LONGTEXT NOT NULL,
    `plant_type` VARCHAR(255) NOT NULL,
    `plant_watered` VARCHAR(10) NOT NULL DEFAULT 'false',
    `time_left` INT(11) NOT NULL,
    `plant_owner` VARCHAR(255) NOT NULL,
    
    -- Campos v2.5.0
    `growth_stage` INT(11) DEFAULT 1,              -- Estágio atual (1, 2, 3)
    `growth_progress` DECIMAL(5,2) DEFAULT 0.00,   -- Progresso percentual (0.00-100.00)
    `water_count` INT(11) DEFAULT 0,               -- Número de regas aplicadas
    `max_water_times` INT(11) DEFAULT 1,           -- Máximo de regas necessárias
    `base_fertilized` TINYINT(1) DEFAULT 0,        -- Se fertilizante básico foi aplicado
    `fertilizer_type` VARCHAR(255) DEFAULT NULL,   -- Tipo de fertilizante aprimorado
    `last_watered_time` TIMESTAMP NULL DEFAULT NULL -- Última vez que foi regada
);
```

---

## ⚡ RESUMO DAS FUNCIONALIDADES

### ✅ Sistema de Plantação
- Verificações automáticas de localização, job e recursos
- Animação de plantio realística
- Sistema inteligente de detecção de fertilizantes
- Prompts interativos para aplicação de fertilizante

### ✅ Sistema de Irrigação v2.5.0
- **Cronômetro inicia na primeira rega** (mudança principal)
- Sistema de múltiplas regas com cooldown
- Notificações detalhadas de progresso
- Verificação automática de inventário de baldes

### ✅ Sistema de Fertilizantes
- 10 tipos diferentes com redução de 10% a 90%
- **Aplicação manual** como itens usáveis independentes
- **Animação realística** com `ScenarioInPlace('WORLD_HUMAN_FEED_PIGS')`
- **Cleanup automático** de props de balde
- Sistema de precedência (básico → aprimorado)
- Cálculo automático de tempo otimizado

### ✅ Sistema Visual Multi-Estágio
- Transições automáticas em 33%, 66% e 100%
- Limpeza aprimorada de props antigos
- Fallback para plantas antigas
- Sistema de debugging robusto

### ✅ Interface NUI
- Detecção automática por proximidade
- Atualização em tempo real
- Cálculo de rendimento esperado
- Design notebook temático

### ✅ Sistema de Colheita
- Verificação automática de prontidão
- Cálculo de bônus por fertilizante/irrigação
- Sistema de inventário inteligente
- Limpeza automática da planta

---

**🌾 Esta documentação cobre todo o fluxo do sistema BCC-Farming v2.5.0, desde a plantação até a colheita, incluindo todas as funcionalidades avançadas implementadas.**