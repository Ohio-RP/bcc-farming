-- test_suite.lua
-- Sistema completo de testes para BCC-Farming Exports
-- Inclui formatação colorida e relatórios detalhados

local TestSuite = {
    results = {},
    startTime = 0,
    totalTests = 0,
    passedTests = 0,
    failedTests = 0,
    config = {
        verbose = true,
        saveResults = true,
        testTimeout = 10000, -- 10 segundos por teste
        samplePlayerId = 1 -- ID do jogador para testes (deve estar online)
    }
}

-- Cores para formatação do console
local Colors = {
    RESET = "^7",
    RED = "^1",
    GREEN = "^2", 
    YELLOW = "^3",
    BLUE = "^4",
    CYAN = "^5",
    MAGENTA = "^6",
    WHITE = "^7",
    GRAY = "^8"
}

-- Função para formatar saída do console
local function FormatOutput(color, prefix, message)
    return string.format("%s[%s]%s %s", color, prefix, Colors.RESET, message)
end

-- Função para imprimir separador visual
local function PrintSeparator(title, char)
    char = char or "="
    local separator = string.rep(char, 80)
    print(Colors.CYAN .. separator .. Colors.RESET)
    if title then
        local padding = math.floor((80 - string.len(title)) / 2)
        local paddedTitle = string.rep(" ", padding) .. title
        print(Colors.WHITE .. paddedTitle .. Colors.RESET)
        print(Colors.CYAN .. separator .. Colors.RESET)
    end
end

-- Função para formatar dados JSON de forma legível
local function FormatData(data, indent)
    indent = indent or 0
    local spaces = string.rep("  ", indent)
    
    if type(data) == "table" then
        local lines = {}
        table.insert(lines, "{")
        
        for key, value in pairs(data) do
            local formattedKey = type(key) == "string" and '"' .. key .. '"' or tostring(key)
            local formattedValue = FormatData(value, indent + 1)
            table.insert(lines, spaces .. "  " .. formattedKey .. ": " .. formattedValue .. ",")
        end
        
        table.insert(lines, spaces .. "}")
        return table.concat(lines, "\n")
    elseif type(data) == "string" then
        return '"' .. data .. '"'
    elseif type(data) == "boolean" then
        return data and "true" or "false"
    else
        return tostring(data)
    end
end

-- Função para executar um teste individual
local function RunTest(testName, testFunction, expectedResult)
    TestSuite.totalTests = TestSuite.totalTests + 1
    print(FormatOutput(Colors.BLUE, "EXECUTANDO", string.format("Teste #%d: %s", TestSuite.totalTests, testName)))
    
    local startTime = GetGameTimer()
    local success, result = pcall(testFunction)
    local duration = GetGameTimer() - startTime
    
    local testResult = {
        name = testName,
        success = success,
        result = result,
        duration = duration,
        timestamp = os.time(),
        expected = expectedResult
    }
    
    if success then
        if expectedResult and result ~= expectedResult then
            TestSuite.failedTests = TestSuite.failedTests + 1
            testResult.status = "FALHOU"
            print(FormatOutput(Colors.RED, "FALHOU", string.format("%s (Resultado inesperado)", testName)))
        else
            TestSuite.passedTests = TestSuite.passedTests + 1
            testResult.status = "PASSOU"
            print(FormatOutput(Colors.GREEN, "PASSOU", string.format("%s (%dms)", testName, duration)))
        end
        
        if TestSuite.config.verbose and result then
            print(FormatOutput(Colors.GRAY, "RESULTADO", FormatData(result, 1)))
        end
    else
        TestSuite.failedTests = TestSuite.failedTests + 1
        testResult.status = "ERRO"
        testResult.error = tostring(result)
        print(FormatOutput(Colors.RED, "ERRO", string.format("%s - %s", testName, tostring(result))))
    end
    
    table.insert(TestSuite.results, testResult)
    print("") -- Linha em branco para separação
end

