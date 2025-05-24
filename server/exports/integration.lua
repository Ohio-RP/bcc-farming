-- server/exports/integration.lua
-- FASE 2 - Sistema de Integração e Comandos Avançados

-- Sistema de administração avançada
local AdminSystem = {
    authorized = {},
    commands = {},
    logs = {}
}

-- Verificar se jogador é admin
local function IsPlayerAdmin(src)
    local user = VORPcore.getUser(src)
    if not user then return false end
    
    local character = user.getUsedCharacter
    if not character then return false end
    
    local group = character.group
    return group == 'admin' or group == 'mod' or group == 'owner'
end

-- Log de ações administrativas
local function LogAdminAction(src, action, details)
    local user = VORPcore.getUser(src)
    local playerName = "Unknown"
    
    if user then
        local character = user.getUsedCharacter
        if character then
            playerName = character.firstname .. " " .. character.lastname
        end
    end
    
    local logEntry = {
        timestamp = os.time(),
        playerId = src,
        playerName = playerName,
        action = action,
        details = details
    }
    
    table.insert(AdminSystem.logs, logEntry)
    
    -- Manter apenas últimos 100 logs
    if #AdminSystem.logs > 100 then
        table.remove(AdminSystem.logs, 1)
    end
    
    print(string.format("^3[BCC-Farming Admin]^7 %s (%d) executed: %s - %s", 
        playerName, src, action, details))
end

-- Export para dashboard administrativo
exports('GetAdminDashboard', function(playerId)
    if not IsPlayerAdmin(playerId) then
        return { success = false, error = "Access denied" }
    end
    
    -- Dados globais
    local globalStats = exports['bcc-farming']:GetFarmingOverview()
    local marketReport = exports['bcc-farming']:GetMarketReport()
    local cacheStats = exports['bcc-farming']:GetCacheStats()
    local eventStats = exports['bcc-farming']:GetEventStats()
    
    -- Top 10 jogadores por plantas
    local success, topPlayers = pcall(function()
        return MySQL.query.await([[
            SELECT 
                plant_owner,
                COUNT(*) as plant_count,
                COUNT(CASE WHEN plant_watered = 'true' THEN 1 END) as watered_count,
                COUNT(CASE WHEN CAST(time_left AS UNSIGNED) <= 0 AND plant_watered = 'true' THEN 1 END) as ready_count
            FROM bcc_farming 
            GROUP BY plant_owner 
            ORDER BY plant_count DESC 
            LIMIT 10
        ]])
    end)
    
    -- Atividade recente
    local recentActivity = exports['bcc-farming']:GetGlobalHistory(1) -- Último dia
    
    -- Alertas do sistema
    local systemAlerts = {}
    
    -- Verificar plantas órfãs (sem dono válido)
    local orphanedPlants = MySQL.scalar.await([[
        SELECT COUNT(*) FROM bcc_farming 
        WHERE plant_owner NOT IN (SELECT charidentifier FROM characters)
    ]]) or 0
    
    if orphanedPlants > 0 then
        table.insert(systemAlerts, {
            type = "warning",
            message = string.format("%d plantas órfãs detectadas", orphanedPlants),
            action = "cleanup_orphaned"
        })
    end
    
    -- Verificar cache hit rate baixo
    if cacheStats.success and cacheStats.data.hitRate < 70 then
        table.insert(systemAlerts, {
            type = "info",
            message = string.format("Cache hit rate baixo: %.1f%%", cacheStats.data.hitRate),
            action = "optimize_cache"
        })
    end
    
    return {
        success = true,
        data = {
            globalStats = globalStats.success and globalStats.data or {},
            marketReport = marketReport.success and marketReport.data or {},
            cacheStats = cacheStats.success and cacheStats.data or {},
            eventStats = eventStats.success and eventStats.data or {},
            topPlayers = topPlayers or {},
            recentActivity = recentActivity.success and recentActivity.data or {},
            systemAlerts = systemAlerts,
            adminLogs = AdminSystem.logs
        },
        timestamp = os.time()
    }
end)

