ESX = exports['es_extended']:getSharedObject()

local oxmysql = exports.oxmysql
if not oxmysql then
end

ESX.RegisterServerCallback('ali_clothing:getOutfits', function(source, cb)
    local player = ESX.GetPlayerFromId(source)
    if not player then return cb({}) end
    
    oxmysql:fetch('SELECT name, outfit FROM impulse_clotheshop WHERE owner = ?', 
        {player.identifier},
        function(result)
            if result then
                for _, outfit in ipairs(result) do
                    if type(outfit.outfit) == 'string' then
                        outfit.outfit = json.decode(outfit.outfit)
                    end
                end
                cb(result)
            else
                cb({})
            end
        end
    )
end)

ESX.RegisterServerCallback('ali_clothing:renameOutfit', function(source, cb, oldName, newName)
    local player = ESX.GetPlayerFromId(source)
    if not player then return cb(false) end
    
    if not oldName or not newName or newName == '' then
        return cb(false)
    end
    
    
    oxmysql:fetch('SELECT id FROM impulse_clotheshop WHERE owner = ? AND name = ?', 
        {player.identifier, newName},
        function(result)
            if result and #result > 0 then
                cb(false) 
            else
                
                oxmysql:update('UPDATE impulse_clotheshop SET name = ? WHERE owner = ? AND name = ?', 
                    {newName, player.identifier, oldName},
                    function(affectedRows)
                        cb(affectedRows > 0)
                    end
                )
            end
        end
    )
end)

RegisterServerEvent('ali_clothing:deleteOutfit')
AddEventHandler('ali_clothing:deleteOutfit', function(outfitName)
    local _source = source
    local player = ESX.GetPlayerFromId(_source)
    if not player or not outfitName then return end
    
    oxmysql:execute('DELETE FROM impulse_clotheshop WHERE owner = ? AND name = ?', 
        {player.identifier, outfitName}
    )
end)

RegisterServerEvent('ali_clothing:saveOutfit')
AddEventHandler('ali_clothing:saveOutfit', function(outfitName, outfit)
    local _source = source
    local player = ESX.GetPlayerFromId(_source)
    if not player then return end
    
    local playerId = player.identifier
    local outfitJson = json.encode(outfit)
    
    if not outfitName or outfitName == '' then
        return
    end

    
    oxmysql:fetch('SELECT id FROM impulse_clotheshop WHERE owner = ? AND name = ?', 
        {playerId, outfitName},
        function(result)
            if result and result[1] then
                oxmysql:update('UPDATE impulse_clotheshop SET outfit = ? WHERE id = ?', 
                    {outfitJson, result[1].id},
                    function(affectedRows)
                        if affectedRows > 0 then
                            TriggerClientEvent('IMPULSEV_hud-v2:notify', _source, 'success', 'Outfit ' .. outfitName .. ' wurde erfolgreich aktualisiert!', 5000)
                        else
                            TriggerClientEvent('IMPULSEV_hud-v2:notify', _source, 'error', 'Fehler beim Aktualisieren des Outfits!', 5000)
                        end
                    end
                )
            else
                
                oxmysql:insert('INSERT INTO impulse_clotheshop (owner, name, outfit) VALUES (?, ?, ?)', 
                    {playerId, outfitName, outfitJson},
                    function(insertId)
                        if insertId then
                            TriggerClientEvent('IMPULSEV_hud-v2:notify', _source, 'success', 'Outfit ' .. outfitName .. ' wurde erfolgreich gespeichert!', 5000)
                        else
                            TriggerClientEvent('IMPULSEV_hud-v2:notify', _source, 'error', 'Fehler beim Speichern des Outfits!', 5000)
                        end
                    end
                )
            end
        end
    )
end)

