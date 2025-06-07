-- =======================================
-- BCC-Farming Test Runner v2.5.0
-- Main test orchestrator for comprehensive system validation
-- =======================================

local TestRunner = {}

-- Test modules will be loaded globally by FiveM/RedM

-- Test runner configuration
local RUNNER_CONFIG = {
    runAllTests = true,
    generateFullReport = true,
    saveReportToFile = false, -- Would need file writing implementation
    exitOnCriticalFailure = false,
    verboseLogging = true
}

-- Consolidated results
local ConsolidatedResults = {
    startTime = 0,
    endTime = 0,
    totalDuration = 0,
    testCategories = {},
    overallStatus = 'UNKNOWN',
    criticalIssues = {},
    recommendations = {}
}

-- =======================================
-- UTILITY FUNCTIONS
-- =======================================

local function LogRunner(level, message, category)
    local timestamp = os.date('%H:%M:%S')
    local prefix = string.format("[%s][RUNNER]", timestamp)
    
    if category then
        prefix = string.format("%s[%s]", prefix, category)
    end
    
    if level == 'PASS' then
        print(string.format("^2%s^7 %s", prefix, message))
    elseif level == 'FAIL' then
        print(string.format("^1%s^7 %s", prefix, message))
    elseif level == 'WARN' then
        print(string.format("^3%s^7 %s", prefix, message))
    elseif level == 'INFO' then
        print(string.format("^6%s^7 %s", prefix, message))
    else
        print(string.format("^7%s %s", prefix, message))
    end
end

local function ExecuteTestCategory(name, testFunc, description, critical)
    LogRunner('INFO', string.format("Starting %s...", description), name)
    
    local categoryStartTime = GetGameTimer()
    local success, results = pcall(testFunc)
    local categoryEndTime = GetGameTimer()
    local categoryDuration = categoryEndTime - categoryStartTime
    
    local categoryResult = {
        name = name,
        description = description,
        duration = categoryDuration,
        success = success,
        critical = critical or false,
        results = results,
        status = 'UNKNOWN'
    }
    
    if success then
        if results then
            -- Analyze results based on the type of test
            if results.passed ~= nil and results.failed ~= nil then
                local total = results.passed + results.failed
                local successRate = total > 0 and (results.passed / total) * 100 or 0
                
                if results.failed == 0 then
                    categoryResult.status = 'PASS'
                    LogRunner('PASS', string.format("%s completed successfully (%d/%d passed, %.1f%%)", 
                        description, results.passed, total, successRate), name)
                elseif successRate >= 80 then
                    categoryResult.status = 'WARN'
                    LogRunner('WARN', string.format("%s completed with warnings (%d/%d passed, %.1f%%)", 
                        description, results.passed, total, successRate), name)
                else
                    categoryResult.status = 'FAIL'
                    LogRunner('FAIL', string.format("%s failed (%d/%d passed, %.1f%%)", 
                        description, results.passed, total, successRate), name)
                    if critical then
                        table.insert(ConsolidatedResults.criticalIssues, {
                            category = name,
                            message = string.format("%s critical failure", description),
                            details = results.errors or {}
                        })
                    end
                end
            else
                categoryResult.status = 'PASS'
                LogRunner('PASS', string.format("%s completed successfully", description), name)
            end
        else
            categoryResult.status = 'PASS'
            LogRunner('PASS', string.format("%s completed successfully", description), name)
        end
    else
        categoryResult.status = 'FAIL'
        LogRunner('FAIL', string.format("%s failed with error: %s", description, tostring(results)), name)
        if critical then
            table.insert(ConsolidatedResults.criticalIssues, {
                category = name,
                message = string.format("%s critical error", description),
                details = {tostring(results)}
            })
        end
    end
    
    ConsolidatedResults.testCategories[name] = categoryResult
    
    -- Check if we should exit on critical failure
    if critical and categoryResult.status == 'FAIL' and RUNNER_CONFIG.exitOnCriticalFailure then
        LogRunner('FAIL', 'Critical test failure detected - stopping test execution', name)
        return false
    end
    
    return true
end

-- =======================================
-- INDIVIDUAL TEST CATEGORY WRAPPERS
-- =======================================

