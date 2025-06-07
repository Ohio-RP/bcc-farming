# BCC-Farming Enhanced Exports v2.5.0

## Multi-Stage Growth System Export Documentation

This document outlines the enhanced export functions available in BCC-Farming v2.5.0, which includes multi-stage growth, multi-watering, and base fertilizer systems.

---

## What's New in v2.5.0

### 🌱 **Enhanced Plant Data**
- **Growth Stages**: 3-stage visual progression system
- **Multi-Watering**: Configurable watering requirements with efficiency tracking
- **Base Fertilizer**: Required/optional fertilizer system with penalties
- **Real-time Progress**: Live growth progress tracking (0-100%)
- **Yield Calculation**: Dynamic reward calculation based on care quality

### 📊 **New Export Functions**
- `GetGrowthStageDistribution()` - Stage-based plant statistics
- `GetPlayerEfficiencyReport()` - Individual player efficiency analysis

### 🔄 **Updated Export Functions**
All existing exports now include v2.5.0 enhanced data while maintaining backward compatibility.

---

## Basic Exports (7 functions)

### 1. `GetGlobalPlantCount()`
Returns total number of plants on the server.

**Enhanced in v2.5.0**: Unchanged functionality, but now works with enhanced database schema.

```lua
local result = exports['bcc-farming']:GetGlobalPlantCount()
-- Returns: { success: boolean, data: number, timestamp: number }
```

### 2. `GetGlobalPlantsByType()`
Returns plant count grouped by type with enhanced v2.5.0 statistics.

**Enhanced in v2.5.0**: Now includes growth stages, water efficiency, and fertilizer statistics.

```lua
local result = exports['bcc-farming']:GetGlobalPlantsByType()
--[[ Returns:
{
    success = true,
    data = {
        {
            plant_type = "corn_seed",
            plant_name = "Corn",
            count = 25,
            avg_progress = 67,           -- NEW: Average growth progress
            avg_stage = 2,               -- NEW: Average growth stage
            ready_count = 8,             -- NEW: Plants ready for harvest
            fertilized_count = 20,       -- NEW: Plants with base fertilizer
            avg_water_count = 2.5,       -- NEW: Average watering count
            water_times = 3,             -- NEW: Required watering times
            avg_water_efficiency = 83,   -- NEW: Average watering efficiency
            ready_percentage = 32,       -- NEW: Percentage ready
            fertilized_percentage = 80,  -- NEW: Percentage fertilized
            requires_base_fertilizer = true
        }
    },
    timestamp = 1640995200
}
--]]
```

### 3. `GetNearHarvestPlants(timeThreshold)`
Returns plants near harvest with enhanced progression data.

**Enhanced in v2.5.0**: Includes growth stages and efficiency metrics.

```lua
local result = exports['bcc-farming']:GetNearHarvestPlants(300) -- 5 minutes
--[[ Returns enhanced data:
{
    success = true,
    data = {
        {
            plantType = "corn_seed",
            plantName = "Corn",
            count = 5,
            avgTimeLeft = 240,
            avgProgress = 98,            -- NEW: Average growth progress
            avgStage = 3,                -- NEW: Average growth stage
            fertilizedCount = 4,         -- NEW: Fertilized plants count
            fertilizedPercentage = 80,   -- NEW: Fertilized percentage
            avgWaterEfficiency = 90      -- NEW: Average water efficiency
        }
    }
}
--]]
```

### 4. `GetFarmingOverview()`
Comprehensive farming statistics with v2.5.0 system metrics.

**Enhanced in v2.5.0**: Includes system-wide progression and efficiency statistics.

```lua
local result = exports['bcc-farming']:GetFarmingOverview()
--[[ Returns enhanced overview:
{
    success = true,
    data = {
        totalPlants = 150,
        totalTypes = 5,
        plantsReadySoon = 25,
        mostCommonPlant = "corn_seed",
        mostCommonCount = 50,
        
        -- NEW v2.5.0 System Statistics
        systemStats = {
            totalFertilized = 120,
            fertilizedPercentage = 80,
            avgWaterEfficiency = 75,
            stageDistribution = {
                stage1 = 45,     -- Plants in stage 1
                stage2 = 60,     -- Plants in stage 2  
                stage3 = 45      -- Plants in stage 3
            },
            stagePercentages = {
                stage1 = 30,     -- 30% in stage 1
                stage2 = 40,     -- 40% in stage 2
                stage3 = 30      -- 30% in stage 3
            }
        },
        
        plantsByType = {...},    -- Enhanced plant data
        upcomingHarvests = {...} -- Enhanced harvest data
    }
}
--]]
```

