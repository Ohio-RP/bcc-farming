-- server/exports/cache.lua
-- FASE 2 - Sistema de Cache Avançado com persistência em banco

local Cache = {
    memory = {},
    expiry = {},
    stats = { 
        hits = 0, 
        misses = 0, 
        writes = 0,
        deletes = 0,
        memory_usage = 0
    },
    config = {
        default_ttl = 300,     -- 5 minutos
        market_ttl = 600,      -- 10 minutos
        player_ttl = 180,      -- 3 minutos
        max_memory_entries = 1000
    }
}

-- Função para obter configuração dinâmica
local function GetCacheConfig(key, default)
    local success, result = pcall(function()
        return MySQL.scalar.await('SELECT config_value FROM bcc_farming_config WHERE config_key = ?', { key })
    end)
    
    if success and result then
        local value = tonumber(result)
        return value or (result == 'true' and true or result == 'false' and false or result)
    end
    
    return default
end

-- Atualizar configurações do cache
local function UpdateCacheConfig()
    Cache.config.default_ttl = GetCacheConfig('cache_ttl_default', 300)
    Cache.config.market_ttl = GetCacheConfig('cache_ttl_market', 600)
end

-- Gerar chave de cache consistente
local function GenerateCacheKey(namespace, ...)
    local parts = { namespace }
    for _, arg in ipairs({...}) do
        table.insert(parts, tostring(arg))
    end
    return table.concat(parts, ":")
end

-- Verificar se entrada está expirada
local function IsExpired(key)
    return Cache.expiry[key] and Cache.expiry[key] <= os.time()
end

-- Limpar memória se necessário
local function CleanupMemory()
    local count = 0
    for _ in pairs(Cache.memory) do
        count = count + 1
    end
    
    if count > Cache.config.max_memory_entries then
        -- Remover 25% das entradas mais antigas
        local toRemove = math.floor(count * 0.25)
        local removed = 0
        
        for key, expiry in pairs(Cache.expiry) do
            if removed >= toRemove then break end
            if expiry <= os.time() + 60 then -- Remover se expira em 1 minuto
                Cache.memory[key] = nil
                Cache.expiry[key] = nil
                removed = removed + 1
            end
        end
    end
    
    Cache.stats.memory_usage = count
end

-- Obter do cache (memória primeiro, depois banco)
function Cache:Get(key)
    CleanupMemory()
    
    -- Verificar memória primeiro
    if self.memory[key] and not IsExpired(key) then
        self.stats.hits = self.stats.hits + 1
        return self.memory[key]
    end
    
    -- Verificar banco de dados
    local success, result = pcall(function()
        return MySQL.scalar.await([[
            SELECT cache_data FROM bcc_farming_cache 
            WHERE cache_key = ? AND expires_at > NOW()
        ]], { key })
    end)
    
    if success and result then
        local data = json.decode(result)
        if data then
            -- Colocar de volta na memória
            self.memory[key] = data
            self.expiry[key] = os.time() + self.config.default_ttl
            self.stats.hits = self.stats.hits + 1
            return data
        end
    end
    
    self.stats.misses = self.stats.misses + 1
    return nil
end

-- Armazenar no cache (memória e banco)
function Cache:Set(key, value, ttl)
    ttl = ttl or self.config.default_ttl
    local expiresAt = os.time() + ttl
    
    -- Armazenar na memória
    self.memory[key] = value
    self.expiry[key] = expiresAt
    
    -- Armazenar no banco de dados (async)
    CreateThread(function()
        local success = pcall(function()
            MySQL.execute('REPLACE INTO bcc_farming_cache (cache_key, cache_data, expires_at) VALUES (?, ?, FROM_UNIXTIME(?))',
                { key, json.encode(value), expiresAt })
        end)
        
        if success then
            self.stats.writes = self.stats.writes + 1
        end
    end)
end

