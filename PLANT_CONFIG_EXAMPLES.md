# Plant Configuration Examples
## Multi-Stage Growth System Configuration Guide

This document provides examples of how to configure plants with the new multi-stage growth system.

---

## 🌱 Configuration Options

### Option 1: Three Different Props (Recommended)
Complete visual progression from seedling to mature plant:

```lua
{
    plantName = 'Apple Tree',
    seedName = 'seed_apple',
    plantProps = {
        stage1 = 'p_sapling_apple_small',      -- Small seedling
        stage2 = 'p_tree_apple_young',         -- Young tree
        stage3 = 'p_tree_apple_01'             -- Mature apple tree
    },
    waterTimes = 3,
    requiresBaseFertilizer = true,
    baseFertilizerItem = 'fertilizer',
    timeToGrow = 1800, -- 30 minutes
    rewards = {
        { itemName = 'apple', itemLabel = 'Apple', amount = 8 }
    }
}
```

### Option 2: Same Prop All Stages
No visual change, progression tracked internally only:

```lua
{
    plantName = 'Corn',
    seedName = 'seed_corn',
    plantProps = {
        stage1 = 'p_corn_01',                  -- Same prop
        stage2 = 'p_corn_01',                  -- Same prop  
        stage3 = 'p_corn_01'                   -- Same prop
    },
    waterTimes = 2,
    requiresBaseFertilizer = false,
    timeToGrow = 1200, -- 20 minutes
    rewards = {
        { itemName = 'corn', itemLabel = 'Corn', amount = 6 }
    }
}
```

### Option 3: Two-Stage Visual (1+2 Same, 3 Different)
Early stages look the same, final stage changes:

```lua
{
    plantName = 'Tobacco',
    seedName = 'seed_tobacco',
    plantProps = {
        stage1 = 'p_plant_tobacco_seedling',   -- Small plant
        stage2 = 'p_plant_tobacco_seedling',   -- Still small
        stage3 = 'p_plant_tobacco_01'          -- Mature tobacco
    },
    waterTimes = 4,
    requiresBaseFertilizer = true,
    baseFertilizerItem = 'fertilizer',
    timeToGrow = 2400, -- 40 minutes
    rewards = {
        { itemName = 'tobacco_leaf', itemLabel = 'Tobacco Leaf', amount = 12 }
    }
}
```

### Option 4: Generic Props
Using generic vegetation props that could represent any plant:

```lua
{
    plantName = 'Carrots',
    seedName = 'seed_carrot',
    plantProps = {
        stage1 = 'p_plant_generic_small',      -- Generic small plant
        stage2 = 'p_plant_generic_medium',     -- Generic medium plant
        stage3 = 'p_plant_generic_large'       -- Generic large plant
    },
    waterTimes = 2,
    requiresBaseFertilizer = true,
    baseFertilizerItem = 'fertilizer',
    timeToGrow = 900, -- 15 minutes
    rewards = {
        { itemName = 'carrot', itemLabel = 'Carrot', amount = 4 }
    }
}
```

---

## 🎨 Creative Examples

### Example 1: Illegal Plant with Camouflage
Plant that looks innocent early but reveals its true nature:

```lua
{
    plantName = 'Special Herbs',
    seedName = 'seed_special',
    plantProps = {
        stage1 = 'p_plant_generic_small',      -- Looks like normal plant
        stage2 = 'p_plant_generic_medium',     -- Still looks normal
        stage3 = 'p_plant_cannabis_01'         -- Reveals as cannabis
    },
    waterTimes = 3,
    requiresBaseFertilizer = true,
    baseFertilizerItem = 'fertilizer',
    timeToGrow = 3600, -- 60 minutes
    smelling = true, -- Police can detect in final stage
    rewards = {
        { itemName = 'special_herb', itemLabel = 'Special Herb', amount = 15 }
    }
}
```

### Example 2: Flower Progression
Beautiful visual progression for decorative plants:

```lua
{
    plantName = 'Rose Bush',
    seedName = 'seed_rose',
    plantProps = {
        stage1 = 'p_flower_bud_01',            -- Small bud
        stage2 = 'p_flower_growing_01',        -- Growing flower
        stage3 = 'p_flower_rose_full_01'       -- Full bloom roses
    },
    waterTimes = 5, -- Flowers need lots of water
    requiresBaseFertilizer = true,
    baseFertilizerItem = 'fertilizer',
    timeToGrow = 1500, -- 25 minutes
    rewards = {
        { itemName = 'rose', itemLabel = 'Rose', amount = 3 }
    }
}
```

