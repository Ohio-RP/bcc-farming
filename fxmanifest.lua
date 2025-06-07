game 'rdr3'
fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

lua54 'yes'
author 'Jake2k4'
description 'bcc-farming with advanced exports system'

shared_scripts {
    'configs/*.lua',
    'locale.lua',
    'languages/*.lua',
    'utils/bln_notify.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/database/setup.lua',
    'server/services/usableItems_v2.lua',
    'server/exports/basic_simple.lua',
    'server/exports/player_simple.lua',
    'server/nui_callbacks.lua',
    'testing/simplified_tests.lua',
    'testing/simple_tests.lua',
    'testing/bln_notify_test.lua',
    'testing/debug_stages.lua'
}

client_scripts {
    'client/main.lua',
    'client/services/prop_management.lua',
    'client/services/planting.lua',
    'client/services/planted.lua',
    'client/nui_integration.lua',
    'testing/bln_notify_test.lua',
    'testing/debug_stages.lua'
}

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/plant-status.css',
    'ui/plant-status.js',
    'ui/paper.png',
    'ui/fonts/*.ttf',
    'ui/fonts/*.otf',
}

dependencies {
    'vorp_character',
    'vorp_inventory',
    'bcc-utils',
    'npp_farmstats'
}

exports {
    -- ✅ WORKING BASIC EXPORTS (5)
    'GetGlobalPlantCount',
    'GetGlobalPlantsByType', 
    'GetFarmingOverview',
    'GetWateringStatus',
    'GetGrowthStageDistribution',
    
    -- ✅ WORKING PLAYER EXPORTS (4)
    'GetPlayerPlantCount',
    'GetPlayerPlants',
    'CanPlayerPlantMore',
    'GetPlayerFarmingStats'
}

version '2.5.0-enhanced'