local function RunConfigurationValidation()
    return ConfigValidator.ValidateFullConfiguration()
end

local function RunMigrationValidation()
    return MigrationValidator.ValidateFullMigration()
end

local function RunSystemTests()
    return TestSuite.RunAllTests()
end

local function RunPerformanceTests()
    return PerformanceTests.RunAllTests()
end

-- =======================================
-- PRE-FLIGHT CHECKS
-- =======================================

function TestRunner.RunPreFlightChecks()
    LogRunner('INFO', 'Running pre-flight checks...', 'PREFLIGHT')
    
    local preflightResults = {
        passed = 0,
        failed = 0,
        checks = {}
    }
    
    -- Check 1: Database connectivity
    local dbSuccess = pcall(function()
        MySQL.scalar.await('SELECT 1')
    end)
    
    if dbSuccess then
        preflightResults.passed = preflightResults.passed + 1
        LogRunner('PASS', 'Database connectivity check passed', 'PREFLIGHT')
    else
        preflightResults.failed = preflightResults.failed + 1
        LogRunner('FAIL', 'Database connectivity check failed', 'PREFLIGHT')
        table.insert(preflightResults.checks, 'Database connectivity failed')
    end
    
    -- Check 2: Required tables exist
    local tablesSuccess = pcall(function()
        local result = MySQL.scalar.await("SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'bcc_farming'")
        return result > 0
    end)
    
    if tablesSuccess then
        preflightResults.passed = preflightResults.passed + 1
        LogRunner('PASS', 'Required tables check passed', 'PREFLIGHT')
    else
        preflightResults.failed = preflightResults.failed + 1
        LogRunner('FAIL', 'Required tables check failed', 'PREFLIGHT')
        table.insert(preflightResults.checks, 'bcc_farming table not found')
    end
    
    -- Check 3: Configuration loaded
    if Plants ~= nil and type(Plants) == "table" and #Plants > 0 then
        preflightResults.passed = preflightResults.passed + 1
        LogRunner('PASS', 'Configuration loaded check passed', 'PREFLIGHT')
    else
        preflightResults.failed = preflightResults.failed + 1
        LogRunner('FAIL', 'Configuration loaded check failed', 'PREFLIGHT')
        table.insert(preflightResults.checks, 'Plants configuration not loaded')
    end
    
    -- Check 4: Core modules available
    local modulesSuccess = pcall(function()
        require('server.services.growth_calculations')
        return true
    end)
    
    if modulesSuccess then
        preflightResults.passed = preflightResults.passed + 1
        LogRunner('PASS', 'Core modules check passed', 'PREFLIGHT')
    else
        preflightResults.failed = preflightResults.failed + 1
        LogRunner('FAIL', 'Core modules check failed', 'PREFLIGHT')
        table.insert(preflightResults.checks, 'Growth calculations module not available')
    end
    
    return preflightResults
end

-- =======================================
-- MAIN TEST EXECUTION
-- =======================================

function TestRunner.RunFullTestSuite()
    LogRunner('INFO', '==========================================')
    LogRunner('INFO', '🚀 BCC-Farming v2.5.0 Full Test Suite')
    LogRunner('INFO', '==========================================')
    
    ConsolidatedResults.startTime = GetGameTimer()
    
    -- Run pre-flight checks
    local preflightResults = TestRunner.RunPreFlightChecks()
    if preflightResults.failed > 0 then
        LogRunner('FAIL', string.format("Pre-flight checks failed (%d issues)", preflightResults.failed))
        if RUNNER_CONFIG.exitOnCriticalFailure then
            LogRunner('FAIL', 'Stopping execution due to pre-flight failures')
            return ConsolidatedResults
        end
    else
        LogRunner('PASS', 'All pre-flight checks passed - proceeding with tests')
    end
    
    -- Test execution order (from most critical to least critical)
    local testQueue = {
        {
            name = 'CONFIG',
            func = RunConfigurationValidation,
            description = 'Configuration Validation',
            critical = true
        },
        {
            name = 'MIGRATION',
            func = RunMigrationValidation,
            description = 'Database Migration Validation',
            critical = true
        },
        {
            name = 'SYSTEM',
            func = RunSystemTests,
            description = 'System Functionality Tests',
            critical = false
        },
        {
            name = 'PERFORMANCE',
            func = RunPerformanceTests,
            description = 'Performance Tests',
            critical = false
        }
    }
    
    -- Execute tests in order
    local allTestsPassed = true
    for _, test in pairs(testQueue) do
        local success = ExecuteTestCategory(test.name, test.func, test.description, test.critical)
        if not success then
            allTestsPassed = false
            break
        end
        
        -- Brief pause between test categories
        Wait(1000)
    end
    
    ConsolidatedResults.endTime = GetGameTimer()
    ConsolidatedResults.totalDuration = ConsolidatedResults.endTime - ConsolidatedResults.startTime
    
    -- Generate comprehensive report
    TestRunner.GenerateConsolidatedReport()
    
    return ConsolidatedResults
