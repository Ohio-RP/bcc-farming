# BCC-Farming Enhancement Plan
## Multi-Stage Growth, Multi-Watering & Base Fertilizer System

### Overview

This document outlines the comprehensive plan to enhance the BCC-Farming system with three major features:

1. **Multi-Stage Growth System** - Plants grow through visual stages (1-30%, 31-60%, 61-100%)
2. **Multi-Watering Reward System** - Rewards scale based on watering frequency
3. **Base Fertilizer Requirement** - Plants require base fertilizer to achieve full potential

---

## 🌱 1. Multi-Stage Growth System

### Current System Analysis
- **Current**: Single prop throughout entire growth cycle
- **Current**: Growth tracked by `time_left` field only
- **Current**: No visual progression indication

### New System Design

#### Growth Stages
```lua
-- Growth Stages Configuration
GrowthStages = {
    stage1 = { -- 1-30% growth
        name = "Seedling",
        minProgress = 0,
        maxProgress = 30
    },
    stage2 = { -- 31-60% growth
        name = "Young Plant",
        minProgress = 31,
        maxProgress = 60
    },
    stage3 = { -- 61-100% growth
        name = "Mature Plant",
        minProgress = 61,
        maxProgress = 100
    }
}
```

#### Plant Configuration Changes
```lua
-- Updated plant config structure
{
    plantName = 'Maçã',
    seedName = 'seed_apple',
    -- NEW: Multiple props for different stages (can be different or same props)
    plantProps = {
        stage1 = 'p_sapling_apple_small',      -- Small sapling
        stage2 = 'p_tree_apple_young',         -- Young tree
        stage3 = 'p_tree_apple_01'             -- Full grown tree (current prop)
    },
    -- Alternative: Same prop for all stages if desired
    -- plantProps = {
    --     stage1 = 'p_tree_apple_01',
    --     stage2 = 'p_tree_apple_01', 
    --     stage3 = 'p_tree_apple_01'
    -- },
    timeToGrow = 1200,
    -- NEW: Multi-watering configuration
    waterTimes = 3, -- Number of times plant needs to be watered
    -- NEW: Base fertilizer requirement
    requiresBaseFertilizer = true,
    baseFertilizerItem = 'fertilizer', -- Basic fertilizer item
    -- Rest of config remains the same...
}
```

#### Database Schema Changes
```sql
-- Add new columns to bcc_farming table
ALTER TABLE `bcc_farming` ADD COLUMN `growth_stage` TINYINT(1) DEFAULT 1;
ALTER TABLE `bcc_farming` ADD COLUMN `growth_progress` FLOAT(5,2) DEFAULT 0.00;
ALTER TABLE `bcc_farming` ADD COLUMN `water_count` TINYINT(3) DEFAULT 0;
ALTER TABLE `bcc_farming` ADD COLUMN `max_water_times` TINYINT(3) DEFAULT 1;
ALTER TABLE `bcc_farming` ADD COLUMN `base_fertilized` BOOLEAN DEFAULT FALSE;
ALTER TABLE `bcc_farming` ADD COLUMN `fertilizer_type` VARCHAR(50) DEFAULT NULL;
ALTER TABLE `bcc_farming` ADD COLUMN `fertilizer_reduction` FLOAT(3,2) DEFAULT 0.00;
```

---

## 💧 2. Multi-Watering Reward System

### Current System
- **Current**: Plant can be watered once (`plant_watered = 'true'/'false'`)
- **Current**: Binary watering state (watered or not)
- **Current**: No scaling of rewards based on care

### New System Design

#### Watering Mechanics
```lua
-- Example calculation
local waterTimes = plantConfig.waterTimes -- e.g., 3
local currentWaterCount = plantData.water_count -- e.g., 2
local baseReward = plantConfig.rewards[1].amount -- e.g., 10

-- Calculate reward scaling
local wateringEfficiency = currentWaterCount / waterTimes -- 2/3 = 0.66
local scaledReward = math.floor(baseReward * wateringEfficiency) -- 10 * 0.66 = 6.6 -> 6
```

