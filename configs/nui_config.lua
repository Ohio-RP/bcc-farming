-- =======================================
-- BCC-Farming NUI Configuration v2.5.0
-- Plant Status Display Settings
-- =======================================

NUIConfig = {}

-- =======================================
-- DISPLAY SETTINGS
-- =======================================

NUIConfig.PlantStatus = {
    -- Enable/disable plant status NUI
    enabled = true,
    
    -- Detection range for plant proximity (units)
    detectionRange = 1.0,
    
    -- Update frequency for plant status checks (milliseconds)
    updateFrequency = 500,
    
    -- Auto-hide delay when leaving plant range (milliseconds)
    autoHideDelay = 200,
    
    -- Animation settings
    animations = {
        fadeInDuration = 500,  -- milliseconds
        fadeOutDuration = 300, -- milliseconds
        enableAnimations = true
    },
    
    -- Position settings
    position = {
        right = '2%',      -- Distance from right edge
        top = '40%',       -- Distance from top edge
        width = '450px'    -- Widget width
    }
}

-- =======================================
-- LANGUAGE SETTINGS
-- =======================================

NUIConfig.Language = {
    -- Progress bar labels
    growth = 'Crescimento',
    water = 'Irrigação', 
    fertilizer = 'Fertilização',
    yield = 'Quantidade',
    
    -- Time labels
    timeLeft = 'Tempo Restante:',
    ready = 'Pronto',
    
    -- Action indicators
    canWater = 'Pode Irrigar',
    needsFertilizer = 'Precisa de Fertilizante',
    readyHarvest = 'Pronto para Colher!',
    
    -- Status messages
    growing = 'Crescendo...',
    needsWatering = 'Precisa Irrigar',
    needsFert = 'Precisa Fertilizar',
    harvestReady = 'Pronto para Colher',
    
    -- Fertilizer types
    fertilizerTypes = {
        base = 'Básico',
        enhanced = 'Melhorado',
        none = 'Nenhum',
        needed = 'Necessário',
        optional = 'Opcional'
    }
}

-- =======================================
-- VISUAL SETTINGS
-- =======================================

NUIConfig.Visual = {
    -- Color scheme
    colors = {
        growth = '#32CD32',      -- Green
        water = '#1E90FF',       -- Blue  
        fertilizer = '#8B4513',  -- Brown
        yield = '#FFD700',       -- Gold
        warning = '#FFA500',     -- Orange
        success = '#32CD32',     -- Green
        danger = '#FF4500'       -- Red
    },
    
    -- Progress bar settings
    progressBars = {
        size = '50px',
        thickness = '8px',
        animationSpeed = '0.3s'
    },
    
    -- Enable/disable specific indicators
    indicators = {
        showWaterIcon = true,
        showFertilizerIcon = true,
        showGrowthIcon = true,
        showYieldIcon = true,
        showTimeIcon = true,
        showActionIndicators = true
    }
}

-- =======================================
-- ADVANCED SETTINGS
-- =======================================

NUIConfig.Advanced = {
    -- Debug mode
    debugMode = false,
    
    -- Performance settings
    performance = {
        maxUpdateRate = 100,     -- Minimum milliseconds between updates
        enableCaching = true,    -- Cache plant data to reduce server calls
        cacheTimeout = 5000      -- Cache timeout in milliseconds
    },
    
    -- Responsive design breakpoints
    responsive = {
        smallScreen = 1366,      -- Width threshold for small screen adjustments
        lowHeight = 720          -- Height threshold for compact mode
    }
}

-- =======================================
-- EXPORT CONFIG
-- =======================================

-- Make config available to other files
_G.NUIConfig = NUIConfig