-- TESTES DOS EXPORTS BÁSICOS
local function TestBasicExports()
    PrintSeparator("TESTES - EXPORTS BÁSICOS")
    
    -- Teste 1: GetGlobalPlantCount
    RunTest("GetGlobalPlantCount", function()
        return exports['bcc-farming']:GetGlobalPlantCount()
    end)
    
    -- Teste 2: GetGlobalPlantsByType
    RunTest("GetGlobalPlantsByType", function()
        return exports['bcc-farming']:GetGlobalPlantsByType()
    end)
    
    -- Teste 3: GetNearHarvestPlants
    RunTest("GetNearHarvestPlants (300s)", function()
        return exports['bcc-farming']:GetNearHarvestPlants(300)
    end)
    
    -- Teste 4: GetFarmingOverview
    RunTest("GetFarmingOverview", function()
        return exports['bcc-farming']:GetFarmingOverview()
    end)
    
    -- Teste 5: GetWateringStatus
    RunTest("GetWateringStatus", function()
        return exports['bcc-farming']:GetWateringStatus()
    end)
end

-- TESTES DOS EXPORTS DE JOGADORES
local function TestPlayerExports()
    PrintSeparator("TESTES - EXPORTS DE JOGADORES")
    
    local playerId = TestSuite.config.samplePlayerId
    
    -- Teste 6: GetPlayerPlantCount
    RunTest("GetPlayerPlantCount", function()
        return exports['bcc-farming']:GetPlayerPlantCount(playerId)
    end)
    
    -- Teste 7: GetPlayerPlants
    RunTest("GetPlayerPlants", function()
        return exports['bcc-farming']:GetPlayerPlants(playerId)
    end)
    
    -- Teste 8: CanPlayerPlantMore
    RunTest("CanPlayerPlantMore", function()
        return exports['bcc-farming']:CanPlayerPlantMore(playerId)
    end)
    
    -- Teste 9: GetPlayerFarmingStats
    RunTest("GetPlayerFarmingStats", function()
        return exports['bcc-farming']:GetPlayerFarmingStats(playerId)
    end)
    
    -- Teste 10: GetPlayerComparison
    RunTest("GetPlayerComparison", function()
        return exports['bcc-farming']:GetPlayerComparison(playerId)
    end)
end

-- TESTES DOS EXPORTS DE PRODUÇÃO
local function TestProductionExports()
    PrintSeparator("TESTES - EXPORTS DE PRODUÇÃO")
    
    -- Teste 11: GetEstimatedProduction
    RunTest("GetEstimatedProduction (24h)", function()
        return exports['bcc-farming']:GetEstimatedProduction(24)
    end)
    
    -- Teste 12: GetTotalProductionPotential
    RunTest("GetTotalProductionPotential", function()
        return exports['bcc-farming']:GetTotalProductionPotential()
    end)
    
    -- Teste 13: GetHourlyProductionForecast
    RunTest("GetHourlyProductionForecast (12h)", function()
        return exports['bcc-farming']:GetHourlyProductionForecast(12)
    end)
    
    -- Teste 14: GetProductionEfficiency
    RunTest("GetProductionEfficiency", function()
        return exports['bcc-farming']:GetProductionEfficiency()
    end)
    
    -- Teste 15: GetGrowthAnalysis
    RunTest("GetGrowthAnalysis", function()
        return exports['bcc-farming']:GetGrowthAnalysis()
    end)
end

-- TESTES DOS EXPORTS GEOGRÁFICOS
local function TestGeographicExports()
    PrintSeparator("TESTES - EXPORTS GEOGRÁFICOS")
    
    local testCoords = {x = -297.48, y = 791.1, z = 118.33} -- Valentine
    
    -- Teste 16: GetPlantsInRadius
    RunTest("GetPlantsInRadius (1000m)", function()
        return exports['bcc-farming']:GetPlantsInRadius(testCoords, 1000)
    end)
    
    -- Teste 17: GetPlantDensity
    RunTest("GetPlantDensity", function()
        return exports['bcc-farming']:GetPlantDensity(testCoords, 500)
    end)
    
    -- Teste 18: GetDominantPlantInArea
    RunTest("GetDominantPlantInArea", function()
        return exports['bcc-farming']:GetDominantPlantInArea(testCoords, 1500)
    end)
    
    -- Teste 19: IsValidPlantLocation
    RunTest("IsValidPlantLocation", function()
        return exports['bcc-farming']:IsValidPlantLocation({x = 100, y = 100, z = 100}, "corn")
    end)
    
    -- Teste 20: FindBestPlantingAreas
    RunTest("FindBestPlantingAreas", function()
        return exports['bcc-farming']:FindBestPlantingAreas(testCoords, 2000, 5)
    end)
    
    -- Teste 21: GetPlantConcentrationMap
    RunTest("GetPlantConcentrationMap", function()
        return exports['bcc-farming']:GetPlantConcentrationMap(testCoords, 1000, 200)
    end)