#### Watering Logic
- Each plant can be watered multiple times during growth cycle
- Watering windows: evenly distributed throughout growth period
- Player receives notification when plant needs watering
- Reward scales linearly with watering completion

#### Implementation Example
```lua
-- Calculate watering windows
local function CalculateWateringWindows(totalGrowthTime, waterTimes)
    local windows = {}
    local interval = totalGrowthTime / waterTimes
    
    for i = 1, waterTimes do
        local windowStart = (i - 1) * interval
        local windowEnd = windowStart + (interval * 0.3) -- 30% window
        table.insert(windows, {
            start = windowStart,
            end = windowEnd,
            completed = false
        })
    end
    
    return windows
end
```

---

## 🧪 3. Base Fertilizer Requirement System

### Current System
- **Current**: Fertilizers only reduce growth time
- **Current**: Multiple fertilizer types with different reduction rates
- **Current**: Optional fertilizer usage

### New System Design

#### Base Fertilizer Mechanics
```lua
-- Reward calculation with base fertilizer
local function CalculateFinalReward(plantConfig, plantData)
    local baseReward = plantConfig.rewards[1].amount
    local wateringMultiplier = plantData.water_count / plantData.max_water_times
    local fertilizerMultiplier = 1.0
    
    -- Base fertilizer check
    if plantConfig.requiresBaseFertilizer then
        if plantData.base_fertilized then
            fertilizerMultiplier = 1.0 -- Full potential
        else
            fertilizerMultiplier = 0.7 -- 30% penalty
        end
    end
    
    -- Final calculation
    local finalReward = math.floor(baseReward * wateringMultiplier * fertilizerMultiplier)
    return finalReward
end
```

#### Example Calculations
```lua
-- Example 1: Fully cared plant
-- baseReward = 10, waterTimes = 2, watered = 2, fertilized = true
-- Result: 10 * (2/2) * 1.0 = 10

-- Example 2: Under-watered, fertilized plant  
-- baseReward = 10, waterTimes = 2, watered = 1, fertilized = true
-- Result: 10 * (1/2) * 1.0 = 5

-- Example 3: Fully watered, not fertilized plant
-- baseReward = 10, waterTimes = 2, watered = 2, fertilized = false
-- Result: 10 * (2/2) * 0.7 = 7

-- Example 4: Under-watered, not fertilized plant
-- baseReward = 10, waterTimes = 2, watered = 1, fertilized = false  
-- Result: 10 * (1/2) * 0.7 = 3
```

---

## 📋 Implementation Plan

### Phase 1: Database & Configuration Setup
1. **Database Migration**
   - Add new columns to `bcc_farming` table
   - Create migration script for existing plants
   - Update plant configuration structure

2. **Configuration Updates**
   - Update `configs/plants.lua` with new structure
   - Add growth stage definitions
   - Configure watering requirements per plant type

### Phase 2: Core System Changes
1. **Growth Stage System**
   - Modify plant spawning to use stage 1 props
   - Implement growth progress calculation
   - Add stage transition logic
   - Update prop switching mechanism

2. **Watering System Overhaul**
   - Replace binary watering with counter system
   - Implement watering windows
   - Add watering availability checks
   - Update watering notifications

3. **Fertilizer System Enhancement**
   - Add base fertilizer requirement checks
   - Implement fertilizer application validation
   - Update reward calculation system
   - Add fertilizer status tracking

### Phase 3: Client-Side Updates
1. **Visual Improvements**
   - Implement prop switching for growth stages
   - Add ground-level positioning for all stages
   - Update interaction prompts
   - Enhance progress indicators

2. **User Interface**
   - Add growth stage information to plant inspection
   - Show watering progress and requirements
   - Display fertilizer status
   - Update notification system

