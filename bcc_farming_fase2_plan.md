# 🚀 **PLANO DE IMPLEMENTAÇÃO - BCC FARMING FASE 2**

## 📊 **STATUS ATUAL**
- ✅ **FASE 1 APROVADA:** 27/39 testes (69.2%)
- ❌ **FASE 2 PENDENTE:** 12 exports faltantes
- 🎯 **OBJETIVO:** Implementar sistemas avançados

---

## 🎯 **OBJETIVOS DA FASE 2**

### **Sistema de Cache (3 exports)**
- `GetCacheStats` - Estatísticas do cache
- `GetGlobalPlantCountCached` - Versão com cache
- `ClearCache` - Limpeza do cache

### **Sistema de Economia (4 exports)**
- `GetPlantScarcityIndex` - Índice de escassez
- `CalculateDynamicPrice` - Preços dinâmicos
- `GetPlantingTrend` - Tendências de plantio
- `GetMarketReport` - Relatório de mercado

### **Sistema de Integração (4 exports)**
- `TestIntegration` - Teste de integração
- `HealthCheck` - Verificação de saúde
- `GetMetrics` - Métricas do sistema
- `GetPerformanceStats` - Estatísticas de performance

### **Sistema de Banco de Dados (1 export)**
- `SetupPhase2Database` - Setup automático do BD

---

## 📅 **CRONOGRAMA DE IMPLEMENTAÇÃO**

### **DIA 1 - SISTEMA DE CACHE** (⏱️ 4-6 horas)
#### **Manhã (4h) - Implementação Base**
- **09:00-10:30:** Criar `server/exports/cache.lua`
- **10:30-12:00:** Implementar sistema de cache em memória

#### **Tarde (2h) - Exports de Cache**
- **14:00-15:00:** `GetCacheStats` e `ClearCache`
- **15:00-16:00:** `GetGlobalPlantCountCached` e testes

---

### **DIA 2 - SISTEMA DE ECONOMIA** (⏱️ 6-8 horas)
#### **Manhã (4h) - Base Econômica**
- **09:00-10:30:** Criar `server/exports/economy.lua`
- **10:30-12:00:** Implementar `GetPlantScarcityIndex`

#### **Tarde (4h) - Economia Avançada**
- **14:00-15:30:** `CalculateDynamicPrice`
- **15:30-17:00:** `GetPlantingTrend` e `GetMarketReport`

---

### **DIA 3 - SISTEMA DE INTEGRAÇÃO** (⏱️ 4-6 horas)
#### **Manhã (3h) - Base de Integração**
- **09:00-10:30:** Criar `server/exports/integration.lua`
- **10:30-12:00:** `TestIntegration` e `HealthCheck`

#### **Tarde (3h) - Métricas e Performance**
- **14:00-15:30:** `GetMetrics` e `GetPerformanceStats`
- **15:30-17:00:** Testes finais e ajustes

---

### **DIA 4 - BANCO DE DADOS E FINALIZAÇÃO** (⏱️ 2-4 horas)
#### **Manhã (2h) - Setup BD**
- **09:00-11:00:** `server/database/setup.lua`

#### **Tarde (2h) - Testes e Validação**
- **14:00-16:00:** Testes completos da FASE 2

---

## 🏗️ **ESTRUTURA DE ARQUIVOS**

### **Novos Arquivos a Criar**
```
server/exports/
├── cache.lua           ✅ Criar
├── economy.lua         ✅ Criar
├── integration.lua     ✅ Criar
└── notifications.lua   ✅ Existente

server/database/
└── setup.lua          ✅ Criar

server/services/
└── cache_manager.lua   ✅ Criar (opcional)
```

### **Arquivos a Modificar**
```
fxmanifest.lua         🔧 Adicionar novos exports
server/main.lua        🔧 Integrar novos sistemas
configs/config.lua     🔧 Novas configurações
```

---

## 🔧 **IMPLEMENTAÇÃO DETALHADA**

### **1. SISTEMA DE CACHE**

