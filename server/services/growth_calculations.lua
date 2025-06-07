-- BCC-Farming Enhanced Growth Calculation System v2.0
-- Multi-Stage Growth, Multi-Watering & Base Fertilizer Logic

local GrowthCalculations = {}

-- ===========================================
-- GROWTH PROGRESS CALCULATIONS
-- ===========================================

-- Calculate current growth progress as percentage
function GrowthCalculations.CalculateGrowthProgress(timeLeft, totalGrowthTime)
    if not timeLeft or not totalGrowthTime or totalGrowthTime <= 0 then
        return 100.0
    end
    
    local timeLeftNum = tonumber(timeLeft) or 0
    local totalTimeNum = tonumber(totalGrowthTime) or 1
    
    local elapsed = totalTimeNum - timeLeftNum
    local progress = (elapsed / totalTimeNum) * 100
    
    -- Ensure progress is between 0 and 100
    return math.min(100, math.max(0, progress))
end

-- Determine growth stage based on progress
function GrowthCalculations.GetGrowthStage(progress)
    if progress <= 30 then
        return 1, "Seedling"
    elseif progress <= 60 then
        return 2, "Young Plant"
    else
        return 3, "Mature Plant"
    end
end

-- Check if plant should transition to next stage
function GrowthCalculations.ShouldTransitionStage(currentStage, progress)
    local newStage = GrowthCalculations.GetGrowthStage(progress)
    return newStage ~= currentStage, newStage
end

-- ===========================================
-- WATERING SYSTEM CALCULATIONS
-- ===========================================

-- Calculate current watering phase based on growth progress
function GrowthCalculations.GetCurrentWateringPhase(progress, maxWaterTimes)
    if maxWaterTimes <= 1 then
        return 1
    end
    
    -- Distribute watering phases evenly across growth cycle
    local phaseSize = 100 / maxWaterTimes
    local currentPhase = math.ceil(progress / phaseSize)
    
    return math.min(currentPhase, maxWaterTimes)
end

-- Check if plant can be watered at current growth stage
function GrowthCalculations.CanWaterPlant(plantData)
    local progress = plantData.growth_progress or 0
    local currentWaterCount = plantData.water_count or 0
    local maxWaterTimes = plantData.max_water_times or 1
    
    -- Can't water if already at max
    if currentWaterCount >= maxWaterTimes then
        return false, "Plant has been watered maximum times"
    end
    
    -- Calculate expected watering phase
    local expectedPhase = GrowthCalculations.GetCurrentWateringPhase(progress, maxWaterTimes)
    
    -- Can water if we're behind on waterings for current phase
    if currentWaterCount < expectedPhase then
        return true, "Plant needs watering for current growth phase"
    end
    
    return false, "Plant doesn't need watering yet"
end

-- Calculate watering efficiency (percentage of optimal watering)
function GrowthCalculations.CalculateWateringEfficiency(waterCount, maxWaterTimes)
    if maxWaterTimes <= 0 then
        return 1.0
    end
    
    return math.min(1.0, waterCount / maxWaterTimes)
end

-- ===========================================
-- FERTILIZER SYSTEM CALCULATIONS
-- ===========================================

-- Check if base fertilizer is required for plant type
function GrowthCalculations.RequiresBaseFertilizer(plantConfig)
    return plantConfig.requiresBaseFertilizer == true
end

-- Calculate fertilizer multiplier for rewards
function GrowthCalculations.CalculateFertilizerMultiplier(plantConfig, plantData)
    local multiplier = 1.0
    
    -- Check if base fertilizer is required but not applied
    if GrowthCalculations.RequiresBaseFertilizer(plantConfig) then
        if not plantData.base_fertilized then
            multiplier = 0.7 -- 30% penalty for no base fertilizer
        end
    end
    
    return multiplier
end

-- Calculate time reduction from enhanced fertilizers
function GrowthCalculations.CalculateTimeReduction(fertilizerType)
    if not fertilizerType then
        return 0.0
    end
    
    -- Check enhanced fertilizers from config
    if FertilizerConfig and FertilizerConfig.enhancedFertilizers then
        for _, fertilizer in pairs(FertilizerConfig.enhancedFertilizers) do
            if fertilizer.fertName == fertilizerType then
                return fertilizer.fertTimeReduction or 0.0
            end
        end
    end
    
    -- Fallback to original config if available
    if Config and Config.fertilizerSetup then
        for _, fertilizer in pairs(Config.fertilizerSetup) do
            if fertilizer.fertName == fertilizerType then
                return fertilizer.fertTimeReduction or 0.0
            end
        end
    end
    
    return 0.0
end

-- ===========================================
-- REWARD CALCULATIONS
-- ===========================================