### Phase 4: Export System Updates
1. **New Exports**
   - `GetPlantGrowthStage(plantId)`
   - `GetPlantWateringStatus(plantId)`
   - `GetPlantFertilizerStatus(plantId)`
   - `CalculatePlantReward(plantId)`

2. **Updated Exports**
   - Modify existing exports to include new data
   - Update statistics calculations
   - Enhance reporting capabilities

### Phase 5: Visual Plant Status NUI System
1. **NUI Interface Design**
   - Right-side plant status panel using VORP Framework UI
   - Circular progress bars for growth, watering, and fertilization
   - Proximity-based display (shows when near plants)
   - Clean, minimalist design matching RedM aesthetic

2. **Status Indicators**
   - **Growth Progress**: Circular bar showing 0-100% growth stage
   - **Watering Status**: Bar showing watering completion (e.g., 2/3 waterings)
   - **Fertilizer Status**: Icon indicating base fertilizer applied
   - **Plant Health**: Overall condition based on care level
   - **Estimated Yield**: Preview of expected rewards

3. **Interactive Features**
   - Real-time updates as player waters/fertilizes
   - Smooth animations for status changes
   - Color-coded indicators (green=good, yellow=needs attention, red=poor)
   - Plant information tooltip on hover

---

## 🔧 Technical Implementation Details

### File Changes Required

#### 1. Database Files
- `bcc-farming.sql` - Add new table columns
- `server/database/setup.lua` - Migration logic

#### 2. Configuration Files
- `configs/plants.lua` - Update plant structure
- `configs/config.lua` - Add growth stage settings

#### 3. Server Files
- `server/main.lua` - Core growth and watering logic
- `server/services/usableItems.lua` - Fertilizer application
- `server/exports/*.lua` - Update all relevant exports

#### 4. Client Files
- `client/main.lua` - Prop management and interactions
- `client/services/planting.lua` - Planting logic
- `client/services/planted.lua` - Plant interaction logic

### Growth Progress Calculation
```lua
local function CalculateGrowthProgress(timeLeft, totalGrowthTime)
    local elapsed = totalGrowthTime - timeLeft
    local progress = (elapsed / totalGrowthTime) * 100
    return math.min(100, math.max(0, progress))
end

local function GetGrowthStage(progress)
    if progress <= 30 then
        return 1
    elseif progress <= 60 then
        return 2
    else
        return 3
    end
end
```

### Watering Window System
```lua
local function CanWaterPlant(plantData, currentTime)
    local progress = CalculateGrowthProgress(plantData.time_left, plantData.total_growth_time)
    local currentWateringPhase = math.ceil((progress / 100) * plantData.max_water_times)
    
    return plantData.water_count < currentWateringPhase and 
           plantData.water_count < plantData.max_water_times
end
```

### Prop Management System
```lua
local function UpdatePlantProp(plantId, newStage, plantConfig, coords)
    -- Remove old prop if it exists
    if PlantProps[plantId] and DoesEntityExist(PlantProps[plantId]) then
        DeleteEntity(PlantProps[plantId])
    end
    
    -- Get the prop name for the current stage
    local propName = plantConfig.plantProps['stage' .. newStage]
    
    -- Spawn new prop at ground level
    local groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z)
    local newProp = CreateObject(propName, coords.x, coords.y, groundZ, false, false, false)
    
    -- Store prop reference
    PlantProps[plantId] = newProp
    
    return newProp
end

-- Example usage with different configurations:
-- Plant with 3 different props:
-- stage1: 'p_sapling_apple_small'
-- stage2: 'p_tree_apple_young' 
-- stage3: 'p_tree_apple_01'

-- Plant with same prop (no visual change):
-- stage1: 'p_tree_apple_01'
-- stage2: 'p_tree_apple_01'
-- stage3: 'p_tree_apple_01'

-- Plant with 2 different props (stages 1&2 same):
-- stage1: 'p_sapling_generic'
-- stage2: 'p_sapling_generic'
-- stage3: 'p_tree_apple_01'
```