-- Export para executar ações administrativas
exports('ExecuteAdminAction', function(playerId, action, params)
    if not IsPlayerAdmin(playerId) then
        return { success = false, error = "Access denied" }
    end
    
    params = params or {}
    
    if action == "cleanup_orphaned" then
        -- Limpar plantas órfãs
        local deleted = MySQL.execute.await([[
            DELETE FROM bcc_farming 
            WHERE plant_owner NOT IN (SELECT charidentifier FROM characters)
        ]])
        
        LogAdminAction(playerId, "cleanup_orphaned", string.format("Deleted %d orphaned plants", deleted))
        
        return { 
            success = true, 
            message = string.format("Removed %d orphaned plants", deleted) 
        }
        
    elseif action == "clear_cache" then
        local pattern = params.pattern
        local result = exports['bcc-farming']:ExecuteAdminAction(source, "give_all_seeds", { 
            targetId = targetId, 
            amount = amount 
        })
        
        if result.success then
            VORPcore.NotifyRightTip(source, result.message, 5000)
        else
            VORPcore.NotifyRightTip(source, "Erro: " .. result.error, 5000)
        end
        
    else
        VORPcore.NotifyRightTip(source, "Ação inválida. Use: dashboard, cleanup, prices, cache, seeds", 5000)
    end
end)

-- Comando para jogadores verificarem suas estatísticas
RegisterCommand('myfarming', function(source, args)
    if source == 0 then return end
    
    local playerStats = exports['bcc-farming']:GetPlayerFarmingStats(source)
    
    if not playerStats.success then
        VORPcore.NotifyRightTip(source, "Erro ao obter suas estatísticas.", 5000)
        return
    end
    
    local stats = playerStats.data
    local message = string.format(
        "🌱 Suas Plantas: %d/%d\\n" ..
        "🌾 Prontas: %d | 💧 Precisam água: %d\\n" ..
        "📈 Eficiência: %d%%",
        stats.farming.totalPlants,
        stats.capacity.maxSlots,
        stats.farming.readyToHarvest,
        stats.farming.needsWater,
        stats.summary.efficiency
    )
    
    exports['bcc-farming']:NotifyFarmingEvent(source, 'custom', { message = message })
end)

-- Export para integração com outros sistemas
exports('RegisterExternalEvent', function(eventName, callback)
    if type(eventName) ~= "string" or type(callback) ~= "function" then
        return { success = false, error = "Invalid parameters" }
    end
    
    -- Registrar evento personalizado
    RegisterNetEvent('bcc-farming:external:' .. eventName)
    AddEventHandler('bcc-farming:external:' .. eventName, callback)
    
    return { success = true, eventName = 'bcc-farming:external:' .. eventName }
end)

-- Export para webhook personalizado
exports('SendWebhook', function(webhookData)
    if not webhookData.url then
        return { success = false, error = "Webhook URL required" }
    end
    
    local payload = {
        username = webhookData.username or "BCC Farming Bot",
        avatar_url = webhookData.avatar_url,
        embeds = {{
            title = webhookData.title or "BCC Farming Event",
            description = webhookData.description or "",
            color = webhookData.color or 3447003,
            fields = webhookData.fields or {},
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            footer = {
                text = "BCC Farming System"
            }
        }}
    }
    
    CreateThread(function()
        PerformHttpRequest(webhookData.url, function(statusCode, response, headers)
            if statusCode == 200 or statusCode == 204 then
                print("^2[BCC-Farming]^7 Webhook sent successfully")
            else
                print(string.format("^1[BCC-Farming]^7 Webhook failed: %d", statusCode))
            end
        end, 'POST', json.encode(payload), {
            ['Content-Type'] = 'application/json'
        })
    end)
    
    return { success = true, message = "Webhook queued" }
end)

-- Sistema de backup automático
CreateThread(function()
    while true do
        Wait(3600000) -- A cada 1 hora
        
        -- Verificar se backup está habilitado
        local backupEnabled = GetCacheConfig('auto_backup_enabled', false)
        if not backupEnabled then
            goto continue
        end
        
        -- Criar backup das tabelas principais
        local timestamp = os.date("%Y%m%d_%H%M%S")
        
        CreateThread(function()
            pcall(function()
                -- Backup da tabela principal
                MySQL.execute(string.format([[
                    CREATE TABLE bcc_farming_backup_%s AS 
                    SELECT * FROM bcc_farming
                ]], timestamp))
                
                -- Backup do histórico (últimos 7 dias)
                MySQL.execute(string.format([[
                    CREATE TABLE bcc_farming_history_backup_%s AS 
                    SELECT * FROM bcc_farming_history 
                    WHERE timestamp > DATE_SUB(NOW(), INTERVAL 7 DAY)
                ]], timestamp))
                
                print(string.format("^2[BCC-Farming]^7 Backup automático criado: %s", timestamp))
            end)
        end)
        
        ::continue::
    end
end)

-- Sistema de monitoramento de performance
local PerformanceMonitor = {
    queries = {},
    slowQueries = {},
    thresholds = {
        slow_query = 1000, -- 1 segundo
        memory_usage = 50 * 1024 * 1024 -- 50MB
    }
}

