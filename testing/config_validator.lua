-- =======================================
-- BCC-Farming Configuration Validator v2.5.0
-- Validates plant configurations for v2.5.0 compatibility
-- =======================================

local ConfigValidator = {}

-- Validation results
local ValidationResults = {
    passed = 0,
    failed = 0,
    warnings = 0,
    details = {},
    suggestions = {}
}

-- =======================================
-- UTILITY FUNCTIONS
-- =======================================

local function LogValidation(type, message, suggestion)
    local timestamp = os.date('%H:%M:%S')
    local prefix = string.format("[%s][CONFIG][%s]", timestamp, type)
    
    if type == 'PASS' then
        ValidationResults.passed = ValidationResults.passed + 1
        print(string.format("^2%s^7 %s", prefix, message))
    elseif type == 'FAIL' then
        ValidationResults.failed = ValidationResults.failed + 1
        print(string.format("^1%s^7 %s", prefix, message))
    elseif type == 'WARN' then
        ValidationResults.warnings = ValidationResults.warnings + 1
        print(string.format("^3%s^7 %s", prefix, message))
    else
        print(string.format("^6%s^7 %s", prefix, message))
    end
    
    table.insert(ValidationResults.details, {
        type = type,
        message = message,
        suggestion = suggestion,
        timestamp = os.time()
    })
    
    if suggestion then
        table.insert(ValidationResults.suggestions, {
            message = message,
            suggestion = suggestion,
            priority = type == 'FAIL' and 'high' or type == 'WARN' and 'medium' or 'low'
        })
    end
end

local function SafeValidate(func, description)
    local success, result = pcall(func)
    if not success then
        LogValidation('FAIL', string.format("%s failed: %s", description, result))
        return false, result
    end
    return true, result
end

-- =======================================
-- BASIC CONFIGURATION VALIDATION
-- =======================================

