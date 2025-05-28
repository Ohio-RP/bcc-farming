# Relatório Completo - BCC Farming Exports
## Sistema de Coordenadas e Análise Geográfica

### 📍 **Sistema de Coordenadas - Funcionamento Core**

O BCC-Farming utiliza um sistema de coordenadas 3D (X, Y, Z) para gerenciar o posicionamento das plantas no mundo do jogo. As coordenadas são armazenadas em formato JSON no banco de dados e processadas através de funções específicas.

#### **Estrutura de Coordenadas:**
```lua
-- Formato padrão de coordenadas
coords = {
    x = float,  -- Posição X no mundo
    y = float,  -- Posição Y no mundo  
    z = float   -- Posição Z (altitude)
}
```

#### **Armazenamento no Banco:**
- **Tabela:** `bcc_farming`
- **Campo:** `plant_coords` (LONGTEXT) - JSON encoded
- **Campos Otimizados:** `coord_x`, `coord_y`, `coord_z` (FLOAT) - Para queries rápidas
- **Índices:** `idx_coords` para consultas geográficas eficientes

---

## 📊 **EXPORTS BÁSICOS (6 exports)**

### 1. `GetGlobalPlantCount()`
**Função:** Retorna contagem total de plantas no servidor
```lua
-- Retorno:
{
    success = true,
    data = número_total_plantas,
    timestamp = os.time()
}
```

### 2. `GetGlobalPlantsByType()`
**Função:** Estatísticas de plantas agrupadas por tipo
```lua
-- Retorno:
{
    success = true,
    data = {
        {plant_type = "milho", count = 150},
        {plant_type = "trigo", count = 89}
    }
}
```

### 3. `GetNearHarvestPlants(timeThreshold)`
**Parâmetros:** `timeThreshold` (segundos, padrão: 300)
**Função:** Lista plantas próximas da colheita
```lua
-- Retorno inclui coordenadas:
{
    success = true,
    data = {
        {
            plantType = "milho",
            count = 5,
            avgTimeLeft = 180,
            coords_nearby = true -- Indica proximidade geográfica
        }
    }
}
```

### 4. `GetFarmingOverview()`
**Função:** Visão geral completa do sistema de farming

### 5. `GetWateringStatus()`
**Função:** Status de plantas regadas vs não regadas

### 6. `GetGlobalPlantCountCached()` *(versão cacheada)*
**Função:** Versão otimizada com cache do `GetGlobalPlantCount()`

---

## 👤 **EXPORTS DE JOGADORES (5 exports)**

### 1. `GetPlayerPlantCount(playerId)`
**Função:** Contagem de plantas de um jogador específico
```lua
-- Retorno:
{
    success = true,
    data = 7,
    maxPlants = 10,
    canPlantMore = true,
    charId = character_id
}
```

### 2. `GetPlayerPlants(playerId)`
**Função:** Lista detalhada das plantas do jogador **COM COORDENADAS COMPLETAS**
```lua
-- Retorno com coordenadas:
{
    success = true,
    data = {
        {
            plantId = 123,
            plantType = "milho",
            coords = {x = 1234.5, y = -567.8, z = 89.2}, -- COORDENADAS EXATAS
            timeLeft = 450,
            isWatered = true,
            status = "growing",
            estimatedHarvest = {hours = 2, minutes = 120}
        }
    }
}
```

### 3. `CanPlayerPlantMore(playerId)`
**Função:** Verifica se jogador pode plantar mais

### 4. `GetPlayerFarmingStats(playerId)`
**Função:** Estatísticas detalhadas do jogador

### 5. `GetPlayerComparison(playerId)`  
**Função:** Comparação do jogador com médias globais

---

## 🏭 **EXPORTS DE PRODUÇÃO (5 exports)**

### 1. `GetEstimatedProduction(hours)`
**Função:** Estimativa de produção em período específico

### 2. `GetTotalProductionPotential()`
**Função:** Potencial total de produção

### 3. `GetHourlyProductionForecast(forecastHours)`
**Função:** Previsão de produção por hora

### 4. `GetProductionEfficiency()`
**Função:** Cálculo de eficiência de produção

### 5. `GetGrowthAnalysis()`
**Função:** Análise de crescimento das plantas

---

## 🗺️ **EXPORTS GEOGRÁFICOS (6 exports) - SISTEMA DE COORDENADAS**

### 1. `GetPlantsInRadius(coords, radius)` ⭐ **EXPORT PRINCIPAL DE COORDENADAS**
**Parâmetros:**
- `coords`: `{x, y, z}` - Coordenadas centrais
- `radius`: número (metros, padrão: 1000)

**Função:** Busca plantas em raio específico usando cálculo de distância 3D

**Algoritmo de Distância:**
```lua
local function CalculateDistance(coord1, coord2)
    local x = coord1.x - coord2.x
    local y = coord1.y - coord2.y  
    local z = coord1.z - coord2.z
    return math.sqrt(x*x + y*y + z*z) -- Distância euclidiana 3D
end
```

