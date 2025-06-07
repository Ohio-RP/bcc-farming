/* ===================================
   BCC-Farming Notebook Style NUI Logic
   ==================================== */

// Global state
let isVisible = false;
let currentPlantData = null;
let updateInterval = null;

// DOM Elements
const widget = document.getElementById('plant-status-widget');
const plantName = document.getElementById('plant-name');
const plantImage = document.getElementById('plant-image');
const harvestAmount = document.getElementById('harvest-amount');
const plantNotes = document.getElementById('plant-notes');

// Checkbox containers
const growthCheckboxes = document.getElementById('growth-checkboxes');
const timeCheckboxes = document.getElementById('time-checkboxes');
const fertilizerCheckboxes = document.getElementById('fertilizer-checkboxes');
const waterCheckboxes = document.getElementById('water-checkboxes');

// ===========================================
// MESSAGE HANDLERS
// ===========================================

window.addEventListener('message', function(event) {
    const data = event.data;
    
    switch(data.action || data.type) {
        case 'showPlantStatus':
            showPlantStatus(data.plantData);
            break;
        case 'hidePlantStatus':
            hidePlantStatus();
            break;
        case 'updatePlantStatus':
            updatePlantStatus(data.plantData);
            break;
    }
});

// ===========================================
// DISPLAY FUNCTIONS
// ===========================================

function showPlantStatus(plantData) {
    if (!plantData) return;
    
    currentPlantData = plantData;
    updateNotebookDisplay(plantData);
    
    if (!isVisible) {
        // Force transparency before showing
        forceTransparency();
        
        widget.style.display = 'block';
        widget.classList.remove('fade-out');
        widget.classList.add('fade-in');
        isVisible = true;
        
        // Start update interval for time countdown
        startUpdateInterval();
        
        // Force transparency again after display
        setTimeout(() => forceTransparency(), 100);
    }
}

function hidePlantStatus() {
    if (isVisible) {
        widget.classList.remove('fade-in');
        widget.classList.add('fade-out');
        
        setTimeout(() => {
            widget.style.display = 'none';
            isVisible = false;
            currentPlantData = null;
            stopUpdateInterval();
        }, 300);
    }
}

function updatePlantStatus(plantData) {
    if (isVisible && plantData) {
        currentPlantData = plantData;
        updateNotebookDisplay(plantData);
    }
}

// ===========================================
// NOTEBOOK UPDATE LOGIC
// ===========================================

// Note: Scratches font supports accents, no need to remove them

function updateNotebookDisplay(plantData) {
    console.log('📝 Updating notebook with plant data:', plantData);
    
    // Update plant name
    if (plantName) {
        plantName.textContent = plantData.plantName || 'Planta Desconhecida';
    }
    
    // Update plant image using first reward item
    if (plantImage && plantData.rewards && plantData.rewards.length > 0) {
        const firstReward = plantData.rewards[0];
        const itemName = firstReward.itemName || firstReward.itemLabel;
        const imageUrl = `https://cfx-nui-vorp_inventory/html/img/items/${itemName.toLowerCase()}.png`;
        
        console.log(`[BCC-Farming] 🖼️ Loading image: ${imageUrl}`);
        console.log(`[BCC-Farming] First reward:`, firstReward);
        
        plantImage.src = imageUrl;
        plantImage.style.display = 'block';
        
        // Hide image if fails to load
        plantImage.onerror = function() {
            console.log(`[BCC-Farming] ❌ Failed to load image: ${imageUrl}`);
            this.style.display = 'none';
        };
        
        plantImage.onload = function() {
            console.log(`[BCC-Farming] ✅ Image loaded successfully: ${imageUrl}`);
        };
    } else {
        console.log('[BCC-Farming] ⚠️ No rewards data available for image');
    }
    
    // Update Growth checkboxes (3 stages)
    updateGrowthCheckboxes(plantData.stageNumber || plantData.growthStage || 1);
    
    // Update Time checkboxes (5 periods of 20% each)
    updateTimeCheckboxes(plantData);
    
    // Update Fertilizer checkbox (1 checkbox)
    updateFertilizerCheckboxes(plantData.baseFertilized || false);
    
    // Update Water checkboxes (based on waterCount/maxWaterTimes)
    updateWaterCheckboxes(plantData.waterCount || 0, plantData.maxWaterTimes || 1);
    
    // Update Harvest amount
    updateHarvestAmount(plantData);
    
    // Update notes section
    updateNotesSection(plantData);
}