function ConfigValidator.ValidateBasicConfig()
    LogValidation('INFO', 'Validating basic configuration structure...')
    
    -- Check if Plants table exists
    SafeValidate(function()
        if Plants == nil then
            LogValidation('FAIL', 'Plants configuration table not found', 
                'Ensure Plants table is loaded before running validation')
            return false
        end
        
        if type(Plants) ~= "table" then
            LogValidation('FAIL', 'Plants is not a table', 
                'Plants should be defined as a table containing plant configurations')
            return false
        end
        
        if #Plants == 0 then
            LogValidation('FAIL', 'Plants table is empty', 
                'Add at least one plant configuration to the Plants table')
            return false
        end
        
        LogValidation('PASS', string.format("Plants table found with %d plant configurations", #Plants))
        return true
    end, 'Basic Plants table validation')
    
    -- Check if Config exists
    SafeValidate(function()
        if Config == nil then
            LogValidation('WARN', 'Config table not found', 
                'Some validations may not work without Config table')
        else
            LogValidation('PASS', 'Config table found')
            
            -- Check plantSetup
            if Config.plantSetup then
                LogValidation('PASS', 'Config.plantSetup exists')
                if Config.plantSetup.maxPlants then
                    LogValidation('PASS', string.format("Max plants configured: %d", Config.plantSetup.maxPlants))
                end
            else
                LogValidation('WARN', 'Config.plantSetup not found', 
                    'Plant setup configuration is recommended for proper limits')
            end
        end
        return true
    end, 'Basic Config validation')
end

-- =======================================
-- PLANT CONFIGURATION VALIDATION
-- =======================================

function ConfigValidator.ValidatePlantConfigurations()
    LogValidation('INFO', 'Validating individual plant configurations...')
    
    local requiredFields = {
        'seedName', 'plantName', 'rewards'
    }
    
    local recommendedFields = {
        'waterTimes', 'requiresBaseFertilizer', 'baseFertilizerItem'
    }
    
    for plantIndex, plant in pairs(Plants) do
        local plantName = plant.plantName or string.format("Plant #%d", plantIndex)
        
        SafeValidate(function()
            -- Check required fields
            for _, field in pairs(requiredFields) do
                if plant[field] == nil then
                    LogValidation('FAIL', string.format("%s missing required field '%s'", plantName, field),
                        string.format("Add %s = 'value' to the plant configuration", field))
                else
                    LogValidation('PASS', string.format("%s has required field '%s'", plantName, field))
                end
            end
            
            -- Check recommended fields for v2.5.0
            for _, field in pairs(recommendedFields) do
                if plant[field] == nil then
                    LogValidation('WARN', string.format("%s missing recommended field '%s'", plantName, field),
                        string.format("Consider adding %s for v2.5.0 features", field))
                else
                    LogValidation('PASS', string.format("%s has recommended field '%s'", plantName, field))
                end
            end
            
            return true
        end, string.format("%s basic field validation", plantName))
        
        -- Validate plant props system
        ConfigValidator.ValidatePlantProps(plant, plantName)
        
        -- Validate watering configuration
        ConfigValidator.ValidateWateringConfig(plant, plantName)
        
        -- Validate fertilizer configuration
        ConfigValidator.ValidateFertilizerConfig(plant, plantName)
        
        -- Validate rewards configuration
        ConfigValidator.ValidateRewardsConfig(plant, plantName)
    end
end

-- =======================================
-- PLANT PROPS VALIDATION (v2.5.0)
-- =======================================

function ConfigValidator.ValidatePlantProps(plant, plantName)
    SafeValidate(function()
        -- Check for v2.5.0 plantProps
        if plant.plantProps then
            if type(plant.plantProps) ~= "table" then
                LogValidation('FAIL', string.format("%s plantProps is not a table", plantName),
                    'plantProps should be a table with stage1, stage2, stage3 keys')
                return false
            end
            
            -- Check for stage props
            local stageCount = 0
            for stage = 1, 3 do
                local stageKey = string.format("stage%d", stage)
                if plant.plantProps[stageKey] then
                    stageCount = stageCount + 1
                    if type(plant.plantProps[stageKey]) == "string" then
                        LogValidation('PASS', string.format("%s has valid %s prop", plantName, stageKey))
                    else
                        LogValidation('FAIL', string.format("%s %s prop is not a string", plantName, stageKey),
                            string.format("Set %s = 'prop_name' in plantProps", stageKey))
                    end
                end
            end
            
            if stageCount == 0 then
                LogValidation('WARN', string.format("%s plantProps has no stage props", plantName),
                    'Add stage1, stage2, stage3 props for multi-stage growth')
            elseif stageCount < 3 then
                LogValidation('WARN', string.format("%s has only %d stage props", plantName, stageCount),
                    'Consider adding all 3 stage props for complete visual progression')
            else
                LogValidation('PASS', string.format("%s has complete 3-stage prop system", plantName))
            end
            
        else
            -- Check for legacy prop system
            if plant.plantProp then
                if type(plant.plantProp) == "string" then
                    LogValidation('PASS', string.format("%s has legacy plantProp (backward compatible)", plantName))
                    LogValidation('WARN', string.format("%s using legacy prop system", plantName),
                        'Consider upgrading to plantProps with stage1, stage2, stage3 for v2.5.0 features')
                else
                    LogValidation('FAIL', string.format("%s plantProp is not a string", plantName),
                        'plantProp should be a string with the prop model name')
                end
            else
                LogValidation('FAIL', string.format("%s has no prop configuration", plantName),
                    'Add either plantProps (v2.5.0) or plantProp (legacy) configuration')
            end
        end
        
        return true
    end, string.format("%s props validation", plantName))
end

-- =======================================
-- WATERING CONFIGURATION VALIDATION
-- =======================================

function ConfigValidator.ValidateWateringConfig(plant, plantName)
    SafeValidate(function()
        if plant.waterTimes then
            if type(plant.waterTimes) ~= "number" then
                LogValidation('FAIL', string.format("%s waterTimes is not a number", plantName),
                    'waterTimes should be a number (e.g., waterTimes = 3)')
            elseif plant.waterTimes < 1 or plant.waterTimes > 10 then
                LogValidation('WARN', string.format("%s waterTimes (%d) outside recommended range", plantName, plant.waterTimes),
                    'waterTimes should be between 1 and 10 for optimal gameplay')
            else
                LogValidation('PASS', string.format("%s has valid waterTimes (%d)", plantName, plant.waterTimes))
            end
        else
            LogValidation('WARN', string.format("%s has no waterTimes configured", plantName),
                'Add waterTimes = 1 (or higher) for v2.5.0 multi-watering system')
        end
        
        return true
    end, string.format("%s watering validation", plantName))
end

-- =======================================
-- FERTILIZER CONFIGURATION VALIDATION
-- =======================================

function ConfigValidator.ValidateFertilizerConfig(plant, plantName)
    SafeValidate(function()
        -- Check base fertilizer requirement
        if plant.requiresBaseFertilizer ~= nil then
            if type(plant.requiresBaseFertilizer) ~= "boolean" then
                LogValidation('FAIL', string.format("%s requiresBaseFertilizer is not boolean", plantName),
                    'requiresBaseFertilizer should be true or false')
            else
                LogValidation('PASS', string.format("%s has valid requiresBaseFertilizer (%s)", 
                    plantName, tostring(plant.requiresBaseFertilizer)))
                
                -- If fertilizer is required, check for item specification
                if plant.requiresBaseFertilizer and not plant.baseFertilizerItem then
                    LogValidation('WARN', string.format("%s requires fertilizer but no item specified", plantName),
                        'Add baseFertilizerItem = "fertilizer" (or custom item name)')
                elseif plant.requiresBaseFertilizer and plant.baseFertilizerItem then
                    LogValidation('PASS', string.format("%s has fertilizer item specified", plantName))
                end
            end
        else
            LogValidation('WARN', string.format("%s has no fertilizer requirement configured", plantName),
                'Add requiresBaseFertilizer = true/false for v2.5.0 fertilizer system')
        end
        
        -- Check fertilizer item
        if plant.baseFertilizerItem then
            if type(plant.baseFertilizerItem) ~= "string" then
                LogValidation('FAIL', string.format("%s baseFertilizerItem is not a string", plantName),
                    'baseFertilizerItem should be the item name (e.g., "fertilizer")')
            else
                LogValidation('PASS', string.format("%s has valid fertilizer item", plantName))
            end
        end
        
        return true
    end, string.format("%s fertilizer validation", plantName))
end

-- =======================================
-- REWARDS CONFIGURATION VALIDATION
-- =======================================

function ConfigValidator.ValidateRewardsConfig(plant, plantName)
    SafeValidate(function()
        if not plant.rewards then
            LogValidation('FAIL', string.format("%s has no rewards configuration", plantName),
                'Add rewards = { amount = X, items = {...} } to the plant configuration')
            return false
        end
        
        if type(plant.rewards) ~= "table" then
            LogValidation('FAIL', string.format("%s rewards is not a table", plantName),
                'rewards should be a table containing amount and items')
            return false
        end
        
        -- Check rewards amount
        if not plant.rewards.amount then
            LogValidation('WARN', string.format("%s rewards has no amount", plantName),
                'Add amount = X to rewards for base reward calculation')
        elseif type(plant.rewards.amount) ~= "number" then
            LogValidation('FAIL', string.format("%s rewards amount is not a number", plantName),
                'rewards.amount should be a number')
        elseif plant.rewards.amount <= 0 then
            LogValidation('WARN', string.format("%s rewards amount is zero or negative", plantName),
                'rewards.amount should be positive for meaningful rewards')
        else
            LogValidation('PASS', string.format("%s has valid rewards amount (%d)", plantName, plant.rewards.amount))
        end
        
        -- Check rewards items
        if not plant.rewards.items then
            LogValidation('WARN', string.format("%s rewards has no items", plantName),
                'Add items = {{item = "item_name", count = X}} to rewards')
        elseif type(plant.rewards.items) ~= "table" then
            LogValidation('FAIL', string.format("%s rewards items is not a table", plantName),
                'rewards.items should be a table of item definitions')
        elseif #plant.rewards.items == 0 then
            LogValidation('WARN', string.format("%s rewards items table is empty", plantName),
                'Add at least one item to rewards.items')
        else
            LogValidation('PASS', string.format("%s has %d reward items configured", plantName, #plant.rewards.items))
            
            -- Validate individual items
            for itemIndex, item in pairs(plant.rewards.items) do
                if type(item) ~= "table" then
                    LogValidation('FAIL', string.format("%s reward item #%d is not a table", plantName, itemIndex),
                        'Each reward item should be {item = "name", count = X}')
                elseif not item.item then
                    LogValidation('FAIL', string.format("%s reward item #%d has no item name", plantName, itemIndex),
                        'Add item = "item_name" to reward item')
                elseif not item.count then
                    LogValidation('WARN', string.format("%s reward item #%d has no count", plantName, itemIndex),
                        'Add count = X to reward item for quantity')
                end
            end
        end
        
        return true
    end, string.format("%s rewards validation", plantName))
end

-- =======================================
-- COMPATIBILITY VALIDATION
-- =======================================

function ConfigValidator.ValidateCompatibility()
    LogValidation('INFO', 'Validating v2.5.0 compatibility...')
    
    SafeValidate(function()
        local v25Compatible = 0
        local legacyOnly = 0
        local incompatible = 0
        
        for _, plant in pairs(Plants) do
            local hasV25Features = false
            local hasLegacyFeatures = false
            
            -- Check for v2.5.0 features
            if plant.plantProps or plant.waterTimes or plant.requiresBaseFertilizer then
                hasV25Features = true
            end
            
            -- Check for legacy features
            if plant.plantProp then
                hasLegacyFeatures = true
            end
            
            if hasV25Features and hasLegacyFeatures then
                v25Compatible = v25Compatible + 1
            elseif hasV25Features then
                v25Compatible = v25Compatible + 1
            elseif hasLegacyFeatures then
                legacyOnly = legacyOnly + 1
            else
                incompatible = incompatible + 1
            end
        end
        
        LogValidation('INFO', string.format("Compatibility analysis: %d v2.5.0 compatible, %d legacy only, %d incompatible", 
            v25Compatible, legacyOnly, incompatible))
        
        if incompatible > 0 then
            LogValidation('FAIL', string.format("%d plants are incompatible", incompatible),
                'Update incompatible plants with required fields')
        end
        
        if legacyOnly > 0 then
            LogValidation('WARN', string.format("%d plants use legacy configuration only", legacyOnly),
                'Consider upgrading to v2.5.0 features for enhanced functionality')
        end
        
        if v25Compatible == #Plants then
            LogValidation('PASS', 'All plants are v2.5.0 compatible!')
        end
        
        return true
    end, 'Compatibility analysis')
end

-- =======================================
-- OPTIMIZATION SUGGESTIONS
-- =======================================

function ConfigValidator.GenerateOptimizationSuggestions()
    LogValidation('INFO', 'Generating optimization suggestions...')
    
    local suggestions = {}
    
    -- Analyze watering configurations
    local wateringStats = {total = 0, withWaterTimes = 0, avgWaterTimes = 0}
    local totalWaterTimes = 0
    
    for _, plant in pairs(Plants) do
        wateringStats.total = wateringStats.total + 1
        if plant.waterTimes then
            wateringStats.withWaterTimes = wateringStats.withWaterTimes + 1
            totalWaterTimes = totalWaterTimes + plant.waterTimes
        end
    end
    
    if wateringStats.withWaterTimes > 0 then
        wateringStats.avgWaterTimes = totalWaterTimes / wateringStats.withWaterTimes
        
        if wateringStats.avgWaterTimes > 5 then
            table.insert(suggestions, {
                type = 'optimization',
                message = 'Average waterTimes is high, consider balancing for gameplay',
                suggestion = 'High watering requirements may be tedious for players'
            })
        end
    end
    
    -- Analyze fertilizer requirements
    local fertilizerStats = {total = 0, required = 0, optional = 0}
    
    for _, plant in pairs(Plants) do
        fertilizerStats.total = fertilizerStats.total + 1
        if plant.requiresBaseFertilizer == true then
            fertilizerStats.required = fertilizerStats.required + 1
        elseif plant.requiresBaseFertilizer == false then
            fertilizerStats.optional = fertilizerStats.optional + 1
        end
    end
    
    if fertilizerStats.required == fertilizerStats.total then
        table.insert(suggestions, {
            type = 'balance',
            message = 'All plants require fertilizer - consider making some optional',
            suggestion = 'Mixed requirements create more interesting gameplay choices'
        })
    end
    
    -- Analyze prop configurations
    local propStats = {v25Props = 0, legacyProps = 0, noProps = 0}
    
    for _, plant in pairs(Plants) do
        if plant.plantProps then
            propStats.v25Props = propStats.v25Props + 1
        elseif plant.plantProp then
            propStats.legacyProps = propStats.legacyProps + 1
        else
            propStats.noProps = propStats.noProps + 1
        end
    end
    
    if propStats.legacyProps > 0 and propStats.v25Props > 0 then
        table.insert(suggestions, {
            type = 'consistency',
            message = 'Mixed prop systems detected',
            suggestion = 'Consider upgrading all plants to v2.5.0 plantProps for consistency'
        })
    end
    
    -- Display suggestions
    if #suggestions > 0 then
        LogValidation('INFO', 'Optimization suggestions:')
        for i, suggestion in pairs(suggestions) do
            LogValidation('INFO', string.format("  %d. [%s] %s", i, suggestion.type:upper(), suggestion.message))
            if suggestion.suggestion then
                LogValidation('INFO', string.format("     → %s", suggestion.suggestion))
            end
        end
    else
        LogValidation('PASS', 'No optimization suggestions - configuration looks good!')
    end
end

-- =======================================
-- MAIN VALIDATION RUNNER
-- =======================================

function ConfigValidator.ValidateFullConfiguration()
    LogValidation('INFO', '========================================')
    LogValidation('INFO', 'BCC-Farming v2.5.0 Configuration Validator')
    LogValidation('INFO', '========================================')
    
    -- Reset validation results
    ValidationResults = {
        passed = 0,
        failed = 0,
        warnings = 0,
        details = {},
        suggestions = {}
    }
    
    local startTime = GetGameTimer()
    
    -- Run all validations
    ConfigValidator.ValidateBasicConfig()
    ConfigValidator.ValidatePlantConfigurations()
    ConfigValidator.ValidateCompatibility()
    ConfigValidator.GenerateOptimizationSuggestions()
    
    local endTime = GetGameTimer()
    local duration = endTime - startTime
    
    -- Generate report
    ConfigValidator.GenerateReport(duration)
    
    return ValidationResults
end

function ConfigValidator.GenerateReport(duration)
    LogValidation('INFO', '========================================')
    LogValidation('INFO', 'Configuration Validation Results')
    LogValidation('INFO', '========================================')
    
    local total = ValidationResults.passed + ValidationResults.failed
    LogValidation('INFO', string.format("Total Checks: %d", total))
    LogValidation('INFO', string.format("Passed: %d", ValidationResults.passed))
    LogValidation('INFO', string.format("Failed: %d", ValidationResults.failed))
    LogValidation('INFO', string.format("Warnings: %d", ValidationResults.warnings))
    LogValidation('INFO', string.format("Validation Time: %dms", duration))
    
    if ValidationResults.failed == 0 then
        LogValidation('PASS', '🎉 Configuration validation completed successfully!')
        if ValidationResults.warnings == 0 then
            LogValidation('PASS', 'Perfect configuration - ready for production!')
        else
            LogValidation('WARN', string.format("Configuration ready with %d minor warnings", ValidationResults.warnings))
        end
    else
        LogValidation('FAIL', '❌ Configuration validation found issues')
        LogValidation('FAIL', 'Please fix failed validations before proceeding')
    end
    
    -- Show top priority suggestions
    local highPrioritySuggestions = {}
    for _, suggestion in pairs(ValidationResults.suggestions) do
        if suggestion.priority == 'high' then
            table.insert(highPrioritySuggestions, suggestion)
        end
    end
    
    if #highPrioritySuggestions > 0 then
        LogValidation('INFO', 'High Priority Fixes:')
        for i, suggestion in pairs(highPrioritySuggestions) do
            LogValidation('FAIL', string.format("  %d. %s", i, suggestion.suggestion))
        end
    end
    
    LogValidation('INFO', '========================================')
end

-- =======================================
-- COMMAND REGISTRATION
-- =======================================

RegisterCommand('farming-validate-config', function()
    ConfigValidator.ValidateFullConfiguration()
end, true)

RegisterCommand('farming-validate-plants', function()
    ConfigValidator.ValidatePlantConfigurations()
    LogValidation('INFO', string.format("Plant validation: %d passed, %d failed, %d warnings", 
        ValidationResults.passed, ValidationResults.failed, ValidationResults.warnings))
end, true)

RegisterCommand('farming-validate-compatibility', function()
    ConfigValidator.ValidateCompatibility()
    LogValidation('INFO', string.format("Compatibility validation: %d passed, %d failed, %d warnings", 
        ValidationResults.passed, ValidationResults.failed, ValidationResults.warnings))
end, true)

return ConfigValidator