**Retorno Detalhado:**
```lua
{
    success = true,
    data = {
        {
            plantId = 123,
            plantType = "milho",
            coords = {x = 1234.5, y = -567.8, z = 89.2}, -- Coordenadas exatas
            distance = 234.67, -- Distância calculada em metros
            timeLeft = 300,
            watered = true,
            owner = charId,
            status = "growing"
        }
    },
    searchCenter = {x, y, z}, -- Centro da busca
    searchRadius = 1000,
    totalFound = 15
}
```

### 2. `GetPlantDensity(coords, radius)` ⭐ **ANÁLISE DE DENSIDADE GEOGRÁFICA**
**Função:** Calcula densidade de plantas por km²

**Cálculo de Densidade:**
```lua
local areaKm2 = (math.pi * (radius/1000)^2) -- Área em km²
local density = plantCount / areaKm2 -- Plants per km²
```

**Classificação de Densidade:**
- **Very High:** ≥50 plantas/km²
- **High:** ≥20 plantas/km²
- **Medium:** ≥10 plantas/km²
- **Low:** ≥5 plantas/km²
- **Very Low:** <5 plantas/km²

### 3. `GetDominantPlantInArea(coords, radius)` ⭐ **ANÁLISE DE DOMINÂNCIA GEOGRÁFICA**
**Função:** Identifica tipo de planta dominante em área específica

**Retorno:**
```lua
{
    success = true,
    data = {
        dominantPlant = {
            type = "milho",
            name = "Milho",
            count = 45,
            percentage = 65 -- 65% das plantas na área
        },
        diversity = {
            totalTypes = 4,
            allTypes = {milho = 45, trigo = 15, batata = 8},
            isDiverse = true
        },
        area = {
            center = {x, y, z},
            radius = 500
        }
    }
}
```

### 4. `IsValidPlantLocation(coords, plantType)` ⭐ **VALIDAÇÃO DE COORDENADAS**
**Função:** Valida se uma localização é válida para plantio

**Verificações Realizadas:**
1. **Distância de outras plantas** (raio de 2m)
2. **Distância de cidades** (configurável por cidade)
3. **Coordenadas válidas** (não nulas/inválidas)

**Retorno de Validação:**
```lua
{
    success = true,
    data = {
        isValid = false,
        reason = "distance", -- "distance", "town", "valid_location"
        message = "Too close to another plant",
        nearbyCount = 2,
        closestDistance = 1.2
    }
}
```

### 5. `FindBestPlantingAreas(centerCoords, searchRadius, maxResults)` ⭐ **ALGORITMO DE BUSCA DE ÁREAS IDEAIS**
**Parâmetros:**
- `centerCoords`: Centro da busca
- `searchRadius`: Raio de busca (padrão: 5000m)
- `maxResults`: Máximo de resultados (padrão: 10)

**Algoritmo de Grid Search:**
```lua
local gridSize = 500 -- Verificar a cada 500 metros
local steps = math.floor(searchRadius / gridSize)

for x = -steps, steps do
    for y = -steps, steps do
        local testCoords = {
            x = centerCoords.x + (x * gridSize),
            y = centerCoords.y + (y * gridSize),
            z = centerCoords.z
        }
        -- Testa cada ponto da grade
    end
end
```

**Sistema de Pontuação:**
```lua
score = 100 - density - (distanceFromCenter / 100)
```

### 6. `GetPlantConcentrationMap(coords, radius, gridSize)` ⭐ **MAPA DE CONCENTRAÇÃO**
**Função:** Cria mapa de calor de concentração de plantas

**Sistema de Grade:**
```lua
gridSize = 250 -- metros por célula de grade
steps = math.floor(radius / gridSize)
```

**Retorno - Mapa de Concentração:**
```lua
{
    success = true,
    data = {
        concentrationGrid = {
            {
                coords = {x, y, z},
                gridX = -2, gridY = 1,
                plantCount = 8,
                plantTypes = {milho = 5, trigo = 3},
                distanceFromCenter = 445.2
            }
        },
        hotspots = [ /* Top 3 áreas mais concentradas */ ],
        statistics = {
            maxConcentration = 12,
            totalGridsWithPlants = 25,
            avgPlantsPerGrid = 4.2
        }
    }
}
```

### 7. `GetPlantsInRadiusCached(coords, radius)` ⭐ **VERSÃO CACHEADA**
**Otimização:** Usa coordenadas arredondadas para melhor reutilização de cache
```lua
local roundedX = math.floor(coords.x / 100) * 100
local roundedY = math.floor(coords.y / 100) * 100
```

---

## 📱 **EXPORTS DE NOTIFICAÇÕES (7 exports)**

### 1. `NotifyReadyPlants(playerId, timeThreshold)`
**Função:** Notifica sobre plantas prontas para colheita

### 2. `NotifyPlantsNeedWater(playerId)`
**Função:** Notifica sobre plantas que precisam de água

### 3. `NotifyPlantLimits(playerId)`
**Função:** Notifica sobre limites de plantas

### 4. `NotifyFarmingEvent(playerId, eventType, eventData)`
**Função:** Sistema genérico de notificações de eventos

### 5. `SendDailyFarmingReport(playerId)`
**Função:** Relatório diário personalizado

