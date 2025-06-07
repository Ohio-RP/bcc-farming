-- =======================================
-- BCC-Farming Simple Tests v2.5.0
-- Simplified testing without require system
-- =======================================

local SimpleTests = {}

-- Test results
local TestResults = {
    passed = 0,
    failed = 0,
    total = 0
}

-- =======================================
-- UTILITY FUNCTIONS
-- =======================================

local function TestLog(level, message)
    local timestamp = os.date('%H:%M:%S')
    local prefix = string.format("[%s][TEST]", timestamp)
    
    if level == 'PASS' then
        print(string.format("^2%s^7 %s", prefix, message))
    elseif level == 'FAIL' then
        print(string.format("^1%s^7 %s", prefix, message))
    elseif level == 'WARN' then
        print(string.format("^3%s^7 %s", prefix, message))
    else
        print(string.format("^6%s^7 %s", prefix, message))
    end
end

local function Assert(condition, message)
    TestResults.total = TestResults.total + 1
    
    if condition then
        TestResults.passed = TestResults.passed + 1
        TestLog('PASS', message)
        return true
    else
        TestResults.failed = TestResults.failed + 1
        TestLog('FAIL', message)
        return false
    end
end

-- =======================================
-- BASIC TESTS
-- =======================================

function SimpleTests.TestDatabaseConnection()
    TestLog('INFO', 'Testing database connection...')
    
    local success = pcall(function()
        MySQL.scalar.await('SELECT 1')
    end)
    
    Assert(success, 'Database connection working')
end

function SimpleTests.TestDatabaseSchema()
    TestLog('INFO', 'Testing database schema...')
    
    local success, result = pcall(function()
        return MySQL.query.await('DESCRIBE bcc_farming')
    end)
    
    if success and result then
        local columnMap = {}
        for _, column in pairs(result) do
            columnMap[column.Field] = true
        end
        
        -- Check for v2.5.0 columns
        Assert(columnMap['growth_stage'], 'growth_stage column exists')
        Assert(columnMap['growth_progress'], 'growth_progress column exists')
        Assert(columnMap['water_count'], 'water_count column exists')
        Assert(columnMap['max_water_times'], 'max_water_times column exists')
        Assert(columnMap['base_fertilized'], 'base_fertilized column exists')
        
        -- Check for legacy columns
        Assert(columnMap['plant_watered'], 'plant_watered column preserved')
        Assert(columnMap['plant_owner'], 'plant_owner column exists')
    else
        Assert(false, 'Failed to describe bcc_farming table')
    end
end

