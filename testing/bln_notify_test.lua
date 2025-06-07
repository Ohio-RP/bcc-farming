-- =======================================
-- BCC-Farming BLN Notify Test Commands
-- =======================================

-- Test command for BLN notifications
RegisterCommand('testfarmnotify', function(source, args, rawCommand)
    local src = source
    if not src or src == 0 then return end
    
    local message = table.concat(args, ' ') or 'Teste de notificação do sistema de fazenda!'
    
    print(string.format("^2[BCC-Farming Test]^7 Sending BLN notification to player %d: %s", src, message))
    
    -- Test the BLN notification
    SendFarmingNotification(src, message)
    
    -- Also send a confirmation via server console
    print(string.format("^2[BCC-Farming Test]^7 BLN notification sent successfully"))
end, false)

-- Test command for client-side notifications
RegisterCommand('testfarmnotifyclient', function(source, args, rawCommand)
    local message = table.concat(args, ' ') or 'Teste de notificação client-side!'
    
    print(string.format("^2[BCC-Farming Test]^7 Sending client BLN notification: %s", message))
    
    -- Test the client-side BLN notification
    SendClientFarmingNotification(message)
end, false)

-- Test command to show multiple types of farming notifications
RegisterCommand('testfarmnotifyall', function(source, args, rawCommand)
    local src = source
    if not src or src == 0 then return end
    
    -- Test different types of farming notifications
    local testMessages = {
        'Planta plantada com sucesso!',
        'Planta regada! (2/3 - 67%)',
        'Planta pronta para colheita!',
        'Você colheu 5x Milho',
        'Ferramenta quebrada - precisa de uma nova',
        'Muito próximo de outra planta',
        'Limite máximo de plantas atingido'
    }
    
    print(string.format("^2[BCC-Farming Test]^7 Sending %d test notifications to player %d", #testMessages, src))
    
    for i, message in ipairs(testMessages) do
        -- Send with delay to avoid spam
        SetTimeout(i * 2000, function()
            SendFarmingNotification(src, message)
        end)
    end
end, false)

print("^2[BCC-Farming]^7 BLN notify test commands loaded!")
print("^2[BCC-Farming]^7 Commands: /testfarmnotify, /testfarmnotifyclient, /testfarmnotifyall")