-- Calculate final reward amount based on care quality
function GrowthCalculations.CalculateFinalReward(plantConfig, plantData)
    local baseReward = 0
    
    -- Get base reward from plant config
    if plantConfig.rewards and #plantConfig.rewards > 0 then
        baseReward = plantConfig.rewards[1].amount or 0
    end
    
    if baseReward <= 0 then
        return 0
    end
    
    -- Calculate watering efficiency
    local wateringEfficiency = GrowthCalculations.CalculateWateringEfficiency(
        plantData.water_count or 0,
        plantData.max_water_times or 1
    )
    
    -- Calculate fertilizer multiplier
    local fertilizerMultiplier = GrowthCalculations.CalculateFertilizerMultiplier(plantConfig, plantData)
    
    -- Apply minimum reward threshold
    local minReward = baseReward * (RewardConfig and RewardConfig.minimumRewardPercentage or 0.10)
    
    -- Calculate final reward
    local finalReward = baseReward * wateringEfficiency * fertilizerMultiplier
    
    -- Apply perfect care bonus
    if wateringEfficiency >= 1.0 and fertilizerMultiplier >= 1.0 then
        local bonus = RewardConfig and RewardConfig.perfectCareBonus or 0.05
        finalReward = finalReward * (1 + bonus)
    end
    
    -- Ensure minimum reward
    finalReward = math.max(finalReward, minReward)
    
    return math.floor(finalReward)
end

-- Calculate detailed reward breakdown for display
function GrowthCalculations.GetRewardBreakdown(plantConfig, plantData)
    local baseReward = 0
    if plantConfig.rewards and #plantConfig.rewards > 0 then
        baseReward = plantConfig.rewards[1].amount or 0
    end
    
    local wateringEfficiency = GrowthCalculations.CalculateWateringEfficiency(
        plantData.water_count or 0,
        plantData.max_water_times or 1
    )
    
    local fertilizerMultiplier = GrowthCalculations.CalculateFertilizerMultiplier(plantConfig, plantData)
    
    local finalReward = GrowthCalculations.CalculateFinalReward(plantConfig, plantData)
    
    return {
        baseReward = baseReward,
        wateringEfficiency = math.floor(wateringEfficiency * 100),
        fertilizerMultiplier = math.floor(fertilizerMultiplier * 100),
        finalReward = finalReward,
        waterCount = plantData.water_count or 0,
        maxWaterTimes = plantData.max_water_times or 1,
        fertilized = plantData.base_fertilized or false
    }
end

-- ===========================================
-- PLANT UPDATE CALCULATIONS
-- ===========================================

-- Update plant growth progress and stage
function GrowthCalculations.UpdatePlantGrowth(plantId)
    local success, plantData = pcall(function()
        return MySQL.query.await('SELECT * FROM bcc_farming WHERE plant_id = ?', { plantId })
    end)
    
    if not success or not plantData or #plantData == 0 then
        return false, "Plant not found"
    end
    
    local plant = plantData[1]
    local progress = GrowthCalculations.CalculateGrowthProgress(
        plant.time_left,
        plant.total_growth_time
    )
    
    local newStage, stageName = GrowthCalculations.GetGrowthStage(progress)
    
    -- Update database
    local updateSuccess = pcall(function()
        MySQL.execute.await([[
            UPDATE bcc_farming 
            SET growth_progress = ?, growth_stage = ?
            WHERE plant_id = ?
        ]], { progress, newStage, plantId })
    end)
    
    if updateSuccess then
        return true, {
            plantId = plantId,
            progress = progress,
            stage = newStage,
            stageName = stageName,
            shouldTransition = plant.growth_stage ~= newStage
        }
    else
        return false, "Database update failed"
    end
end

-- Calculate watering windows for a plant
function GrowthCalculations.CalculateWateringWindows(totalGrowthTime, maxWaterTimes)
    local windows = {}
    
    if maxWaterTimes <= 1 then
        -- Single watering can happen anytime during first 80% of growth
        table.insert(windows, {
            number = 1,
            startTime = 0,
            endTime = totalGrowthTime * 0.8,
            startProgress = 0,
            endProgress = 80
        })
        return windows
    end
    
    -- Distribute watering windows evenly
    local windowSize = 100 / maxWaterTimes
    local overlap = 10 -- 10% overlap between windows
    
    for i = 1, maxWaterTimes do
        local startProgress = (i - 1) * windowSize
        local endProgress = math.min(100, i * windowSize + overlap)
        
        table.insert(windows, {
            number = i,
            startTime = (startProgress / 100) * totalGrowthTime,
            endTime = (endProgress / 100) * totalGrowthTime,
            startProgress = startProgress,
            endProgress = endProgress
        })
    end
    
    return windows
