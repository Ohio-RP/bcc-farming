-- server/database/setup.lua
-- FASE 2 - Setup automático do banco de dados

local function ExecuteSQL(query, description)
    local success, result = pcall(function()
        return MySQL.query.await(query)
    end)
    
    if success then
        print(string.format("^2[BCC-Farming DB]^7 %s - ✅ Sucesso", description))
        return true
    else
        print(string.format("^1[BCC-Farming DB]^7 %s - ❌ Erro: %s", description, tostring(result)))
        return false
    end
end

local function SetupPhase2Database()
    print("^3[BCC-Farming]^7 Iniciando setup da FASE 2...")
    
    -- 1. Adicionar colunas otimizadas para performance
    print("^3[BCC-Farming]^7 Adicionando colunas otimizadas...")
    
    ExecuteSQL([[
        ALTER TABLE `bcc_farming` 
        ADD COLUMN IF NOT EXISTS `coord_x` FLOAT GENERATED ALWAYS AS (JSON_EXTRACT(plant_coords, '$.x')) STORED,
        ADD COLUMN IF NOT EXISTS `coord_y` FLOAT GENERATED ALWAYS AS (JSON_EXTRACT(plant_coords, '$.y')) STORED,
        ADD COLUMN IF NOT EXISTS `coord_z` FLOAT GENERATED ALWAYS AS (JSON_EXTRACT(plant_coords, '$.z')) STORED,
        ADD COLUMN IF NOT EXISTS `time_left_int` INT GENERATED ALWAYS AS (CAST(time_left AS UNSIGNED)) STORED,
        ADD COLUMN IF NOT EXISTS `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        ADD COLUMN IF NOT EXISTS `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ]], "Adicionando colunas otimizadas")
    
    -- 2. Criar índices para performance
    print("^3[BCC-Farming]^7 Criando índices...")
    
    ExecuteSQL([[
        CREATE INDEX IF NOT EXISTS `idx_coords` ON `bcc_farming`(`coord_x`, `coord_y`, `coord_z`)
    ]], "Índice de coordenadas")
    
    ExecuteSQL([[
        CREATE INDEX IF NOT EXISTS `idx_time_left` ON `bcc_farming`(`time_left_int`)
    ]], "Índice de tempo restante")
    
    ExecuteSQL([[
        CREATE INDEX IF NOT EXISTS `idx_plant_type` ON `bcc_farming`(`plant_type`)
    ]], "Índice de tipo de planta")
    
    ExecuteSQL([[
        CREATE INDEX IF NOT EXISTS `idx_plant_owner` ON `bcc_farming`(`plant_owner`)
    ]], "Índice de proprietário")
    
    ExecuteSQL([[
        CREATE INDEX IF NOT EXISTS `idx_plant_watered` ON `bcc_farming`(`plant_watered`)
    ]], "Índice de status de rega")
    
    -- 3. Criar tabela de histórico
    print("^3[BCC-Farming]^7 Criando tabela de histórico...")
    
    ExecuteSQL([[
        CREATE TABLE IF NOT EXISTS `bcc_farming_history` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `plant_type` VARCHAR(40) NOT NULL,
            `action` ENUM('planted', 'harvested', 'destroyed', 'watered', 'fertilized') NOT NULL,
            `quantity` INT DEFAULT 1,
            `player_id` INT NOT NULL,
            `coords_x` FLOAT,
            `coords_y` FLOAT,
            `coords_z` FLOAT,
            `extra_data` JSON DEFAULT NULL,
            `timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX `idx_plant_type_action` (`plant_type`, `action`),
            INDEX `idx_timestamp` (`timestamp`),
            INDEX `idx_player_id` (`player_id`),
            INDEX `idx_action` (`action`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]], "Tabela de histórico")
    
    -- 4. Criar tabela de estatísticas de mercado
    print("^3[BCC-Farming]^7 Criando tabela de estatísticas de mercado...")
    
    ExecuteSQL([[
        CREATE TABLE IF NOT EXISTS `bcc_farming_market_stats` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `plant_type` VARCHAR(40) NOT NULL UNIQUE,
            `total_planted` INT DEFAULT 0,
            `total_harvested` INT DEFAULT 0,
            `total_destroyed` INT DEFAULT 0,
            `active_plants` INT DEFAULT 0,
            `avg_growth_time` INT DEFAULT 0,
            `last_update` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            `scarcity_index` DECIMAL(3,2) DEFAULT 0.50,
            `trend` ENUM('growing', 'stable', 'declining') DEFAULT 'stable',
            `base_price` DECIMAL(10,2) DEFAULT 1.00,
            `current_price_multiplier` DECIMAL(3,2) DEFAULT 1.00,
            INDEX `idx_plant_type` (`plant_type`),
            INDEX `idx_scarcity` (`scarcity_index`),
            INDEX `idx_trend` (`trend`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]], "Tabela de estatísticas de mercado")
    
    -- 5. Criar tabela de cache do sistema
    print("^3[BCC-Farming]^7 Criando tabela de cache...")
    
    ExecuteSQL([[
        CREATE TABLE IF NOT EXISTS `bcc_farming_cache` (
            `cache_key` VARCHAR(255) PRIMARY KEY,
            `cache_data` LONGTEXT NOT NULL,
            `expires_at` TIMESTAMP NOT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX `idx_expires` (`expires_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]], "Tabela de cache")
    
    -- 6. Criar tabela de configurações dinâmicas
    print("^3[BCC-Farming]^7 Criando tabela de configurações...")
    
    ExecuteSQL([[
        CREATE TABLE IF NOT EXISTS `bcc_farming_config` (
            `config_key` VARCHAR(100) PRIMARY KEY,
            `config_value` LONGTEXT NOT NULL,
            `config_type` ENUM('string', 'number', 'boolean', 'json') DEFAULT 'string',
            `description` TEXT,
            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            `updated_by` VARCHAR(100)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]], "Tabela de configurações")
    
    -- 7. Criar tabela de alertas e notificações
    print("^3[BCC-Farming]^7 Criando tabela de alertas...")
    
    ExecuteSQL([[
        CREATE TABLE IF NOT EXISTS `bcc_farming_alerts` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `player_id` INT NOT NULL,
            `alert_type` ENUM('plant_ready', 'need_water', 'limit_reached', 'market_change', 'daily_report') NOT NULL,
            `plant_type` VARCHAR(40),
            `message` TEXT NOT NULL,
            `data` JSON DEFAULT NULL,
            `is_read` BOOLEAN DEFAULT FALSE,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `expires_at` TIMESTAMP NULL,
            INDEX `idx_player_alerts` (`player_id`, `is_read`),
            INDEX `idx_alert_type` (`alert_type`),
            INDEX `idx_expires` (`expires_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]], "Tabela de alertas")
    
    -- 8. Inserir configurações padrão
    print("^3[BCC-Farming]^7 Inserindo configurações padrão...")
    
    ExecuteSQL([[
        INSERT IGNORE INTO `bcc_farming_config` (`config_key`, `config_value`, `config_type`, `description`) VALUES
        ('economy_enabled', 'true', 'boolean', 'Habilitar sistema de economia dinâmica'),
        ('cache_ttl_default', '300', 'number', 'TTL padrão do cache em segundos'),
        ('cache_ttl_market', '600', 'number', 'TTL do cache de mercado em segundos'),
        ('scarcity_calculation_hours', '24', 'number', 'Horas para cálculo de escassez'),
        ('price_update_interval', '1800', 'number', 'Intervalo de atualização de preços em segundos'),
        ('auto_notifications', 'true', 'boolean', 'Notificações automáticas habilitadas'),
        ('notification_ready_threshold', '600', 'number', 'Tempo em segundos para notificar plantas prontas'),
        ('daily_report_enabled', 'true', 'boolean', 'Relatórios diários habilitados'),
        ('market_volatility', '0.3', 'number', 'Volatilidade do mercado (0.0 a 1.0)')
    ]], "Configurações padrão")
    
    -- 9. Inicializar estatísticas de mercado para plantas existentes
    print("^3[BCC-Farming]^7 Inicializando estatísticas de mercado...")
    
    ExecuteSQL([[
        INSERT IGNORE INTO `bcc_farming_market_stats` (`plant_type`, `base_price`)
        SELECT DISTINCT `plant_type`, 1.00
        FROM `bcc_farming`
    ]], "Estatísticas iniciais de mercado")
    
    -- 10. Criar triggers para manter dados sincronizados
    print("^3[BCC-Farming]^7 Criando triggers de sincronização...")
    
    ExecuteSQL([[
        DROP TRIGGER IF EXISTS `bcc_farming_after_insert`
    ]], "Removendo trigger antigo")
    
    ExecuteSQL([[
        CREATE TRIGGER `bcc_farming_after_insert`
        AFTER INSERT ON `bcc_farming`
        FOR EACH ROW
        BEGIN
            INSERT INTO `bcc_farming_history` 
            (`plant_type`, `action`, `quantity`, `player_id`, `coords_x`, `coords_y`, `coords_z`)
            VALUES 
            (NEW.plant_type, 'planted', 1, NEW.plant_owner, NEW.coord_x, NEW.coord_y, NEW.coord_z);
            
            UPDATE `bcc_farming_market_stats` 
            SET `total_planted` = `total_planted` + 1,
                `active_plants` = (SELECT COUNT(*) FROM `bcc_farming` WHERE `plant_type` = NEW.plant_type)
            WHERE `plant_type` = NEW.plant_type;
        END
    ]], "Trigger de inserção")
    
    ExecuteSQL([[
        DROP TRIGGER IF EXISTS `bcc_farming_after_delete`
    ]], "Removendo trigger antigo")
    
    ExecuteSQL([[
        CREATE TRIGGER `bcc_farming_after_delete`
        AFTER DELETE ON `bcc_farming`
        FOR EACH ROW
        BEGIN
            UPDATE `bcc_farming_market_stats` 
            SET `active_plants` = (SELECT COUNT(*) FROM `bcc_farming` WHERE `plant_type` = OLD.plant_type)
            WHERE `plant_type` = OLD.plant_type;
        END
    ]], "Trigger de deleção")
    
    -- 11. Evento de limpeza automática
    print("^3[BCC-Farming]^7 Configurando limpeza automática...")
    
    ExecuteSQL([[
        CREATE EVENT IF NOT EXISTS `bcc_farming_cleanup`
        ON SCHEDULE EVERY 1 HOUR
        DO
        BEGIN
            -- Limpar cache expirado
            DELETE FROM `bcc_farming_cache` WHERE `expires_at` < NOW();
            
            -- Limpar alertas expirados
            DELETE FROM `bcc_farming_alerts` WHERE `expires_at` IS NOT NULL AND `expires_at` < NOW();
            
            -- Limpar histórico muito antigo (mais de 30 dias)
            DELETE FROM `bcc_farming_history` WHERE `timestamp` < DATE_SUB(NOW(), INTERVAL 30 DAY);
        END
    ]], "Evento de limpeza automática")
    
    print("^2[BCC-Farming]^7 Setup da FASE 2 concluído com sucesso! ✅")
    print("^3[BCC-Farming]^7 Funcionalidades adicionadas:")
    print("  • Sistema de cache otimizado")
    print("  • Histórico completo de ações")
    print("  • Economia dinâmica com preços")
    print("  • Sistema de alertas e notificações")
    print("  • Índices para alta performance")
    print("  • Triggers automáticos")
    print("  • Limpeza automática de dados")
end

-- Executar setup na inicialização
CreateThread(function()
    Wait(2000) -- Aguardar inicialização do MySQL
    SetupPhase2Database()
end)

-- Comando para re-executar setup (apenas console)
RegisterCommand('farming-setup-db', function(source)
    if source ~= 0 then return end -- Apenas console
    print("^3[BCC-Farming]^7 Re-executando setup do banco de dados...")
    SetupPhase2Database()
end)