-- =======================================
-- BCC-Farming v2.5.0 Simplified Test System
-- Working test framework without complex module dependencies
-- =======================================

local SimplifiedTests = {}

-- =======================================
-- LOGGING FUNCTIONS
-- =======================================

local function TestLog(level, message)
    local timestamp = os.date("%H:%M:%S", os.time())
    local prefix = string.format("[%s][%s]", timestamp, level)
    print(string.format("^2[BCC-Farming]^7 %s %s", prefix, message))
end

local function TestPass(category, message)
    TestLog("PASS", string.format("[%s] %s", category, message))
end

local function TestFail(category, message)
    TestLog("FAIL", string.format("[%s] %s", category, message))
end

local function TestWarn(category, message)
    TestLog("WARN", string.format("[%s] %s", category, message))
end

-- =======================================
-- BASIC SYSTEM TESTS
-- =======================================

function SimplifiedTests.TestDatabase()
    TestLog("INFO", "Testing database connectivity...")
    
    local success, result = pcall(function()
        return MySQL.scalar.await('SELECT 1')
    end)
    
    if success then
        TestPass("DATABASE", "Connection successful")
        
        -- Test main table exists
        local tableExists = pcall(function()
            return MySQL.scalar.await('SELECT COUNT(*) FROM `bcc_farming`')
        end)
        
        if tableExists then
            TestPass("DATABASE", "Main table 'bcc_farming' exists")
        else
            TestFail("DATABASE", "Main table 'bcc_farming' missing")
        end
        
        -- Test v2.5.0 columns
        local columns = {
            'growth_stage',
            'growth_progress', 
            'water_count',
            'max_water_times',
            'base_fertilized'
        }
        
        for _, column in pairs(columns) do
            local columnExists = pcall(function()
                return MySQL.scalar.await(string.format('SELECT %s FROM `bcc_farming` LIMIT 1', column))
            end)
            
            if columnExists then
                TestPass("DATABASE", string.format("Column '%s' exists", column))
            else
                TestFail("DATABASE", string.format("Column '%s' missing", column))
            end
        end
        
        return true
    else
        TestFail("DATABASE", "Connection failed")
        return false
    end
end