### 5. `GetWateringStatus()`
Enhanced watering statistics with multi-watering support.

**Enhanced in v2.5.0**: Now supports partial watering states and efficiency tracking.

```lua
local result = exports['bcc-farming']:GetWateringStatus()
--[[ Returns enhanced watering data:
{
    success = true,
    data = {
        fullyWatered = {         -- NEW: Fully watered plants
            count = 80,
            avgTimeLeft = 1200,
            avgProgress = 85,
            avgEfficiency = 100,
            percentage = 50
        },
        partiallyWatered = {     -- NEW: Partially watered plants
            count = 50,
            avgTimeLeft = 2400,
            avgProgress = 60,
            avgEfficiency = 60,
            percentage = 31
        },
        notWatered = {
            count = 30,
            avgTimeLeft = 3600,
            avgProgress = 30,
            avgEfficiency = 0,
            percentage = 19
        },
        total = 160,
        summary = {              -- NEW: Summary statistics
            needsWatering = 80,
            fullyOptimized = 80,
            overallEfficiency = 70
        }
    }
}
--]]
```

### 6. `GetGrowthStageDistribution()` ⭐ NEW
Distribution of plants across growth stages with detailed metrics.

**New in v2.5.0**: Provides insights into stage-based progression.

```lua
local result = exports['bcc-farming']:GetGrowthStageDistribution()
--[[ Returns:
{
    success = true,
    data = {
        stages = {
            {
                stage = 1,
                count = 45,
                avgProgress = 25,
                avgTimeLeft = 3200,
                fertilizedCount = 35,
                avgWaterCount = 1,
                avgMaxWater = 3,
                waterEfficiency = 33,
                percentage = 30,
                fertilizedPercentage = 78
            },
            {
                stage = 2,
                count = 60,
                avgProgress = 65,
                avgTimeLeft = 1800,
                fertilizedCount = 50,
                avgWaterCount = 2,
                avgMaxWater = 3,
                waterEfficiency = 67,
                percentage = 40,
                fertilizedPercentage = 83
            },
            {
                stage = 3,
                count = 45,
                avgProgress = 90,
                avgTimeLeft = 600,
                fertilizedCount = 40,
                avgWaterCount = 3,
                avgMaxWater = 3,
                waterEfficiency = 100,
                percentage = 30,
                fertilizedPercentage = 89
            }
        },
        totalPlants = 150,
        summary = {
            mostCommonStage = 2,
            avgProgressAcrossStages = 60
        }
    }
}
--]]
```

---

## Player Exports (6 functions)

### 1. `GetPlayerPlantCount(playerId)`
Returns player's plant count with capacity information.

**Enhanced in v2.5.0**: Unchanged functionality, works with enhanced system.

### 2. `GetPlayerPlants(playerId)`
Returns all player plants with comprehensive v2.5.0 data.

**Enhanced in v2.5.0**: Now includes growth stages, watering efficiency, fertilizer status, and yield calculations.