function updateGrowthCheckboxes(currentStage) {
    if (!growthCheckboxes) return;
    
    const checkboxes = growthCheckboxes.querySelectorAll('.checkbox');
    checkboxes.forEach((checkbox, index) => {
        const stageNumber = index + 1;
        if (stageNumber <= currentStage) {
            checkbox.classList.add('checked');
        } else {
            checkbox.classList.remove('checked');
        }
    });
}

function updateTimeCheckboxes(plantData) {
    if (!timeCheckboxes) return;
    
    // Calculate time progress (0-100%)
    let timeProgress = 0;
    if (plantData.timeLeft !== undefined && plantData.timeToGrow) {
        const elapsedTime = plantData.timeToGrow - plantData.timeLeft;
        timeProgress = Math.min(100, (elapsedTime / plantData.timeToGrow) * 100);
    } else if (plantData.overallProgress !== undefined) {
        timeProgress = plantData.overallProgress;
    }
    
    // Convert to checkboxes (5 checkboxes = 20% each)
    const timeChecks = Math.floor(timeProgress / 20);
    
    const checkboxes = timeCheckboxes.querySelectorAll('.checkbox');
    checkboxes.forEach((checkbox, index) => {
        if (index < timeChecks) {
            checkbox.classList.add('checked');
        } else {
            checkbox.classList.remove('checked');
        }
    });
}

function updateFertilizerCheckboxes(isFertilized) {
    if (!fertilizerCheckboxes) return;
    
    const checkbox = fertilizerCheckboxes.querySelector('.checkbox');
    if (checkbox) {
        if (isFertilized) {
            checkbox.classList.add('checked');
        } else {
            checkbox.classList.remove('checked');
        }
    }
}

function updateWaterCheckboxes(waterCount, maxWaterTimes) {
    if (!waterCheckboxes) return;
    
    const checkboxes = waterCheckboxes.querySelectorAll('.checkbox');
    
    // Show only necessary checkboxes for this plant
    checkboxes.forEach((checkbox, index) => {
        if (index < maxWaterTimes) {
            checkbox.style.display = 'inline-block';
            if (index < waterCount) {
                checkbox.classList.add('checked');
            } else {
                checkbox.classList.remove('checked');
            }
        } else {
            checkbox.style.display = 'none';
        }
    });
}

function updateHarvestAmount(plantData) {
    if (!harvestAmount) return;
    
    const yieldAmount = calculateExpectedYield(plantData);
    const amountText = harvestAmount.querySelector('.amount-text');
    
    if (amountText) {
        amountText.textContent = `${yieldAmount}x`;
    }
}

function updateNotesSection(plantData) {
    if (!plantNotes) return;
    
    let notes = [];
    
    // Add status-based notes
    if (plantData.isReady) {
        notes.push("🌾 Pronto para colheita!");
    } else {
        // Check what the plant needs
        const needsWater = (plantData.waterCount || 0) < (plantData.maxWaterTimes || 1);
        const needsFertilizer = plantData.requiresBaseFertilizer && !plantData.baseFertilized;
        
        if (needsWater && needsFertilizer) {
            notes.push("💧 Precisa de água");
            notes.push("🧪 Precisa de fertilizante");
        } else if (needsWater) {
            notes.push("💧 Precisa de água");
        } else if (needsFertilizer) {
            notes.push("🧪 Precisa de fertilizante");
        } else {
            notes.push("🌱 Crescendo normalmente...");
        }
        
        // Add time information
        if (plantData.timeLeft > 0) {
            const timeFormatted = formatTime(plantData.timeLeft);
            notes.push("⏰ " + timeFormatted + " restantes");
        }
    }
    
    // Add fertilizer type if available
    if (plantData.baseFertilized && plantData.fertilizerType && plantData.fertilizerType !== 'NULL') {
        notes.push("🧪 " + plantData.fertilizerType);
    }
    
    // Add efficiency info
    if (plantData.waterCount > 0 && plantData.maxWaterTimes > 0) {
        const efficiency = Math.floor((plantData.waterCount / plantData.maxWaterTimes) * 100);
        notes.push("📈 Eficiência: " + efficiency + "%");
    }
    
    plantNotes.textContent = notes.join('\n');
}

// ===========================================
// UTILITY FUNCTIONS
// ===========================================

