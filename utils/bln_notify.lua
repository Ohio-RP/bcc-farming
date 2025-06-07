-- =======================================
-- BCC-Farming BLN Notify Integration
-- Utility functions for BLN notifications
-- =======================================

-- Server-side BLN notification function
function SendFarmingNotification(src, message, notificationType)
    if not src or not message then return end
    
    -- Default to SUCCESS type if not specified
    local template = 'FARMING'
    
    -- Determine notification type based on message content or explicit type
    local options = {
        description = message
    }
    
    -- Send BLN notification to specific player
    TriggerClientEvent("bln_notify:send", src, options, template)
end

-- Server-side BLN notification function for all players
function SendFarmingNotificationToAll(message, notificationType)
    if not message then return end
    
    local template = 'FARMING'
    
    local options = {
        description = message
    }
    
    -- Send BLN notification to all players
    TriggerClientEvent("bln_notify:send", -1, options, template)
end

-- Client-side BLN notification function (if needed)
function SendClientFarmingNotification(message, notificationType)
    if not message then return end
    
    local template = 'FARMING'
    
    local options = {
        description = message
    }
    
    -- Send BLN notification from client
    TriggerEvent("bln_notify:send", options, template)
end

-- Export functions for use in other scripts
if IsDuplicityVersion() then
    -- Server-side exports
    exports('SendFarmingNotification', SendFarmingNotification)
    exports('SendFarmingNotificationToAll', SendFarmingNotificationToAll)
else
    -- Client-side exports
    exports('SendClientFarmingNotification', SendClientFarmingNotification)
end

print("^2[BCC-Farming]^7 BLN Notify integration loaded!")