function SimpleTests.TestConfiguration()
    TestLog('INFO', 'Testing configuration...')
    
    Assert(Plants ~= nil, 'Plants table exists')
    Assert(type(Plants) == "table", 'Plants is a table')
    Assert(#Plants > 0, 'Plants table is not empty')
    
    local plantsWithV25Features = 0
    for _, plant in pairs(Plants) do
        if plant.plantProps or plant.waterTimes or plant.requiresBaseFertilizer then
            plantsWithV25Features = plantsWithV25Features + 1
        end
    end
    
    TestLog('INFO', string.format('Found %d plants with v2.5.0 features', plantsWithV25Features))
end

function SimpleTests.TestExportFunctions()
    TestLog('INFO', 'Testing export functions...')
    
    local basicExports = {
        'GetGlobalPlantCount',
        'GetGlobalPlantsByType',
        'GetFarmingOverview'
    }
    
    for _, exportName in pairs(basicExports) do
        local success = pcall(function()
            local result = exports['bcc-farming'][exportName]()
            return result ~= nil and type(result) == "table"
        end)
        
        Assert(success, string.format('Export %s works', exportName))
    end
end

function SimpleTests.TestHelperTables()
    TestLog('INFO', 'Testing helper tables...')
    
    local helperTables = {
        'bcc_farming_growth_stages',
        'bcc_farming_watering_log', 
        'bcc_farming_fertilizer_log'
    }
    
    for _, tableName in pairs(helperTables) do
        local success, result = pcall(function()
            return MySQL.scalar.await(string.format([[
                SELECT COUNT(*) FROM information_schema.tables 
                WHERE table_schema = DATABASE() AND table_name = '%s'
            ]], tableName))
        end)
        
        if success and result then
            Assert(result > 0, string.format('Helper table %s exists', tableName))
        else
            Assert(false, string.format('Failed to check helper table %s', tableName))
        end
    end
end

function SimpleTests.TestDataIntegrity()
    TestLog('INFO', 'Testing data integrity...')
    
    local success, result = pcall(function()
        return MySQL.query.await([[
            SELECT COUNT(*) as total,
                   COUNT(CASE WHEN growth_stage BETWEEN 1 AND 3 THEN 1 END) as valid_stages,
                   COUNT(CASE WHEN growth_progress BETWEEN 0 AND 100 THEN 1 END) as valid_progress,
                   COUNT(CASE WHEN water_count >= 0 THEN 1 END) as valid_water
            FROM bcc_farming
        ]])
    end)
    
    if success and result and #result > 0 then
        local stats = result[1]
        Assert(stats.total == stats.valid_stages, 'All growth stages are valid (1-3)')
        Assert(stats.total == stats.valid_progress, 'All growth progress values are valid (0-100)')
        Assert(stats.total == stats.valid_water, 'All water count values are valid (>=0)')
    else
        TestLog('WARN', 'No plants found in database to test data integrity')
    end
end

-- =======================================
-- MAIN TEST RUNNER
-- =======================================

function SimpleTests.RunAllTests()
    TestLog('INFO', '========================================')
    TestLog('INFO', 'BCC-Farming v2.5.0 Simple Tests')
    TestLog('INFO', '========================================')
    
    -- Reset counters
    TestResults = {passed = 0, failed = 0, total = 0}
    
    local startTime = GetGameTimer()
    
    -- Run tests
    SimpleTests.TestDatabaseConnection()
    SimpleTests.TestDatabaseSchema()
    SimpleTests.TestConfiguration()
    SimpleTests.TestExportFunctions()
    SimpleTests.TestHelperTables()
    SimpleTests.TestDataIntegrity()
    
    local endTime = GetGameTimer()
    local duration = endTime - startTime
    
    -- Generate report
    TestLog('INFO', '========================================')
    TestLog('INFO', 'Test Results')
    TestLog('INFO', '========================================')
    
    TestLog('INFO', string.format('Total Tests: %d', TestResults.total))
    TestLog('INFO', string.format('Passed: %d', TestResults.passed))
    TestLog('INFO', string.format('Failed: %d', TestResults.failed))
    TestLog('INFO', string.format('Duration: %dms', duration))
    
    local successRate = TestResults.total > 0 and (TestResults.passed / TestResults.total) * 100 or 0
    TestLog('INFO', string.format('Success Rate: %.1f%%', successRate))
    
    if TestResults.failed == 0 then
        TestLog('PASS', '🎉 All tests passed! System looks good!')
    elseif successRate >= 80 then
        TestLog('WARN', '⚠️ Most tests passed, but some issues detected')
    else
        TestLog('FAIL', '❌ Multiple test failures detected')
    end
    
    TestLog('INFO', '========================================')
    
    return TestResults
end

function SimpleTests.QuickCheck()
    TestLog('INFO', 'Running quick system check...')
    
    TestResults = {passed = 0, failed = 0, total = 0}
    
    SimpleTests.TestDatabaseConnection()
    SimpleTests.TestConfiguration()
    
    if TestResults.failed == 0 then
        TestLog('PASS', '✅ Quick check passed - basic systems working')
    else
        TestLog('FAIL', '❌ Quick check failed - basic issues detected')
    end
    
    return TestResults
end

-- =======================================
-- MANUAL VALIDATION FUNCTIONS
-- =======================================

function SimpleTests.ValidateMigration()
    TestLog('INFO', 'Manual migration validation...')
    
    local success, result = pcall(function()
        return MySQL.query.await([[
            SELECT 
                COUNT(*) as total_plants,
                AVG(growth_stage) as avg_stage,
                AVG(growth_progress) as avg_progress,
                SUM(CASE WHEN base_fertilized = 1 THEN 1 ELSE 0 END) as fertilized_count
            FROM bcc_farming
        ]])
    end)
    
    if success and result and #result > 0 then
        local stats = result[1]
        TestLog('INFO', string.format('Total plants: %d', stats.total_plants))
        TestLog('INFO', string.format('Average stage: %.1f', stats.avg_stage or 0))
        TestLog('INFO', string.format('Average progress: %.1f%%', stats.avg_progress or 0))
        TestLog('INFO', string.format('Fertilized plants: %d', stats.fertilized_count))
        
        if stats.total_plants > 0 then
            TestLog('PASS', 'Migration appears successful - data found')
        else
            TestLog('WARN', 'No plant data found - either new install or migration issue')
        end
    else
        TestLog('FAIL', 'Failed to query plant statistics')
    end
end

-- =======================================
-- COMMAND REGISTRATION
-- =======================================

RegisterCommand('farming-simple-test', function()
    SimpleTests.RunAllTests()
end, true)

RegisterCommand('farming-quick-check', function()
    SimpleTests.QuickCheck()
end, true)

RegisterCommand('farming-validate-simple', function()
    SimpleTests.ValidateMigration()
end, true)

RegisterCommand('farming-test-db', function()
    SimpleTests.TestDatabaseConnection()
    SimpleTests.TestDatabaseSchema()
    SimpleTests.TestDataIntegrity()
    TestLog('INFO', string.format('Database tests: %d passed, %d failed', 
        TestResults.passed, TestResults.failed))
end, true)

RegisterCommand('farming-test-config', function()
    SimpleTests.TestConfiguration()
    TestLog('INFO', string.format('Configuration tests: %d passed, %d failed', 
        TestResults.passed, TestResults.failed))
end, true)

return SimpleTests