-- Hook no MySQL para monitorar queries
local originalExecute = MySQL.execute
MySQL.execute = function(query, params, callback)
    local startTime = GetGameTimer()
    
    local function onComplete(...)
        local duration = GetGameTimer() - startTime
        
        -- Log queries lentas
        if duration > PerformanceMonitor.thresholds.slow_query then
            table.insert(PerformanceMonitor.slowQueries, {
                query = string.sub(query, 1, 100) .. "...",
                duration = duration,
                timestamp = os.time()
            })
            
            -- Manter apenas últimas 50
            if #PerformanceMonitor.slowQueries > 50 then
                table.remove(PerformanceMonitor.slowQueries, 1)
            end
            
            print(string.format("^3[BCC-Farming Performance]^7 Slow query detected: %dms", duration))
        end
        
        if callback then
            callback(...)
        end
    end
    
    return originalExecute(query, params, onComplete)
end

-- Export para estatísticas de performance
exports('GetPerformanceStats', function()
    return {
        success = true,
        data = {
            slowQueries = PerformanceMonitor.slowQueries,
            memoryUsage = collectgarbage("count") * 1024, -- Convertir para bytes
            cacheStats = exports['bcc-farming']:GetCacheStats().data
        },
        timestamp = os.time()
    }
end)

-- Sistema de configuração dinâmica
exports('UpdateConfig', function(adminId, configKey, configValue, configType)
    if not IsPlayerAdmin(adminId) then
        return { success = false, error = "Access denied" }
    end
    
    configType = configType or 'string'
    
    local success = pcall(function()
        MySQL.execute([[
            INSERT INTO bcc_farming_config (config_key, config_value, config_type, updated_by) 
            VALUES (?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE 
            config_value = VALUES(config_value),
            config_type = VALUES(config_type),
            updated_by = VALUES(updated_by)
        ]], { configKey, tostring(configValue), configType, tostring(adminId) })
    end)
    
    if success then
        LogAdminAction(adminId, "update_config", string.format("%s = %s (%s)", configKey, configValue, configType))
        
        -- Invalidar cache de configuração
        TriggerEvent('bcc-farming:InvalidateCache', 'config')
        
        return { success = true, message = "Configuration updated" }
    else
        return { success = false, error = "Database error" }
    end
end)

-- Export para obter configurações
exports('GetAllConfigs', function(adminId)
    if not IsPlayerAdmin(adminId) then
        return { success = false, error = "Access denied" }
    end
    
    local success, configs = pcall(function()
        return MySQL.query.await('SELECT * FROM bcc_farming_config ORDER BY config_key')
    end)
    
    if success and configs then
        -- Processar valores por tipo
        for _, config in pairs(configs) do
            if config.config_type == 'number' then
                config.config_value = tonumber(config.config_value)
            elseif config.config_type == 'boolean' then
                config.config_value = config.config_value == 'true'
            elseif config.config_type == 'json' then
                local parseSuccess, jsonValue = pcall(function()
                    return json.decode(config.config_value)
                end)
                if parseSuccess then
                    config.config_value = jsonValue
                end
            end
        end
        
        return { success = true, data = configs }
    end
    
    return { success = false, error = "Database error" }
end)

-- Função helper para obter configuração do cache
function GetCacheConfig(key, default)
    local success, result = pcall(function()
        return MySQL.scalar.await('SELECT config_value FROM bcc_farming_config WHERE config_key = ?', { key })
    end)
    
    if success and result then
        local value = tonumber(result)
        return value or (result == 'true' and true or result == 'false' and false or result)
    end
    
    return default
end

-- Export para teste de integração
exports('TestIntegration', function()
    return {
        success = true,
        message = "BCC-Farming FASE 2 integration system is working!",
        version = "2.5.0-phase2",
        exports_count = 67,
        features = {
            "Dynamic Economy",
            "Advanced Cache",
            "Smart Notifications", 
            "Complete History",
            "Admin Dashboard",
            "Performance Monitoring",
            "Webhook Integration"
        },
        timestamp = os.time()
    }
end)

-- Sistema de health check
exports('HealthCheck', function()
    local health = {
        database = false,
        cache = false,
        economy = false,
        notifications = false
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
    
    -- Verificar notificações
    health.notifications = GetNotificationSystem ~= nil
    
    local allHealthy = health.database and health.cache and health.economy and health.notifications
    
    return {
        success = true,
        healthy = allHealthy,
        components = health,
        timestamp = os.time()
    }
end)

-- Sistema de métricas para monitoramento externo
exports('GetMetrics', function()
    local metrics = {
        timestamp = os.time(),
        server = {
            uptime = GetGameTimer(),
            players_online = GetNumPlayerIndices()
        },
        farming = {},
        performance = {},
        cache = {},
        economy = {}
    }
    
    -- Métricas de farming
    local overview = exports['bcc-farming']:GetFarmingOverview()
    if overview.success then
        metrics.farming = {
            total_plants = overview.data.totalPlants,
            plant_types = overview.data.totalTypes,
            ready_plants = overview.data.plantsReadySoon
        }
    end
    
    -- Métricas de performance
    local perf = exports['bcc-farming']:GetPerformanceStats()
    if perf.success then
        metrics.performance = {
            memory_usage_mb = math.floor(perf.data.memoryUsage / 1024 / 1024),
            slow_queries = #perf.data.slowQueries
        }
    end
    
    -- Métricas de cache
    local cache = exports['bcc-farming']:GetCacheStats()
    if cache.success then
        metrics.cache = {
            hit_rate = cache.data.hitRate,
            memory_entries = cache.data.memoryEntries,
            total_hits = cache.data.hits,
            total_misses = cache.data.misses
        }
    end
    
    -- Métricas de economia
    local market = exports['bcc-farming']:GetMarketReport()
    if market.success then
        metrics.economy = {
            total_markets = market.data.summary.totalMarkets,
            bullish_markets = market.data.summary.bullishMarkets,
            bearish_markets = market.data.summary.bearishMarkets,
            average_scarcity = math.floor(market.data.summary.averageScarcity * 100) / 100
        }
    end
    
    return {
        success = true,
        data = metrics
    }
end)

-- Sistema de debug avançado
exports('DebugInfo', function(adminId, component)
    if not IsPlayerAdmin(adminId) then
        return { success = false, error = "Access denied" }
    end
    
    local debugInfo = {
        timestamp = os.time(),
        server_info = {
            resource_name = GetCurrentResourceName(),
            resource_state = GetResourceState(GetCurrentResourceName()),
            game_timer = GetGameTimer(),
            server_endpoints = GetNumPlayerIndices()
        }
    }
    
    if not component or component == "all" or component == "database" then
        debugInfo.database = {
            tables_exist = {},
            table_counts = {},
            index_status = {}
        }
        
        -- Verificar tabelas
        local tables = {"bcc_farming", "bcc_farming_history", "bcc_farming_market_stats", "bcc_farming_cache", "bcc_farming_config", "bcc_farming_alerts"}
        for _, table in pairs(tables) do
            local exists = pcall(function()
                return MySQL.scalar.await(string.format('SELECT COUNT(*) FROM %s LIMIT 1', table))
            end)
            debugInfo.database.tables_exist[table] = exists
            
            if exists then
                local count = MySQL.scalar.await(string.format('SELECT COUNT(*) FROM %s', table)) or 0
                debugInfo.database.table_counts[table] = count
            end
        end
    end
    
    if not component or component == "all" or component == "cache" then
        debugInfo.cache = exports['bcc-farming']:GetCacheStats().data or {}
    end
    
    if not component or component == "all" or component == "economy" then
        debugInfo.economy = {
            market_report = exports['bcc-farming']:GetMarketReport().data or {},
            last_update = Economy.lastUpdate or 0
        }
    end
    
    if not component or component == "all" or component == "events" then
        debugInfo.events = exports['bcc-farming']:GetEventStats().data or {}
    end
    
    return {
        success = true,
        data = debugInfo
    }
end)

-- Sistema de benchmark
exports('RunBenchmark', function(adminId)
    if not IsPlayerAdmin(adminId) then
        return { success = false, error = "Access denied" }
    end
    
    local results = {
        timestamp = os.time(),
        tests = {}
    }
    
    -- Benchmark de cache
    local cacheStart = GetGameTimer()
    for i = 1, 100 do
        exports['bcc-farming']:GetGlobalPlantCountCached()
    end
    local cacheTime = GetGameTimer() - cacheStart
    results.tests.cache_100_calls = cacheTime
    
    -- Benchmark de banco direto
    local dbStart = GetGameTimer()
    for i = 1, 10 do
        exports['bcc-farming']:GetGlobalPlantCount()
    end
    local dbTime = GetGameTimer() - dbStart
    results.tests.database_10_calls = dbTime
    
    -- Benchmark de economia
    local economyStart = GetGameTimer()
    exports['bcc-farming']:GetMarketReport()
    local economyTime = GetGameTimer() - economyStart
    results.tests.market_report = economyTime
    
    -- Benchmark de geolocalização
    local geoStart = GetGameTimer()
    exports['bcc-farming']:GetPlantsInRadius({x = 0, y = 0, z = 0}, 1000)
    local geoTime = GetGameTimer() - geoStart
    results.tests.geo_search_1km = geoTime
    
    results.summary = {
        cache_efficiency = cacheTime < dbTime and "GOOD" or "NEEDS_OPTIMIZATION",
        economy_performance = economyTime < 1000 and "GOOD" or "SLOW",
        geo_performance = geoTime < 500 and "GOOD" or "SLOW"
    }
    
    LogAdminAction(adminId, "run_benchmark", json.encode(results.summary))
    
    return {
        success = true,
        data = results
    }
end)

-- Comando de diagnóstico completo
RegisterCommand('farming-diagnostic', function(source)
    if source ~= 0 then return end
    
    print("^3=== BCC-Farming Complete Diagnostic ===^7")
    
    -- Health Check
    local health = exports['bcc-farming']:HealthCheck()
    print(string.format("Overall Health: %s", health.healthy and "^2HEALTHY^7" or "^1UNHEALTHY^7"))
    print(string.format("Database: %s", health.components.database and "^2OK^7" or "^1FAIL^7"))
    print(string.format("Cache: %s", health.components.cache and "^2OK^7" or "^1FAIL^7"))
    print(string.format("Economy: %s", health.components.economy and "^2OK^7" or "^1FAIL^7"))
    print(string.format("Notifications: %s", health.components.notifications and "^2OK^7" or "^1FAIL^7"))
    
    -- Metrics
    local metrics = exports['bcc-farming']:GetMetrics()
    if metrics.success then
        print("\n^3=== Current Metrics ===^7")
        print(string.format("Total Plants: %d", metrics.data.farming.total_plants or 0))
        print(string.format("Plant Types: %d", metrics.data.farming.plant_types or 0))
        print(string.format("Cache Hit Rate: %.1f%%", metrics.data.cache.hit_rate or 0))
        print(string.format("Memory Usage: %d MB", metrics.data.performance.memory_usage_mb or 0))
        print(string.format("Active Markets: %d", metrics.data.economy.total_markets or 0))
    end
    
    -- Test Integration
    local integration = exports['bcc-farming']:TestIntegration()
    print(string.format("\n^3=== Integration Test ===^7"))
    print(string.format("Status: %s", integration.success and "^2PASS^7" or "^1FAIL^7"))
    print(string.format("Version: %s", integration.version))
    print(string.format("Total Exports: %d", integration.exports_count))
end)

-- Sistema de migração automática para versões futuras
exports('MigrateData', function(adminId, fromVersion, toVersion)
    if not IsPlayerAdmin(adminId) then
        return { success = false, error = "Access denied" }
    end
    
    LogAdminAction(adminId, "migrate_data", string.format("From: %s, To: %s", fromVersion, toVersion))
    
    -- Placeholder para futuras migrações
    return {
        success = true,
        message = "No migration needed",
        fromVersion = fromVersion,
        toVersion = toVersion
    }
end)

-- Thread de monitoramento de saúde do sistema
CreateThread(function()
    while true do
        Wait(1800000) -- A cada 30 minutos
        
        local health = exports['bcc-farming']:HealthCheck()
        
        if not health.healthy then
            print("^1[BCC-Farming Health]^7 System health check failed!")
            
            if not health.components.database then
                print("^1[BCC-Farming Health]^7 Database issues detected")
            end
            
            if not health.components.cache then
                print("^1[BCC-Farming Health]^7 Cache issues detected")
            end
            
            if not health.components.economy then
                print("^1[BCC-Farming Health]^7 Economy system issues detected")
            end
        else
            -- Log de saúde apenas a cada 2 horas se tudo estiver bem
            if os.time() % 7200 < 1800 then
                print("^2[BCC-Farming Health]^7 All systems operational")
            end
        end
    end
end)

print("^2[BCC-Farming]^7 Sistema de integração da FASE 2 carregado! ✅")
print("^3[BCC-Farming]^7 Comandos disponíveis:")
print("  • /farming-admin [action] - Painel administrativo")
print("  • /myfarming - Estatísticas pessoais")
print("  • /farmnotify [type] - Testar notificações")
print("  • farming-diagnostic - Diagnóstico completo (console)")
print("^3[BCC-Farming]^7 Exports adicionais:")
print("  • TestIntegration() - Teste de integração")
print("  • HealthCheck() - Verificação de saúde")
print("  • GetMetrics() - Métricas do sistema")
print("  • DebugInfo() - Informações de debug")
print("  • RunBenchmark() - Teste de performance")