local ComponentMapping = {
    ['MASKE'] = 'mask',             ['MASKE FARBE'] = 'mask',
    ['OBERKÖRPER'] = 'torso',       ['OBERKÖRPER FARBE'] = 'torso',
    ['ARME'] = 'arms',              ['ARME FARBE'] = 'arms',
    ['HOSEN'] = 'pants',            ['HOSEN FARBE'] = 'pants',
    ['TASCHE'] = 'bags',            ['TASCHE FARBE'] = 'bags',
    ['SCHUHE'] = 'shoes',           ['SCHUHE FARBE'] = 'shoes',
    ['KETTE'] = 'chain',            ['KETTE FARBE'] = 'chain',
    ['T-SHIRT'] = 'tshirt',         ['T-SHIRT FARBE'] = 'tshirt',
    ['WESTE'] = 'bproof',           ['WESTE FARBE'] = 'bproof',
    ['AUFKLEBER'] = 'decals',       ['AUFKLEBER FARBE'] = 'decals'
}

local PropMapping = {
    ['KOPFBEDECKUNG'] = 'helmet',   ['KOPFBEDECKUNG FARBE'] = 'helmet',
    ['BRILLE'] = 'glasses',         ['BRILLE FARBE'] = 'glasses',
    ['ARMBÄNDER'] = 'bracelets',    ['ARMBÄNDER FARBE'] = 'bracelets'
}

RegisterNetEvent('ali_clothing:purchaseOutfit', function(outfitData, method)
    local _source = source
    local xPlayer = ESX.GetPlayerFromId(_source)

    if not xPlayer then return end

    local changedItemsCount = 0
    if type(outfitData) == 'table' then
        for _ in pairs(outfitData) do
            changedItemsCount = changedItemsCount + 1
        end
    end

    if changedItemsCount == 0 then
        return
    end

    local price = changedItemsCount * Config.Price

    local function applyPurchase()
        oxmysql:fetch('SELECT skin FROM users WHERE identifier = ?', {xPlayer.identifier}, function(result)
            if result and result[1] and result[1].skin then
                local currentSkin = json.decode(result[1].skin)
                
                if type(currentSkin) ~= 'table' then
                    currentSkin = {}
                end

                local allGermanKeys = {}
                for k, _ in pairs(ComponentMapping) do allGermanKeys[k] = true end
                for k, _ in pairs(PropMapping) do allGermanKeys[k] = true end

                for k, _ in pairs(currentSkin) do
                    if allGermanKeys[k] then
                        currentSkin[k] = nil
                    end
                end

                for category, data in pairs(outfitData) do
                    local technicalName = ComponentMapping[category] or PropMapping[category]

                    if technicalName then
                        if string.find(category, 'FARBE') then
                            currentSkin[technicalName .. '_2'] = data
                        else
                            currentSkin[technicalName .. '_1'] = data
                            currentSkin[technicalName .. '_2'] = 0
                        end
                    end
                end
                
                oxmysql:execute('UPDATE users SET skin = ? WHERE identifier = ?', {json.encode(currentSkin), xPlayer.identifier}, function(result)
                    xPlayer.set('skin', currentSkin)
                    TriggerClientEvent('ali_clothing:purchaseSuccess', _source)
                end)
            else
                TriggerClientEvent('IMPULSEV_hud-v2:notify', _source, 'error', 'Fehler: Dein Skin konnte nicht geladen werden!', 5000)
            end
        end)
    end

    if method == 'bank' then
        local playerBank = xPlayer.getAccount('bank').money
        if playerBank >= price then
            xPlayer.removeAccountMoney('bank', price)
            applyPurchase()
        else
            TriggerClientEvent('IMPULSEV_hud-v2:notify', _source, 'error', 'Du hast nicht genug Geld auf der Bank!', 5000)
        end
    else 
        local playerCash = xPlayer.getMoney()
        if playerCash >= price then
            xPlayer.removeMoney(price)
            applyPurchase()
        else
            TriggerClientEvent('IMPULSEV_hud-v2:notify', _source, 'error', 'Du hast nicht genug Bargeld!', 5000)
        end
    end
end)