```lua
local result = exports['bcc-farming']:GetPlayerPlants(playerId)
--[[ Returns enhanced plant data:
{
    success = true,
    data = {
        {
            plantId = 123,
            plantType = "corn_seed",
            plantName = "Corn",
            coords = {x = 100, y = 200, z = 50},
            plantedAt = 1640995200,
            
            -- Growth Information (v2.5.0)
            growthStage = 2,             -- Current stage (1-3)
            stageName = "Young Plant",   -- Stage display name
            growthProgress = 67.5,       -- Progress percentage
            timeLeft = 1800,             -- Seconds remaining
            
            -- Watering Information (v2.5.0)  
            waterCount = 2,              -- Current watering count
            maxWaterTimes = 3,           -- Required watering times
            wateringEfficiency = 67,     -- Watering efficiency %
            canWater = true,             -- Can be watered now
            
            -- Fertilizer Information (v2.5.0)
            baseFertilized = true,       -- Base fertilizer applied
            fertilizerType = "enhanced", -- Type of fertilizer
            needsBaseFertilizer = false, -- Needs base fertilizer
            requiresBaseFertilizer = true,-- Plant requires base fertilizer
            
            -- Status and Rewards
            isReady = false,
            status = "growing",          -- ready/growing/needs_water/needs_fertilizer
            expectedReward = 8,          -- Calculated expected yield
            
            estimatedHarvest = {
                hours = 1,
                minutes = 30,
                seconds = 1800
            }
        }
    },
    count = 1,
    playerId = playerId,
    charId = "char123"
}
--]]
```

### 3. `CanPlayerPlantMore(playerId)`
Checks if player can plant more crops.

**Enhanced in v2.5.0**: Unchanged functionality.

### 4. `GetPlayerFarmingStats(playerId)`
Comprehensive player farming statistics with v2.5.0 metrics.

**Enhanced in v2.5.0**: Includes stage distribution, efficiency tracking, and performance analysis.

```lua
local result = exports['bcc-farming']:GetPlayerFarmingStats(playerId)
--[[ Returns enhanced stats:
{
    success = true,
    data = {
        farming = {
            totalPlants = 15,
            readyToHarvest = 3,
            needsWater = 5,
            needsFertilizer = 2,         -- NEW: Plants needing fertilizer
            growing = 5,
            
            -- Stage Distribution (v2.5.0)
            stageDistribution = {
                stage1 = 5,
                stage2 = 7,
                stage3 = 3
            },
            
            -- Efficiency Metrics (v2.5.0)
            averageProgress = 65,        -- Average growth progress
            totalWaterEfficiency = 78,   -- Average water efficiency
            fullyFertilized = 12,        -- Plants with fertilizer
            totalExpectedReward = 120,   -- Total expected yield
            
            plantTypes = {...},
            oldestPlant = {...},
            newestPlant = {...},
            bestPerformingPlant = {...}, -- NEW: Most efficient plant
            worstPerformingPlant = {...} -- NEW: Least efficient plant
        },
        capacity = {...},
        summary = {
            efficiency = 20,             -- Overall efficiency %
            wateringNeeded = true,
            fertilizingNeeded = true,    -- NEW: Fertilizer needed
            hasReadyPlants = true,
            isMaxCapacity = false,
            
            -- v2.5.0 Summary Stats
            avgWaterEfficiency = 78,
            fertilizedPercentage = 80,
            stageDistributionText = "Stage 1: 5, Stage 2: 7, Stage 3: 3",
            totalPotentialReward = 120
        }
    }
}
--]]
```

### 5. `GetPlayerComparison(playerId)`
Compare player with global averages including v2.5.0 metrics.

**Enhanced in v2.5.0**: Includes efficiency comparisons and performance rankings.

```lua
local result = exports['bcc-farming']:GetPlayerComparison(playerId)
--[[ Returns enhanced comparison:
{
    success = true,
    data = {
        player = {
            plantCount = 15,
            readyPlants = 3,
            efficiency = 20,
            
            -- v2.5.0 Player Metrics
            waterEfficiency = 78,
            fertilizedPercentage = 80,
            potentialReward = 120,
            stageDistribution = {...}
        },
        global = {
            totalPlants = 500,
            avgPerPlayer = 12.5,
            totalPlayers = 40,
            
            -- v2.5.0 Global Metrics
            avgWaterEfficiency = 70,
            avgFertilizedPercentage = 75,
            stageDistribution = {...}
        },
        comparison = {
            aboveAverage = true,
            percentageOfGlobal = 3,
            rank = "above_average",
            
            -- v2.5.0 Comparison Rankings
            waterEfficiencyRank = "above_average",
            fertilizationRank = "above_average",
            
            performance = {
                plantsVsAvg = 2.5,           -- Plants above average
                waterEfficiencyVsAvg = 8,    -- Water efficiency difference
                fertilizationVsAvg = 5       -- Fertilization difference
            }
        }
    }
}
--]]
```