function SimplifiedTests.TestConfiguration()
    TestLog("INFO", "Testing configuration...")
    
    -- Test Plants table
    if Plants and type(Plants) == "table" then
        TestPass("CONFIG", string.format("Plants table loaded (%d plants)", #Plants))
        
        -- Test each plant has required fields
        for i, plant in pairs(Plants) do
            local plantName = plant.plantName or "Unknown"
            
            -- Required fields
            if plant.seedName then
                TestPass("CONFIG", string.format("%s has seedName", plantName))
            else
                TestFail("CONFIG", string.format("%s missing seedName", plantName))
            end
            
            if plant.plantProps and type(plant.plantProps) == "table" then
                TestPass("CONFIG", string.format("%s has plantProps", plantName))
                
                if plant.plantProps.stage1 then
                    TestPass("CONFIG", string.format("%s has stage1 prop", plantName))
                else
                    TestFail("CONFIG", string.format("%s missing stage1 prop", plantName))
                end
                
                if plant.plantProps.stage2 then
                    TestPass("CONFIG", string.format("%s has stage2 prop", plantName))
                else
                    TestFail("CONFIG", string.format("%s missing stage2 prop", plantName))
                end
                
                if plant.plantProps.stage3 then
                    TestPass("CONFIG", string.format("%s has stage3 prop", plantName))
                else
                    TestFail("CONFIG", string.format("%s missing stage3 prop", plantName))
                end
            else
                TestFail("CONFIG", string.format("%s missing plantProps", plantName))
            end
            
            -- v2.5.0 fields
            if plant.waterTimes and type(plant.waterTimes) == "number" then
                TestPass("CONFIG", string.format("%s has waterTimes (%d)", plantName, plant.waterTimes))
            else
                TestWarn("CONFIG", string.format("%s missing waterTimes", plantName))
            end
            
            if plant.requiresBaseFertilizer ~= nil then
                TestPass("CONFIG", string.format("%s has requiresBaseFertilizer (%s)", plantName, tostring(plant.requiresBaseFertilizer)))
            else
                TestWarn("CONFIG", string.format("%s missing requiresBaseFertilizer", plantName))
            end
        end
        
        return true
    else
        TestFail("CONFIG", "Plants table not loaded or invalid")
        return false
    end
end

function SimplifiedTests.TestExports()
    TestLog("INFO", "Testing export functions...")
    
    local workingExports = {
        'GetGlobalPlantCount',
        'GetGlobalPlantsByType', 
        'GetFarmingOverview',
        'GetWateringStatus',
        'GetGrowthStageDistribution',
        'GetPlayerPlantCount',
        'GetPlayerPlants',
        'CanPlayerPlantMore',
        'GetPlayerFarmingStats'
    }
    
    local passedExports = 0
    
    for _, exportName in pairs(workingExports) do
        local success, result = pcall(function()
            return exports['bcc-farming'][exportName]
        end)
        
        if success and result then
            TestPass("EXPORTS", string.format("%s is available", exportName))
            passedExports = passedExports + 1
        else
            TestFail("EXPORTS", string.format("%s is not available", exportName))
        end
    end
    
    TestLog("INFO", string.format("Exports test: %d/%d passed", passedExports, #workingExports))
    return passedExports == #workingExports
end

function SimplifiedTests.TestExportFunctionality()
    TestLog("INFO", "Testing export functionality...")
    
    -- Test GetGlobalPlantCount
    local success, result = pcall(function()
        return exports['bcc-farming']:GetGlobalPlantCount()
    end)
    
    if success and result and result.success ~= nil then
        TestPass("EXPORTS", "GetGlobalPlantCount returns valid structure")
    else
        TestFail("EXPORTS", "GetGlobalPlantCount failed or invalid structure")
    end
    
    -- Test GetGlobalPlantsByType
    local success2, result2 = pcall(function()
        return exports['bcc-farming']:GetGlobalPlantsByType()
    end)
    
    if success2 and result2 and result2.success ~= nil then
        TestPass("EXPORTS", "GetGlobalPlantsByType returns valid structure")
    else
        TestFail("EXPORTS", "GetGlobalPlantsByType failed or invalid structure")
    end
    
    -- Test GetFarmingOverview
    local success3, result3 = pcall(function()
        return exports['bcc-farming']:GetFarmingOverview()
    end)
    
    if success3 and result3 and result3.success ~= nil then
        TestPass("EXPORTS", "GetFarmingOverview returns valid structure")
        
        if result3.data and result3.data.systemStats then
            TestPass("EXPORTS", "GetFarmingOverview includes systemStats")
        else
            TestWarn("EXPORTS", "GetFarmingOverview missing systemStats")
        end
    else
        TestFail("EXPORTS", "GetFarmingOverview failed or invalid structure")
    end
    
    return success and success2 and success3
end

function SimplifiedTests.TestPerformance()
    TestLog("INFO", "Testing basic performance...")
    
    local startTime = GetGameTimer()
    
    -- Test database query speed
    local dbSuccess, dbResult = pcall(function()
        return MySQL.scalar.await('SELECT COUNT(*) FROM `bcc_farming`')
    end)
    
    local dbTime = GetGameTimer() - startTime
    
    if dbSuccess then
        TestPass("PERFORMANCE", string.format("Database query completed in %dms", dbTime))
    else
        TestFail("PERFORMANCE", "Database query failed")
    end
    
    -- Test export speed
    local exportStart = GetGameTimer()
    local exportSuccess, exportResult = pcall(function()
        return exports['bcc-farming']:GetGlobalPlantCount()
    end)
    local exportTime = GetGameTimer() - exportStart
    
    if exportSuccess then
        TestPass("PERFORMANCE", string.format("Export call completed in %dms", exportTime))
    else
        TestFail("PERFORMANCE", "Export call failed")
    end
    
    return dbSuccess and exportSuccess
end

-- =======================================
-- MAIN TEST RUNNERS
-- =======================================

function SimplifiedTests.RunQuickTest()
    TestLog("INFO", "========================================")
    TestLog("INFO", "BCC-Farming v2.5.0 Quick Test")
    TestLog("INFO", "========================================")
    
    local testsPassed = 0
    local totalTests = 4
    
    if SimplifiedTests.TestDatabase() then testsPassed = testsPassed + 1 end
    if SimplifiedTests.TestConfiguration() then testsPassed = testsPassed + 1 end
    if SimplifiedTests.TestExports() then testsPassed = testsPassed + 1 end
    if SimplifiedTests.TestExportFunctionality() then testsPassed = testsPassed + 1 end
    
    TestLog("INFO", "========================================")
    TestLog("INFO", string.format("Quick Test Results: %d/%d passed", testsPassed, totalTests))
    
    if testsPassed == totalTests then
        TestLog("INFO", "🎉 All quick tests passed!")
        return true
    else
        TestLog("INFO", "❌ Some tests failed - see details above")
        return false
    end
end

function SimplifiedTests.RunFullTest()
    TestLog("INFO", "========================================")
    TestLog("INFO", "BCC-Farming v2.5.0 Full Test Suite")
    TestLog("INFO", "========================================")
    
    local testsPassed = 0
    local totalTests = 5
    
    if SimplifiedTests.TestDatabase() then testsPassed = testsPassed + 1 end
    if SimplifiedTests.TestConfiguration() then testsPassed = testsPassed + 1 end
    if SimplifiedTests.TestExports() then testsPassed = testsPassed + 1 end
    if SimplifiedTests.TestExportFunctionality() then testsPassed = testsPassed + 1 end
    if SimplifiedTests.TestPerformance() then testsPassed = testsPassed + 1 end
    
    TestLog("INFO", "========================================")
    TestLog("INFO", string.format("Full Test Results: %d/%d passed", testsPassed, totalTests))
    
    if testsPassed == totalTests then
        TestLog("INFO", "🎉 All tests passed! System is ready for production.")
        return true
    else
        TestLog("INFO", string.format("❌ %d tests failed - system needs attention", totalTests - testsPassed))
        return false
    end
end

-- =======================================
-- INDIVIDUAL TEST COMMANDS
-- =======================================

RegisterCommand('farming-test-simple', function()
    SimplifiedTests.RunQuickTest()
end, true)

RegisterCommand('farming-test-complete', function()
    SimplifiedTests.RunFullTest()
end, true)

RegisterCommand('farming-test-database', function()
    TestLog("INFO", "Running database-only test...")
    SimplifiedTests.TestDatabase()
end, true)

RegisterCommand('farming-test-config', function()
    TestLog("INFO", "Running configuration-only test...")
    SimplifiedTests.TestConfiguration()
end, true)

RegisterCommand('farming-test-exports', function()
    TestLog("INFO", "Running exports-only test...")
    SimplifiedTests.TestExports()
    SimplifiedTests.TestExportFunctionality()
end, true)

RegisterCommand('farming-test-performance', function()
    TestLog("INFO", "Running performance-only test...")
    SimplifiedTests.TestPerformance()
end, true)

-- =======================================
-- SYSTEM STATUS CHECK
-- =======================================

function SimplifiedTests.GetSystemStatus()
    local status = {
        database = false,
        configuration = false,
        exports = false,
        functionality = false,
        performance = false
    }
    
    status.database = SimplifiedTests.TestDatabase()
    status.configuration = SimplifiedTests.TestConfiguration()
    status.exports = SimplifiedTests.TestExports()
    status.functionality = SimplifiedTests.TestExportFunctionality()
    status.performance = SimplifiedTests.TestPerformance()
    
    local overallHealth = status.database and status.configuration and status.exports and status.functionality
    
    return {
        overall = overallHealth,
        components = status,
        timestamp = os.time()
    }
end

RegisterCommand('farming-health-check', function()
    TestLog("INFO", "Running system health check...")
    local status = SimplifiedTests.GetSystemStatus()
    
    TestLog("INFO", "System Health Report:")
    TestLog("INFO", string.format("  Database: %s", status.components.database and "✅ OK" or "❌ FAIL"))
    TestLog("INFO", string.format("  Configuration: %s", status.components.configuration and "✅ OK" or "❌ FAIL"))
    TestLog("INFO", string.format("  Exports: %s", status.components.exports and "✅ OK" or "❌ FAIL"))
    TestLog("INFO", string.format("  Functionality: %s", status.components.functionality and "✅ OK" or "❌ FAIL"))
    TestLog("INFO", string.format("  Performance: %s", status.components.performance and "✅ OK" or "❌ FAIL"))
    TestLog("INFO", string.format("Overall System: %s", status.overall and "🟢 HEALTHY" or "🔴 UNHEALTHY"))
end, true)

TestLog("INFO", "Simplified test system loaded!")
TestLog("INFO", "Available commands:")
TestLog("INFO", "  /farming-test-simple - Quick validation")
TestLog("INFO", "  /farming-test-complete - Full test suite")
TestLog("INFO", "  /farming-test-database - Database tests only")
TestLog("INFO", "  /farming-test-config - Configuration tests only") 
TestLog("INFO", "  /farming-test-exports - Export tests only")
TestLog("INFO", "  /farming-test-performance - Performance tests only")
TestLog("INFO", "  /farming-health-check - System health report")

return SimplifiedTests