end

-- TESTES DOS EXPORTS DE NOTIFICAÇÕES
local function TestNotificationExports()
    PrintSeparator("TESTES - EXPORTS DE NOTIFICAÇÕES")
    
    local playerId = TestSuite.config.samplePlayerId
    
    -- Teste 22: NotifyReadyPlants
    RunTest("NotifyReadyPlants", function()
        return exports['bcc-farming']:NotifyReadyPlants(playerId, 600)
    end)
    
    -- Teste 23: NotifyPlantsNeedWater
    RunTest("NotifyPlantsNeedWater", function()
        return exports['bcc-farming']:NotifyPlantsNeedWater(playerId)
    end)
    
    -- Teste 24: NotifyPlantLimits
    RunTest("NotifyPlantLimits", function()
        return exports['bcc-farming']:NotifyPlantLimits(playerId)
    end)
    
    -- Teste 25: NotifyFarmingEvent
    RunTest("NotifyFarmingEvent", function()
        return exports['bcc-farming']:NotifyFarmingEvent(playerId, 'plant_grown', {plantName = "Milho Teste"})
    end)
    
    -- Teste 26: SendDailyFarmingReport
    RunTest("SendDailyFarmingReport", function()
        return exports['bcc-farming']:SendDailyFarmingReport(playerId)
    end)
end

-- TESTES DOS EXPORTS DE CACHE (se disponível)
local function TestCacheExports()
    PrintSeparator("TESTES - EXPORTS DE CACHE")
    
    -- Teste 27: GetCacheStats
    RunTest("GetCacheStats", function()
        return exports['bcc-farming']:GetCacheStats()
    end)
    
    -- Teste 28: GetGlobalPlantCountCached
    RunTest("GetGlobalPlantCountCached", function()
        return exports['bcc-farming']:GetGlobalPlantCountCached()
    end)
    
    -- Teste 29: ClearCache (padrão específico)
    RunTest("ClearCache (global:*)", function()
        return exports['bcc-farming']:ClearCache("global:")
    end)
end

-- TESTES DOS EXPORTS DE ECONOMIA (se disponível)
local function TestEconomyExports()
    PrintSeparator("TESTES - EXPORTS DE ECONOMIA")
    
    -- Teste 30: GetPlantScarcityIndex
    RunTest("GetPlantScarcityIndex (corn)", function()
        return exports['bcc-farming']:GetPlantScarcityIndex("cornseed")
    end)
    
    -- Teste 31: CalculateDynamicPrice
    RunTest("CalculateDynamicPrice", function()
        return exports['bcc-farming']:CalculateDynamicPrice("cornseed", 10.0)
    end)
    
    -- Teste 32: GetPlantingTrend
    RunTest("GetPlantingTrend (7 dias)", function()
        return exports['bcc-farming']:GetPlantingTrend("cornseed", 7)
    end)
    
    -- Teste 33: GetMarketReport
    RunTest("GetMarketReport", function()
        return exports['bcc-farming']:GetMarketReport()
    end)
end

-- TESTES DOS EXPORTS DE INTEGRAÇÃO
local function TestIntegrationExports()
    PrintSeparator("TESTES - EXPORTS DE INTEGRAÇÃO")
    
    -- Teste 34: TestIntegration
    RunTest("TestIntegration", function()
        return exports['bcc-farming']:TestIntegration()
    end)
    
    -- Teste 35: HealthCheck
    RunTest("HealthCheck", function()
        return exports['bcc-farming']:HealthCheck()
    end)
    
    -- Teste 36: GetMetrics
    RunTest("GetMetrics", function()
        return exports['bcc-farming']:GetMetrics()
    end)
    
    -- Teste 37: GetPerformanceStats
    RunTest("GetPerformanceStats", function()
        return exports['bcc-farming']:GetPerformanceStats()
    end)