end

-- Check if current time is in any watering window
function GrowthCalculations.IsInWateringWindow(progress, waterCount, maxWaterTimes)
    if maxWaterTimes <= 1 then
        return progress <= 80 and waterCount < 1
    end
    
    local currentPhase = GrowthCalculations.GetCurrentWateringPhase(progress, maxWaterTimes)
    
    -- Can water if we're in or past a phase but haven't watered for it yet
    return waterCount < currentPhase
end

-- ===========================================
-- PLANT STATUS CALCULATIONS
-- ===========================================

-- Get comprehensive plant status
function GrowthCalculations.GetPlantStatus(plantId)
    local success, plantData = pcall(function()
        return MySQL.query.await([[
            SELECT f.*, 
                   CASE 
                       WHEN f.growth_progress <= 30 THEN 'Seedling'
                       WHEN f.growth_progress <= 60 THEN 'Young Plant'
                       ELSE 'Mature Plant'
                   END as stage_name
            FROM bcc_farming f 
            WHERE f.plant_id = ?
        ]], { plantId })
    end)
    
    if not success or not plantData or #plantData == 0 then
        return nil
    end
    
    local plant = plantData[1]
    
    -- Find plant config
    local plantConfig = nil
    for _, config in pairs(Plants) do
        if config.seedName == plant.plant_type then
            plantConfig = config
            break
        end
    end
    
    if not plantConfig then
        return nil
    end
    
    -- Calculate comprehensive status
    local canWater, waterReason = GrowthCalculations.CanWaterPlant(plant)
    local rewardBreakdown = GrowthCalculations.GetRewardBreakdown(plantConfig, plant)
    local isReady = plant.growth_progress >= 100 or (tonumber(plant.time_left) <= 0 and plant.water_count > 0)
    
    return {
        plantId = plantId,
        plantType = plant.plant_type,
        plantName = plantConfig.plantName,
        
        -- Growth status
        growthProgress = plant.growth_progress,
        growthStage = plant.growth_stage,
        stageName = plant.stage_name,
        timeLeft = tonumber(plant.time_left) or 0,
        
        -- Watering status
        waterCount = plant.water_count,
        maxWaterTimes = plant.max_water_times,
        canWater = canWater,
        waterReason = waterReason,
        wateringEfficiency = rewardBreakdown.wateringEfficiency,
        
        -- Fertilizer status
        baseFertilized = plant.base_fertilized,
        fertilizerType = plant.fertilizer_type,
        fertilizerReduction = plant.fertilizer_reduction,
        requiresFertilizer = GrowthCalculations.RequiresBaseFertilizer(plantConfig),
        
        -- Harvest status
        isReady = isReady,
        expectedReward = rewardBreakdown.finalReward,
        rewardBreakdown = rewardBreakdown,
        
        -- Timestamps
        plantedAt = plant.plant_time,
        lastWatered = plant.last_watered,
        fertilizedAt = plant.fertilized_at
    }
end

-- ===========================================
-- UTILITY FUNCTIONS
-- ===========================================

-- Format time remaining in human readable format
function GrowthCalculations.FormatTimeRemaining(seconds)
    if seconds <= 0 then
        return "Ready"
    end
    
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    
    if hours > 0 then
        return string.format("%dh %dm", hours, minutes)
    elseif minutes > 0 then
        return string.format("%dm %ds", minutes, secs)
    else
        return string.format("%ds", secs)
    end
end

-- Calculate estimated harvest time
function GrowthCalculations.CalculateHarvestTime(plantData)
    local timeLeft = tonumber(plantData.time_left) or 0
    
    if timeLeft <= 0 then
        return os.time() -- Ready now
    end
    
    return os.time() + timeLeft
end

-- Validate plant configuration
function GrowthCalculations.ValidatePlantConfig(plantConfig)
    local errors = {}
    
    if not plantConfig.plantName then
        table.insert(errors, "Missing plantName")
    end
    
    if not plantConfig.seedName then
        table.insert(errors, "Missing seedName")
    end
    
    if not plantConfig.plantProps and not plantConfig.plantProp then
        table.insert(errors, "Missing plantProps or plantProp")
    end
    
    if not plantConfig.timeToGrow or plantConfig.timeToGrow <= 0 then
        table.insert(errors, "Invalid timeToGrow")
    end
    
    if not plantConfig.waterTimes or plantConfig.waterTimes < 1 then
        table.insert(errors, "Invalid waterTimes")
    end
    
    if not plantConfig.rewards or #plantConfig.rewards == 0 then
        table.insert(errors, "Missing rewards")
    end
    
    return #errors == 0, errors
end

-- Export the module
return GrowthCalculations