### Example 3: Tree Progression
From sapling to full tree:

```lua
{
    plantName = 'Oak Tree',
    seedName = 'seed_oak',
    plantProps = {
        stage1 = 'p_tree_sapling_01',          -- Small sapling
        stage2 = 'p_tree_oak_young_01',        -- Young oak
        stage3 = 'p_tree_oak_large_01'         -- Mature oak tree
    },
    waterTimes = 2,
    requiresBaseFertilizer = true,
    baseFertilizerItem = 'fertilizer',
    timeToGrow = 4800, -- 80 minutes (trees take longer)
    rewards = {
        { itemName = 'oak_wood', itemLabel = 'Oak Wood', amount = 20 },
        { itemName = 'acorn', itemLabel = 'Acorn', amount = 5 }
    }
}
```

---

## 🔧 Technical Considerations

### Prop Availability
Make sure the props you specify exist in RedM:

```lua
-- Check if prop exists before using
local function PropExists(propName)
    return IsModelInCdimage(GetHashKey(propName))
end

-- Example usage in plant config validation
if PropExists('p_tree_apple_01') then
    -- Use this prop
else
    -- Fall back to default prop
    propName = 'p_plant_generic_01'
end
```

### Performance Optimization
For servers with many plants, consider:

```lua
-- Option: Fewer visual stages for performance
{
    plantProps = {
        stage1 = 'p_plant_small',
        stage2 = 'p_plant_small',    -- Same as stage 1
        stage3 = 'p_plant_large'     -- Only change at end
    }
}

-- Option: Same prop with different scaling (if supported)
{
    plantProps = {
        stage1 = 'p_tree_apple_01',
        stage2 = 'p_tree_apple_01',
        stage3 = 'p_tree_apple_01'
    },
    propScaling = {
        stage1 = 0.5,  -- Half size
        stage2 = 0.75, -- 3/4 size
        stage3 = 1.0   -- Full size
    }
}
```

### Backward Compatibility
Converting existing plants to new system:

```lua
-- Old system (still works)
{
    plantProp = 'p_tree_apple_01',
    -- other config...
}

-- Automatically converts to:
{
    plantProps = {
        stage1 = 'p_tree_apple_01',
        stage2 = 'p_tree_apple_01',
        stage3 = 'p_tree_apple_01'
    },
    -- other config...
}
```

---

## 📋 Configuration Checklist

Before adding a new plant configuration:

### ✅ Required Fields
- [ ] `plantName` - Display name
- [ ] `seedName` - Item name for seed
- [ ] `plantProps.stage1` - Early growth prop
- [ ] `plantProps.stage2` - Mid growth prop  
- [ ] `plantProps.stage3` - Mature growth prop
- [ ] `waterTimes` - Number of required waterings
- [ ] `timeToGrow` - Total growth time in seconds

### ✅ Optional Fields
- [ ] `requiresBaseFertilizer` - Require base fertilizer (default: false)
- [ ] `baseFertilizerItem` - Base fertilizer item name
- [ ] `smelling` - Can be detected by police (default: false)
- [ ] `rewards` - Items given when harvested

### ✅ Validation
- [ ] All prop names exist in game
- [ ] `waterTimes` is reasonable (1-5 recommended)
- [ ] `timeToGrow` is balanced for gameplay
- [ ] Reward amounts are economically balanced
- [ ] Plant fits server theme/style

---

## 🎯 Best Practices

### Visual Progression
1. **Start Small**: Stage 1 should be noticeably smaller/younger
2. **Clear Progression**: Each stage should be visually distinct
3. **Logical Growth**: Progression should make botanical sense
4. **Consistent Style**: All stages should match art style

### Gameplay Balance
1. **Water Requirements**: More valuable plants need more waterings
2. **Growth Time**: Balance time vs. reward value
3. **Fertilizer Needs**: High-value plants should require fertilizer
4. **Risk vs. Reward**: Illegal plants = higher risk = higher reward

### Server Performance
1. **Limit Unique Props**: Reuse props when possible
2. **Reasonable Limits**: Don't make 10-stage plants
3. **Test at Scale**: Verify performance with many plants
4. **Monitor Resources**: Watch memory and CPU usage

---

This flexible configuration system allows server owners to create diverse farming experiences while maintaining performance and ease of use.