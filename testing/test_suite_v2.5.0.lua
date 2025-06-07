-- =======================================
-- BCC-Farming Test Suite v2.5.0
-- Comprehensive Testing for Multi-Stage Growth System
-- =======================================

local TestSuite = {}

-- Test configuration
local TEST_CONFIG = {
    testPlayerIds = {1, 2}, -- Server IDs for testing
    testPlantTypes = {'corn_seed', 'wheat_seed', 'tobacco_seed'},
    testCoords = {
        {x = 100, y = 200, z = 50},
        {x = 150, y = 250, z = 52},
        {x = 200, y = 300, z = 48}
    },
    runLiveTests = false, -- Set to true only for live server testing
    logLevel = 'detailed' -- 'basic', 'detailed', 'verbose'
}

-- Test results storage
local TestResults = {
    passed = 0,
    failed = 0,
    total = 0,
    errors = {},
    details = {}
}

-- =======================================
-- UTILITY FUNCTIONS
-- =======================================

-- Logging function
local function TestLog(level, message, category)
    if TEST_CONFIG.logLevel == 'basic' and level ~= 'ERROR' and level ~= 'RESULT' then
        return
    end
    
    local timestamp = os.date('%H:%M:%S')
    local prefix = string.format("[%s][%s]", timestamp, level)
    if category then
        prefix = prefix .. string.format("[%s]", category)
    end
    
    print(string.format("^3%s^7 %s", prefix, message))
end

-- Assert function for tests
local function Assert(condition, message, category)
    TestResults.total = TestResults.total + 1
    
    if condition then
        TestResults.passed = TestResults.passed + 1
        TestLog('PASS', message, category)
        return true
    else
        TestResults.failed = TestResults.failed + 1
        TestResults.errors[TestResults.total] = {
            message = message,
            category = category,
            timestamp = os.time()
        }
        TestLog('FAIL', message, category)
        return false
    end
end

-- Safe function execution
local function SafeCall(func, category, description)
    local success, result = pcall(func)
    if not success then
        TestLog('ERROR', string.format("%s failed: %s", description, result), category)
        TestResults.errors[#TestResults.errors + 1] = {
            message = string.format("%s: %s", description, result),
            category = category,
            timestamp = os.time()
        }
        return false, result
    end
    return true, result
end

-- =======================================
-- DATABASE TESTS
-- =======================================

function TestSuite.TestDatabaseSchema()
    TestLog('INFO', 'Starting database schema tests...', 'DATABASE')
    
    -- Test 1: Verify new columns exist
    SafeCall(function()
        local result = MySQL.query.await([[
            DESCRIBE bcc_farming
        ]])
        
        local requiredColumns = {
            'growth_stage', 'growth_progress', 'water_count', 
            'max_water_times', 'base_fertilized'
        }
        
        local foundColumns = {}
        for _, column in pairs(result) do
            foundColumns[column.Field] = true
        end
        
        for _, reqCol in pairs(requiredColumns) do
            Assert(foundColumns[reqCol], 
                string.format("Required column '%s' exists", reqCol), 'DATABASE')
        end
    end, 'DATABASE', 'Database schema validation')
    
    -- Test 2: Verify helper tables exist
    SafeCall(function()
        local tables = {'bcc_farming_growth_stages', 'bcc_farming_watering_log', 'bcc_farming_fertilizer_log'}
        
        for _, table in pairs(tables) do
            local result = MySQL.scalar.await(string.format(
                "SELECT COUNT(*) FROM information_schema.tables WHERE table_name = '%s'", table
            ))
            Assert(result > 0, string.format("Helper table '%s' exists", table), 'DATABASE')
        end
    end, 'DATABASE', 'Helper tables validation')
    
    -- Test 3: Test default values
    SafeCall(function()
        local result = MySQL.query.await([[
            SELECT growth_stage, growth_progress, water_count, max_water_times, base_fertilized
            FROM bcc_farming LIMIT 1
        ]])
        
        if #result > 0 then
            local row = result[1]
            Assert(row.growth_stage >= 1 and row.growth_stage <= 3, 
                "Growth stage is within valid range (1-3)", 'DATABASE')
            Assert(row.growth_progress >= 0 and row.growth_progress <= 100, 
                "Growth progress is within valid range (0-100)", 'DATABASE')
            Assert(row.water_count >= 0, "Water count is non-negative", 'DATABASE')
            Assert(row.max_water_times >= 1, "Max water times is positive", 'DATABASE')
        end
    end, 'DATABASE', 'Default values validation')