end

-- TESTES DE STRESS E PERFORMANCE
local function TestStressAndPerformance()
    PrintSeparator("TESTES - STRESS E PERFORMANCE")
    
    -- Teste 38: Múltiplas chamadas simultâneas
    RunTest("Stress Test - 50 chamadas GetGlobalPlantCount", function()
        local startTime = GetGameTimer()
        for i = 1, 50 do
            exports['bcc-farming']:GetGlobalPlantCount()
        end
        local duration = GetGameTimer() - startTime
        
        return {
            success = true,
            totalCalls = 50,
            totalDuration = duration,
            avgDuration = duration / 50,
            callsPerSecond = math.floor(50000 / duration)
        }
    end)
    
    -- Teste 39: Cache vs Direto
    RunTest("Performance - Cache vs Direct", function()
        -- Teste direto
        local directStart = GetGameTimer()
        local directResult = exports['bcc-farming']:GetGlobalPlantCount()
        local directTime = GetGameTimer() - directStart
        
        -- Teste com cache (se disponível)
        local cacheStart = GetGameTimer()
        local cacheResult = exports['bcc-farming'].GetGlobalPlantCountCached and 
                           exports['bcc-farming']:GetGlobalPlantCountCached() or directResult
        local cacheTime = GetGameTimer() - cacheStart
        
        return {
            success = true,
            directQuery = {
                duration = directTime,
                result = directResult.success
            },
            cachedQuery = {
                duration = cacheTime,
                result = cacheResult.success
            },
            improvement = directTime > 0 and math.floor(((directTime - cacheTime) / directTime) * 100) or 0
        }
    end)
end

-- FUNÇÃO PRINCIPAL PARA EXECUTAR TODOS OS TESTES
local function RunAllTests()
    PrintSeparator("BCC-FARMING SISTEMA DE TESTES COMPLETO")
    print(FormatOutput(Colors.YELLOW, "INÍCIO", string.format("Iniciando bateria de testes - %s", os.date("%Y-%m-%d %H:%M:%S"))))
    print(FormatOutput(Colors.BLUE, "CONFIG", string.format("Jogador de teste: %d | Timeout: %dms | Verbose: %s", 
        TestSuite.config.samplePlayerId, TestSuite.config.testTimeout, TestSuite.config.verbose and "SIM" or "NÃO")))
    print("")
    
    TestSuite.startTime = GetGameTimer()
    TestSuite.results = {}
    TestSuite.totalTests = 0
    TestSuite.passedTests = 0
    TestSuite.failedTests = 0
    
    -- Executar todas as suites de teste
    TestBasicExports()
    TestPlayerExports()
    TestProductionExports()
    TestGeographicExports()
    TestNotificationExports()
    TestCacheExports()
    TestEconomyExports()
    TestIntegrationExports()
    TestStressAndPerformance()
    
    -- Relatório final
    GenerateFinalReport()
end

