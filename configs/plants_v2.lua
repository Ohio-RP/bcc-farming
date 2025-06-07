-- BCC-Farming Enhanced Plant Configuration v2.0
-- Multi-Stage Growth, Multi-Watering & Base Fertilizer System
-- This file contains updated plant configurations with new features

Plants = {
    -- ===========================================
    -- FRUITS (Enhanced with multi-stage system)
    -- ===========================================
    
    {
        -- Apple Tree - Full visual progression example
        webhooked = false,
        plantingToolRequired = true,
        plantingTool = 'hoe',
        plantingToolUsage = 2,
        plantingDistance = 1,
        plantName = 'Maçã',
        seedName = 'seed_apple',
        seedAmount = 1,
        
        -- NEW: Multi-stage props (can use different props for each stage)
        plantProps = {
            stage1 = 'prop_sapling_01',      -- Small apple sapling
            stage2 = 'prop_sapling_02',        -- Young apple tree
            stage3 = 'p_tree_apple_01'            -- Mature apple tree
        },
        -- FALLBACK: If new props don't exist, use original prop for all stages
        plantProp = 'p_tree_apple_01', -- Backward compatibility
        
        soilRequired = false,
        soilAmount = 1,
        soilName = 'soil',
        timeToGrow = 1800, -- 30 minutes
        plantOffset = 0,
        
        -- NEW: Multi-watering system
        waterTimes = 3, -- Requires 3 waterings for full reward
        
        -- NEW: Base fertilizer requirement
        requiresBaseFertilizer = true,
        baseFertilizerItem = 'fertilizer',
        
        jobLocked = false,
        smelling = false,
        blips = {
            enabled = true,
            sprite = 'blip_plant',
            name = 'Maçã',
            color = 'WHITE'
        },
        rewards = {
            {
                itemName = 'apple',
                itemLabel = 'Maçã',
                amount = 9 -- Higher base amount due to watering requirement
            }
        },
        jobs = {
            'farmer',
            'doctor'
        }
    },
    
    {
        -- Banana Tree - Same prop progression
        webhooked = false,
        plantingToolRequired = true,
        plantingTool = 'hoe',
        plantingToolUsage = 2,
        plantingDistance = 1,
        plantName = 'Banana',
        seedName = 'seed_banana',
        seedAmount = 1,
        
        -- Using same prop for all stages (no visual change)
        plantProps = {
            stage1 = 'p_tree_banana_01_crt',
            stage2 = 'p_tree_banana_01_crt',
            stage3 = 'p_tree_banana_01_crt'
        },
        plantProp = 'p_tree_banana_01_crt', -- Backward compatibility
        
        soilRequired = false,
        soilAmount = 1,
        soilName = 'soil',
        timeToGrow = 2100, -- 35 minutes
        plantOffset = 0,
        
        waterTimes = 2, -- Requires 2 waterings
        requiresBaseFertilizer = false, -- No base fertilizer needed
        
        jobLocked = false,
        smelling = false,
        blips = {
            enabled = true,
            sprite = 'blip_plant',
            name = 'Banana',
            color = 'WHITE'
        },
        rewards = {
            {
                itemName = 'banana',
                itemLabel = 'Banana',
                amount = 6
            }
        },
        jobs = {
            'farmer',
            'doctor'
        }
    },
    
    {
        -- Cherry Bush - Two-stage visual progression
        webhooked = false,
        plantingToolRequired = true,
        plantingTool = 'hoe',
        plantingToolUsage = 2,
        plantingDistance = 1,
        plantName = 'Cereja',
        seedName = 'seed_cherry',
        seedAmount = 1,
        
        -- Two-stage progression (stage 1&2 same, stage 3 different)
        plantProps = {
            stage1 = 'crp_berry_aa_sim',
            stage2 = 'crp_berry_aa_sim',      -- Same as stage 1
            stage3 = 'crp_berry_aa_sim'       -- Could be different mature version
        },
        plantProp = 'crp_berry_aa_sim', -- Backward compatibility
        
        soilRequired = false,
        soilAmount = 1,
        soilName = 'soil',
        timeToGrow = 1500, -- 25 minutes
        plantOffset = 1,
        
        waterTimes = 2,
        requiresBaseFertilizer = true,
        baseFertilizerItem = 'fertilizer',
        
        jobLocked = false,
        smelling = false,
        blips = {
            enabled = true,
            sprite = 'blip_plant',
            name = 'Cereja',
            color = 'WHITE'
        },
        rewards = {
            {
                itemName = 'cherry',
                itemLabel = 'Cereja',
                amount = 8
            }
        },
        jobs = {
            'farmer',
            'doctor'
        }
    },
    
    -- ===========================================
    -- VEGETABLES (Enhanced configurations)
    -- ===========================================
    
    {
        -- Corn - Simple single watering
        webhooked = false,
        plantingToolRequired = true,
        plantingTool = 'hoe',
        plantingToolUsage = 2,
        plantingDistance = 1,
        plantName = 'Milho',
        seedName = 'seed_corn',
        seedAmount = 1,
        
        plantProps = {
            stage1 = 'crp_cornstalks_ba_sim',
            stage2 = 'crp_cornstalks_bb_sim',
            stage3 = 'crp_cornstalks_bc_sim'
        },
        plantProp = 'crp_cornstalks_bc_sim',
        
        soilRequired = false,
        soilAmount = 1,
        soilName = 'soil',
        timeToGrow = 1200, -- 20 minutes
        plantOffset = 0,
        
        waterTimes = 3, -- Simple single watering
        requiresBaseFertilizer = false,
        
        jobLocked = false,
        smelling = false,
        blips = {
            enabled = true,
            sprite = 'blip_plant',
            name = 'Milho',
            color = 'WHITE'
        },
        rewards = {
            {
                itemName = 'corn',
                itemLabel = 'Milho',
                amount = 4
            }
        },
        jobs = {
            'farmer'
        }
    },
    
    {
        -- Tobacco - High maintenance crop
        webhooked = false,
        plantingToolRequired = true,
        plantingTool = 'hoe',
        plantingToolUsage = 3,
        plantingDistance = 1.5,
        plantName = 'Tabaco',
        seedName = 'seed_tobacco',
        seedAmount = 1,
        
        plantProps = {
            stage1 = 'crp_tobacco_aa_sim',
            stage2 = 'crp_tobacco_aa_sim',
            stage3 = 'crp_tobacco_aa_sim'
        },
        plantProp = 'crp_tobacco_aa_sim',
        
        soilRequired = true,
        soilAmount = 2,
        soilName = 'soil',
        timeToGrow = 3600, -- 60 minutes (long growth)
        plantOffset = 0,
        
        waterTimes = 4, -- High maintenance - 4 waterings needed
        requiresBaseFertilizer = true,
        baseFertilizerItem = 'fertilizer',
        
        jobLocked = true, -- Restricted to specific jobs
        smelling = true,  -- Can be detected by police
        blips = {
            enabled = true,
            sprite = 'blip_plant',
            name = 'Tabaco',
            color = 'YELLOW'
        },
        rewards = {
            {
                itemName = 'tobacco_leaf',
                itemLabel = 'Folha de Tabaco',
                amount = 15 -- High reward for high maintenance
            }
        },
        jobs = {
            'farmer',
            'tobacco_worker'
        }
    },
    
    -- ===========================================
    -- ILLEGAL PLANTS (High risk, high reward)
    -- ===========================================
    
    {
        -- Cannabis - Illegal plant with camouflage stages
        webhooked = true,
        plantingToolRequired = true,
        plantingTool = 'hoe',
        plantingToolUsage = 3,
        plantingDistance = 2,
        plantName = 'Erva Especial',
        seedName = 'seed_cannabis',
        seedAmount = 1,
        
        -- Camouflage progression - looks innocent until mature
        plantProps = {
            stage1 = 'crp_cornstalks_aa_sim',    -- Looks like corn
            stage2 = 'crp_tobacco_aa_sim',       -- Looks like tobacco
            stage3 = 'mp001_p_mp_cannabis01x'    -- Reveals as cannabis
        },
        plantProp = 'mp001_p_mp_cannabis01x',
        
        soilRequired = true,
        soilAmount = 3,
        soilName = 'soil',
        timeToGrow = 4800, -- 80 minutes (very long)
        plantOffset = 0,
        
        waterTimes = 5, -- Very high maintenance
        requiresBaseFertilizer = true,
        baseFertilizerItem = 'fertilizer',
        
        jobLocked = true,
        smelling = true, -- Police can detect when mature
        blips = {
            enabled = false, -- No blips for illegal plants
            sprite = 'blip_plant',
            name = 'Planta Suspeita',
            color = 'RED'
        },
        rewards = {
            {
                itemName = 'cannabis',
                itemLabel = 'Cannabis',
                amount = 25 -- Very high reward
            },
            {
                itemName = 'cannabis_seed',
                itemLabel = 'Semente de Cannabis',
                amount = 2 -- Bonus seeds
            }
        },
        jobs = {
            'criminal'
        }
    },
    
    -- ===========================================
    -- DECORATIVE PLANTS (Low maintenance)
    -- ===========================================
    
    {
        -- Flowers - Decorative with medium watering needs
        webhooked = false,
        plantingToolRequired = false,
        plantingDistance = 0.5,
        plantName = 'Flores',
        seedName = 'seed_flowers',
        seedAmount = 1,
        
        plantProps = {
            stage1 = 'p_flower_bud_01',
            stage2 = 'p_flower_growing_01',
            stage3 = 'p_flower_bouquet_01'
        },
        plantProp = 'p_flower_bouquet_01',
        
        soilRequired = false,
        soilAmount = 1,
        soilName = 'soil',
        timeToGrow = 900, -- 15 minutes
        plantOffset = 0,
        
        waterTimes = 3, -- Flowers need regular watering
        requiresBaseFertilizer = false,
        
        jobLocked = false,
        smelling = false,
        blips = {
            enabled = true,
            sprite = 'blip_plant',
            name = 'Flores',
            color = 'PINK'
        },
        rewards = {
            {
                itemName = 'flower',
                itemLabel = 'Flor',
                amount = 5
            }
        },
        jobs = {}
    }
}