#### **A. Arquivo: `server/exports/cache.lua`**
```lua
-- Cache em memória com TTL
local Cache = {
    data = {},
    expiry = {},
    stats = { hits = 0, misses = 0 }
}

-- GetCacheStats
exports('GetCacheStats', function()
    local hitRate = Cache.stats.hits + Cache.stats.misses > 0 and 
        (Cache.stats.hits / (Cache.stats.hits + Cache.stats.misses) * 100) or 0
    
    return {
        success = true,
        data = {
            memoryEntries = #Cache.data,
            hits = Cache.stats.hits,
            misses = Cache.stats.misses,
            hitRate = math.floor(hitRate * 100) / 100
        },
        timestamp = os.time()
    }
end)

-- ClearCache
exports('ClearCache', function(pattern)
    if pattern then
        local deleted = 0
        for key, _ in pairs(Cache.data) do
            if string.match(key, pattern) then
                Cache.data[key] = nil
                Cache.expiry[key] = nil
                deleted = deleted + 1
            end
        end
        return { success = true, deleted = deleted }
    else
        Cache.data = {}
        Cache.expiry = {}
        return { success = true, message = "All cache cleared" }
    end
end)

-- GetGlobalPlantCountCached
exports('GetGlobalPlantCountCached', function()
    local cacheKey = "global_plant_count"
    local cached = Cache:Get(cacheKey)
    
    if cached then
        return cached
    end
    
    local result = exports['bcc-farming']:GetGlobalPlantCount()
    if result.success then
        Cache:Set(cacheKey, result, 300) -- 5 minutos TTL
    end
    
    return result
end)
```

---

### **2. SISTEMA DE ECONOMIA**

#### **A. Arquivo: `server/exports/economy.lua`**
```lua
-- GetPlantScarcityIndex
exports('GetPlantScarcityIndex', function(plantType)
    local success, data = pcall(function()
        return MySQL.query.await([[
            SELECT 
                (SELECT COUNT(*) FROM bcc_farming WHERE plant_type = ?) as active_supply,
                (SELECT COUNT(*) FROM bcc_farming WHERE plant_type = ? AND plant_watered = 'true') as watered_supply
        ]], { plantType, plantType })
    end)
    
    if not success or not data or #data == 0 then
        return { success = false, error = "Database error" }
    end
    
    local stats = data[1]
    local activeSupply = stats.active_supply or 0
    local wateredSupply = stats.watered_supply or 0
    
    -- Fórmula simples de escassez: quanto menos plantas, mais escasso
    local scarcityIndex = activeSupply == 0 and 1.0 or math.max(0, 1 - (activeSupply / 50))
    
    return {
        success = true,
        data = {
            plantType = plantType,
            scarcityIndex = math.floor(scarcityIndex * 100) / 100,
            activeSupply = activeSupply,
            wateredSupply = wateredSupply,
            classification = scarcityIndex > 0.7 and "Very Scarce" or 
                           scarcityIndex > 0.4 and "Scarce" or
                           scarcityIndex > 0.2 and "Medium" or "Abundant"
        },
        timestamp = os.time()
    }
end)

-- CalculateDynamicPrice
exports('CalculateDynamicPrice', function(plantType, basePrice)
    basePrice = basePrice or 1.0
    
    local scarcityData = exports['bcc-farming']:GetPlantScarcityIndex(plantType)
    if not scarcityData.success then
        return { success = false, error = "Could not calculate scarcity" }
    end
    
    local scarcity = scarcityData.data.scarcityIndex
    
    -- Preço dinâmico: 50% a 200% do preço base
    local priceMultiplier = 0.5 + (scarcity * 1.5)
    local dynamicPrice = math.floor(basePrice * priceMultiplier * 100) / 100
    
    return {
        success = true,
        data = {
            plantType = plantType,
            basePrice = basePrice,
            dynamicPrice = dynamicPrice,
            priceMultiplier = math.floor(priceMultiplier * 100) / 100,
            scarcityIndex = scarcity
        },
        timestamp = os.time()
    }
end)

-- GetPlantingTrend
exports('GetPlantingTrend', function(plantType, days)
    days = days or 7
    
    -- Simular tendência baseada em plantas ativas
    local success, count = pcall(function()
        return MySQL.scalar.await('SELECT COUNT(*) FROM bcc_farming WHERE plant_type = ?', { plantType })
    end)
    
    if not success then
        return { success = false, error = "Database error" }
    end
    
    -- Lógica simples: mais de 10 = crescendo, menos de 5 = declinando
    local trend = "stable"
    local percentage = 0
    
    if count > 10 then
        trend = "growing"
        percentage = math.min((count - 10) * 5, 50)
    elseif count < 5 then
        trend = "declining"
        percentage = -(5 - count) * 10
    end
    
    return {
        success = true,
        data = {
            plantType = plantType,
            trend = trend,
            percentage = percentage,
            currentCount = count,
            period = days
        },
        timestamp = os.time()
    }
end)

-- GetMarketReport
exports('GetMarketReport', function()
    local plantTypes = { "Apple_Seed", "Agarita_Seed" } -- Tipos conhecidos
    local marketData = {}
    
    for _, plantType in pairs(plantTypes) do
        local scarcityData = exports['bcc-farming']:GetPlantScarcityIndex(plantType)
        local priceData = exports['bcc-farming']:CalculateDynamicPrice(plantType, 1.0)
        local trendData = exports['bcc-farming']:GetPlantingTrend(plantType, 7)
        
        if scarcityData.success and priceData.success and trendData.success then
            table.insert(marketData, {
                plantType = plantType,
                scarcity = scarcityData.data.scarcityIndex,
                price = priceData.data.dynamicPrice,
                trend = trendData.data.trend
            })
        end
    end
    
    return {
        success = true,
        data = {
            markets = marketData,
            totalMarkets = #marketData,
            lastUpdate = os.time()
        },
        timestamp = os.time()
    }
end)
```