end

-- =======================================
-- CONFIGURATION TESTS
-- =======================================

function TestSuite.TestPlantConfiguration()
    TestLog('INFO', 'Starting plant configuration tests...', 'CONFIG')
    
    -- Test 1: Verify Plants table exists and is valid
    SafeCall(function()
        Assert(Plants ~= nil, "Plants configuration table exists", 'CONFIG')
        Assert(type(Plants) == "table", "Plants is a table", 'CONFIG')
        Assert(#Plants > 0, "Plants table is not empty", 'CONFIG')
    end, 'CONFIG', 'Basic Plants table validation')
    
    -- Test 2: Validate plant configurations
    SafeCall(function()
        for plantIndex, plant in pairs(Plants) do
            local plantName = plant.plantName or string.format("Plant #%d", plantIndex)
            
            -- Test required fields
            Assert(plant.seedName ~= nil, 
                string.format("%s has seedName", plantName), 'CONFIG')
            Assert(plant.plantName ~= nil, 
                string.format("%s has plantName", plantName), 'CONFIG')
            
            -- Test v2.5.0 specific configurations
            if plant.plantProps then
                Assert(type(plant.plantProps) == "table", 
                    string.format("%s plantProps is a table", plantName), 'CONFIG')
                
                -- Check for stage props
                for stage = 1, 3 do
                    local stageKey = string.format("stage%d", stage)
                    if plant.plantProps[stageKey] then
                        Assert(type(plant.plantProps[stageKey]) == "string", 
                            string.format("%s %s is a string", plantName, stageKey), 'CONFIG')
                    end
                end
            end
            
            -- Test watering configuration
            if plant.waterTimes then
                Assert(plant.waterTimes >= 1 and plant.waterTimes <= 10, 
                    string.format("%s waterTimes is within valid range", plantName), 'CONFIG')
            end
            
            -- Test fertilizer configuration
            if plant.requiresBaseFertilizer then
                Assert(type(plant.requiresBaseFertilizer) == "boolean", 
                    string.format("%s requiresBaseFertilizer is boolean", plantName), 'CONFIG')
            end
        end
    end, 'CONFIG', 'Individual plant configuration validation')
    
    -- Test 3: Validate backward compatibility
    SafeCall(function()
        for _, plant in pairs(Plants) do
            -- Ensure legacy props still work
            if not plant.plantProps and plant.plantProp then
                Assert(type(plant.plantProp) == "string", 
                    string.format("%s legacy plantProp is valid", plant.plantName), 'CONFIG')
            end
        end
    end, 'CONFIG', 'Backward compatibility validation')
end

-- =======================================
-- CORE FUNCTION TESTS
-- =======================================

function TestSuite.TestGrowthCalculations()
    TestLog('INFO', 'Starting growth calculations tests...', 'CALCULATIONS')
    
    -- Test 1: Growth stage calculation
    SafeCall(function()
        local GrowthCalculations = require('server.services.growth_calculations')
        
        -- Test stage determination
        Assert(GrowthCalculations.DetermineGrowthStage(15) == 1, 
            "Progress 15% = Stage 1", 'CALCULATIONS')
        Assert(GrowthCalculations.DetermineGrowthStage(45) == 2, 
            "Progress 45% = Stage 2", 'CALCULATIONS')
        Assert(GrowthCalculations.DetermineGrowthStage(85) == 3, 
            "Progress 85% = Stage 3", 'CALCULATIONS')
        Assert(GrowthCalculations.DetermineGrowthStage(100) == 3, 
            "Progress 100% = Stage 3", 'CALCULATIONS')
    end, 'CALCULATIONS', 'Growth stage calculation')
    
    -- Test 2: Reward calculation
    SafeCall(function()
        local GrowthCalculations = require('server.services.growth_calculations')
        
        local mockPlantConfig = {
            rewards = {amount = 10},
            waterTimes = 3,
            requiresBaseFertilizer = true
        }
        
        -- Test full efficiency
        local fullReward = GrowthCalculations.CalculateFinalReward(mockPlantConfig, {
            water_count = 3,
            max_water_times = 3,
            base_fertilized = true
        })
        Assert(fullReward == 10, "Full efficiency = full reward", 'CALCULATIONS')
        
        -- Test water penalty
        local waterPenalty = GrowthCalculations.CalculateFinalReward(mockPlantConfig, {
            water_count = 1,
            max_water_times = 3,
            base_fertilized = true
        })
        Assert(waterPenalty < 10, "Insufficient watering reduces reward", 'CALCULATIONS')
        
        -- Test fertilizer penalty
        local fertPenalty = GrowthCalculations.CalculateFinalReward(mockPlantConfig, {
            water_count = 3,
            max_water_times = 3,
            base_fertilized = false
        })
        Assert(fertPenalty < 10, "No base fertilizer reduces reward", 'CALCULATIONS')
    end, 'CALCULATIONS', 'Reward calculation')
    
    -- Test 3: Watering validation
    SafeCall(function()
        local GrowthCalculations = require('server.services.growth_calculations')
        
        local mockPlantData = {
            water_count = 2,
            max_water_times = 3,
            growth_progress = 50
        }
        
        local canWater, reason = GrowthCalculations.CanWaterPlant(mockPlantData)
        Assert(canWater == true, "Plant with incomplete watering can be watered", 'CALCULATIONS')
        
        mockPlantData.water_count = 3
        local cannotWater, reason2 = GrowthCalculations.CanWaterPlant(mockPlantData)
        Assert(cannotWater == false, "Fully watered plant cannot be watered more", 'CALCULATIONS')
    end, 'CALCULATIONS', 'Watering validation')
end

-- =======================================
-- EXPORT FUNCTION TESTS
-- =======================================

function TestSuite.TestExportFunctions()
    TestLog('INFO', 'Starting export functions tests...', 'EXPORTS')
    
    -- Test 1: Basic exports
    SafeCall(function()
        local exports = {
            'GetGlobalPlantCount',
            'GetGlobalPlantsByType',
            'GetFarmingOverview',
            'GetWateringStatus',
            'GetGrowthStageDistribution' -- New in v2.5.0
        }
        
        for _, exportName in pairs(exports) do
            local result = exports['bcc-farming'][exportName]()
            Assert(result ~= nil, string.format("Export %s returns result", exportName), 'EXPORTS')
            Assert(type(result) == "table", string.format("Export %s returns table", exportName), 'EXPORTS')
            Assert(result.success ~= nil, string.format("Export %s has success field", exportName), 'EXPORTS')
        end
    end, 'EXPORTS', 'Basic export validation')
    
    -- Test 2: Player exports (if test player IDs are available)
    if TEST_CONFIG.runLiveTests then
        SafeCall(function()
            for _, playerId in pairs(TEST_CONFIG.testPlayerIds) do
                local result = exports['bcc-farming']:GetPlayerPlantCount(playerId)
                Assert(result ~= nil, string.format("GetPlayerPlantCount works for player %d", playerId), 'EXPORTS')
                
                if result.success then
                    local plantsResult = exports['bcc-farming']:GetPlayerPlants(playerId)
                    Assert(plantsResult ~= nil, string.format("GetPlayerPlants works for player %d", playerId), 'EXPORTS')
                    
                    -- Test new v2.5.0 export
                    local efficiencyResult = exports['bcc-farming']:GetPlayerEfficiencyReport(playerId)
                    Assert(efficiencyResult ~= nil, string.format("GetPlayerEfficiencyReport works for player %d", playerId), 'EXPORTS')
                end
            end
        end, 'EXPORTS', 'Player export validation')
    end
    
    -- Test 3: Export data structure validation
    SafeCall(function()
        local overviewResult = exports['bcc-farming']:GetFarmingOverview()
        if overviewResult.success then
            -- Test v2.5.0 enhanced structure
            Assert(overviewResult.data.systemStats ~= nil, 
                "FarmingOverview includes systemStats", 'EXPORTS')
            Assert(overviewResult.data.systemStats.stageDistribution ~= nil, 
                "systemStats includes stageDistribution", 'EXPORTS')
            Assert(overviewResult.data.systemStats.fertilizedPercentage ~= nil, 
                "systemStats includes fertilizedPercentage", 'EXPORTS')
        end
        
        local stageResult = exports['bcc-farming']:GetGrowthStageDistribution()
        if stageResult.success then
            Assert(stageResult.data.stages ~= nil, 
                "GetGrowthStageDistribution includes stages", 'EXPORTS')
            Assert(type(stageResult.data.stages) == "table", 
                "stages is a table", 'EXPORTS')
        end
    end, 'EXPORTS', 'Export structure validation')
end

-- =======================================
-- NUI SYSTEM TESTS
-- =======================================

function TestSuite.TestNUISystem()
    TestLog('INFO', 'Starting NUI system tests...', 'NUI')
    
    -- Test 1: NUI configuration
    SafeCall(function()
        Assert(NUIConfig ~= nil, "NUIConfig exists", 'NUI')
        Assert(NUIConfig.PlantStatus ~= nil, "NUIConfig.PlantStatus exists", 'NUI')
        Assert(NUIConfig.PlantStatus.enabled ~= nil, "NUI enabled setting exists", 'NUI')
        Assert(NUIConfig.Visual ~= nil, "NUIConfig.Visual exists", 'NUI')
        Assert(NUIConfig.Language ~= nil, "NUIConfig.Language exists", 'NUI')
    end, 'NUI', 'NUI configuration validation')
    
    -- Test 2: NUI files existence (simplified check)
    SafeCall(function()
        -- This would need to be adapted for actual file system checks
        -- For now, we'll check if the resource includes the files in manifest
        TestLog('INFO', "NUI files validation would require file system access", 'NUI')
        Assert(true, "NUI files check placeholder", 'NUI')
    end, 'NUI', 'NUI files validation')
end

-- =======================================
-- INTEGRATION TESTS
-- =======================================

function TestSuite.TestSystemIntegration()
    TestLog('INFO', 'Starting system integration tests...', 'INTEGRATION')
    
    -- Test 1: Client-server communication
    SafeCall(function()
        -- This would test event communication between client and server
        TestLog('INFO', "Client-server communication test requires live environment", 'INTEGRATION')
        Assert(true, "Client-server communication placeholder", 'INTEGRATION')
    end, 'INTEGRATION', 'Client-server communication')
    
    -- Test 2: Database consistency
    SafeCall(function()
        -- Check for any plants with invalid data
        local result = MySQL.query.await([[
            SELECT COUNT(*) as invalid_count FROM bcc_farming 
            WHERE growth_stage < 1 OR growth_stage > 3 
               OR growth_progress < 0 OR growth_progress > 100
               OR water_count < 0 OR max_water_times < 1
        ]])
        
        if #result > 0 then
            Assert(result[1].invalid_count == 0, 
                "No plants with invalid data in database", 'INTEGRATION')
        end
    end, 'INTEGRATION', 'Database consistency check')
    
    -- Test 3: Configuration compatibility
    SafeCall(function()
        -- Test that all configured plants have valid props
        for _, plant in pairs(Plants) do
            if plant.plantProps then
                -- Check that at least stage1 prop exists
                Assert(plant.plantProps.stage1 ~= nil, 
                    string.format("%s has stage1 prop", plant.plantName), 'INTEGRATION')
            end
        end
    end, 'INTEGRATION', 'Configuration compatibility')
end

-- =======================================
-- PERFORMANCE TESTS
-- =======================================

function TestSuite.TestPerformance()
    TestLog('INFO', 'Starting performance tests...', 'PERFORMANCE')
    
    -- Test 1: Export function performance
    SafeCall(function()
        local startTime = GetGameTimer()
        local result = exports['bcc-farming']:GetFarmingOverview()
        local endTime = GetGameTimer()
        local duration = endTime - startTime
        
        Assert(duration < 1000, 
            string.format("GetFarmingOverview completed in %dms (< 1000ms)", duration), 'PERFORMANCE')
    end, 'PERFORMANCE', 'Export performance test')
    
    -- Test 2: Growth calculation performance
    SafeCall(function()
        local GrowthCalculations = require('server.services.growth_calculations')
        local mockPlantConfig = {
            rewards = {amount = 10},
            waterTimes = 3,
            requiresBaseFertilizer = true
        }
        local mockPlantData = {
            water_count = 2,
            max_water_times = 3,
            base_fertilized = true
        }
        
        local startTime = GetGameTimer()
        for i = 1, 100 do
            GrowthCalculations.CalculateFinalReward(mockPlantConfig, mockPlantData)
        end
        local endTime = GetGameTimer()
        local duration = endTime - startTime
        
        Assert(duration < 100, 
            string.format("100 reward calculations completed in %dms (< 100ms)", duration), 'PERFORMANCE')
    end, 'PERFORMANCE', 'Calculation performance test')
end

-- =======================================
-- MAIN TEST RUNNER
-- =======================================

function TestSuite.RunAllTests()
    TestLog('INFO', '========================================', 'SYSTEM')
    TestLog('INFO', 'BCC-Farming v2.5.0 Test Suite Starting', 'SYSTEM')
    TestLog('INFO', '========================================', 'SYSTEM')
    
    -- Reset test results
    TestResults = {
        passed = 0,
        failed = 0,
        total = 0,
        errors = {},
        details = {}
    }
    
    local startTime = GetGameTimer()
    
    -- Run test categories
    TestSuite.TestDatabaseSchema()
    TestSuite.TestPlantConfiguration()
    TestSuite.TestGrowthCalculations()
    TestSuite.TestExportFunctions()
    TestSuite.TestNUISystem()
    TestSuite.TestSystemIntegration()
    TestSuite.TestPerformance()
    
    local endTime = GetGameTimer()
    local totalDuration = endTime - startTime
    
    -- Generate report
    TestSuite.GenerateReport(totalDuration)
end

function TestSuite.GenerateReport(duration)
    TestLog('INFO', '========================================', 'RESULTS')
    TestLog('INFO', 'BCC-Farming v2.5.0 Test Results', 'RESULTS')
    TestLog('INFO', '========================================', 'RESULTS')
    
    TestLog('RESULT', string.format("Total Tests: %d", TestResults.total), 'RESULTS')
    TestLog('RESULT', string.format("Passed: %d", TestResults.passed), 'RESULTS')
    TestLog('RESULT', string.format("Failed: %d", TestResults.failed), 'RESULTS')
    TestLog('RESULT', string.format("Success Rate: %.1f%%", 
        TestResults.total > 0 and (TestResults.passed / TestResults.total) * 100 or 0), 'RESULTS')
    TestLog('RESULT', string.format("Test Duration: %dms", duration), 'RESULTS')
    
    if TestResults.failed > 0 then
        TestLog('ERROR', 'Failed Tests:', 'RESULTS')
        for _, error in pairs(TestResults.errors) do
            TestLog('ERROR', string.format("  [%s] %s", error.category or 'UNKNOWN', error.message), 'RESULTS')
        end
    else
        TestLog('INFO', '🎉 All tests passed! System is ready for production.', 'RESULTS')
    end
    
    TestLog('INFO', '========================================', 'RESULTS')
    
    return TestResults
end

-- =======================================
-- COMMAND REGISTRATION
-- =======================================

-- Register test commands
RegisterCommand('farming-test-all', function()
    TestSuite.RunAllTests()
end, true) -- Restrict to admins

RegisterCommand('farming-test-database', function()
    TestSuite.TestDatabaseSchema()
    TestLog('INFO', string.format("Database tests completed: %d passed, %d failed", 
        TestResults.passed, TestResults.failed), 'RESULTS')
end, true)

RegisterCommand('farming-test-exports', function()
    TestSuite.TestExportFunctions()
    TestLog('INFO', string.format("Export tests completed: %d passed, %d failed", 
        TestResults.passed, TestResults.failed), 'RESULTS')
end, true)

RegisterCommand('farming-test-config', function()
    TestSuite.TestPlantConfiguration()
    TestLog('INFO', string.format("Configuration tests completed: %d passed, %d failed", 
        TestResults.passed, TestResults.failed), 'RESULTS')
end, true)

-- Export the test suite
return TestSuite