-- Invalidar cache com padrão
function Cache:Invalidate(pattern)
    local deleted = 0
    
    -- Limpar da memória
    for key, _ in pairs(self.memory) do
        if string.match(key, pattern) then
            self.memory[key] = nil
            self.expiry[key] = nil
            deleted = deleted + 1
        end
    end
    
    -- Limpar do banco de dados (async)
    CreateThread(function()
        pcall(function()
            MySQL.execute('DELETE FROM bcc_farming_cache WHERE cache_key LIKE ?', 
                { pattern:gsub("%%", "%%%%") })
        end)
    end)
    
    self.stats.deletes = self.stats.deletes + deleted
    return deleted
end

-- Limpar cache expirado
function Cache:Cleanup()
    local cleaned = 0
    local now = os.time()
    
    -- Limpar memória
    for key, expiry in pairs(self.expiry) do
        if expiry <= now then
            self.memory[key] = nil
            self.expiry[key] = nil
            cleaned = cleaned + 1
        end
    end
    
    -- Limpar banco de dados
    CreateThread(function()
        pcall(function()
            MySQL.execute('DELETE FROM bcc_farming_cache WHERE expires_at < NOW()')
        end)
    end)
    
    return cleaned
end

-- Export das estatísticas do cache
exports('GetCacheStats', function()
    local memoryCount = 0
    for _ in pairs(Cache.memory) do
        memoryCount = memoryCount + 1
    end
    
    local hitRate = Cache.stats.hits + Cache.stats.misses > 0 and 
        (Cache.stats.hits / (Cache.stats.hits + Cache.stats.misses) * 100) or 0
    
    return {
        success = true,
        data = {
            memoryEntries = memoryCount,
            hits = Cache.stats.hits,
            misses = Cache.stats.misses,
            writes = Cache.stats.writes,
            deletes = Cache.stats.deletes,
            hitRate = math.floor(hitRate * 100) / 100,
            config = Cache.config
        },
        timestamp = os.time()
    }
end)

-- Export para limpar cache
exports('ClearCache', function(pattern)
    if pattern then
        return {
            success = true,
            deleted = Cache:Invalidate(pattern),
            timestamp = os.time()
        }
    else
        Cache.memory = {}
        Cache.expiry = {}
        CreateThread(function()
            pcall(function()
                MySQL.execute('DELETE FROM bcc_farming_cache')
            end)
        end)
        return {
            success = true,
            message = "All cache cleared",
            timestamp = os.time()
        }
    end
end)

-- Versões cacheadas dos exports existentes
exports('GetGlobalPlantCountCached', function()
    local cacheKey = GenerateCacheKey("global", "plant_count")
    local cached = Cache:Get(cacheKey)
    
    if cached then
        return cached
    end
    
    local result = exports['bcc-farming']:GetGlobalPlantCount()
    if result.success then
        Cache:Set(cacheKey, result, Cache.config.default_ttl)
    end
    
    return result
end)

exports('GetGlobalPlantsByTypeCached', function()
    local cacheKey = GenerateCacheKey("global", "plants_by_type")
    local cached = Cache:Get(cacheKey)
    
    if cached then
        return cached
    end
    
    local result = exports['bcc-farming']:GetGlobalPlantsByType()
    if result.success then
        Cache:Set(cacheKey, result, Cache.config.default_ttl)
    end
    
    return result
end)

exports('GetPlayerPlantsCached', function(playerId)
    local cacheKey = GenerateCacheKey("player", playerId, "plants")
    local cached = Cache:Get(cacheKey)
    
    if cached then
        return cached
    end
    
    local result = exports['bcc-farming']:GetPlayerPlants(playerId)
    if result.success then
        Cache:Set(cacheKey, result, Cache.config.player_ttl)
    end
    
    return result
end)

exports('GetFarmingOverviewCached', function()
    local cacheKey = GenerateCacheKey("global", "overview")
    local cached = Cache:Get(cacheKey)
    
    if cached then
        return cached
    end
    
    local result = exports['bcc-farming']:GetFarmingOverview()
    if result.success then
        Cache:Set(cacheKey, result, Cache.config.default_ttl)
    end
    
    return result
end)

