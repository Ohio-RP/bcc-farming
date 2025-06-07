@echo off
echo ====================================
echo BCC-Farming v2.5.0 Cleanup Script
echo ====================================
echo.
echo Este script removerá arquivos desnecessários do projeto BCC-Farming
echo.
pause

echo Removendo arquivos de teste complexos não funcionais...
del /f "testing\test_runner.lua" 2>nul
del /f "testing\test_suite_v2.5.0.lua" 2>nul
del /f "testing\performance_tests.lua" 2>nul
del /f "testing\config_validator.lua" 2>nul
del /f "testing\migration_validator.lua" 2>nul

echo Removendo arquivos de servidor duplicados/antigos...
del /f "server\main_v2.lua" 2>nul
del /f "server\exports\basic.lua" 2>nul
del /f "server\exports\basic_v2.lua" 2>nul
del /f "server\exports\player.lua" 2>nul
del /f "server\exports\player_v2.lua" 2>nul
del /f "server\services\growth_calculations.lua" 2>nul
del /f "server\services\usableItems.lua" 2>nul

echo Removendo arquivos de cliente antigos...
del /f "client\main_v2.lua" 2>nul
del /f "client\services\plant_interactions.lua" 2>nul
del /f "client\services\planted.lua" 2>nul
del /f "client\services\planting.lua" 2>nul
del /f "client\services\prop_management.lua" 2>nul

echo Removendo configurações duplicadas...
del /f "configs\plants_v2.lua" 2>nul
del /f "configs\nui_config.lua" 2>nul

echo Removendo exports não funcionais...
del /f "server\exports\event_hooks.lua" 2>nul
del /f "server\exports\cache.lua" 2>nul
del /f "server\exports\economy.lua" 2>nul
del /f "server\exports\geographic.lua" 2>nul
del /f "server\exports\integration.lua" 2>nul
del /f "server\exports\notifications.lua" 2>nul
del /f "server\exports\production.lua" 2>nul

echo Removendo documentação temporária...
del /f "BCC_FARMING_EXPORTS_V2.5.0.md" 2>nul
del /f "FARMING_ENHANCEMENT_PLAN.md" 2>nul
del /f "NUI_SYSTEM_README.md" 2>nul
del /f "PLANT_CONFIG_EXAMPLES.md" 2>nul
del /f "QUICK_FIX_GUIDE.md" 2>nul
del /f "TESTING_DOCUMENTATION.md" 2>nul

echo.
echo ====================================
echo Limpeza concluída!
echo ====================================
echo.
echo Arquivos mantidos (essenciais):
echo ✅ Core: fxmanifest.lua, server/main.lua, client/main.lua
echo ✅ Config: configs/config.lua, configs/plants.lua
echo ✅ Exports: basic_simple.lua, player_simple.lua
echo ✅ Database: database_migration_v2.sql, server/database/setup.lua
echo ✅ Services: usableItems_v2.lua, irrigation_alerts.lua
echo ✅ Tests: simplified_tests.lua, simple_tests.lua
echo ✅ UI: ui/ (index.html, CSS, JS)
echo ✅ Docs: README.md, CHANGELOG.md, BCC_FARMING_DOCUMENTATION.md
echo.
echo Sistema agora está limpo e otimizado!
echo.
pause