end

-- =======================================
-- SPECIFIC TEST RUNNERS
-- =======================================

function TestRunner.RunQuickValidation()
    LogRunner('INFO', 'Running quick validation suite...')
    
    ConsolidatedResults.startTime = GetGameTimer()
    
    -- Run only critical tests
    ExecuteTestCategory('CONFIG', RunConfigurationValidation, 'Configuration Validation', true)
    ExecuteTestCategory('MIGRATION', RunMigrationValidation, 'Migration Validation', true)
    
    ConsolidatedResults.endTime = GetGameTimer()
    ConsolidatedResults.totalDuration = ConsolidatedResults.endTime - ConsolidatedResults.startTime
    
    TestRunner.GenerateQuickReport()
    return ConsolidatedResults
end

function TestRunner.RunProductionReadinessCheck()
    LogRunner('INFO', 'Running production readiness check...')
    
    ConsolidatedResults.startTime = GetGameTimer()
    
    -- Run all tests except performance (for production readiness)
    ExecuteTestCategory('CONFIG', RunConfigurationValidation, 'Configuration Validation', true)
    ExecuteTestCategory('MIGRATION', RunMigrationValidation, 'Migration Validation', true)
    ExecuteTestCategory('SYSTEM', RunSystemTests, 'System Tests', true)
    
    ConsolidatedResults.endTime = GetGameTimer()
    ConsolidatedResults.totalDuration = ConsolidatedResults.endTime - ConsolidatedResults.startTime
    
    TestRunner.GenerateProductionReport()
    return ConsolidatedResults
end

-- =======================================
-- REPORT GENERATION
-- =======================================

function TestRunner.GenerateConsolidatedReport()
    LogRunner('INFO', '==========================================')
    LogRunner('INFO', '📊 Consolidated Test Results')
    LogRunner('INFO', '==========================================')
    
    LogRunner('INFO', string.format("Total test duration: %dms (%.1fs)", 
        ConsolidatedResults.totalDuration, ConsolidatedResults.totalDuration / 1000))
    
    -- Category summary
    local totalCategories = 0
    local passedCategories = 0
    local failedCategories = 0
    local warnCategories = 0
    
    LogRunner('INFO', 'Test Category Results:')
    for categoryName, categoryResult in pairs(ConsolidatedResults.testCategories) do
        totalCategories = totalCategories + 1
        
        local statusIcon = '❓'
        if categoryResult.status == 'PASS' then
            statusIcon = '✅'
            passedCategories = passedCategories + 1
        elseif categoryResult.status == 'FAIL' then
            statusIcon = '❌'
            failedCategories = failedCategories + 1
        elseif categoryResult.status == 'WARN' then
            statusIcon = '⚠️'
            warnCategories = warnCategories + 1
        end
        
        LogRunner('INFO', string.format("  %s %s: %s (%dms)", 
            statusIcon, categoryResult.description, categoryResult.status, categoryResult.duration))
    end
    
    -- Overall assessment
    LogRunner('INFO', '==========================================')
    if failedCategories == 0 and warnCategories == 0 then
        ConsolidatedResults.overallStatus = 'EXCELLENT'
        LogRunner('PASS', '🎉 EXCELLENT! All tests passed perfectly!')
        LogRunner('PASS', '✨ System is ready for production deployment')
    elseif failedCategories == 0 then
        ConsolidatedResults.overallStatus = 'GOOD'
        LogRunner('PASS', '🟢 GOOD! All tests passed with minor warnings')
        LogRunner('WARN', string.format("📋 Review %d warning(s) before production", warnCategories))
    elseif #ConsolidatedResults.criticalIssues == 0 then
        ConsolidatedResults.overallStatus = 'ACCEPTABLE'
        LogRunner('WARN', '🟡 ACCEPTABLE! Some non-critical tests failed')
        LogRunner('WARN', 'Consider fixing issues for optimal performance')
    else
        ConsolidatedResults.overallStatus = 'CRITICAL'
        LogRunner('FAIL', '🔴 CRITICAL ISSUES DETECTED!')
        LogRunner('FAIL', 'System requires immediate attention before deployment')
    end
    
    -- Critical issues summary
    if #ConsolidatedResults.criticalIssues > 0 then
        LogRunner('INFO', '🚨 Critical Issues:')
        for i, issue in pairs(ConsolidatedResults.criticalIssues) do
            LogRunner('FAIL', string.format("  %d. [%s] %s", i, issue.category, issue.message))
        end
    end
    
    -- Recommendations
    TestRunner.GenerateRecommendations()
    
    LogRunner('INFO', '==========================================')