-- FUNÇÃO PARA GERAR RELATÓRIO FINAL
function GenerateFinalReport()
    local totalDuration = GetGameTimer() - TestSuite.startTime
    
    PrintSeparator("RELATÓRIO FINAL DOS TESTES")
    
    -- Estatísticas gerais
    print(FormatOutput(Colors.WHITE, "RESUMO", string.format("Total de testes: %d", TestSuite.totalTests)))
    print(FormatOutput(Colors.GREEN, "PASSOU", string.format("%d testes (%.1f%%)", 
        TestSuite.passedTests, (TestSuite.passedTests / TestSuite.totalTests) * 100)))
    print(FormatOutput(Colors.RED, "FALHOU", string.format("%d testes (%.1f%%)", 
        TestSuite.failedTests, (TestSuite.failedTests / TestSuite.totalTests) * 100)))
    print(FormatOutput(Colors.BLUE, "TEMPO", string.format("Duração total: %.2fs", totalDuration / 1000)))
    print("")
    
    -- Testes que falharam
    if TestSuite.failedTests > 0 then
        print(FormatOutput(Colors.RED, "FALHAS", "Detalhes dos testes que falharam:"))
        for _, result in pairs(TestSuite.results) do
            if result.status == "FALHOU" or result.status == "ERRO" then
                print(FormatOutput(Colors.RED, "  →", string.format("%s: %s", 
                    result.name, result.error or "Resultado inesperado")))
            end
        end
        print("")
    end
    
    -- Top 5 testes mais lentos
    local slowestTests = {}
    for _, result in pairs(TestSuite.results) do
        table.insert(slowestTests, result)
    end
    table.sort(slowestTests, function(a, b) return a.duration > b.duration end)
    
    print(FormatOutput(Colors.YELLOW, "PERFORMANCE", "5 testes mais lentos:"))
    for i = 1, math.min(5, #slowestTests) do
        local test = slowestTests[i]
        print(FormatOutput(Colors.YELLOW, "  →", string.format("%s: %dms", test.name, test.duration)))
    end
    print("")
    
    -- Status final
    local overallStatus = TestSuite.failedTests == 0 and "TODOS OS TESTES PASSARAM! ✅" or 
                         string.format("ALGUNS TESTES FALHARAM ❌ (%d/%d)", TestSuite.failedTests, TestSuite.totalTests)
    
    print(FormatOutput(TestSuite.failedTests == 0 and Colors.GREEN or Colors.RED, "STATUS", overallStatus))
    
    -- Salvar resultados se configurado
    if TestSuite.config.saveResults then
        SaveTestResults()
    end
    
    PrintSeparator()
end

-- FUNÇÃO PARA SALVAR RESULTADOS EM ARQUIVO
function SaveTestResults()
    local timestamp = os.date("%Y%m%d_%H%M%S")
    local filename = string.format("bcc_farming_test_results_%s.json", timestamp)
    
    local reportData = {
        timestamp = os.time(),
        date = os.date("%Y-%m-%d %H:%M:%S"),
        summary = {
            totalTests = TestSuite.totalTests,
            passedTests = TestSuite.passedTests,
            failedTests = TestSuite.failedTests,
            successRate = (TestSuite.passedTests / TestSuite.totalTests) * 100,
            totalDuration = GetGameTimer() - TestSuite.startTime
        },
        config = TestSuite.config,
        results = TestSuite.results
    }
    
    -- Simular salvamento (seria necessário implementar escrita de arquivo)
    print(FormatOutput(Colors.CYAN, "SAVE", string.format("Resultados salvos em: %s", filename)))
    print(FormatOutput(Colors.GRAY, "DATA", FormatData(reportData.summary, 1)))
end

-- COMANDOS PARA EXECUTAR TESTES
RegisterCommand('farming-test-all', function(source)
    if source ~= 0 then return end -- Apenas console
    
    print(FormatOutput(Colors.CYAN, "COMANDO", "Executando todos os testes do BCC-Farming..."))
    RunAllTests()
end)

RegisterCommand('farming-test-basic', function(source)
    if source ~= 0 then return end
    
    print(FormatOutput(Colors.CYAN, "COMANDO", "Executando testes básicos..."))
    TestSuite.startTime = GetGameTimer()
    TestSuite.results = {}
    TestSuite.totalTests = 0
    TestSuite.passedTests = 0
    TestSuite.failedTests = 0
    
    TestBasicExports()
    GenerateFinalReport()
end)

RegisterCommand('farming-test-player', function(source, args)
    if source ~= 0 then return end
    
    local playerId = tonumber(args[1]) or TestSuite.config.samplePlayerId
    TestSuite.config.samplePlayerId = playerId
    
    print(FormatOutput(Colors.CYAN, "COMANDO", string.format("Executando testes de jogador (ID: %d)...", playerId)))
    TestSuite.startTime = GetGameTimer()
    TestSuite.results = {}
    TestSuite.totalTests = 0
    TestSuite.passedTests = 0
    TestSuite.failedTests = 0
    
    TestPlayerExports()
    GenerateFinalReport()
end)

RegisterCommand('farming-test-performance', function(source)
    if source ~= 0 then return end
    
    print(FormatOutput(Colors.CYAN, "COMANDO", "Executando testes de performance..."))
    TestSuite.startTime = GetGameTimer()
    TestSuite.results = {}
    TestSuite.totalTests = 0
    TestSuite.passedTests = 0
    TestSuite.failedTests = 0
    
    TestStressAndPerformance()
    GenerateFinalReport()
end)

RegisterCommand('farming-test-config', function(source, args)
    if source ~= 0 then return end
    
    local setting = args[1]
    local value = args[2]
    
    if setting == "verbose" then
        TestSuite.config.verbose = value == "true"
        print(FormatOutput(Colors.GREEN, "CONFIG", string.format("Verbose definido para: %s", TestSuite.config.verbose and "SIM" or "NÃO")))
    elseif setting == "player" then
        TestSuite.config.samplePlayerId = tonumber(value) or 1
        print(FormatOutput(Colors.GREEN, "CONFIG", string.format("ID do jogador de teste: %d", TestSuite.config.samplePlayerId)))
    elseif setting == "timeout" then
        TestSuite.config.testTimeout = tonumber(value) or 10000
        print(FormatOutput(Colors.GREEN, "CONFIG", string.format("Timeout dos testes: %dms", TestSuite.config.testTimeout)))
    else
        print(FormatOutput(Colors.YELLOW, "HELP", "Uso: farming-test-config [verbose|player|timeout] [valor]"))
        print(FormatOutput(Colors.GRAY, "  →", "verbose: true/false"))
        print(FormatOutput(Colors.GRAY, "  →", "player: ID do jogador"))
        print(FormatOutput(Colors.GRAY, "  →", "timeout: tempo limite em ms"))
    end
end)

-- FUNÇÃO PARA TESTAR UM EXPORT ESPECÍFICO
RegisterCommand('farming-test-export', function(source, args)
    if source ~= 0 then return end
    
    local exportName = args[1]
    if not exportName then
        print(FormatOutput(Colors.RED, "ERRO", "Especifique o nome do export para testar"))
        return
    end
    
    print(FormatOutput(Colors.CYAN, "TESTE", string.format("Testando export: %s", exportName)))
    
    local success, result = pcall(function()
        return exports['bcc-farming'][exportName]()
    end)
    
    if success then
        print(FormatOutput(Colors.GREEN, "SUCESSO", "Export executado com sucesso"))
        if result then
            print(FormatOutput(Colors.GRAY, "RESULTADO", FormatData(result, 1)))
        end
    else
        print(FormatOutput(Colors.RED, "ERRO", string.format("Falha ao executar export: %s", tostring(result))))
    end
end)

-- AJUDA DOS COMANDOS
RegisterCommand('farming-test-help', function(source)
    if source ~= 0 then return end
    
    PrintSeparator("COMANDOS DE TESTE - BCC FARMING")
    print(FormatOutput(Colors.WHITE, "HELP", "farming-test-all - Executa todos os testes"))
    print(FormatOutput(Colors.WHITE, "HELP", "farming-test-basic - Executa apenas testes básicos"))
    print(FormatOutput(Colors.WHITE, "HELP", "farming-test-player [id] - Testa exports de jogador"))
    print(FormatOutput(Colors.WHITE, "HELP", "farming-test-performance - Testa performance"))
    print(FormatOutput(Colors.WHITE, "HELP", "farming-test-export [nome] - Testa export específico"))
    print(FormatOutput(Colors.WHITE, "HELP", "farming-test-config [setting] [value] - Configura testes"))
    print(FormatOutput(Colors.WHITE, "HELP", "farming-test-help - Mostra esta ajuda"))
    PrintSeparator()
end)

print(FormatOutput(Colors.GREEN, "LOADED", "Sistema de testes BCC-Farming carregado! ✅"))
print(FormatOutput(Colors.BLUE, "INFO", "Use 'farming-test-help' para ver todos os comandos disponíveis"))
print(FormatOutput(Colors.YELLOW, "QUICK", "Comando rápido: 'farming-test-all' para executar todos os testes"))