### 6. `GetPlayerEfficiencyReport(playerId)` ⭐ NEW
Detailed efficiency analysis with optimization recommendations.

**New in v2.5.0**: Provides actionable insights for improving plant yields.

```lua
local result = exports['bcc-farming']:GetPlayerEfficiencyReport(playerId)
--[[ Returns:
{
    success = true,
    data = {
        totalPlants = 15,
        maxPossibleReward = 150,     -- Maximum possible yield
        currentExpectedReward = 120, -- Current expected yield
        efficiencyLoss = 30,         -- Lost potential yield
        efficiencyPercentage = 80,   -- Overall efficiency %
        
        recommendations = {          -- Optimization suggestions
            {
                plantId = 123,
                plantName = "Corn",
                issue = "water_efficiency",
                description = "Plant needs more watering (67% efficiency)",
                potentialGain = 3        -- Additional items possible
            },
            {
                plantId = 124,
                plantName = "Wheat",
                issue = "base_fertilizer",
                description = "Plant needs base fertilizer",
                potentialGain = 2
            }
        }
    }
}
--]]
```

---

## Usage Examples

### Basic Server Overview
```lua
-- Get comprehensive server farming overview
local overview = exports['bcc-farming']:GetFarmingOverview()
if overview.success then
    print(string.format("Server has %d plants across %d types", 
        overview.data.totalPlants, overview.data.totalTypes))
    print(string.format("Overall water efficiency: %d%%", 
        overview.data.systemStats.avgWaterEfficiency))
    print(string.format("Fertilized plants: %d%%", 
        overview.data.systemStats.fertilizedPercentage))
end
```

### Player Performance Analysis
```lua
-- Analyze specific player performance
local playerId = 1
local stats = exports['bcc-farming']:GetPlayerFarmingStats(playerId)
local efficiency = exports['bcc-farming']:GetPlayerEfficiencyReport(playerId)

if stats.success and efficiency.success then
    print(string.format("Player %d has %d plants with %d%% efficiency", 
        playerId, stats.data.farming.totalPlants, 
        efficiency.data.efficiencyPercentage))
    
    if #efficiency.data.recommendations > 0 then
        print("Optimization recommendations:")
        for _, rec in pairs(efficiency.data.recommendations) do
            print(string.format("- %s: %s (Potential +%d items)", 
                rec.plantName, rec.description, rec.potentialGain))
        end
    end
end
```

### Growth Stage Analysis
```lua
-- Analyze growth stage distribution
local stages = exports['bcc-farming']:GetGrowthStageDistribution()
if stages.success then
    print("Growth Stage Distribution:")
    for _, stage in pairs(stages.data.stages) do
        print(string.format("Stage %d: %d plants (%d%%) - Avg Progress: %d%%", 
            stage.stage, stage.count, stage.percentage, stage.avgProgress))
        print(string.format("  Water Efficiency: %d%%, Fertilized: %d%%", 
            stage.waterEfficiency, stage.fertilizedPercentage))
    end
end
```

---

## Migration Notes

### From v2.4.2 to v2.5.0

1. **Database Migration Required**: Run `database_migration_v2.sql` before upgrading
2. **Backward Compatibility**: All existing exports maintain their original functionality
3. **Enhanced Data**: Existing exports now return additional v2.5.0 fields
4. **New Exports**: Two new export functions are available
5. **Configuration**: Update plant configurations to include v2.5.0 settings

### Breaking Changes
- None! All existing integrations will continue to work
- Enhanced data is additive, not replacing existing fields

---

## Performance Considerations

- **Database Optimization**: v2.5.0 includes indexed columns for better query performance
- **Caching**: Consider caching results for frequently called exports
- **Rate Limiting**: Implement rate limiting for intensive exports like `GetPlayerEfficiencyReport`

---

## Support

For technical support with v2.5.0 exports:
1. Verify database migration completed successfully
2. Check server console for any SQL errors
3. Test exports with debug commands
4. Refer to the NUI system documentation for client-side integration