-- =======================================
-- BCC-Farming Performance Tests v2.5.0
-- Performance benchmarking and load testing
-- =======================================

local PerformanceTests = {}

-- Performance test configuration
local PERF_CONFIG = {
    -- Test parameters
    maxTestPlants = 1000,      -- Maximum plants to test with
    testIterations = 100,      -- Number of iterations for performance tests
    maxResponseTime = 1000,    -- Maximum acceptable response time (ms)
    maxMemoryUsage = 50,       -- Maximum memory usage increase (MB)
    
    -- Test modes
    runLoadTests = false,      -- Run high-load tests (resource intensive)
    runStressTests = false,    -- Run stress tests (very resource intensive)
    logDetailedResults = true, -- Log detailed performance metrics
}

-- Performance metrics storage
local PerfMetrics = {
    exportTimes = {},
    calculationTimes = {},
    databaseTimes = {},
    memoryUsage = {},
    cpuUsage = {}
}

-- =======================================
-- UTILITY FUNCTIONS
-- =======================================

local function LogPerf(level, message, duration, category)
    local timestamp = os.date('%H:%M:%S')
    local prefix = string.format("[%s][PERF][%s]", timestamp, level)
    
    if duration then
        message = string.format("%s (Duration: %dms)", message, duration)
    end
    
    if category then
        prefix = string.format("%s[%s]", prefix, category)
    end
    
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

local function MeasureTime(func, description)
    local startTime = GetGameTimer()
    local success, result = pcall(func)
    local endTime = GetGameTimer()
    local duration = endTime - startTime
    
    if not success then
        LogPerf('FAIL', string.format("%s failed: %s", description, result), duration)
        return false, duration, result
    end
    
    return true, duration, result
end

local function GetMemoryUsage()
    -- Basic memory usage estimation (in MB)
    collectgarbage("collect")
    return collectgarbage("count") / 1024
end

