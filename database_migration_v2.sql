-- BCC-Farming Database Migration Script v2.0
-- Multi-Stage Growth, Multi-Watering & Base Fertilizer Enhancement
-- Run this script to upgrade from v2.4.2 to v2.5.0

-- =====================================================
-- BACKUP EXISTING DATA (IMPORTANT!)
-- =====================================================
-- Before running this migration, backup your existing data:
-- CREATE TABLE bcc_farming_backup_v242 AS SELECT * FROM bcc_farming;

-- =====================================================
-- 1. ADD NEW COLUMNS TO EXISTING TABLE
-- =====================================================

-- Add growth stage tracking
ALTER TABLE `bcc_farming` ADD COLUMN `growth_stage` TINYINT(1) DEFAULT 1 COMMENT 'Current growth stage (1-3)';
ALTER TABLE `bcc_farming` ADD COLUMN `growth_progress` FLOAT(5,2) DEFAULT 0.00 COMMENT 'Growth percentage (0.00-100.00)';

-- Add multi-watering system
ALTER TABLE `bcc_farming` ADD COLUMN `water_count` TINYINT(3) DEFAULT 0 COMMENT 'Times watered so far';
ALTER TABLE `bcc_farming` ADD COLUMN `max_water_times` TINYINT(3) DEFAULT 1 COMMENT 'Maximum required waterings';

-- Add fertilizer system
ALTER TABLE `bcc_farming` ADD COLUMN `base_fertilized` BOOLEAN DEFAULT FALSE COMMENT 'Base fertilizer applied';
ALTER TABLE `bcc_farming` ADD COLUMN `fertilizer_type` VARCHAR(50) DEFAULT NULL COMMENT 'Type of fertilizer used';
ALTER TABLE `bcc_farming` ADD COLUMN `fertilizer_reduction` FLOAT(3,2) DEFAULT 0.00 COMMENT 'Time reduction from fertilizer';

-- Add enhanced tracking
ALTER TABLE `bcc_farming` ADD COLUMN `total_growth_time` INT(11) DEFAULT NULL COMMENT 'Original total growth time';
ALTER TABLE `bcc_farming` ADD COLUMN `last_watered` TIMESTAMP NULL DEFAULT NULL COMMENT 'Last watering time';
ALTER TABLE `bcc_farming` ADD COLUMN `fertilized_at` TIMESTAMP NULL DEFAULT NULL COMMENT 'Fertilizer application time';

-- =====================================================
-- 2. CREATE NEW SUPPORTING TABLES
-- =====================================================

