game 'rdr3'
fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

lua54 'yes'
author 'Jake2k4'
description 'bcc-farming'

shared_scripts {
    'configs/*.lua',
    'locale.lua',
    'languages/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
<<<<<<< Updated upstream
    'server/services/*.lua'
=======
    'server/services/*.lua',
    -- NOVOS EXPORTS - FASE 1
    'server/exports/basic.lua',
    'server/exports/player.lua',
    'server/exports/production.lua',
    'server/exports/geographic.lua',
    'server/exports/notifications.lua'
>>>>>>> Stashed changes
}

client_scripts {
    'client/main.lua',
    'client/services/*.lua'
}

dependencies {
    'vorp_character',
    'vorp_inventory',
    'bcc-utils'
}

<<<<<<< Updated upstream
version '2.4.2'
=======
-- Exports disponíveis - FASE 1
exports {
    -- BÁSICOS (6 exports)
    'GetGlobalPlantCount',
    'GetGlobalPlantsByType', 
    'GetNearHarvestPlants',
    'GetFarmingOverview',
    'GetWateringStatus',
    
    -- JOGADORES (5 exports)
    'GetPlayerPlantCount',
    'GetPlayerPlants',
    'CanPlayerPlantMore',
    'GetPlayerFarmingStats',
    'GetPlayerComparison',
    
    -- PRODUÇÃO (5 exports)
    'GetEstimatedProduction',
    'GetTotalProductionPotential',
    'GetHourlyProductionForecast',
    'GetProductionEfficiency',
    'GetGrowthAnalysis',
    
    -- GEOGRÁFICOS (6 exports)
    'GetPlantsInRadius',
    'GetPlantDensity',
    'GetDominantPlantInArea',
    'IsValidPlantLocation',
    'FindBestPlantingAreas',
    'GetPlantConcentrationMap',
    
    -- NOTIFICAÇÕES (7 exports)
    'NotifyReadyPlants',
    'NotifyPlantsNeedWater', 
    'NotifyPlantLimits',
    'NotifyFarmingEvent',
    'SendDailyFarmingReport',
    'NotifyPlantSmelled',
    'PlantConcentrationMap'
}

version '2.4.2-exports'
>>>>>>> Stashed changes