### Plant Status NUI System
```html
<!-- plant-status.html -->
<div class="plant-status-panel" v-if="nearPlant && visible">
    <div class="plant-info">
        <h3>{{ plantData.name }}</h3>
        <span class="plant-stage">{{ plantData.stageName }}</span>
    </div>
    
    <div class="status-indicators">
        <!-- Growth Progress -->
        <div role="progressbar" aria-valuenow="65" aria-valuemin="0" aria-valuemax="100" 
             :style="'--value:' + plantData.growthProgress">
            <i class="fa-solid fa-seedling"></i>
            <span class="status-label">Growth</span>
        </div>
        
        <!-- Watering Status -->
        <div role="progressbar" aria-valuenow="65" aria-valuemin="0" aria-valuemax="100" 
             :style="'--value:' + (plantData.waterCount / plantData.maxWater * 100)">
            <i class="fa-solid fa-droplet"></i>
            <span class="status-label">Watering</span>
            <span class="fraction">{{ plantData.waterCount }}/{{ plantData.maxWater }}</span>
        </div>
        
        <!-- Fertilizer Status -->
        <div class="fertilizer-status" :class="plantData.fertilized ? 'fertilized' : 'not-fertilized'">
            <i class="fa-solid fa-flask"></i>
            <span class="status-label">Fertilizer</span>
            <span class="status-text">{{ plantData.fertilized ? 'Applied' : 'Needed' }}</span>
        </div>
        
        <!-- Expected Yield -->
        <div class="yield-preview">
            <i class="fa-solid fa-coins"></i>
            <span class="yield-amount">{{ plantData.expectedYield }}</span>
            <span class="yield-label">Expected Yield</span>
        </div>
    </div>
</div>
```

```lua
-- Client-side proximity detection and NUI management
local currentPlantNUI = nil
local isNearPlant = false

CreateThread(function()
    while true do
        Wait(500) -- Check every 500ms
        local playerCoords = GetEntityCoords(PlayerPedId())
        local nearestPlant = nil
        local shortestDistance = 999999
        
        -- Check distance to all plants
        for plantId, plantData in pairs(ClientPlants) do
            local distance = #(playerCoords - plantData.coords)
            if distance < 3.0 and distance < shortestDistance then -- 3 unit radius
                shortestDistance = distance
                nearestPlant = plantData
                nearestPlant.id = plantId
            end
        end
        
        -- Update NUI state
        if nearestPlant and not isNearPlant then
            isNearPlant = true
            currentPlantNUI = nearestPlant
            TriggerServerEvent('bcc-farming:RequestPlantStatus', nearestPlant.id)
        elseif not nearestPlant and isNearPlant then
            isNearPlant = false
            currentPlantNUI = nil
            SendNUIMessage({
                type = 'hidePlantStatus'
            })
        end
    end
end)

-- Handle plant status updates from server
RegisterNetEvent('bcc-farming:UpdatePlantStatus')
AddEventHandler('bcc-farming:UpdatePlantStatus', function(plantData)
    if isNearPlant and currentPlantNUI then
        SendNUIMessage({
            type = 'showPlantStatus',
            plantData = {
                name = plantData.plantName,
                stageName = plantData.stageName,
                growthProgress = plantData.growthProgress,
                waterCount = plantData.waterCount,
                maxWater = plantData.maxWaterTimes,
                fertilized = plantData.baseFertilized,
                expectedYield = plantData.expectedReward
            }
        })
    end
end)
```

