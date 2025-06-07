# BCC-Farming NUI System v2.5.0

## Plant Status Display Widget

The BCC-Farming NUI system provides a real-time, visual plant status widget that appears when players are near their plants. This system uses the npp_farmstats framework for consistent styling with the server's UI theme.

---

## Features

### 🌱 **Real-time Plant Status**
- **Growth Progress**: Circular progress bar showing growth percentage and current stage
- **Watering Status**: Shows current watering count vs. maximum with efficiency percentage
- **Fertilizer Status**: Displays base fertilizer and enhanced fertilizer status
- **Expected Yield**: Shows calculated reward based on current conditions

### ⏱️ **Live Updates**
- **Time Remaining**: Real-time countdown to harvest readiness
- **Status Changes**: Automatic updates when plant conditions change
- **Proximity Detection**: Widget appears/disappears based on player distance

### 🎯 **Interactive Indicators**
- **Can Water**: Highlights when plant can be watered
- **Needs Fertilizer**: Warning indicator for missing base fertilizer
- **Ready to Harvest**: Success indicator when plant is ready

---

## Visual Elements

### Progress Bars
The NUI uses circular progress bars borrowed from the npp_farmstats framework:

- **Growth**: Green progress ring (0-100%)
- **Water**: Blue progress ring showing watering efficiency
- **Fertilizer**: Brown progress ring showing fertilizer status
- **Yield**: Gold display showing expected items

### Color Coding
- 🟢 **Green**: Growth progress, ready states
- 🔵 **Blue**: Water-related indicators
- 🟤 **Brown**: Fertilizer indicators
- 🟡 **Gold**: Yield and rewards
- 🟠 **Orange**: Warning states
- 🔴 **Red**: Critical warnings

---

## Configuration

### Basic Settings (`configs/nui_config.lua`)

```lua
NUIConfig.PlantStatus = {
    enabled = true,              -- Enable/disable NUI
    detectionRange = 3.0,        -- Plant detection range
    updateFrequency = 500,       -- Update rate (ms)
    autoHideDelay = 1000        -- Hide delay (ms)
}
```

### Position Settings
```lua
NUIConfig.position = {
    right = '2%',               -- Distance from right edge
    top = '20%',                -- Distance from top edge  
    width = '320px'             -- Widget width
}
```

### Visual Customization
```lua
NUIConfig.Visual = {
    colors = {
        growth = '#32CD32',      -- Customize colors
        water = '#1E90FF',
        fertilizer = '#8B4513',
        yield = '#FFD700'
    }
}
```

---

## Files Structure

```
bcc-farming/
├── ui/
│   ├── index.html           # Main NUI HTML
│   ├── plant-status.css     # Widget styles
│   └── plant-status.js      # Widget functionality
├── configs/
│   └── nui_config.lua       # NUI configuration
└── client/
    └── main_v2.lua          # Client integration
```

---

## Dependencies

- **npp_farmstats**: Required for UI framework and styling
- **vorp_core**: Required for notifications and core functionality
- **Font Awesome 6.1.2**: For icons (loaded via CDN)

---

## Integration

### Client-Side Events

The NUI system responds to these events:

```lua
-- Show plant status widget
TriggerEvent('bcc-farming:UpdatePlantStatus', plantStatusData)

-- Hide plant status widget
SendNUIMessage({type = 'hidePlantStatus'})

-- Update plant data
SendNUIMessage({
    type = 'showPlantStatus',
    plantData = {
        plantId = 1,
        name = 'Corn',
        stageName = 'Young Plant',
        growthProgress = 65.5,
        waterCount = 2,
        maxWater = 3,
        wateringEfficiency = 67,
        fertilized = true,
        expectedYield = 8,
        isReady = false,
        canWater = true,
        timeLeft = 1235
    }
})
```

### Data Structure

The plant status data includes:

```lua
plantData = {
    plantId = number,           -- Unique plant ID
    name = string,              -- Plant display name
    stageName = string,         -- Current growth stage name
    growthProgress = number,    -- Growth percentage (0-100)
    growthStage = number,       -- Current stage (1-3)
    waterCount = number,        -- Current watering count
    maxWater = number,          -- Maximum watering times
    wateringEfficiency = number, -- Watering efficiency percentage
    fertilized = boolean,       -- Base fertilizer applied
    requiresFertilizer = boolean, -- Whether base fertilizer is required
    fertilizerType = string,    -- Type of fertilizer applied
    expectedYield = number,     -- Expected item reward
    isReady = boolean,          -- Ready for harvest
    canWater = boolean,         -- Can be watered now
    timeLeft = number,          -- Seconds until ready
    timeLeftFormatted = string  -- Formatted time string
}
```

---

## Debug Commands

### Client Commands

```lua
-- Show plant status debug info
/farming-status

-- Toggle NUI visibility
/farming-nui-toggle

-- Show client debug information
/farming-client-debug
```

### Debug Mode

Enable debug mode in `nui_config.lua`:

```lua
NUIConfig.Advanced.debugMode = true
```

This will:
- Log NUI events to console
- Show additional debug information
- Enable test sample data

---

## Troubleshooting

### Widget Not Appearing
1. Check if `npp_farmstats` is running
2. Verify player is within detection range (3.0 units)
3. Ensure NUI is enabled in config
4. Check browser console for JavaScript errors

### Incorrect Data Display
1. Verify plant status data structure
2. Check server-side calculations
3. Ensure database has been migrated to v2.5.0
4. Test with debug commands

### Performance Issues
1. Increase `updateFrequency` in config
2. Enable caching in advanced settings
3. Reduce `detectionRange` if needed
4. Check for JavaScript console errors

---

## Browser Development

For UI development, you can test the widget in a browser:

1. Open `ui/index.html` in a browser
2. Uncomment the debug line in `plant-status.js`
3. Use browser developer tools to test
4. Use `debugShowSamplePlant()` in console

---

## Performance Notes

- Widget only updates when player is near plants
- Uses efficient proximity detection
- Automatic cleanup when resource stops
- Minimal resource usage when not visible
- Caching system to reduce server calls

---

## Future Enhancements

Planned features for future versions:
- Multi-plant overview mode
- Plant management shortcuts
- Statistics charts
- Custom themes support
- Mobile-responsive design

---

## Support

For issues with the NUI system:
1. Check console logs for errors
2. Verify all dependencies are installed
3. Test with debug commands
4. Check database migration status

The NUI system is designed to be lightweight, performant, and visually appealing while providing essential plant information at a glance.