-- ===========================================
-- GROWTH STAGES CONFIGURATION
-- ===========================================
GrowthStages = {
    stage1 = {
        name = "Seedling",
        minProgress = 0,
        maxProgress = 30,
        description = "Early growth stage - small seedling just emerged"
    },
    stage2 = {
        name = "Young Plant", 
        minProgress = 31,
        maxProgress = 60,
        description = "Mid growth stage - plant is developing and growing"
    },
    stage3 = {
        name = "Mature Plant",
        minProgress = 61,
        maxProgress = 100,
        description = "Final growth stage - ready for harvest"
    }
}

-- ===========================================
-- WATERING CONFIGURATION
-- ===========================================
WateringConfig = {
    -- Time windows for watering (as percentage of total growth time)
    windows = {
        window1 = { start = 0, endTime = 30 },    -- 0-30% of growth time
        window2 = { start = 30, endTime = 60 },   -- 30-60% of growth time  
        window3 = { start = 60, endTime = 90 },   -- 60-90% of growth time
        window4 = { start = 70, endTime = 95 },   -- 70-95% of growth time (overlap for flexibility)
        window5 = { start = 80, endTime = 100 }   -- 80-100% of growth time (final watering)
    },
    
    -- Grace period for watering (percentage of window size)
    gracePeriod = 0.2, -- 20% grace period
    
    -- Notification thresholds
    notifyNeedsWater = true,
    notifyWindowStart = true,
    notifyWindowEnd = true
}