-- Plant growth stages configuration
CREATE TABLE IF NOT EXISTS `bcc_farming_growth_stages` (
    `stage_id` TINYINT(1) NOT NULL,
    `stage_name` VARCHAR(50) NOT NULL,
    `min_progress` FLOAT(5,2) NOT NULL,
    `max_progress` FLOAT(5,2) NOT NULL,
    `description` TEXT NULL,
    PRIMARY KEY (`stage_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insert default growth stages
INSERT INTO `bcc_farming_growth_stages` (`stage_id`, `stage_name`, `min_progress`, `max_progress`, `description`) VALUES
(1, 'Seedling', 0.00, 30.00, 'Early growth stage - small seedling'),
(2, 'Young Plant', 30.01, 60.00, 'Mid growth stage - developing plant'),
(3, 'Mature Plant', 60.01, 100.00, 'Final growth stage - ready for harvest');

-- Plant watering history
CREATE TABLE IF NOT EXISTS `bcc_farming_watering_log` (
    `log_id` INT(11) NOT NULL AUTO_INCREMENT,
    `plant_id` INT(40) NOT NULL,
    `player_id` INT(40) NOT NULL,
    `watered_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `water_type` VARCHAR(50) DEFAULT 'clean_water',
    `growth_progress_at_time` FLOAT(5,2) DEFAULT 0.00,
    PRIMARY KEY (`log_id`),
    KEY `idx_plant_id` (`plant_id`),
    KEY `idx_player_id` (`player_id`),
    FOREIGN KEY (`plant_id`) REFERENCES `bcc_farming` (`plant_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Plant fertilizer history
CREATE TABLE IF NOT EXISTS `bcc_farming_fertilizer_log` (
    `log_id` INT(11) NOT NULL AUTO_INCREMENT,
    `plant_id` INT(40) NOT NULL,
    `player_id` INT(40) NOT NULL,
    `fertilizer_type` VARCHAR(50) NOT NULL,
    `reduction_amount` FLOAT(3,2) NOT NULL,
    `applied_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `growth_progress_at_time` FLOAT(5,2) DEFAULT 0.00,
    PRIMARY KEY (`log_id`),
    KEY `idx_plant_id` (`plant_id`),
    KEY `idx_player_id` (`player_id`),
    FOREIGN KEY (`plant_id`) REFERENCES `bcc_farming` (`plant_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- 3. MIGRATE EXISTING DATA
-- =====================================================

-- Set default values for existing plants based on current system
UPDATE `bcc_farming` SET 
    `total_growth_time` = CAST(`time_left` AS UNSIGNED) + 1200 -- Estimate original time (current time_left + 20 min default)
WHERE `total_growth_time` IS NULL;

-- Calculate current growth progress for existing plants
UPDATE `bcc_farming` SET 
    `growth_progress` = CASE 
        WHEN `total_growth_time` > 0 THEN 
            GREATEST(0, LEAST(100, (((`total_growth_time` - CAST(`time_left` AS UNSIGNED)) / `total_growth_time`) * 100)))
        ELSE 100
    END
WHERE `growth_progress` = 0.00;

-- Set growth stage based on progress
UPDATE `bcc_farming` SET 
    `growth_stage` = CASE 
        WHEN `growth_progress` <= 30 THEN 1
        WHEN `growth_progress` <= 60 THEN 2
        ELSE 3
    END
WHERE `growth_stage` = 1 AND `growth_progress` > 0;

-- Set water count based on current watered status
UPDATE `bcc_farming` SET 
    `water_count` = CASE 
        WHEN `plant_watered` = 'true' THEN 1
        ELSE 0
    END,
    `max_water_times` = 1 -- Default to 1 for existing plants
WHERE `water_count` = 0;

-- Set last watered time for currently watered plants
UPDATE `bcc_farming` SET 
    `last_watered` = `plant_time`
WHERE `plant_watered` = 'true' AND `last_watered` IS NULL;

-- =====================================================
-- 4. ADD INDEXES FOR PERFORMANCE
-- =====================================================

-- Growth stage index
ALTER TABLE `bcc_farming` ADD INDEX `idx_growth_stage` (`growth_stage`);

-- Growth progress index  
ALTER TABLE `bcc_farming` ADD INDEX `idx_growth_progress` (`growth_progress`);

-- Water count index
ALTER TABLE `bcc_farming` ADD INDEX `idx_water_count` (`water_count`, `max_water_times`);

-- Fertilizer status index
ALTER TABLE `bcc_farming` ADD INDEX `idx_fertilizer_status` (`base_fertilized`, `fertilizer_type`);

-- Combined performance index
ALTER TABLE `bcc_farming` ADD INDEX `idx_plant_status` (`growth_stage`, `water_count`, `base_fertilized`);

-- =====================================================
-- 5. UPDATE ITEMS TABLE (NEW FERTILIZER ITEMS)
-- =====================================================

-- Add base fertilizer item if it doesn't exist
INSERT INTO `items`(`item`, `label`, `limit`, `can_remove`, `type`, `usable`, `desc`)
VALUES ('fertilizer', 'Basic Fertilizer', 10, 1, 'item_standard', 1, 'Essential fertilizer for healthy plant growth.')
ON DUPLICATE KEY UPDATE 
    `label` = 'Basic Fertilizer',
    `desc` = 'Essential fertilizer for healthy plant growth.';

-- Update existing fertilizers with better descriptions
UPDATE `items` SET 
    `desc` = 'Low grade fertilizer. Reduces growth time by 10%.'
WHERE `item` = 'fertilizer1';

UPDATE `items` SET 
    `desc` = 'Mid grade fertilizer. Reduces growth time by 20%.'
WHERE `item` = 'fertilizer2';

UPDATE `items` SET 
    `desc` = 'High grade fertilizer. Reduces growth time by 30%.'
WHERE `item` = 'fertilizer3';

-- =====================================================
-- 6. CREATE VIEWS FOR EASY DATA ACCESS
-- =====================================================

-- View for plant status overview
CREATE OR REPLACE VIEW `v_bcc_farming_status` AS
SELECT 
    f.plant_id,
    f.plant_type,
    f.plant_owner,
    f.growth_stage,
    s.stage_name,
    f.growth_progress,
    f.water_count,
    f.max_water_times,
    ROUND((f.water_count / f.max_water_times) * 100, 2) as water_efficiency,
    f.base_fertilized,
    f.fertilizer_type,
    f.fertilizer_reduction,
    CAST(f.time_left AS UNSIGNED) as time_left_seconds,
    f.plant_time as planted_at,
    f.last_watered,
    f.fertilized_at
FROM `bcc_farming` f
LEFT JOIN `bcc_farming_growth_stages` s ON f.growth_stage = s.stage_id;

-- View for ready plants
CREATE OR REPLACE VIEW `v_bcc_farming_ready` AS
SELECT 
    plant_id,
    plant_type,
    plant_owner,
    growth_progress,
    water_count,
    max_water_times,
    base_fertilized,
    fertilizer_reduction
FROM `v_bcc_farming_status`
WHERE growth_progress >= 100 
   OR (CAST(time_left AS UNSIGNED) <= 0 AND water_count > 0);

-- =====================================================
-- 7. CREATE STORED PROCEDURES FOR COMMON OPERATIONS
-- =====================================================

DELIMITER //

-- Procedure to calculate expected reward
CREATE PROCEDURE `sp_calculate_plant_reward`(
    IN p_plant_id INT,
    IN p_base_reward INT,
    OUT p_final_reward INT
)
BEGIN
    DECLARE v_water_efficiency FLOAT DEFAULT 1.0;
    DECLARE v_fertilizer_multiplier FLOAT DEFAULT 1.0;
    DECLARE v_requires_fertilizer BOOLEAN DEFAULT FALSE;
    
    -- Get plant data
    SELECT 
        (water_count / max_water_times),
        base_fertilized
    INTO 
        v_water_efficiency,
        v_requires_fertilizer
    FROM bcc_farming 
    WHERE plant_id = p_plant_id;
    
    -- Apply fertilizer penalty if not fertilized
    IF v_requires_fertilizer = FALSE THEN
        SET v_fertilizer_multiplier = 0.7; -- 30% penalty
    END IF;
    
    -- Calculate final reward
    SET p_final_reward = FLOOR(p_base_reward * v_water_efficiency * v_fertilizer_multiplier);
END //

-- Procedure to update plant growth
CREATE PROCEDURE `sp_update_plant_growth`(
    IN p_plant_id INT
)
BEGIN
    DECLARE v_total_time INT;
    DECLARE v_time_left INT;
    DECLARE v_progress FLOAT;
    DECLARE v_new_stage TINYINT;
    
    -- Get current time data
    SELECT 
        total_growth_time,
        CAST(time_left AS UNSIGNED)
    INTO 
        v_total_time,
        v_time_left
    FROM bcc_farming 
    WHERE plant_id = p_plant_id;
    
    -- Calculate progress
    IF v_total_time > 0 THEN
        SET v_progress = ((v_total_time - v_time_left) / v_total_time) * 100;
        SET v_progress = GREATEST(0, LEAST(100, v_progress));
    ELSE
        SET v_progress = 100;
    END IF;
    
    -- Determine stage
    IF v_progress <= 30 THEN
        SET v_new_stage = 1;
    ELSEIF v_progress <= 60 THEN
        SET v_new_stage = 2;
    ELSE
        SET v_new_stage = 3;
    END IF;
    
    -- Update plant
    UPDATE bcc_farming SET 
        growth_progress = v_progress,
        growth_stage = v_new_stage
    WHERE plant_id = p_plant_id;
END //

DELIMITER ;

-- =====================================================
-- 8. VERIFICATION QUERIES
-- =====================================================

-- Check migration success
SELECT 
    'Migration Status' as check_type,
    CASE 
        WHEN COUNT(*) > 0 THEN 'SUCCESS: New columns added'
        ELSE 'ERROR: Migration failed'
    END as result
FROM INFORMATION_SCHEMA.COLUMNS 
WHERE TABLE_NAME = 'bcc_farming' 
  AND COLUMN_NAME IN ('growth_stage', 'growth_progress', 'water_count', 'max_water_times', 'base_fertilized')
  AND TABLE_SCHEMA = DATABASE();

-- Check data migration
SELECT 
    'Data Migration' as check_type,
    CONCAT(
        'Plants: ', COUNT(*), 
        ' | Avg Progress: ', ROUND(AVG(growth_progress), 2), '%',
        ' | Stages: ', COUNT(DISTINCT growth_stage)
    ) as result
FROM bcc_farming;

-- Check new tables
SELECT 
    'New Tables' as check_type,
    CASE 
        WHEN COUNT(*) >= 3 THEN 'SUCCESS: All tables created'
        ELSE 'WARNING: Some tables missing'
    END as result
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_NAME IN ('bcc_farming_growth_stages', 'bcc_farming_watering_log', 'bcc_farming_fertilizer_log')
  AND TABLE_SCHEMA = DATABASE();

-- =====================================================
-- 9. POST-MIGRATION NOTES
-- =====================================================

/*
MIGRATION COMPLETE! 

Next Steps:
1. Update bcc-farming scripts with new logic
2. Configure plants in configs/plants.lua with new structure
3. Test multi-stage growth system
4. Test multi-watering functionality
5. Test base fertilizer system

Rollback Instructions (if needed):
1. DROP the new tables: bcc_farming_growth_stages, bcc_farming_watering_log, bcc_farming_fertilizer_log
2. DROP the new columns: ALTER TABLE bcc_farming DROP COLUMN growth_stage, DROP COLUMN growth_progress, etc.
3. Restore from backup: INSERT INTO bcc_farming SELECT * FROM bcc_farming_backup_v242;

Performance Notes:
- New indexes added for optimized queries
- Views created for common data access patterns
- Stored procedures for complex calculations

Testing:
- Use v_bcc_farming_status view to monitor plant states
- Check sp_calculate_plant_reward for reward calculations
- Monitor performance with new indexes
*/