local function BenchmarkFunction(func, iterations, description, category)
    LogPerf('INFO', string.format("Benchmarking: %s (%d iterations)", description, iterations), nil, category)
    
    local times = {}
    local totalTime = 0
    local failures = 0
    
    for i = 1, iterations do
        local success, duration, result = MeasureTime(func, description)
        if success then
            table.insert(times, duration)
            totalTime = totalTime + duration
        else
            failures = failures + 1
        end
    end
    
    if #times > 0 then
        table.sort(times)
        local avgTime = totalTime / #times
        local medianTime = times[math.ceil(#times / 2)]
        local minTime = times[1]
        local maxTime = times[#times]
        
        LogPerf('INFO', string.format("Results - Avg: %dms, Median: %dms, Min: %dms, Max: %dms", 
            avgTime, medianTime, minTime, maxTime), nil, category)
        
        if avgTime <= PERF_CONFIG.maxResponseTime then
            LogPerf('PASS', string.format("Performance acceptable (avg %dms <= %dms)", 
                avgTime, PERF_CONFIG.maxResponseTime), nil, category)
        else
            LogPerf('FAIL', string.format("Performance poor (avg %dms > %dms)", 
                avgTime, PERF_CONFIG.maxResponseTime), nil, category)
        end
        
        if failures > 0 then
            LogPerf('WARN', string.format("%d/%d iterations failed", failures, iterations), nil, category)
        end
        
        return {
            avg = avgTime,
            median = medianTime,
            min = minTime,
            max = maxTime,
            failures = failures,
            total = iterations
        }
    else
        LogPerf('FAIL', "All iterations failed", nil, category)
        return nil
    end
end

-- =======================================
-- EXPORT FUNCTION PERFORMANCE TESTS
-- =======================================

function PerformanceTests.TestExportPerformance()
    LogPerf('INFO', 'Starting export function performance tests...', nil, 'EXPORTS')
    
    local exportTests = {
        {
            name = 'GetGlobalPlantCount',
            func = function() return exports['bcc-farming']:GetGlobalPlantCount() end
        },
        {
            name = 'GetGlobalPlantsByType',
            func = function() return exports['bcc-farming']:GetGlobalPlantsByType() end
        },
        {
            name = 'GetFarmingOverview',
            func = function() return exports['bcc-farming']:GetFarmingOverview() end
        },
        {
            name = 'GetWateringStatus',
            func = function() return exports['bcc-farming']:GetWateringStatus() end
        },
        {
            name = 'GetGrowthStageDistribution',
            func = function() return exports['bcc-farming']:GetGrowthStageDistribution() end
        }
    }
    
    for _, test in pairs(exportTests) do
        local results = BenchmarkFunction(test.func, 10, test.name, 'EXPORTS')
        if results then
            PerfMetrics.exportTimes[test.name] = results
        end
    end
end

-- =======================================
-- CALCULATION PERFORMANCE TESTS
-- =======================================

function PerformanceTests.TestCalculationPerformance()
    LogPerf('INFO', 'Starting calculation performance tests...', nil, 'CALC')
    
    local GrowthCalculations = require('server.services.growth_calculations')
    
    -- Test growth stage calculation
    local stageCalcResults = BenchmarkFunction(
        function()
            for i = 1, 100 do
                GrowthCalculations.DetermineGrowthStage(math.random(0, 100))
            end
        end,
        PERF_CONFIG.testIterations,
        'Growth Stage Calculation (100 calls)',
        'CALC'
    )
    
    -- Test reward calculation
    local mockPlantConfig = {
        rewards = {amount = 10},
        waterTimes = 3,
        requiresBaseFertilizer = true
    }
    
    local rewardCalcResults = BenchmarkFunction(
        function()
            for i = 1, 100 do
                GrowthCalculations.CalculateFinalReward(mockPlantConfig, {
                    water_count = math.random(0, 3),
                    max_water_times = 3,
                    base_fertilized = math.random() > 0.5,
                    fertilizer_type = nil
                })
            end
        end,
        PERF_CONFIG.testIterations,
        'Reward Calculation (100 calls)',
        'CALC'
    )
    
    -- Test watering validation
    local waterValidResults = BenchmarkFunction(
        function()
            for i = 1, 100 do
                GrowthCalculations.CanWaterPlant({
                    water_count = math.random(0, 5),
                    max_water_times = math.random(1, 5),
                    growth_progress = math.random(0, 100)
                })
            end
        end,
        PERF_CONFIG.testIterations,
        'Watering Validation (100 calls)',
        'CALC'
    )
    
    PerfMetrics.calculationTimes = {
        stageCalculation = stageCalcResults,
        rewardCalculation = rewardCalcResults,
        wateringValidation = waterValidResults
    }
end

-- =======================================
-- DATABASE PERFORMANCE TESTS
-- =======================================

function PerformanceTests.TestDatabasePerformance()
    LogPerf('INFO', 'Starting database performance tests...', nil, 'DATABASE')
    
    -- Test basic queries
    local basicQueryResults = BenchmarkFunction(
        function()
            return MySQL.scalar.await('SELECT COUNT(*) FROM bcc_farming')
        end,
        50,
        'Basic Count Query',
        'DATABASE'
    )
    
    -- Test complex joins (if helper tables exist)
    local complexQueryResults = BenchmarkFunction(
        function()
            return MySQL.query.await([[
                SELECT 
                    f.plant_type,
                    COUNT(*) as count,
                    AVG(f.growth_progress) as avg_progress,
                    AVG(f.water_count) as avg_water
                FROM bcc_farming f
                GROUP BY f.plant_type
                LIMIT 10
            ]])
        end,
        20,
        'Complex Aggregation Query',
        'DATABASE'
    )
    
    -- Test plant status query (simulating NUI requests)
    local statusQueryResults = BenchmarkFunction(
        function()
            return MySQL.query.await([[
                SELECT plant_id, growth_stage, growth_progress, water_count, max_water_times, base_fertilized
                FROM bcc_farming 
                ORDER BY plant_id DESC
                LIMIT 10
            ]])
        end,
        30,
        'Plant Status Query (NUI simulation)',
        'DATABASE'
    )
    
    PerfMetrics.databaseTimes = {
        basicQuery = basicQueryResults,
        complexQuery = complexQueryResults,
        statusQuery = statusQueryResults
    }
end

-- =======================================
-- MEMORY USAGE TESTS
-- =======================================

function PerformanceTests.TestMemoryUsage()
    LogPerf('INFO', 'Starting memory usage tests...', nil, 'MEMORY')
    
    local initialMemory = GetMemoryUsage()
    LogPerf('INFO', string.format("Initial memory usage: %.2fMB", initialMemory), nil, 'MEMORY')
    
    -- Test memory usage during heavy export operations
    local memoryBefore = GetMemoryUsage()
    
    for i = 1, 50 do
        exports['bcc-farming']:GetFarmingOverview()
        exports['bcc-farming']:GetGlobalPlantsByType()
        if i % 10 == 0 then
            collectgarbage("collect")
        end
    end
    
    local memoryAfter = GetMemoryUsage()
    local memoryIncrease = memoryAfter - memoryBefore
    
    LogPerf('INFO', string.format("Memory after exports: %.2fMB (increase: %.2fMB)", 
        memoryAfter, memoryIncrease), nil, 'MEMORY')
    
    if memoryIncrease <= PERF_CONFIG.maxMemoryUsage then
        LogPerf('PASS', string.format("Memory increase acceptable (%.2fMB <= %dMB)", 
            memoryIncrease, PERF_CONFIG.maxMemoryUsage), nil, 'MEMORY')
    else
        LogPerf('FAIL', string.format("Memory increase too high (%.2fMB > %dMB)", 
            memoryIncrease, PERF_CONFIG.maxMemoryUsage), nil, 'MEMORY')
    end
    
    PerfMetrics.memoryUsage = {
        initial = initialMemory,
        final = memoryAfter,
        increase = memoryIncrease
    }
    
    -- Force garbage collection
    collectgarbage("collect")
    local memoryAfterGC = GetMemoryUsage()
    LogPerf('INFO', string.format("Memory after GC: %.2fMB", memoryAfterGC), nil, 'MEMORY')
end

-- =======================================
-- LOAD TESTS
-- =======================================

function PerformanceTests.TestHighLoad()
    if not PERF_CONFIG.runLoadTests then
        LogPerf('INFO', 'Skipping load tests (disabled in config)', nil, 'LOAD')
        return
    end
    
    LogPerf('INFO', 'Starting high load tests...', nil, 'LOAD')
    
    -- Simulate multiple concurrent export requests
    local loadTestResults = BenchmarkFunction(
        function()
            local results = {}
            
            -- Simulate 10 concurrent requests
            for i = 1, 10 do
                table.insert(results, exports['bcc-farming']:GetFarmingOverview())
                table.insert(results, exports['bcc-farming']:GetGlobalPlantsByType())
                table.insert(results, exports['bcc-farming']:GetWateringStatus())
            end
            
            return results
        end,
        10,
        'High Load Test (30 exports per iteration)',
        'LOAD'
    )
    
    PerfMetrics.loadTest = loadTestResults
end

-- =======================================
-- STRESS TESTS
-- =======================================

function PerformanceTests.TestStress()
    if not PERF_CONFIG.runStressTests then
        LogPerf('INFO', 'Skipping stress tests (disabled in config)', nil, 'STRESS')
        return
    end
    
    LogPerf('INFO', 'Starting stress tests...', nil, 'STRESS')
    LogPerf('WARN', 'Stress tests are resource intensive and may impact server performance', nil, 'STRESS')
    
    -- Stress test: Rapid-fire calculations
    local stressResults = BenchmarkFunction(
        function()
            local GrowthCalculations = require('server.services.growth_calculations')
            
            for i = 1, 1000 do
                GrowthCalculations.DetermineGrowthStage(math.random(0, 100))
                GrowthCalculations.CalculateFinalReward(
                    {rewards = {amount = 10}, waterTimes = 3, requiresBaseFertilizer = true},
                    {water_count = 2, max_water_times = 3, base_fertilized = true}
                )
            end
        end,
        5,
        'Stress Test (1000 calculations per iteration)',
        'STRESS'
    )
    
    PerfMetrics.stressTest = stressResults
end

-- =======================================
-- NUI PERFORMANCE SIMULATION
-- =======================================

function PerformanceTests.TestNUIPerformance()
    LogPerf('INFO', 'Starting NUI performance simulation...', nil, 'NUI')
    
    -- Simulate plant status requests (like NUI would make)
    local nuiResults = BenchmarkFunction(
        function()
            -- Simulate getting plant status for 5 different plants
            for plantId = 1, 5 do
                local result = MySQL.query.await([[
                    SELECT 
                        plant_id, plant_type, growth_stage, growth_progress,
                        water_count, max_water_times, base_fertilized, 
                        fertilizer_type, CAST(time_left AS UNSIGNED) as time_left
                    FROM bcc_farming 
                    WHERE plant_id = ?
                ]], {plantId})
                
                -- Simulate growth calculations for each plant
                if #result > 0 then
                    local plant = result[1]
                    local GrowthCalculations = require('server.services.growth_calculations')
                    
                    -- Simulate status calculations
                    GrowthCalculations.DetermineGrowthStage(plant.growth_progress or 0)
                    GrowthCalculations.CanWaterPlant({
                        water_count = plant.water_count or 0,
                        max_water_times = plant.max_water_times or 1,
                        growth_progress = plant.growth_progress or 0
                    })
                end
            end
        end,
        30,
        'NUI Performance Simulation (5 plants per iteration)',
        'NUI'
    )
    
    PerfMetrics.nuiPerformance = nuiResults
end

-- =======================================
-- MAIN PERFORMANCE TEST RUNNER
-- =======================================

function PerformanceTests.RunAllTests()
    LogPerf('INFO', '========================================', nil, 'SYSTEM')
    LogPerf('INFO', 'BCC-Farming v2.5.0 Performance Tests', nil, 'SYSTEM')
    LogPerf('INFO', '========================================', nil, 'SYSTEM')
    
    -- Reset metrics
    PerfMetrics = {
        exportTimes = {},
        calculationTimes = {},
        databaseTimes = {},
        memoryUsage = {},
        cpuUsage = {}
    }
    
    local totalStartTime = GetGameTimer()
    
    -- Run all performance tests
    PerformanceTests.TestExportPerformance()
    PerformanceTests.TestCalculationPerformance()
    PerformanceTests.TestDatabasePerformance()
    PerformanceTests.TestMemoryUsage()
    PerformanceTests.TestNUIPerformance()
    PerformanceTests.TestHighLoad()
    PerformanceTests.TestStress()
    
    local totalEndTime = GetGameTimer()
    local totalDuration = totalEndTime - totalStartTime
    
    -- Generate performance report
    PerformanceTests.GenerateReport(totalDuration)
    
    return PerfMetrics
end

function PerformanceTests.GenerateReport(totalDuration)
    LogPerf('INFO', '========================================', nil, 'RESULTS')
    LogPerf('INFO', 'Performance Test Results', nil, 'RESULTS')
    LogPerf('INFO', '========================================', nil, 'RESULTS')
    
    LogPerf('INFO', string.format("Total test duration: %dms", totalDuration), nil, 'RESULTS')
    
    -- Export performance summary
    if next(PerfMetrics.exportTimes) then
        LogPerf('INFO', 'Export Performance Summary:', nil, 'RESULTS')
        for exportName, metrics in pairs(PerfMetrics.exportTimes) do
            LogPerf('INFO', string.format("  %s: avg %dms, max %dms", 
                exportName, metrics.avg, metrics.max), nil, 'RESULTS')
        end
    end
    
    -- Calculation performance summary
    if next(PerfMetrics.calculationTimes) then
        LogPerf('INFO', 'Calculation Performance Summary:', nil, 'RESULTS')
        for calcName, metrics in pairs(PerfMetrics.calculationTimes) do
            if metrics then
                LogPerf('INFO', string.format("  %s: avg %dms, max %dms", 
                    calcName, metrics.avg, metrics.max), nil, 'RESULTS')
            end
        end
    end
    
    -- Database performance summary
    if next(PerfMetrics.databaseTimes) then
        LogPerf('INFO', 'Database Performance Summary:', nil, 'RESULTS')
        for queryName, metrics in pairs(PerfMetrics.databaseTimes) do
            if metrics then
                LogPerf('INFO', string.format("  %s: avg %dms, max %dms", 
                    queryName, metrics.avg, metrics.max), nil, 'RESULTS')
            end
        end
    end
    
    -- Memory usage summary
    if PerfMetrics.memoryUsage.increase then
        LogPerf('INFO', string.format("Memory Usage: +%.2fMB during tests", 
            PerfMetrics.memoryUsage.increase), nil, 'RESULTS')
    end
    
    -- Overall assessment
    LogPerf('INFO', '========================================', nil, 'RESULTS')
    LogPerf('INFO', '🚀 Performance testing completed!', nil, 'RESULTS')
    LogPerf('INFO', 'Review results above for optimization opportunities', nil, 'RESULTS')
    LogPerf('INFO', '========================================', nil, 'RESULTS')
end

-- =======================================
-- COMMAND REGISTRATION
-- =======================================

RegisterCommand('farming-perf-all', function()
    PerformanceTests.RunAllTests()
end, true)

RegisterCommand('farming-perf-exports', function()
    PerformanceTests.TestExportPerformance()
    LogPerf('INFO', 'Export performance tests completed', nil, 'RESULTS')
end, true)

RegisterCommand('farming-perf-calc', function()
    PerformanceTests.TestCalculationPerformance()
    LogPerf('INFO', 'Calculation performance tests completed', nil, 'RESULTS')
end, true)

RegisterCommand('farming-perf-db', function()
    PerformanceTests.TestDatabasePerformance()
    LogPerf('INFO', 'Database performance tests completed', nil, 'RESULTS')
end, true)

RegisterCommand('farming-perf-memory', function()
    PerformanceTests.TestMemoryUsage()
    LogPerf('INFO', 'Memory usage tests completed', nil, 'RESULTS')
end, true)

return PerformanceTests