exports('GetPlantsInRadiusCached', function(coords, radius)
    -- Cache baseado em coordenadas arredondadas para melhor reutilização
    local roundedX = math.floor(coords.x / 100) * 100
    local roundedY = math.floor(coords.y / 100) * 100
    local roundedRadius = math.ceil(radius / 100) * 100
    
    local cacheKey = GenerateCacheKey("geo", "radius", roundedX, roundedY, roundedRadius)
    local cached = Cache:Get(cacheKey)
    
    if cached then
        -- Filtrar resultados exatos se necessário
        local filteredData = {}
        for _, plant in pairs(cached.data) do
            local distance = math.sqrt(
                (plant.coords.x - coords.x)^2 + 
                (plant.coords.y - coords.y)^2 + 
                (plant.coords.z - coords.z)^2
            )
            if distance <= radius then
                table.insert(filteredData, plant)
            end
        end
        cached.data = filteredData
        cached.totalFound = #filteredData
        return cached
    end
    
    local result = exports['bcc-farming']:GetPlantsInRadius(coords, roundedRadius)
    if result.success then
        Cache:Set(cacheKey, result, Cache.config.default_ttl)
        
        -- Retornar resultado filtrado para raio exato
        local filteredData = {}
        for _, plant in pairs(result.data) do
            local distance = math.sqrt(
                (plant.coords.x - coords.x)^2 + 
                (plant.coords.y - coords.y)^2 + 
                (plant.coords.z - coords.z)^2
            )
            if distance <= radius then
                table.insert(filteredData, plant)
            end
        end
        result.data = filteredData
        result.totalFound = #filteredData
    end
    
    return result
end)

-- Sistema de invalidação inteligente
RegisterNetEvent('bcc-farming:InvalidateCache')
AddEventHandler('bcc-farming:InvalidateCache', function(cacheType, ...)
    local args = {...}
    
    if cacheType == 'player' and args[1] then
        Cache:Invalidate("player:" .. args[1])
    elseif cacheType == 'global' then
        Cache:Invalidate("global:")
    elseif cacheType == 'geo' then
        Cache:Invalidate("geo:")
    elseif cacheType == 'market' then
        Cache:Invalidate("market:")
    elseif cacheType == 'all' then
        Cache:Invalidate(".*")
    end
end)

-- Thread de manutenção do cache
CreateThread(function()
    while true do
        Wait(300000) -- A cada 5 minutos
        
        -- Atualizar configurações
        UpdateCacheConfig()
        
        -- Limpar cache expirado
        local cleaned = Cache:Cleanup()
        
        if cleaned > 0 then
            print(string.format("^3[BCC-Farming Cache]^7 Limpeza automática: %d entradas removidas", cleaned))
        end
        
        -- Log de estatísticas (apenas se houver atividade)
        if Cache.stats.hits + Cache.stats.misses > 0 then
            local hitRate = (Cache.stats.hits / (Cache.stats.hits + Cache.stats.misses)) * 100
            print(string.format("^2[BCC-Farming Cache]^7 Stats: %.1f%% hit rate, %d entradas na memória", 
                hitRate, Cache.stats.memory_usage))
        end
    end
end)

-- Comando para estatísticas do cache
RegisterCommand('farming-cache-stats', function(source)
    if source ~= 0 then return end -- Apenas console
    
    local stats = exports['bcc-farming']:GetCacheStats()
    print("^3=== BCC-Farming Cache Statistics ===^7")
    print(string.format("Memory Entries: %d", stats.data.memoryEntries))
    print(string.format("Hit Rate: %.2f%%", stats.data.hitRate))
    print(string.format("Hits: %d | Misses: %d", stats.data.hits, stats.data.misses))
    print(string.format("Writes: %d | Deletes: %d", stats.data.writes, stats.data.deletes))
    print(string.format("Config - Default TTL: %ds | Market TTL: %ds", 
        stats.data.config.default_ttl, stats.data.config.market_ttl))
end)

-- Comando para limpar cache
RegisterCommand('farming-cache-clear', function(source, args)
    if source ~= 0 then return end -- Apenas console
    
    local pattern = args[1]
    local result = exports['bcc-farming']:ClearCache(pattern)
    
    if pattern then
        print(string.format("^2[BCC-Farming]^7 Cache pattern '%s' cleared. %d entries deleted.", 
            pattern, result.deleted or 0))
    else
        print("^2[BCC-Farming]^7 All cache cleared.")
    end
end)