end

function TestRunner.GenerateQuickReport()
    LogRunner('INFO', '📋 Quick Validation Report')
    LogRunner('INFO', '==========================================')
    
    local criticalIssues = #ConsolidatedResults.criticalIssues
    if criticalIssues == 0 then
        LogRunner('PASS', '✅ Quick validation passed - no critical issues')
    else
        LogRunner('FAIL', string.format("❌ Quick validation failed - %d critical issues", criticalIssues))
    end
end

function TestRunner.GenerateProductionReport()
    LogRunner('INFO', '🚀 Production Readiness Report')
    LogRunner('INFO', '==========================================')
    
    local readyForProduction = #ConsolidatedResults.criticalIssues == 0
    local failedCategories = 0
    
    for _, categoryResult in pairs(ConsolidatedResults.testCategories) do
        if categoryResult.status == 'FAIL' then
            failedCategories = failedCategories + 1
        end
    end
    
    if readyForProduction and failedCategories == 0 then
        LogRunner('PASS', '🚀 READY FOR PRODUCTION!')
        LogRunner('PASS', 'All critical systems validated successfully')
    elseif readyForProduction then
        LogRunner('WARN', '⚠️ MOSTLY READY - Minor issues detected')
        LogRunner('WARN', 'Production deployment possible with monitoring')
    else
        LogRunner('FAIL', '🛑 NOT READY FOR PRODUCTION')
        LogRunner('FAIL', 'Critical issues must be resolved first')
    end
end

function TestRunner.GenerateRecommendations()
    LogRunner('INFO', '💡 Recommendations:')
    
    -- Generate recommendations based on test results
    local recommendations = {}
    
    for categoryName, categoryResult in pairs(ConsolidatedResults.testCategories) do
        if categoryResult.status == 'FAIL' then
            table.insert(recommendations, string.format("Fix critical issues in %s", categoryResult.description))
        elseif categoryResult.status == 'WARN' then
            table.insert(recommendations, string.format("Review warnings in %s", categoryResult.description))
        end
    end
    
    if #recommendations == 0 then
        table.insert(recommendations, "System appears to be well-configured!")
        table.insert(recommendations, "Consider running performance tests regularly")
        table.insert(recommendations, "Monitor system performance in production")
    end
    
    for i, recommendation in pairs(recommendations) do
        LogRunner('INFO', string.format("  %d. %s", i, recommendation))
    end
    
    ConsolidatedResults.recommendations = recommendations
end

-- =======================================
-- COMMAND REGISTRATION
-- =======================================

RegisterCommand('farming-test-full', function()
    TestRunner.RunFullTestSuite()
end, true)

RegisterCommand('farming-test-quick', function()
    TestRunner.RunQuickValidation()
end, true)

RegisterCommand('farming-test-production', function()
    TestRunner.RunProductionReadinessCheck()
end, true)

RegisterCommand('farming-test-preflight', function()
    local results = TestRunner.RunPreFlightChecks()
    LogRunner('INFO', string.format("Pre-flight checks completed: %d passed, %d failed", 
        results.passed, results.failed))
end, true)

return TestRunner