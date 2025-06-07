# 📚 **DOCUMENTAÇÃO TÉCNICA COMPLETA - BCC FARMING EXPORTS**

## 🎯 **VISÃO GERAL**

O BCC-Farming é um sistema avançado de agricultura para RedM com **39 exports** divididos em 7 categorias principais. Este documento fornece informações completas sobre como utilizar cada export.

### **📊 Estatísticas do Sistema**
- **Total de Exports:** 39
- **Versão:** 2.4.2-exports
- **Banco de Dados:** MySQL/OxMySQL
- **Framework:** VORP Core
- **Linguagem:** Lua

---

## 📋 **ÍNDICE DE EXPORTS**

### **1. BÁSICOS (6 exports)**
- [GetGlobalPlantCount](#getglobalplantcount)
- [GetGlobalPlantsByType](#getglobalplantsbytype)  
- [GetNearHarvestPlants](#getnearharverstplants)
- [GetFarmingOverview](#getfarmingoverview)
- [GetWateringStatus](#getwateringstatus)

### **2. JOGADORES (5 exports)**
- [GetPlayerPlantCount](#getplayerplantcount)
- [GetPlayerPlants](#getplayerplants)
- [CanPlayerPlantMore](#canplayerplantmore)
- [GetPlayerFarmingStats](#getplayerfarmingstats)
- [GetPlayerComparison](#getplayercomparison)

### **3. PRODUÇÃO (5 exports)**
- [GetEstimatedProduction](#getestimatedproduction)
- [GetTotalProductionPotential](#gettotalproductionpotential)
- [GetHourlyProductionForecast](#gethourlyproductionforecast)
- [GetProductionEfficiency](#getproductionefficiency)
- [GetGrowthAnalysis](#getgrowthanalysis)

### **4. GEOGRÁFICOS (6 exports)**
- [GetPlantsInRadius](#getplantsinradius)
- [GetPlantDensity](#getplantdensity)
- [GetDominantPlantInArea](#getdominantplantinarea)
- [IsValidPlantLocation](#isvalidplantlocation)
- [FindBestPlantingAreas](#findbestplantingareas)
- [GetPlantConcentrationMap](#getplantconcentrationmap)

### **5. NOTIFICAÇÕES (7 exports)**
- [NotifyReadyPlants](#notifyreadyplants)
- [NotifyPlantsNeedWater](#notifyplantsneedwater)
- [NotifyPlantLimits](#notifyplantlimits)
- [NotifyFarmingEvent](#notifyfarmingevent)
- [SendDailyFarmingReport](#senddailyfamingreport)
- [NotifyPlantSmelled](#notifyplantsmelled)

### **6. CACHE (3 exports)**
- [GetCacheStats](#getcachestats)
- [GetGlobalPlantCountCached](#getglobalplantcountcached)
- [ClearCache](#clearcache)

### **7. ECONOMIA (4 exports)**
- [GetPlantScarcityIndex](#getplantscarcityindex)
- [CalculateDynamicPrice](#calculatedynamicprice)
- [GetPlantingTrend](#getplantingtrend)
- [GetMarketReport](#getmarketreport)

---

## 🔧 **COMO USAR OS EXPORTS**

### **Sintaxe Básica**
```lua
-- Exemplo básico de uso
local resultado = exports['bcc-farming']:NOME_DO_EXPORT(parametros)

-- Verificar se foi bem-sucedido
if resultado.success then
    print("Dados:", json.encode(resultado.data))
else
    print("Erro:", resultado.error)
end
```

### **Estrutura de Resposta Padrão**
```lua
{
    success = true/false,     -- Indica se a operação foi bem-sucedida
    data = {...},            -- Dados retornados (quando success = true)
    error = "mensagem",      -- Mensagem de erro (quando success = false)
    timestamp = 1640995200   -- Timestamp Unix da consulta
}
```

---

## 📈 **EXPORTS BÁSICOS**

### **GetGlobalPlantCount**
Retorna o número total de plantas no servidor.

**Parâmetros:** Nenhum
**Retorno:**
```lua
{
    success = true,
    data = 150,              -- Número total de plantas
    timestamp = 1640995200
}
```

**Exemplo de Uso:**
```lua
local totalPlantas = exports['bcc-farming']:GetGlobalPlantCount()
if totalPlantas.success then
    print("Total de plantas no servidor: " .. totalPlantas.data)
end
```

---

### **GetGlobalPlantsByType**
Retorna contagem de plantas agrupadas por tipo.

**Parâmetros:** Nenhum
**Retorno:**
```lua
{
    success = true,
    data = {
        {plant_type = "corn_Seed", count = 25},
        {plant_type = "apple_Seed", count = 18},
        {plant_type = "tomato_Seed", count = 12}
    },
    timestamp = 1640995200
}
```

**Exemplo de Uso:**
```lua
local tiposPlantas = exports['bcc-farming']:GetGlobalPlantsByType()
if tiposPlantas.success then
    for _, planta in pairs(tiposPlantas.data) do
        print(string.format("%s: %d plantas", planta.plant_type, planta.count))
    end
end
```

---

### **GetNearHarvestPlants**
Retorna plantas próximas da colheita (dentro de um tempo limite).

**Parâmetros:**
- `timeThreshold` (opcional): Tempo em segundos (padrão: 300 = 5 minutos)

**Retorno:**
```lua
{
    success = true,
    data = {
        {
            plantType = "corn_Seed",
            count = 5,
            avgTimeLeft = 180,       -- Tempo médio restante em segundos
            minTimeLeft = 120,       -- Tempo mínimo
            maxTimeLeft = 240,       -- Tempo máximo
            readyInMinutes = 3       -- Tempo médio em minutos
        }
    },
    threshold_seconds = 300,
    threshold_minutes = 5,
    timestamp = 1640995200
}
```

**Exemplo de Uso:**
```lua
-- Plantas prontas em 10 minutos
local plantasProntas = exports['bcc-farming']:GetNearHarvestPlants(600)
if plantasProntas.success then
    for _, planta in pairs(plantasProntas.data) do
        print(string.format("%d %s estarão prontas em %d minutos", 
            planta.count, planta.plantType, planta.readyInMinutes))
    end
end
```

---

### **GetFarmingOverview**
Retorna um resumo geral do farming no servidor.

**Parâmetros:** Nenhum
**Retorno:**
```lua
{
    success = true,
    data = {
        totalPlants = 150,
        totalTypes = 8,
        plantsReadySoon = 23,
        mostCommonPlant = "corn_Seed",
        mostCommonCount = 45,
        plantsByType = {...},        -- Array com todos os tipos
        upcomingHarvests = {...}     -- Plantas próximas da colheita
    },
    timestamp = 1640995200
}
```

**Exemplo de Uso:**
```lua
local overview = exports['bcc-farming']:GetFarmingOverview()
if overview.success then
    local dados = overview.data
    print(string.format("Servidor: %d plantas de %d tipos diferentes", 
        dados.totalPlants, dados.totalTypes))
    print(string.format("Tipo mais comum: %s (%d plantas)", 
        dados.mostCommonPlant, dados.mostCommonCount))
end
```

---

### **GetWateringStatus**
Retorna estatísticas sobre plantas regadas vs não regadas.

**Parâmetros:** Nenhum
**Retorno:**
```lua
{
    success = true,
    data = {
        watered = {
            count = 95,
            avgTimeLeft = 1200,      -- Tempo médio restante
            percentage = 63          -- Porcentagem do total
        },
        notWatered = {
            count = 55,
            avgTimeLeft = 0,
            percentage = 37
        },
        total = 150
    },
    timestamp = 1640995200
}
```

**Exemplo de Uso:**
```lua
local statusAgua = exports['bcc-farming']:GetWateringStatus()
if statusAgua.success then
    local dados = statusAgua.data
    print(string.format("Plantas regadas: %d (%d%%)", 
        dados.watered.count, dados.watered.percentage))
    print(string.format("Plantas precisando água: %d (%d%%)", 
        dados.notWatered.count, dados.notWatered.percentage))
end
```

---

## 👤 **EXPORTS DE JOGADORES**

### **GetPlayerPlantCount**
Retorna quantas plantas um jogador possui.

**Parâmetros:**
- `playerId`: ID do jogador (number)

**Retorno:**
```lua
{
    success = true,
    data = 8,                    -- Número de plantas do jogador
    maxPlants = 10,              -- Limite máximo
    canPlantMore = true,         -- Se pode plantar mais
    playerId = 1,
    charId = "char123",
    timestamp = 1640995200
}
```

**Exemplo de Uso:**
```lua
local plantasJogador = exports['bcc-farming']:GetPlayerPlantCount(source)
if plantasJogador.success then
    local dados = plantasJogador.data
    print(string.format("Jogador tem %d/%d plantas", dados, plantasJogador.maxPlants))
    
    if not plantasJogador.canPlantMore then
        print("Jogador atingiu o limite máximo!")
    end
end
```

---

### **GetPlayerPlants**
Retorna todas as plantas de um jogador com detalhes completos.

**Parâmetros:**
- `playerId`: ID do jogador (number)

**Retorno:**
```lua
{
    success = true,
    data = {
        {
            plantId = "plant_123",
            plantType = "corn_Seed",
            coords = {x = 100.0, y = 200.0, z = 30.0},
            timeLeft = 1800,         -- Segundos restantes
            isWatered = true,
            isReady = false,
            needsWater = false,
            plantedAt = 1640990000,  -- Timestamp do plantio
            status = "growing",      -- "ready", "needs_water", "growing"
            estimatedHarvest = {
                hours = 1,
                minutes = 30,
                seconds = 1800
            }
        }
    },
    count = 8,
    playerId = 1,
    charId = "char123",
    timestamp = 1640995200
}
```

**Exemplo de Uso:**
```lua
local plantasDetalhadas = exports['bcc-farming']:GetPlayerPlants(source)
if plantasDetalhadas.success then
    print(string.format("Jogador tem %d plantas:", plantasDetalhadas.count))
    
    for _, planta in pairs(plantasDetalhadas.data) do
        if planta.isReady then
            print(string.format("✅ %s está pronta para colheita!", planta.plantType))
        elseif planta.needsWater then
            print(string.format("💧 %s precisa de água", planta.plantType))
        else
            print(string.format("🌱 %s crescendo (%d min restantes)", 
                planta.plantType, planta.estimatedHarvest.minutes))
        end
    end
end
```

---

### **CanPlayerPlantMore**
Verifica se o jogador pode plantar mais plantas.

**Parâmetros:**
- `playerId`: ID do jogador (number)

**Retorno:**
```lua
{
    success = true,
    data = {
        canPlant = true,             -- Se pode plantar
        slotsUsed = 8,              -- Slots em uso
        maxSlots = 10,              -- Total de slots
        availableSlots = 2,         -- Slots disponíveis
        usagePercentage = 80        -- Porcentagem de uso
    },
    playerId = 1,
    timestamp = 1640995200
}
```

**Exemplo de Uso:**
```lua
local podesPlantar = exports['bcc-farming']:CanPlayerPlantMore(source)
if podesPlantar.success then
    local dados = podesPlantar.data
    
    if dados.canPlant then
        print(string.format("Você pode plantar mais %d plantas", dados.availableSlots))
    else
        print("Você atingiu o limite máximo de plantas!")
    end
    
    print(string.format("Uso atual: %d%% (%d/%d)", 
        dados.usagePercentage, dados.slotsUsed, dados.maxSlots))
end
```

---

### **GetPlayerFarmingStats**
Retorna estatísticas detalhadas do farming de um jogador.

**Parâmetros:**
- `playerId`: ID do jogador (number)

**Retorno:**
```lua
{
    success = true,
    data = {
        farming = {
            totalPlants = 8,
            readyToHarvest = 2,
            needsWater = 3,
            growing = 3,
            plantTypes = {
                ["corn_Seed"] = 3,
                ["apple_Seed"] = 2,
                ["tomato_Seed"] = 3
            },
            oldestPlant = {...},        -- Planta mais antiga
            newestPlant = {...},        -- Planta mais nova
            averageGrowthTime = 1500    -- Tempo médio de crescimento
        },
        capacity = {
            canPlant = true,
            slotsUsed = 8,
            maxSlots = 10,
            availableSlots = 2,
            usagePercentage = 80
        },
        summary = {
            efficiency = 25,            -- Eficiência geral (%)
            wateringNeeded = true,      -- Se precisa regar plantas
            hasReadyPlants = true,      -- Se tem plantas prontas
            isMaxCapacity = false       -- Se está no limite máximo
        }
    },
    playerId = 1,
    timestamp = 1640995200
}
```

**Exemplo de Uso:**
```lua
local statsJogador = exports['bcc-farming']:GetPlayerFarmingStats(source)
if statsJogador.success then
    local dados = statsJogador.data
    
    print("=== ESTATÍSTICAS DE FARMING ===")
    print(string.format("Total de plantas: %d", dados.farming.totalPlants))
    print(string.format("Prontas para colheita: %d", dados.farming.readyToHarvest))
    print(string.format("Precisam de água: %d", dados.farming.needsWater))
    print(string.format("Eficiência geral: %d%%", dados.summary.efficiency))
    
    if dados.summary.hasReadyPlants then
        print("🌾 Você tem plantas prontas para colheita!")
    end
    
    if dados.summary.wateringNeeded then
        print("💧 Algumas plantas precisam de água!")
    end
end
```

---

### **GetPlayerComparison**
Compara as estatísticas do jogador com as médias globais.

**Parâmetros:**
- `playerId`: ID do jogador (number)

**Retorno:**
```lua
{
    success = true,
    data = {
        player = {
            plantCount = 8,
            readyPlants = 2,
            efficiency = 25
        },
        global = {
            totalPlants = 150,
            avgPerPlayer = 12.5,
            totalPlayers = 12
        },
        comparison = {
            aboveAverage = false,       -- Se está acima da média
            percentageOfGlobal = 5,     -- Porcentagem do total global
            rank = "below_average"      -- "above_average", "average", "below_average"
        }
    },
    playerId = 1,
    timestamp = 1640995200
}
```

**Exemplo de Uso:**
```lua
local comparacao = exports['bcc-farming']:GetPlayerComparison(source)
if comparacao.success then
    local dados = comparacao.data
    
    print("=== COMPARAÇÃO COM OUTROS JOGADORES ===")
    print(string.format("Suas plantas: %d", dados.player.plantCount))
    print(string.format("Média do servidor: %.1f", dados.global.avgPerPlayer))
    
    if dados.comparison.aboveAverage then
        print("🏆 Você está acima da média!")
    else
        print("📈 Você pode melhorar seu farming!")
    end
    
    print(string.format("Você possui %d%% de todas as plantas do servidor", 
        dados.comparison.percentageOfGlobal))
end
```

---

## 🏭 **EXPORTS DE PRODUÇÃO**

### **GetEstimatedProduction**
Estima a produção de items nas próximas horas.

**Parâmetros:**
- `hours` (opcional): Horas para análise (padrão: 24)

**Retorno:**
```lua
{
    success = true,
    data = {
        {
            plantType = "corn_Seed",
            plantName = "Milho",
            plantsReady = 5,
            avgTimeLeft = 1800,
            minTimeLeft = 900,
            maxTimeLeft = 3600,
            avgTimeLeftHours = 0.5,
            estimatedItems = {
                ["corn"] = {
                    itemName = "corn",
                    itemLabel = "Milho",
                    amountPerPlant = 5,
                    totalAmount = 25,
                    plants = 5
                }
            },
            estimatedValue = 25         -- Valor estimado total
        }
    },
    summary = {
        totalPlants = 15,
        totalTypes = 3,
        estimatedValue = 75,
        timeframeHours = 24
    },
    timeframe_hours = 24,
    timestamp = 1640995200
}
```

**Exemplo de Uso:**
```lua
-- Produção estimada para as próximas 12 horas
local producao = exports['bcc-farming']:GetEstimatedProduction(12)
if producao.success then
    print(string.format("Produção estimada nas próximas %d horas:", producao.timeframe_hours))
    print(string.format("Total de plantas prontas: %d", producao.summary.totalPlants))
    
    for _, planta in pairs(producao.data) do
        print(string.format("🌾 %s: %d plantas prontas", planta.plantName, planta.plantsReady))
        
        for itemName, item in pairs(planta.estimatedItems) do
            print(string.format("  → %d x %s", item.totalAmount, item.itemLabel))
        end
    end
end
```

---

### **GetTotalProductionPotential**
Calcula o potencial total de produção de todas as plantas.

**Parâmetros:** Nenhum

**Retorno:**
```lua
{
    success = true,
    data = {
        {
            plantType = "corn_Seed",
            plantName = "Milho",
            totalPlants = 25,
            wateredPlants = 20,
            readyPlants = 5,
            notWateredPlants = 5,
            avgTimeLeftHours = 2.5,
            potentialItems = {
                ["corn"] = {
                    itemName = "corn",
                    itemLabel = "Milho",
                    potentialTotal = 125,   -- Total se todas crescerem
                    readyNow = 25,          -- Prontas agora
                    whenAllReady = 125      -- Quando todas estiverem prontas
                }
            },
            potentialValue = 125,
            efficiency = 80             -- Eficiência (% regadas)
        }
    },
    totals = {
        totalPlants = 150,
        wateredPlants = 120,
        readyPlants = 30,
        estimatedTotalItems = 500
    },
    efficiency = {
        globalWateringRate = 80,        -- % global de plantas regadas
        globalReadyRate = 25            -- % global de plantas prontas
    },
    timestamp = 1640995200
}
```

**Exemplo de Uso:**
```lua
local potencial = exports['bcc-farming']:GetTotalProductionPotential()
if potencial.success then
    print("=== POTENCIAL TOTAL DE PRODUÇÃO ===")
    print(string.format("Total de plantas no servidor: %d", potencial.totals.totalPlants))
    print(string.format("Taxa de rega global: %d%%", potencial.efficiency.globalWateringRate))
    print(string.format("Taxa de plantas prontas: %d%%", potencial.efficiency.globalReadyRate))
    
    for _, planta in pairs(potencial.data) do
        print(string.format("\n🌱 %s:", planta.plantName))
        print(string.format("  Total: %d plantas", planta.totalPlants))
        print(string.format("  Regadas: %d (%d%%)", planta.wateredPlants, planta.efficiency))
        print(string.format("  Prontas: %d", planta.readyPlants))
        
        for itemName, item in pairs(planta.potentialItems) do
            print(string.format("  📦 Potencial: %d x %s", item.potentialTotal, item.itemLabel))
        end
    end
end
```

---

### **GetHourlyProductionForecast**
Prevê a produção hora por hora nas próximas horas.

**Parâmetros:**
- `forecastHours` (opcional): Horas para previsão (padrão: 12)

**Retorno:**
```lua
{
    success = true,
    data = {
        {
            hour = 1,
            timeFromNow = "1h",
            plants = {
                ["corn_Seed"] = {
                    plantName = "Milho",
                    count = 3
                }
            },
            totalPlants = 8,
            estimatedItems = {
                ["corn"] = {
                    itemLabel = "Milho",
                    amount = 15
                }
            }
        }
    },
    forecastHours = 12,
    summary = {
        totalHours = 12,
        peakHour = 3               -- Hora com mais produção
    },
    timestamp = 1640995200
}
```

**Exemplo de Uso:**
```lua
local previsao = exports['bcc-farming']:GetHourlyProductionForecast(6)
if previsao.success then
    print(string.format("=== PREVISÃO HORÁRIA (%d horas) ===", previsao.forecastHours))
    print(string.format("Pico de produção na hora: %d", previsao.summary.peakHour))
    
    for _, hora in pairs(previsao.data) do
        if hora.totalPlants > 0 then
            print(string.format("\n⏰ Hora %d (%s):", hora.hour, hora.timeFromNow))
            print(string.format("  Plantas prontas: %d", hora.totalPlants))
            
            for itemName, item in pairs(hora.estimatedItems) do
                print(string.format("  📦 %d x %s", item.amount, item.itemLabel))
            end
        end
    end
end
```

---

### **GetProductionEfficiency**
Calcula a eficiência geral de produção do servidor.

**Parâmetros:** Nenhum

**Retorno:**
```lua
{
    success = true,
    data = {
        watering = {
            efficiency = 80,            -- Eficiência de rega (%)
            wateredPlants = 120,
            totalPlants = 150,
            notWateredPlants = 30
        },
        harvesting = {
            efficiency = 25,            -- Eficiência de colheita (%)
            readyPlants = 30,
            wateredPlants = 120,
            stillGrowingPlants = 90
        },
        overall = {
            efficiency = 52,            -- Eficiência geral (%)
            grade = "Average",          -- "Excellent", "Good", "Average", "Poor", "Very Poor"
            recommendations = {
                needsMoreWatering = false,
                needsMoreHarvesting = true,
                isWellMaintained = false
            }
        }
    },
    timestamp = 1640995200
}
```

**Exemplo de Uso:**
```lua
local eficiencia = exports['bcc-farming']:GetProductionEfficiency()
if eficiencia.success then
    local dados = eficiencia.data
    
    print("=== EFICIÊNCIA DE PRODUÇÃO ===")
    print(string.format("Eficiência geral: %d%% (%s)", dados.overall.efficiency, dados.overall.grade))
    print(string.format("Eficiência de rega: %d%%", dados.watering.efficiency))
    print(string.format("Eficiência de colheita: %d%%", dados.harvesting.efficiency))
    
    if dados.overall.recommendations.needsMoreWatering then
        print("💧 Recomendação: Mais plantas precisam ser regadas")
    end
    
    if dados.overall.recommendations.needsMoreHarvesting then
        print("🌾 Recomendação: Há plantas prontas para colheita")
    end
    
    if dados.overall.recommendations.isWellMaintained then
        print("✅ O sistema está bem mantido!")
    end
end
```

---

### **GetGrowthAnalysis**
Analisa o crescimento das plantas por tipo.

**Parâmetros:** Nenhum

**Retorno:**
```lua
{
    success = true,
    data = {
        {
            plantType = "corn_Seed",
            plantName = "Milho",
            total = 25,
            fullyGrown = 5,
            watered = 20,
            almostReady = 8,            -- 30 minutos ou menos
            avgTimeLeftHours = 2.5,
            growthPercentage = 70,      -- Progresso médio de crescimento
            efficiency = {
                wateringRate = 80,       -- % regadas
                readyRate = 20,         -- % prontas
                nearReadyRate = 32      -- % quase prontas
            }
        }
    },
    overallStats = {
        totalPlants = 150,
        totalFullyGrown = 30,
        totalWatered = 120,
        totalAlmostReady = 45
    },
    overallEfficiency = {
        globalWateringRate = 80,
        globalReadyRate = 20,
        globalNearReadyRate = 30
    },
    insights = {
        mostEfficient = "Milho",        -- Tipo mais eficiente
        needsAttention = "Tomate"       -- Tipo que precisa atenção
    },
    timestamp = 1640995200
}
```

**Exemplo de Uso:**
```lua
local analise = exports['bcc-farming']:GetGrowthAnalysis()
if analise.success then
    print("=== ANÁLISE DE CRESCIMENTO ===")
    print(string.format("Taxa global de rega: %d%%", analise.overallEfficiency.globalWateringRate))
    print(string.format("Tipo mais eficiente: %s", analise.insights.mostEfficient))
    
    if analise.insights.needsAttention ~= "None" then
        print(string.format("⚠️ Precisa atenção: %s", analise.insights.needsAttention))
    end
    
    print("\n📊 Por tipo de planta:")
    for _, planta in pairs(analise.data) do
        print(string.format("\n🌱 %s:", planta.plantName))
        print(string.format("  Total: %d | Prontas: %d | Regadas: %d", 
            planta.total, planta.fullyGrown, planta.watered))
        print(string.format("  Progresso médio: %d%%", planta.growthPercentage))
        print(string.format("  Eficiência de rega: %d%%", planta.efficiency.wateringRate))
    end
end
```

---

## 🗺️ **EXPORTS GEOGRÁFICOS**

### **GetPlantsInRadius**
Encontra plantas dentro de um raio específico.

**Parâmetros:**
- `coords`: Coordenadas centrais `{x = 0, y = 0, z = 0}`
- `radius`: Raio em metros (number)

**Retorno:**
```lua
{
    success = true,
    data = {
        {
            plantId = "plant_123",
            plantType = "corn_Seed",
            coords = {x = 100, y = 200, z = 30},
            distance = 150.5,           -- Distância do centro
            timeLeft = 1800,
            watered = true,
            owner = "char123",
            plantedAt = 1640990000,
            status = "growing"          -- "ready", "needs_water", "growing"
        }
    },
    searchCenter = {x = 0, y = 0, z = 0},
    searchRadius = 1000,
    totalFound = 15,
    timestamp = 1640995200
}
```

**Exemplo de Uso:**
```lua
-- Buscar plantas num raio de 500 metros
local coordenadas = {x = -1801, y = -374, z = 161} -- Strawberry
local plantas = exports['bcc-farming']:GetPlantsInRadius(coordenadas, 500)

if plantas.success then
    print(string.format("Encontradas %d plantas num raio de %dm", 
        plantas.totalFound, plantas.searchRadius))
    
    for _, planta in pairs(plantas.data) do
        print(string.format("🌱 %s a %.1fm (%s)", 
            planta.plantType, planta.distance, planta.status))
    end
end
```

---

### **GetPlantDensity**
Calcula a densidade de plantas em uma área.

**Parâmetros:**
- `coords`: Coordenadas centrais `{x = 0, y = 0, z = 0}`
- `radius`: Raio em metros (number)

**Retorno:**
```lua
{
    success = true,
    data = {
        plantsCount = 25,
        areaKm2 = 3.141,               -- Área em quilômetros quadrados
        areaM2 = 3141593,              -- Área em metros quadrados
        density = 7.96,                -- Plantas por km²
        densityPerKm2 = 7.96,
        classification = "Medium",      -- "Very Low", "Low", "Medium", "High", "Very High"
        searchRadius = 1000
    },
    searchCenter = {x = 0, y = 0, z = 0},
    timestamp = 1640995200
}
```

**Exemplo de Uso:**
```lua
local coords = {x = 2632.52, y = -1312.31, z = 51.42} -- Saint Denis
local densidade = exports['bcc-farming']:GetPlantDensity(coords, 2000)

if densidade.success then
    local dados = densidade.data
    print(string.format("=== DENSIDADE DE PLANTAS ==="))
    print(string.format("Área analisada: %.2f km²", dados.areaKm2))
    print(string.format("Plantas encontradas: %d", dados.plantsCount))
    print(string.format("Densidade: %.2f plantas/km²", dados.density))
    print(string.format("Classificação: %s", dados.classification))
    
    if dados.classification == "Very High" then
        print("🚨 Área muito densa - considere expandir plantio")
    elseif dados.classification == "Very Low" then
        print("🌱 Área com baixa densidade - boa para plantio")
    end
end
```

---

### **GetDominantPlantInArea**
Identifica o tipo de planta dominante em uma área.

**Parâmetros:**
- `coords`: Coordenadas centrais `{x = 0, y = 0, z = 0}`
- `radius`: Raio em metros (number)

**Retorno:**
```lua
{
    success = true,
    data = {
        dominantPlant = {
            type = "corn_Seed",
            name = "Milho",
            count = 15,
            percentage = 60            -- Porcentagem do total
        },
        diversity = {
            totalTypes = 4,
            allTypes = {
                ["corn_Seed"] = 15,
                ["apple_Seed"] = 6,
                ["tomato_Seed"] = 3,
                ["carrot_Seed"] = 1
            },
            isDiverse = true           -- Se tem 3+ tipos diferentes
        },
        status = {
            ready = 8,
            growing = 12,
            needsWater = 5
        },
        totalPlants = 25,
        area = {
            center = {x = 0, y = 0, z = 0},
            radius = 1000
        }
    },
    timestamp = 1640995200
}
```

**Exemplo de Uso:**
```lua
local coords = {x = 1346.14, y = -1312.5, z = 76.53} -- Rhodes
local dominante = exports['bcc-farming']:GetDominantPlantInArea(coords, 1500)

if dominante.success then
    local dados = dominante.data
    
    if dados.dominantPlant then
        print(string.format("=== PLANTA DOMINANTE ==="))
        print(string.format("Tipo dominante: %s (%d%%)", 
            dados.dominantPlant.name, dados.dominantPlant.percentage))
        print(string.format("Quantidade: %d de %d plantas", 
            dados.dominantPlant.count, dados.totalPlants))
    else
        print("Nenhuma planta encontrada na área")
    end
    
    print(string.format("\n📊 Diversidade: %d tipos diferentes", dados.diversity.totalTypes))
    if dados.diversity.isDiverse then
        print("✅ Área com boa diversidade de plantas")
    else
        print("⚠️ Área com pouca diversidade")
    end
    
    print(string.format("\n📈 Status das plantas:"))
    print(string.format("  Prontas: %d | Crescendo: %d | Precisam água: %d", 
        dados.status.ready, dados.status.growing, dados.status.needsWater))
end
```

---

### **IsValidPlantLocation**
Verifica se uma localização é válida para plantio.

**Parâmetros:**
- `coords`: Coordenadas para verificar `{x = 0, y = 0, z = 0}`
- `plantType` (opcional): Tipo da planta (string)

**Retorno:**
```lua
{
    success = true,
    data = {
        isValid = false,
        reason = "distance",           -- "distance", "town", "valid_location"
        message = "Too close to another plant",
        nearbyCount = 3,              -- Quantas plantas próximas
        closestDistance = 1.5,        -- Distância da planta mais próxima
        plantTypeValid = true         -- Se o tipo de planta é válido
    },
    timestamp = 1640995200
}
```

**Exemplo de Uso:**
```lua
local coords = {x = 100, y = 200, z = 30}
local validacao = exports['bcc-farming']:IsValidPlantLocation(coords, "corn_Seed")

if validacao.success then
    local dados = validacao.data
    
    if dados.isValid then
        print("✅ Localização válida para plantio!")
    else
        print(string.format("❌ Localização inválida: %s", dados.message))
        
        if dados.reason == "distance" then
            print(string.format("  Plantas próximas: %d", dados.nearbyCount))
            print(string.format("  Distância mínima: %.1fm", dados.closestDistance))
        elseif dados.reason == "town" then
            print(string.format("  Distância da cidade: %.1fm", dados.distance))
        end
    end
end
```

---

### **FindBestPlantingAreas**
Encontra as melhores áreas para plantio em uma região.

**Parâmetros:**
- `centerCoords`: Coordenadas centrais da busca `{x = 0, y = 0, z = 0}`
- `searchRadius` (opcional): Raio de busca em metros (padrão: 5000)
- `maxResults` (opcional): Máximo de resultados (padrão: 10)

**Retorno:**
```lua
{
    success = true,
    data = {
        {
            coords = {x = 150, y = 250, z = 35},
            distanceFromSearch = 500,      -- Distância do centro da busca
            density = 2.5,                 -- Densidade local
            classification = "Low",         -- Classificação da densidade
            nearbyPlants = 5,              -- Plantas próximas
            score = 85.2                   -- Score de qualidade (0-100)
        }
    },
    searchParameters = {
        center = {x = 0, y = 0, z = 0},
        radius = 5000,
        gridSize = 500,                    -- Tamanho da grade de busca
        maxResults = 10,
        totalChecked = 441,                -- Total de pontos verificados
        validFound = 8                     -- Locais válidos encontrados
    },
    timestamp = 1640995200
}
```

**Exemplo de Uso:**
```lua
local centro = {x = -297.48, y = 791.1, z = 118.33} -- Valentine
local melhoresAreas = exports['bcc-farming']:FindBestPlantingAreas(centro, 3000, 5)

if melhoresAreas.success then
    print(string.format("=== MELHORES ÁREAS PARA PLANTIO ==="))
    print(string.format("Encontradas %d áreas de %d verificadas", 
        #melhoresAreas.data, melhoresAreas.searchParameters.totalChecked))
    
    for i, area in ipairs(melhoresAreas.data) do
        print(string.format("\n🏆 Área #%d (Score: %.1f)", i, area.score))
        print(string.format("  Coordenadas: %.1f, %.1f, %.1f", 
            area.coords.x, area.coords.y, area.coords.z))
        print(string.format("  Distância do centro: %dm", area.distanceFromSearch))
        print(string.format("  Densidade local: %.1f (%s)", area.density, area.classification))
        print(string.format("  Plantas próximas: %d", area.nearbyPlants))
    end
end
```

---

### **GetPlantConcentrationMap**
Cria um mapa de concentração de plantas usando sistema de grade.

**Parâmetros:**
- `coords`: Coordenadas centrais `{x = 0, y = 0, z = 0}`
- `radius` (opcional): Raio da análise em metros (padrão: 2000)
- `gridSize` (opcional): Tamanho da grade em metros (padrão: 250)

**Retorno:**
```lua
{
    success = true,
    data = {
        concentrationGrid = {
            {
                coords = {x = 100, y = 200, z = 30},
                gridX = 2,                 -- Posição X na grade
                gridY = 3,                 -- Posição Y na grade
                plantCount = 8,            -- Plantas neste quadrante
                plantTypes = {
                    ["corn_Seed"] = 5,
                    ["apple_Seed"] = 3
                },
                distanceFromCenter = 350
            }
        },
        hotspots = {                       -- Top 3 áreas com mais plantas
            {...}, {...}, {...}
        },
        statistics = {
            maxConcentration = 12,         -- Máxima concentração encontrada
            totalGridsWithPlants = 15,     -- Quadrantes com plantas
            avgPlantsPerGrid = 4.2         -- Média de plantas por quadrante
        }
    },
    parameters = {
        center = {x = 0, y = 0, z = 0},
        radius = 2000,
        gridSize = 250,
        totalGrids = 289                   -- Total de quadrantes verificados
    },
    timestamp = 1640995200
}
```

**Exemplo de Uso:**
```lua
local coords = {x = -801.77, y = -1336.43, z = 43.54} -- Blackwater
local mapa = exports['bcc-farming']:GetPlantConcentrationMap(coords, 1500, 200)

if mapa.success then
    local dados = mapa.data
    
    print("=== MAPA DE CONCENTRAÇÃO ===")
    print(string.format("Área analisada: %dm de raio", mapa.parameters.radius))
    print(string.format("Quadrantes com plantas: %d de %d", 
        dados.statistics.totalGridsWithPlants, mapa.parameters.totalGrids))
    print(string.format("Concentração máxima: %d plantas", dados.statistics.maxConcentration))
    print(string.format("Média por quadrante: %.1f plantas", dados.statistics.avgPlantsPerGrid))
    
    print("\n🔥 Top 3 Hotspots:")
    for i, hotspot in ipairs(dados.hotspots) do
        if hotspot then
            print(string.format("  #%d: %d plantas a %dm do centro", 
                i, hotspot.plantCount, hotspot.distanceFromCenter))
        end
    end
    
    -- Mostrar grade completa se necessário
    if #dados.concentrationGrid <= 20 then -- Só se não for muita informação
        print("\n📊 Grade de Concentração:")
        for _, grid in pairs(dados.concentrationGrid) do
            print(string.format("  Grid [%d,%d]: %d plantas", 
                grid.gridX, grid.gridY, grid.plantCount))
        end
    end
end
```

---

## 🔔 **EXPORTS DE NOTIFICAÇÕES**

### **NotifyReadyPlants**
Notifica jogador sobre plantas prontas para colheita.

**Parâmetros:**
- `playerId`: ID do jogador (number)
- `timeThreshold` (opcional): Limite de tempo em segundos (padrão: 300)

**Retorno:**
```lua
{
    success = true,
    plantsFound = 3,               -- Plantas encontradas
    plantTypes = 2,                -- Tipos diferentes
    timestamp = 1640995200
}
```

**Exemplo de Uso:**
```lua
-- Notificar sobre plantas prontas em 10 minutos
local resultado = exports['bcc-farming']:NotifyReadyPlants(source, 600)
if resultado.success then
    print(string.format("Notificação enviada: %d plantas prontas em breve", resultado.plantsFound))
end
```

---

### **NotifyPlantsNeedWater**
Notifica jogador sobre plantas que precisam de água.

**Parâmetros:**
- `playerId`: ID do jogador (number)

**Retorno:**
```lua
{
    success = true,
    plantsFound = 5,               -- Plantas que precisam água
    plantTypes = 3,                -- Tipos diferentes
    timestamp = 1640995200
}
```

**Exemplo de Uso:**
```lua
local resultado = exports['bcc-farming']:NotifyPlantsNeedWater(source)
if resultado.success and resultado.plantsFound > 0 then
    print(string.format("Jogador notificado: %d plantas precisam água", resultado.plantsFound))
end
```

---

### **NotifyPlantLimits**
Notifica jogador sobre limites de plantas.

**Parâmetros:**
- `playerId`: ID do jogador (number)

**Retorno:**
```lua
{
    success = true,
    data = {
        canPlant = false,
        slotsUsed = 10,
        maxSlots = 10,
        availableSlots = 0,
        usagePercentage = 100
    },
    notificationSent = true,
    timestamp = 1640995200
}
```

**Exemplo de Uso:**
```lua
local resultado = exports['bcc-farming']:NotifyPlantLimits(source)
if resultado.success then
    if resultado.data.usagePercentage >= 80 then
        print("Jogador notificado sobre proximidade do limite")
    end
end
```

---

### **NotifyFarmingEvent**
Notifica jogador sobre eventos específicos de farming.

**Parâmetros:**
- `playerId`: ID do jogador (number)
- `eventType`: Tipo do evento (string) - "plant_grown", "plant_planted", "plant_harvested", "plant_watered", "fertilizer_used", "error", "custom"
- `eventData`: Dados do evento (table)

**Retorno:**
```lua
{
    success = true,
    eventType = "plant_grown",
    timestamp = 1640995200
}
```

**Exemplo de Uso:**
```lua
-- Notificar que planta cresceu
exports['bcc-farming']:NotifyFarmingEvent(source, 'plant_grown', {
    plantName = "Milho"
})

-- Notificar erro personalizado
exports['bcc-farming']:NotifyFarmingEvent(source, 'error', {
    message = "Você não tem ferramentas suficientes"
})

-- Notificação customizada
exports['bcc-farming']:NotifyFarmingEvent(source, 'custom', {
    message = "Evento especial de farming ativado!"
})
```

---

### **SendDailyFarmingReport**
Envia relatório diário de farming para o jogador.

**Parâmetros:**
- `playerId`: ID do jogador (number)

**Retorno:**
```lua
{
    success = true,
    stats = {
        farming = {
            totalPlants = 8,
            readyToHarvest = 2,
            needsWater = 3,
            efficiency = 62
        },
        capacity = {
            usagePercentage = 80
        }
    },
    comparison = {
        comparison = {
            rank = "above_average",
            percentageOfGlobal = 12
        }
    },
    timestamp = 1640995200
}
```

**Exemplo de Uso:**
```lua
-- Enviar relatório diário para jogador
local resultado = exports['bcc-farming']:SendDailyFarmingReport(source)
if resultado.success then
    print("Relatório diário enviado com sucesso")
end

-- Enviar para todos jogadores com plantas
for _, playerId in ipairs(GetPlayers()) do
    local src = tonumber(playerId)
    if src then
        local plantCount = exports['bcc-farming']:GetPlayerPlantCount(src)
        if plantCount.success and plantCount.data > 0 then
            exports['bcc-farming']:SendDailyFarmingReport(src)
        end
    end
end
```

---

### **NotifyPlantSmelled**
Notifica jogador sobre plantas detectadas por cheiro (sistema policial).

**Parâmetros:**
- `playerId`: ID do jogador (number)
- `plantData`: Dados das plantas detectadas (table)

**Retorno:**
```lua
{
    success = true,
    plantsDetected = 3,
    timestamp = 1640995200
}
```

**Exemplo de Uso:**
```lua
-- Usado automaticamente pelo sistema quando jogador policial detecta plantas
exports['bcc-farming']:NotifyPlantSmelled(source, {
    count = 2,
    types = {"hemp_Seed"}
})
```

---

## 💾 **EXPORTS DE CACHE**

### **GetCacheStats**
Retorna estatísticas do sistema de cache.

**Parâmetros:** Nenhum

**Retorno:**
```lua
{
    success = true,
    data = {
        memoryEntries = 45,            -- Entradas na memória
        hits = 150,                    -- Cache hits
        misses = 23,                   -- Cache misses
        writes = 89,                   -- Escritas no cache
        deletes = 12,                  -- Deletions
        hitRate = 86.7,               -- Taxa de acerto (%)
        config = {
            default_ttl = 300,         -- TTL padrão
            market_ttl = 600,          -- TTL do mercado
            player_ttl = 180,          -- TTL do jogador
            max_memory_entries = 1000
        }
    },
    timestamp = 1640995200
}
```

**Exemplo de Uso:**
```lua
local stats = exports['bcc-farming']:GetCacheStats()
if stats.success then
    local dados = stats.data
    print("=== ESTATÍSTICAS DO CACHE ===")
    print(string.format("Taxa de acerto: %.1f%%", dados.hitRate))
    print(string.format("Entradas na memória: %d", dados.memoryEntries))
    print(string.format("Hits: %d | Misses: %d", dados.hits, dados.misses))
    print(string.format("TTL padrão: %ds", dados.config.default_ttl))
    
    if dados.hitRate < 70 then
        print("⚠️ Taxa de acerto baixa - considere ajustar TTLs")
    elseif dados.hitRate > 90 then
        print("✅ Cache funcionando muito bem!")
    end
end
```

---

### **GetGlobalPlantCountCached**
Versão com cache do GetGlobalPlantCount.

**Parâmetros:** Nenhum

**Retorno:** Mesmo que `GetGlobalPlantCount`, mas usando cache

**Exemplo de Uso:**
```lua
-- Usar versão com cache para melhor performance
local total = exports['bcc-farming']:GetGlobalPlantCountCached()
if total.success then
    print("Total de plantas (cache): " .. total.data)
end
```

---

### **ClearCache**
Limpa o cache do sistema.

**Parâmetros:**
- `pattern` (opcional): Padrão para limpeza seletiva (string)

**Retorno:**
```lua
{
    success = true,
    deleted = 15,                  -- Entradas deletadas (se pattern usado)
    message = "All cache cleared", -- Se limpeza total
    timestamp = 1640995200
}
```

**Exemplo de Uso:**
```lua
-- Limpar todo o cache
exports['bcc-farming']:ClearCache()

-- Limpar apenas cache de jogadores
local resultado = exports['bcc-farming']:ClearCache("player:")
print(string.format("Cache de jogadores limpo: %d entradas", resultado.deleted))

-- Limpar cache de dados globais
exports['bcc-farming']:ClearCache("global:")

-- Limpar cache geográfico
exports['bcc-farming']:ClearCache("geo:")
```

---

## 💰 **EXPORTS DE ECONOMIA**

### **GetPlantScarcityIndex**
Calcula o índice de escassez de uma planta.

**Parâmetros:**
- `plantType`: Tipo da planta (string)

**Retorno:**
```lua
{
    success = true,
    data = {
        plantType = "corn_Seed",
        scarcityIndex = 0.35,          -- 0.0 = abundante, 1.0 = muito escasso
        classification = "Medium",      -- "Low", "Medium", "High", "Very High", "Critical"
        activeSupply = 25,             -- Plantas ativas no servidor
        recentDemand = 8,              -- Colheitas nas últimas 24h
        baseline = 15,                 -- Baseline de referência
        supplyRatio = 1.67,            -- Ratio de oferta
        demandRatio = 0.76,            -- Ratio de demanda
        marketCondition = "Balanced"    -- "Sellers Market", "Buyers Market", "Balanced"
    },
    timestamp = 1640995200
}
```

**Exemplo de Uso:**
```lua
local escassez = exports['bcc-farming']:GetPlantScarcityIndex("corn_Seed")
if escassez.success then
    local dados = escassez.data
    
    print(string.format("=== ÍNDICE DE ESCASSEZ - %s ===", dados.plantType))
    print(string.format("Índice: %.2f (%s)", dados.scarcityIndex, dados.classification))
    print(string.format("Oferta ativa: %d plantas", dados.activeSupply))
    print(string.format("Demanda recente: %d colheitas (24h)", dados.recentDemand))
    print(string.format("Condição do mercado: %s", dados.marketCondition))
    
    if dados.scarcityIndex > 0.7 then
        print("🚨 ESCASSEZ CRÍTICA - Preços altos esperados")
    elseif dados.scarcityIndex < 0.3 then
        print("💰 ABUNDÂNCIA - Bom momento para comprar")
    else
        print("⚖️ MERCADO EQUILIBRADO")
    end
end
```

---

### **CalculateDynamicPrice**
Calcula preço dinâmico baseado na escassez.

**Parâmetros:**
- `plantType`: Tipo da planta (string)
- `basePrice`: Preço base (number)

**Retorno:**
```lua
{
    success = true,
    data = {
        plantType = "corn_Seed",
        basePrice = 10.0,              -- Preço base
        dynamicPrice = 13.5,           -- Preço dinâmico calculado
        priceMultiplier = 1.35,        -- Multiplicador aplicado
        previousMultiplier = 1.28,     -- Multiplicador anterior
        scarcityIndex = 0.35,          -- Índice de escassez usado
        priceChange = 5,               -- Mudança de preço (%)
        priceChangeDirection = "up",    -- "up", "down", "stable"
        marketCondition = "Balanced",
        volatilityFactor = 1.02        -- Fator de volatilidade
    },
    timestamp = 1640995200
}
```

**Exemplo de Uso:**
```lua
local preco = exports['bcc-farming']:CalculateDynamicPrice("corn_Seed", 10.0)
if preco.success then
    local dados = preco.data
    
    print(string.format("=== PREÇO DINÂMICO - %s ===", dados.plantType))
    print(string.format("Preço base: $%.2f", dados.basePrice))
    print(string.format("Preço atual: $%.2f (×%.2f)", dados.dynamicPrice, dados.priceMultiplier))
    
    if dados.priceChange ~= 0 then
        print(string.format("Mudança: %+d%% (%s)", dados.priceChange, dados.priceChangeDirection))
    end
    
    print(string.format("Baseado em escassez: %.2f", dados.scarcityIndex))
    
    -- Recomendação de compra/venda
    if dados.priceMultiplier > 1.5 then
        print("💸 VENDA - Preços altos")
    elseif dados.priceMultiplier < 0.8 then
        print("💰 COMPRA - Preços baixos")
    else
        print("⏳ AGUARDE - Preços normais")
    end
end
```

---

### **GetPlantingTrend**
Analisa tendência de plantio de uma planta.

**Parâmetros:**
- `plantType`: Tipo da planta (string)
- `days` (opcional): Dias para análise (padrão: 7)

**Retorno:**
```lua
{
    success = true,
    data = {
        plantType = "corn_Seed",
        trend = "growing",             -- "growing", "declining", "stable", "insufficient_data"
        trendDirection = "up",         -- "up", "down", "flat", "unknown"
        trendStrength = 0.75,         -- Força da tendência (0-1)
        growthRate = 15.2,            -- Taxa de crescimento (%)
        avgDaily = 8.5,               -- Média diária
        period = 7,                   -- Período analisado
        statistics = {
            totalPlanted = 60,
            totalHarvested = 52,
            totalDestroyed = 3,
            harvestRate = 0.87,       -- Taxa de colheita
            lossRate = 0.05,          -- Taxa de perda
            efficiency = 0.82         -- Eficiência geral
        },
        dailyStats = {                -- Estatísticas diárias
            {date = "2023-12-01", planted = 8, harvested = 6, destroyed = 0},
            {date = "2023-12-02", planted = 9, harvested = 7, destroyed = 1}
        }
    },
    timestamp = 1640995200
}
```

**Exemplo de Uso:**
```lua
local tendencia = exports['bcc-farming']:GetPlantingTrend("corn_Seed", 14)
if tendencia.success then
    local dados = tendencia.data
    
    if dados.trend == "insufficient_data" then
        print("⚠️ Dados insuficientes para análise de tendência")
        return
    end
    
    print(string.format("=== TENDÊNCIA - %s (%d dias) ===", dados.plantType, dados.period))
    print(string.format("Tendência: %s (%s)", dados.trend, dados.trendDirection))
    print(string.format("Força da tendência: %.1f%%", dados.trendStrength * 100))
    print(string.format("Taxa de crescimento: %+.1f%%", dados.growthRate))
    print(string.format("Média diária: %.1f plantas", dados.avgDaily))
    
    print(string.format("\n📊 Estatísticas do período:"))
    print(string.format("  Plantadas: %d | Colhidas: %d | Perdidas: %d", 
        dados.statistics.totalPlanted, dados.statistics.totalHarvested, dados.statistics.totalDestroyed))
    print(string.format("  Taxa de colheita: %.1f%%", dados.statistics.harvestRate * 100))
    print(string.format("  Taxa de perda: %.1f%%", dados.statistics.lossRate * 100))
    print(string.format("  Eficiência geral: %.1f%%", dados.statistics.efficiency * 100))
    
    -- Recomendações baseadas na tendência
    if dados.trend == "growing" and dados.trendStrength > 0.5 then
        print("📈 TENDÊNCIA FORTE DE CRESCIMENTO - Mercado aquecido")
    elseif dados.trend == "declining" and dados.trendStrength > 0.5 then
        print("📉 TENDÊNCIA FORTE DE DECLÍNIO - Possível escassez futura")
    else
        print("⚖️ MERCADO ESTÁVEL")
    end
end
```

---

### **GetMarketReport**
Gera relatório completo do mercado.

**Parâmetros:** Nenhum

**Retorno:**
```lua
{
    success = true,
    data = {
        markets = {
            {
                plantType = "corn_Seed",
                scarcityIndex = 0.35,
                scarcityClassification = "Medium",
                priceMultiplier = 1.35,
                priceChange = 5,
                trend = "growing",
                trendStrength = 0.75,
                marketCondition = "bullish",   -- "bullish", "bearish", "neutral"
                recommendation = "BUY"         -- "BUY", "SELL", "HOLD"
            }
        },
        summary = {
            totalMarkets = 15,
            bullishMarkets = 6,            -- Mercados em alta
            bearishMarkets = 4,            -- Mercados em baixa  
            st