-- ===========================================
-- FERTILIZER CONFIGURATION  
-- ===========================================
FertilizerConfig = {
    -- Base fertilizer (required for some plants)
    baseFertilizer = {
        item = 'fertilizer',
        name = 'Basic Fertilizer',
        reduction = 0.0, -- No time reduction, just prevents penalty
        required = true   -- Required for certain plants
    },
    
    -- Enhanced fertilizers (optional, provide time reduction)
    enhancedFertilizers = {
        {
            fertName = 'fertilizer1',
            fertTimeReduction = 0.10,
            label = 'Low Grade Fertilizer'
        },
        {
            fertName = 'fertilizer2', 
            fertTimeReduction = 0.20,
            label = 'Mid Grade Fertilizer'
        },
        {
            fertName = 'fertilizer3',
            fertTimeReduction = 0.30,
            label = 'High Grade Fertilizer'
        }
    }
}

-- ===========================================
-- REWARD CALCULATION CONFIGURATION
-- ===========================================
RewardConfig = {
    -- Penalty for not using base fertilizer
    noBaseFertilizerPenalty = 0.30, -- 30% reduction
    
    -- Minimum reward percentage (even with poor care)
    minimumRewardPercentage = 0.10, -- Never less than 10%
    
    -- Bonus for perfect care
    perfectCareBonus = 0.05 -- 5% bonus for full watering + fertilizer
}

-- ===========================================
-- BACKWARD COMPATIBILITY FUNCTIONS
-- ===========================================

-- Function to convert old plant config to new format
function ConvertLegacyPlant(plantConfig)
    -- If old format (single plantProp), convert to new format
    if plantConfig.plantProp and not plantConfig.plantProps then
        plantConfig.plantProps = {
            stage1 = plantConfig.plantProp,
            stage2 = plantConfig.plantProp,
            stage3 = plantConfig.plantProp
        }
    end
    
    -- Set defaults for new fields if not present
    if not plantConfig.waterTimes then
        plantConfig.waterTimes = 1
    end
    
    if plantConfig.requiresBaseFertilizer == nil then
        plantConfig.requiresBaseFertilizer = false
    end
    
    if not plantConfig.baseFertilizerItem then
        plantConfig.baseFertilizerItem = 'fertilizer'
    end
    
    return plantConfig
end

-- Apply conversion to all plants for backward compatibility
for i, plant in ipairs(Plants) do
    Plants[i] = ConvertLegacyPlant(plant)
end

print("^2[BCC-Farming]^7 Enhanced plant configuration loaded with " .. #Plants .. " plants")
print("^3[BCC-Farming]^7 Multi-stage growth, multi-watering, and base fertilizer systems enabled")