// Calculate expected yield based on various factors
function calculateExpectedYield(plantData) {
    if (!plantData.rewards || !Array.isArray(plantData.rewards)) {
        return 1; // Default yield
    }
    
    let baseYield = 0;
    
    // Sum all reward amounts
    plantData.rewards.forEach(reward => {
        baseYield += reward.amount || 1;
    });
    
    // Apply fertilizer bonus (usually 10-20% increase)
    if (plantData.baseFertilized) {
        baseYield = Math.floor(baseYield * 1.15); // 15% bonus
    }
    
    // Apply watering efficiency bonus
    if (plantData.waterCount && plantData.maxWaterTimes) {
        const waterEfficiency = plantData.waterCount / plantData.maxWaterTimes;
        if (waterEfficiency >= 1.0) {
            baseYield = Math.floor(baseYield * 1.1); // 10% bonus for full watering
        }
    }
    
    // Apply growth stage bonus
    const currentStage = plantData.stageNumber || plantData.growthStage || 1;
    if (currentStage >= 3) {
        baseYield = Math.floor(baseYield * 1.05); // 5% bonus for full growth
    }
    
    return Math.max(1, baseYield); // Minimum 1 item
}

function formatTime(seconds) {
    if (seconds <= 0) return 'Pronto';
    
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;
    
    if (hours > 0) {
        return `${hours}h ${minutes}m`;
    } else if (minutes > 0) {
        return `${minutes}m ${secs}s`;
    } else {
        return `${secs}s`;
    }
}

function startUpdateInterval() {
    if (updateInterval) clearInterval(updateInterval);
    
    updateInterval = setInterval(() => {
        if (currentPlantData && currentPlantData.timeLeft > 0) {
            currentPlantData.timeLeft--;
            updateTimeCheckboxes(currentPlantData);
            updateNotesSection(currentPlantData);
            
            // Check if plant is now ready
            if (currentPlantData.timeLeft <= 0) {
                currentPlantData.isReady = true;
                updateNotesSection(currentPlantData);
            }
        }
    }, 1000);
}

function stopUpdateInterval() {
    if (updateInterval) {
        clearInterval(updateInterval);
        updateInterval = null;
    }
}

// Function to force transparency on background elements
function forceTransparency() {
    const elementsToMakeTransparent = [
        document.documentElement, // <html>
        document.body,           // <body>
        document.getElementById('app')
    ];
    
    elementsToMakeTransparent.forEach(element => {
        if (element) {
            element.style.setProperty('background', 'transparent', 'important');
            element.style.setProperty('background-color', 'transparent', 'important');
        }
    });
    
    console.log('[BCC-Farming] Transparência forçada nos elementos container');
}

// ===========================================
// DEBUG FUNCTIONS (for development)
// ===========================================

function debugShowSamplePlant() {
    const sampleData = {
        plantId: 1,
        plantName: 'Plantação de Milho',
        plantType: 'corn_seed',
        stageNumber: 2,
        stageName: 'Planta Jovem',
        growthStage: 2,
        overallProgress: 45.5,
        timeLeft: 850,
        timeToGrow: 1200,
        waterCount: 2,
        maxWaterTimes: 3,
        baseFertilized: true,
        requiresBaseFertilizer: true,
        fertilizerType: 'Fertilizante Básico',
        isReady: false,
        waterEfficiency: 67,
        rewards: [
            { itemName: 'corn', itemLabel: 'Milho', amount: 3 },
            { itemName: 'corn_seed', itemLabel: 'Semente de Milho', amount: 1 }
        ]
    };
    
    showPlantStatus(sampleData);
}

// Make debug function available globally
window.debugShowSamplePlant = debugShowSamplePlant;

// ===========================================
// INITIALIZATION
// ===========================================

document.addEventListener('DOMContentLoaded', function() {
    console.log('[BCC-Farming] 📝 Notebook NUI carregado com sucesso');
    
    // Hide widget initially
    widget.style.display = 'none';
    
    // Force transparency on all container elements
    forceTransparency();
    
    // Debug mode - uncomment to test in browser
    // setTimeout(() => debugShowSamplePlant(), 1000);
    
    // Scratches font supports full accent characters
    console.log('[BCC-Farming] ✅ Interface carregada com suporte completo à acentuação');
});

// Handle resource stop
window.addEventListener('beforeunload', function() {
    stopUpdateInterval();
});