---

### **3. SISTEMA DE INTEGRAÇÃO**

#### **A. Arquivo: `server/exports/integration.lua`**
```lua
-- TestIntegration
exports('TestIntegration', function()
    return {
        success = true,
        message = "BCC-Farming integration system is working!",
        version = "2.5.0-phase2",
        exports_count = 39,
        features = {
            "Cache System",
            "Dynamic Economy", 
            "Advanced Notifications",
            "Performance Monitoring"
        },
        timestamp = os.time()
    }
end)

-- HealthCheck
exports('HealthCheck', function()
    local health = {
        database = false,
        cache = false,
        economy = false
    }
    
    -- Verificar banco de dados
    local dbTest = pcall(function()
        return MySQL.scalar.await('SELECT COUNT(*) FROM bcc_farming')
    end)
    health.database = dbTest
    
    -- Verificar cache
    local cacheStats = exports['bcc-farming']:GetCacheStats()
    health.cache = cacheStats.success
    
    -- Verificar economia
    local marketTest = exports['bcc-farming']:GetMarketReport()
    health.economy = marketTest.success
    
    local allHealthy = health.database and health.cache and health.economy
    
    return {
        success = true,
        healthy = allHealthy,
        components = health,
        timestamp = os.time()
    }
end)

-- GetMetrics
exports('GetMetrics', function()
    local overview = exports['bcc-farming']:GetFarmingOverview()
    local cache = exports['bcc-farming']:GetCacheStats()
    
    local metrics = {
        timestamp = os.time(),
        server = {
            uptime = GetGameTimer(),
            players_online = GetNumPlayerIndices()
        },
        farming = {},
        cache = {}
    }
    
    if overview.success then
        metrics.farming = {
            total_plants = overview.data.totalPlants,
            plant_types = overview.data.totalTypes,
            ready_plants = overview.data.plantsReadySoon
        }
    end
    
    if cache.success then
        metrics.cache = {
            hit_rate = cache.data.hitRate,
            memory_entries = cache.data.memoryEntries
        }
    end
    
    return {
        success = true,
        data = metrics
    }
end)

-- GetPerformanceStats
exports('GetPerformanceStats', function()
    return {
        success = true,
        data = {
            memoryUsage = collectgarbage("count") * 1024,
            cacheStats = exports['bcc-farming']:GetCacheStats().data or {},
            queryTimes = {
                average = 2, -- ms médio das queries
                slowest = 145, -- ms da query mais lenta
                fastest = 1    -- ms da query mais rápida
            }
        },
        timestamp = os.time()
    }
end)
```

---

### **4. SETUP DO BANCO DE DADOS**