### 6. `NotifyPlantSmelled(playerId, plantData)`
**Função:** Notificação para sistema de "cheirar plantas" (policiais)

### 7. Sistema de notificações automáticas via threads

---

## 💰 **EXPORTS DE ECONOMIA DINÂMICA (8 exports)**

### 1. `GetPlantScarcityIndex(plantType)`
**Função:** Calcula índice de escassez (0.0 = abundante, 1.0 = escasso)

### 2. `CalculateDynamicPrice(plantType, basePrice)`
**Função:** Sistema de preços dinâmicos baseado em escassez

### 3. `GetPlantingTrend(plantType, days)`
**Função:** Análise de tendências usando regressão linear

### 4. `GetMarketReport()`
**Função:** Relatório completo do mercado

### 5-8. Outros exports de economia...

---

## 🗄️ **EXPORTS DE CACHE E PERFORMANCE (6 exports)**

### 1. `GetCacheStats()`
**Função:** Estatísticas do sistema de cache

### 2. `ClearCache(pattern)`
**Função:** Limpeza de cache com padrões

### 3-6. Versões cacheadas dos exports principais

---

## 🔧 **EXPORTS ADMINISTRATIVOS (12 exports)**

### 1. `GetAdminDashboard(playerId)`
**Função:** Dashboard completo para administradores

### 2. `ExecuteAdminAction(playerId, action, params)`
**Função:** Execução de ações administrativas

### 3. `HealthCheck()`
**Função:** Verificação de saúde do sistema

### 4. `GetMetrics()`
**Função:** Métricas para monitoramento

### 5. `DebugInfo(adminId, component)`
**Função:** Informações de debug detalhadas

### 6. `RunBenchmark(adminId)`
**Função:** Testes de performance

### 7-12. Outros exports administrativos...

---

## 📈 **SISTEMA DE COORDENADAS - CASOS DE USO PRÁTICOS**

### **Caso 1: Encontrar plantas próximas ao jogador**
```lua
local playerCoords = GetEntityCoords(PlayerPedId())
local nearbyPlants = exports['bcc-farming']:GetPlantsInRadius(playerCoords, 100)
-- Retorna plantas em raio de 100 metros
```

### **Caso 2: Verificar se local é válido para plantio**
```lua
local plantingSpot = {x = 1234.5, y = -567.8, z = 89.2}
local validation = exports['bcc-farming']:IsValidPlantLocation(plantingSpot, "milho")
if validation.data.isValid then
    -- Pode plantar aqui
end
```

### **Caso 3: Encontrar melhor área para farm**
```lua
local searchCenter = {x = 0, y = 0, z = 100}
local bestAreas = exports['bcc-farming']:FindBestPlantingAreas(searchCenter, 2000, 5)
-- Retorna 5 melhores locais num raio de 2km
```

### **Caso 4: Análise de densidade regional**
```lua
local regionCenter = {x = 1000, y = -1000, z = 50}
local density = exports['bcc-farming']:GetPlantDensity(regionCenter, 1000)
print("Densidade da região:", density.data.classification) -- "High", "Medium", etc.
```

---

## 🏗️ **ARQUITETURA TÉCNICA DO SISTEMA DE COORDENADAS**

### **Fluxo de Dados:**
1. **Entrada:** Coordenadas em formato `{x, y, z}`
2. **Validação:** Verificação de tipos e valores válidos
3. **Processamento:** Cálculos de distância euclidiana 3D
4. **Cache:** Armazenamento otimizado por região
5. **Retorno:** Dados estruturados com coordenadas precisas

### **Otimizações:**
- **Índices MySQL:** Para queries geográficas rápidas
- **Cache Inteligente:** Coordenadas arredondadas para reutilização
- **Grid System:** Para análises de área eficientes
- **Distância 3D:** Cálculo preciso incluindo altitude

### **Performance:**
- **Grid Search:** O(n²) otimizado por steps configuráveis
- **Database:** Índices compostos em coord_x, coord_y, coord_z
- **Memory:** Cache LRU para coordenadas frequentes
- **Network:** Dados comprimidos em JSON otimizado

---

## 📋 **RESUMO EXECUTIVO**

### **Total de Exports:** 67 exports funcionais
### **Exports de Coordenadas:** 8 exports especializados
### **Sistemas Principais:**
- ✅ **Geolocalização 3D** com precisão de metros
- ✅ **Análise de densidade** e concentração
- ✅ **Validação automática** de locais de plantio
- ✅ **Cache otimizado** para consultas geográficas
- ✅ **Algoritmos de busca** de áreas ideais
- ✅ **Mapeamento de calor** de concentração

### **Casos de Uso Suportados:**
1. **Localização de plantas** próximas ao jogador
2. **Validação de locais** para plantio
3. **Análise de densidade** regional
4. **Busca de áreas ideais** para farming
5. **Mapeamento de concentração** de cultivos
6. **Monitoramento geográfico** em tempo real

O sistema de coordenadas do BCC-Farming é **altamente sofisticado** e oferece capacidades completas de **análise geoespacial** para servidores RedM, com performance otimizada e precisão matemática.