```css
/* plant-status.css */
.plant-status-panel {
    position: fixed;
    right: 20px;
    top: 50%;
    transform: translateY(-50%);
    background: rgba(0, 0, 0, 0.8);
    border: 2px solid #8B4513;
    border-radius: 10px;
    padding: 15px;
    min-width: 200px;
    color: white;
    font-family: 'RDR Lino', serif;
}

.plant-info h3 {
    margin: 0 0 5px 0;
    color: #D4AF37;
    font-size: 1.2em;
}

.plant-stage {
    color: #90EE90;
    font-size: 0.9em;
}

.status-indicators {
    margin-top: 15px;
}

.status-indicators > div {
    margin-bottom: 10px;
    position: relative;
}

/* Circular progress bar styling */
[role="progressbar"] {
    --size: 50px;
    --fg: #D4AF37;
    --bg: #4A4A4A;
    --pgPercentage: var(--value);
    animation: growProgressBar 2s 1 forwards;
    width: var(--size);
    height: var(--size);
    border-radius: 50%;
    display: grid;
    place-items: center;
    background: 
        radial-gradient(closest-side, black 70%, transparent 0 99.9%, black 0),
        conic-gradient(var(--fg) calc(var(--pgPercentage) * 1%), var(--bg) 0);
    margin-right: 10px;
    display: inline-block;
}

.fertilizer-status {
    display: flex;
    align-items: center;
    gap: 8px;
}

.fertilizer-status.fertilized .status-text {
    color: #90EE90;
}

.fertilizer-status.not-fertilized .status-text {
    color: #FFB347;
}

.yield-preview {
    display: flex;
    align-items: center;
    gap: 8px;
    background: rgba(212, 175, 55, 0.1);
    padding: 5px 8px;
    border-radius: 5px;
    margin-top: 10px;
}

.yield-amount {
    color: #D4AF37;
    font-weight: bold;
}

@keyframes growProgressBar {
    0%, 33% { --pgPercentage: 0; }
    100% { --pgPercentage: var(--value); }
}
```

---

## 🎯 Expected Benefits

### 1. Enhanced Player Engagement
- Visual progression provides satisfaction
- Multiple interactions increase investment
- Strategic decision-making (fertilizer vs. cost)

### 2. Economic Balance
- Rewards scale with effort invested
- Creates tiered farming strategies
- Balances casual vs. dedicated farmers

### 3. Roleplay Enhancement
- More realistic farming simulation
- Encourages plant care and attention
- Creates agricultural knowledge requirements

### 4. System Scalability
- Framework supports additional growth stages
- Extensible to different plant types
- Future expansion possibilities

---

## 🚀 Implementation Timeline

### Week 1: Foundation
- Database schema changes
- Configuration structure updates
- Core calculation functions

### Week 2: Growth System
- Multi-stage growth implementation
- Prop switching mechanism
- Growth progress tracking

### Week 3: Watering & Fertilizer
- Multi-watering system
- Base fertilizer requirements
- Reward calculation updates

### Week 4: Export System & Core Polish
- Export system updates
- Core mechanics testing
- Bug fixes and optimization

### Week 5: Plant Status NUI System
- Design and implement status interface
- Proximity detection system
- Real-time status updates
- Progress bar animations

### Week 6: Integration & Final Testing
- NUI integration with core systems
- Comprehensive testing
- Performance optimization
- User experience validation

### Week 7: Documentation & Deployment
- Update documentation
- Create migration guides
- Deployment and monitoring

---

## 🔍 Testing Strategy

### 1. Unit Testing
- Growth progress calculations
- Reward scaling formulas
- Watering window logic

### 2. Integration Testing
- Complete growth cycles
- Multiple plant types
- Export system validation

### 3. Performance Testing
- Database query optimization
- Memory usage monitoring
- Server load analysis

### 4. User Acceptance Testing
- Player experience validation
- Interface usability
- Balance verification

---

## 📊 Success Metrics

### Technical Metrics
- Database query performance maintained
- Memory usage within acceptable limits
- No regression in existing functionality

### Gameplay Metrics
- Player engagement with watering system
- Fertilizer usage statistics
- Reward distribution analysis

### Economic Metrics
- Market balance maintenance
- Resource consumption rates
- Player progression tracking

---

This comprehensive plan provides a roadmap for implementing the requested enhancements while maintaining system stability and performance. Each phase builds upon the previous one, ensuring a smooth transition from the current system to the enhanced version.