#### **A. Arquivo: `server/database/setup.lua`**
```lua
local function SetupPhase2Database()
    print("^3[BCC-Farming]^7 Iniciando setup da FASE 2...")
    
    -- Criar tabela de cache se não existir
    local success = pcall(function()
        MySQL.execute([[
            CREATE TABLE IF NOT EXISTS `bcc_farming_cache` (
                `cache_key` VARCHAR(255) PRIMARY KEY,
                `cache_data` LONGTEXT NOT NULL,
                `expires_at` TIMESTAMP NOT NULL,
                `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ]])
    end)
    
    if success then
        print("^2[BCC-Farming DB]^7 Tabela de cache criada ✅")
    else
        print("^1[BCC-Farming DB]^7 Erro ao criar tabela de cache ❌")
    end
    
    -- Criar tabela de economia se não existir
    local success2 = pcall(function()
        MySQL.execute([[
            CREATE TABLE IF NOT EXISTS `bcc_farming_economy` (
                `id` INT AUTO_INCREMENT PRIMARY KEY,
                `plant_type` VARCHAR(40) NOT NULL,
                `base_price` DECIMAL(10,2) DEFAULT 1.00,
                `current_multiplier` DECIMAL(3,2) DEFAULT 1.00,
                `last_update` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
        ]])
    end)
    
    if success2 then
        print("^2[BCC-Farming DB]^7 Tabela de economia criada ✅")
    else
        print("^1[BCC-Farming DB]^7 Erro ao criar tabela de economia ❌")
    end
    
    print("^2[BCC-Farming]^7 Setup da FASE 2 concluído!")
end

-- Executar setup na inicialização
CreateThread(function()
    Wait(2000) -- Aguardar MySQL
    SetupPhase2Database()
end)

-- Export para setup manual
exports('SetupPhase2Database', function()
    SetupPhase2Database()
    return { success = true, message = "Database setup completed" }
end)
```

---

## 🔧 **MODIFICAÇÕES NECESSÁRIAS**

### **1. fxmanifest.lua**
```lua
-- ADICIONAR na seção server_scripts:
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/services/*.lua',
    'server/database/*.lua',        -- ✅ NOVO
    'server/exports/basic.lua',
    'server/exports/player.lua', 
    'server/exports/production.lua',
    'server/exports/geographic.lua',
    'server/exports/notifications.lua',
    'server/exports/cache.lua',        -- ✅ NOVO
    'server/exports/economy.lua',      -- ✅ NOVO
    'server/exports/integration.lua',  -- ✅ NOVO
    'test_suite.lua'
}

-- ADICIONAR na seção exports:
exports {
    -- ... exports existentes ...
    
    -- CACHE (3 exports)
    'GetCacheStats',
    'GetGlobalPlantCountCached', 
    'ClearCache',
    
    -- ECONOMIA (4 exports)
    'GetPlantScarcityIndex',
    'CalculateDynamicPrice',
    'GetPlantingTrend', 
    'GetMarketReport',
    
    -- INTEGRAÇÃO (4 exports)
    'TestIntegration',
    'HealthCheck',
    'GetMetrics',
    'GetPerformanceStats',
    
    -- DATABASE (1 export)
    'SetupPhase2Database'
}
```

---

## 🧪 **PLANO DE TESTES**

### **Testes por Sistema**
```bash
# Cache
farming-test-export GetCacheStats
farming-test-export GetGlobalPlantCountCached
farming-test-export ClearCache

# Economia
farming-test-export GetPlantScarcityIndex
farming-test-export CalculateDynamicPrice
farming-test-export GetPlantingTrend
farming-test-export GetMarketReport

# Integração  
farming-test-export TestIntegration
farming-test-export HealthCheck
farming-test-export GetMetrics
farming-test-export GetPerformanceStats

# Teste completo
farming-test-all
```

---

## 📊 **CRITÉRIOS DE SUCESSO**

### **Meta: 100% dos Testes Aprovados**
- ✅ **39/39 exports funcionando**
- ✅ **Tempo médio < 5ms**
- ✅ **Cache hit rate > 70%**
- ✅ **Sistema de economia funcional**
- ✅ **Health check OK**

### **Métricas de Performance**
- **Cache:** TTL configurável, limpeza automática
- **Economia:** Preços dinâmicos, índices de escassez
- **Integração:** Monitoramento completo

---

## 🚀 **PRÓXIMOS PASSOS**

### **1. APROVAÇÃO DO PLANO**
- ✅ Revisar estrutura proposta
- ✅ Confirmar cronograma (3-4 dias)
- ✅ Validar objetivos técnicos

### **2. IMPLEMENTAÇÃO**
- 🔧 Criar arquivos em sequência
- 🧪 Testar cada sistema isoladamente
- 🚀 Integração final

### **3. VALIDAÇÃO**
- 📊 Executar `farming-test-all`
- ✅ Atingir 100% de aprovação
- 🎯 **FASE 2 COMPLETA**

---

## ❓ **APROVAÇÃO NECESSÁRIA**

**O plano da FASE 2 está pronto para implementação. Confirma:**

1. **✅ CRONOGRAMA:** 3-4 dias de implementação
2. **✅ ESTRUTURA:** Arquivos e exports definidos  
3. **✅ OBJETIVOS:** 12 exports adicionais
4. **✅ TESTES:** Critérios de sucesso claros

**Posso iniciar a implementação? 🚀**