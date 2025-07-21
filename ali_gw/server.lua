ESX = exports['es_extended']:getSharedObject()

function sendToDiscord(logType, title, message, color)
    if not Config.DiscordLogs.enabled then return end

    local logConfig = Config.DiscordLogs.webhooks[logType]
    if not logConfig or not logConfig.enabled or not logConfig.url or logConfig.url == "" then
        return
    end

    local embed = {
        {
            ["title"] = title,
            ["description"] = message,
            ["color"] = color or 65280, 
            ["footer"] = {
                ["text"] = "ali_gw Logs - " .. os.date("%x %X")
            }
        }
    }

    PerformHttpRequest(logConfig.url, function(err, text, headers) end, 'POST', json.encode({username = "GW Logs", embeds = embed}), { ['Content-Type'] = 'application/json' })
end
exports('isPlayerInActiveGw', function(playerId)
    return isPlayerInActiveGw(playerId)
end)

local waitingForWar = {}
local activeWars = {} 
local playersBeingProcessedForWar = {}

function isFactionInActiveWar(factionName)
    for _, warData in pairs(activeWars) do
        if warData.defender == factionName or warData.attacker == factionName then
            return true
        end
    end
    return false
end

function isFactionInQueue(factionName)
    for _, queue in pairs(waitingForWar) do
        for _, entry in ipairs(queue) do
            if entry.fraktion == factionName then
                return true
            end
        end
    end
    return false
end 



function getZoneIndex(zoneName)
    for i, zone in ipairs(Config.gwgebiete) do
        if zone.name == zoneName then
            return i
        end
    end
    return nil
end


function savePlayerInventory(playerId, cb)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return end

    local playerPed = GetPlayerPed(playerId)
    local coords = GetEntityCoords(playerPed)

    local inventoryData = {
        inventory = xPlayer.getInventory(),
        loadout = xPlayer.getLoadout(),
        accounts = xPlayer.getAccounts(),
        coords = { x = coords.x, y = coords.y, z = coords.z, heading = GetEntityHeading(playerPed) }
    }

    local encodedInventory = json.encode(inventoryData)

    exports.oxmysql:execute('DELETE FROM ali_gwinv WHERE identifier = @identifier', {
        ['@identifier'] = xPlayer.identifier
    }, function()
        exports.oxmysql:execute('INSERT INTO ali_gwinv (identifier, inventory) VALUES (@identifier, @inventory)', {
            ['@identifier'] = xPlayer.identifier,
            ['@inventory'] = encodedInventory
        }, function(result)
            if cb then cb(result and result.affectedRows > 0) end
        end)
    end)
end

function clearPlayerInventory(playerId, cb)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return end

    for _, item in ipairs(xPlayer.getInventory()) do
        if item.count > 0 then
            xPlayer.removeInventoryItem(item.name, item.count)
        end
    end

    for _, weapon in ipairs(xPlayer.getLoadout()) do
        xPlayer.removeWeapon(weapon.name)
    end
    
    if cb then cb() end
end

function giveWarLoadout(playerId)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return end


    for _, weaponData in ipairs(Config.GangwarLoadout.weapons) do
        xPlayer.addWeapon(weaponData.name, weaponData.ammo)

        local weaponAsItem = xPlayer.getInventoryItem(weaponData.name)
        if weaponAsItem and weaponAsItem.count > 0 then
            xPlayer.removeInventoryItem(weaponData.name, weaponAsItem.count)
        end
    end

    for _, itemData in ipairs(Config.GangwarLoadout.items) do
        xPlayer.addInventoryItem(itemData.name, itemData.count)
    end
end

function isPlayerInActiveGw(playerId)
    for _, warData in pairs(activeWars) do
        if warData.defenderPlayers and table.find(warData.defenderPlayers, playerId) then
            return true
        end
        if warData.attackerPlayers and table.find(warData.attackerPlayers, playerId) then
            return true
        end
    end
    return false
end

function restorePlayerInventory(playerId, cb, forceRestore)
    if not forceRestore and isPlayerInActiveGw(playerId) then
        if cb then cb(false) end
        return
    end

    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then
        if cb then cb(false) end
        return
    end

    exports.oxmysql:fetch('SELECT inventory FROM ali_gwinv WHERE identifier = @identifier', {
        ['@identifier'] = xPlayer.identifier
    }, function(result)
        if result and result[1] and result[1].inventory then
            local inventoryData = json.decode(result[1].inventory)
            local freshXPlayer = ESX.GetPlayerFromId(playerId)

            if not freshXPlayer then
                if cb then cb(false) end
                return
            end

            clearPlayerInventory(playerId, function()

                if inventoryData.inventory then
                    for _, item in ipairs(inventoryData.inventory) do
                        if item.count > 0 then
                            freshXPlayer.addInventoryItem(item.name, item.count, item.metadata)
                        end
                    end
                end

    
                if inventoryData.loadout then
                    for _, weapon in ipairs(inventoryData.loadout) do
                        freshXPlayer.addWeapon(weapon.name, weapon.ammo)
                    end
                end

          
                if inventoryData.accounts then
                    for _, account in ipairs(inventoryData.accounts) do
                        freshXPlayer.setAccountMoney(account.name, account.money)
                    end
                end


                if inventoryData.coords then
                    TriggerClientEvent('ali_gw:teleport', playerId, inventoryData.coords)
                end

                exports.oxmysql:execute('DELETE FROM ali_gwinv WHERE identifier = @identifier', {
                    ['@identifier'] = freshXPlayer.identifier
                }, function()
                    if cb then cb(true) end
                end)
            end)
        else
            if cb then cb(false) end
        end
    end)
end



function broadcastStateUpdate()
    local simplifiedQueue = {}
    for zone, factions in pairs(waitingForWar) do
        simplifiedQueue[zone] = {}
        for _, data in ipairs(factions) do
            table.insert(simplifiedQueue[zone], data.fraktion)
        end
    end

    local warsForClient = {}
    for zoneName, warData in pairs(activeWars) do
        if warData and warData.endTime then
            warsForClient[zoneName] = {
                defender = warData.defender,
                attacker = warData.attacker,
                defenderCount = warData.defenderCount,
                attackerCount = warData.attackerCount,
                remainingTime = warData.endTime - os.time()
            }
        end
    end

    TriggerClientEvent('ali_gw:stateUpdate', -1, simplifiedQueue, warsForClient, Config.FactionLogos)
end

function sendStateUpdate()
    TriggerClientEvent('ali_gw:stateUpdate', -1, waitingForWar, activeWars, Config.FactionLogos)
end


RegisterNetEvent('ali_gw:playerDiedInGw', function(killerId)
    local victimPlayer = ESX.GetPlayerFromId(source)
    if not victimPlayer then return end


    MySQL.Async.execute(
        'INSERT INTO ali_gwplayers (identifier, kills, deaths) VALUES (@identifier, 0, 1) ON DUPLICATE KEY UPDATE deaths = deaths + 1',
        { ['@identifier'] = victimPlayer.identifier }
    )


    if killerId and killerId ~= -1 and killerId ~= source then
        local killerPlayer = ESX.GetPlayerFromId(killerId)
        if killerPlayer then
            MySQL.Async.execute(
                'INSERT INTO ali_gwplayers (identifier, kills, deaths) VALUES (@identifier, 1, 0) ON DUPLICATE KEY UPDATE kills = kills + 1',
                { ['@identifier'] = killerPlayer.identifier }
            )
        end
    end
end)

RegisterNetEvent('ali_gw:buyShopItem', function(itemName)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local selectedItem = nil
    for _, item in ipairs(Config.shop) do
        if item.item == itemName then
            selectedItem = item
            break
        end
    end

    if not selectedItem then
        TriggerClientEvent('IMPULSEV_hud-v2:notify', src, 'error', 'Dieser Gegenstand existiert nicht.', 5000)
        return
    end


    local factionJob = xPlayer.job.name

    if not Config.gwfraks[factionJob] then
        TriggerClientEvent('IMPULSEV_hud-v2:notify', src, 'error', 'Deine Fraktion kann keine Gangwar-Shop-Items kaufen.', 5000)
        return
    end

    exports.oxmysql:fetch('SELECT points FROM ali_gwmain WHERE faction_name = @faction', {
        ['@faction'] = factionJob
    }, function(result)
        local factionPoints = (result[1] and result[1].points) or 0

        if factionPoints >= selectedItem.points then
            local newPoints = factionPoints - selectedItem.points
            exports.oxmysql:execute('INSERT INTO ali_gwmain (faction_name, points) VALUES (@faction, @points) ON DUPLICATE KEY UPDATE points = @points', {
                ['@faction'] = factionJob,
                ['@points'] = newPoints
            }, function(rowsChanged)
                xPlayer.addInventoryItem(selectedItem.item, selectedItem.count)
                sendToDiscord('shopPurchase', 'Shop-Kauf', string.format('**%s** von der Fraktion **%s** hat **%s**x **%s** für **%d** Punkte gekauft.', xPlayer.getName(), factionJob, selectedItem.count, selectedItem.name, selectedItem.points), 65280)
                TriggerClientEvent('IMPULSEV_hud-v2:notify', src, 'success', 'Deine Fraktion hat ' .. selectedItem.name .. ' für ' .. selectedItem.points .. ' Punkte gekauft! Verbleibende Punkte: ' .. newPoints, 6000)
            end)
        else
            TriggerClientEvent('IMPULSEV_hud-v2:notify', src, 'error', 'Deine Fraktion hat nicht genügend Punkte. Verfügbar: ' .. factionPoints, 5000)
        end
    end)
end)

RegisterNetEvent('ali_gw:requestGw')
AddEventHandler('ali_gw:requestGw', function(zoneName)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or not xPlayer.job or not xPlayer.job.name then return end
    local playerJob = xPlayer.job.name

    if not Config.gwfraks[playerJob] then
        TriggerClientEvent('IMPULSEV_hud-v2:notify', src, 'error', 'Deine Fraktion ist für Gangwars nicht zugelassen.', 5000)
        return
    end

    if isFactionInActiveWar(playerJob) then
        TriggerClientEvent('IMPULSEV_hud-v2:notify', src, 'error', 'Deine Fraktion kämpft bereits in einem anderen Gebiet.', 7000)
        return
    end

    if isFactionInQueue(playerJob) then
        TriggerClientEvent('IMPULSEV_hud-v2:notify', src, 'error', 'Deine Fraktion wartet bereits auf einen Gegner.', 7000)
        return
    end

    if Config.time.enabled then
        local hour = tonumber(os.date('%H'))
        if hour < Config.time.start_hour or hour >= Config.time.end_hour then
            TriggerClientEvent('IMPULSEV_hud-v2:notify', src, 'error', 'Gangwars sind nur zwischen ' .. Config.time.start_hour .. ':00 und ' .. Config.time.end_hour .. ':00 Uhr möglich.', 10000)
            return
        end
    end

    if activeWars[zoneName] then
        TriggerClientEvent('IMPULSEV_hud-v2:notify', src, 'error', 'In dieser Zone läuft bereits ein Kampf.', 5000)
        return
    end

    local queue = waitingForWar[zoneName] or {}
    for _, entry in ipairs(queue) do
        if entry.fraktion == playerJob then
            TriggerClientEvent('IMPULSEV_hud-v2:notify', src, 'error', 'Deine Fraktion wartet bereits in der Warteschlange.', 5000)
            return
        end
    end

    table.insert(queue, {
        fraktion = playerJob,
        players = getPlayersFromJob(playerJob)
    })
    waitingForWar[zoneName] = queue


    if #queue == 1 then
        for _, playerSrc in ipairs(getPlayersFromJob(playerJob)) do
            TriggerClientEvent('IMPULSEV_hud-v2:notify', playerSrc, 'inform', "Deine Fraktion wartet nun auf einen Gegner in " .. zoneName .. ".", 5000)
        end
        broadcastStateUpdate()
        return
    end
    

    if #queue >= 2 then
        local defenderData = queue[1]
        local attackerData = queue[2]
        local zoneIndex = getZoneIndex(zoneName)
        if not zoneIndex then

            return
        end

        local zoneConfig = Config.gwgebiete[zoneIndex]
        if not zoneConfig then

            return
        end

        waitingForWar[zoneName] = nil

        local warBucket = math.random(200, 3099)



        local allWarPlayers = {}
        for _, pId in ipairs(defenderData.players) do table.insert(allWarPlayers, pId) end
        for _, pId in ipairs(attackerData.players) do table.insert(allWarPlayers, pId) end

        activeWars[zoneName] = {
            defender = defenderData.fraktion,
            attacker = attackerData.fraktion,
            defenderPlayers = {},
            attackerPlayers = {},
            defenderCount = 0,
            attackerCount = 0,
            allPlayers = allWarPlayers,
            bucket = warBucket,
            startTime = os.time(),
            endTime = os.time() + (zoneConfig.duration * 60),
            spawnedVehicles = {}
        }

        local defenderFaction = defenderData.fraktion
        local attackerFaction = attackerData.fraktion

        local defenderMarkerCoords, attackerMarkerCoords
        for _, marker in ipairs(Config.interactionMarkers) do
            if string.lower(marker.name) == string.lower(defenderFaction) then
                defenderMarkerCoords = marker.coords
            elseif string.lower(marker.name) == string.lower(attackerFaction) then
                attackerMarkerCoords = marker.coords
            end
        end

        if not defenderMarkerCoords or not attackerMarkerCoords then

            return
        end

        TriggerClientEvent('ali_gw:showFactionJoinMarkers', -1, zoneName, {
            defender = { coords = defenderMarkerCoords, faction = defenderFaction },
            attacker = { coords = attackerMarkerCoords, faction = attackerFaction }
        })


        Citizen.CreateThread(function()
            Citizen.Wait(Config.JoinTime * 1000)

            local currentWar = activeWars[zoneName]
            if not currentWar then return end


            if currentWar.defenderCount == 0 or currentWar.attackerCount == 0 then

                local message
                if currentWar.defenderCount == 0 and currentWar.attackerCount > 0 then
                    message = 'Die Fraktion ' .. currentWar.defender .. ' ist nicht zum Kampf erschienen. Der Kampf wurde abgebrochen.'
                elseif currentWar.attackerCount == 0 and currentWar.defenderCount > 0 then
                    message = 'Die Fraktion ' .. currentWar.attacker .. ' ist nicht zum Kampf erschienen. Der Kampf wurde abgebrochen.'
                else
                    message = 'Keine der Fraktionen ist zum Kampf erschienen. Der Kampf wurde abgebrochen.'
                end
                TriggerClientEvent('IMPULSEV_hud-v2:notify', -1, 'inform', message, 10000)

                local playersToRestore = {}
                for _, pId in ipairs(currentWar.defenderPlayers) do table.insert(playersToRestore, pId) end
                for _, pId in ipairs(currentWar.attackerPlayers) do table.insert(playersToRestore, pId) end
                
                for _, pId in ipairs(playersToRestore) do
                    local xPlayer = ESX.GetPlayerFromId(pId)
                    if xPlayer then
                        local factionName = xPlayer.job.name
                        local teleportMarker = nil
                        for _, marker in ipairs(Config.interactionMarkers) do
                            if marker.name and factionName and string.lower(marker.name) == string.lower(factionName) then
                                teleportMarker = marker.coords
                                break
                            end
                        end
                        if teleportMarker then
                            TriggerClientEvent('ali_gw:cancelWarCleanup', pId, teleportMarker)
                        else

                            TriggerClientEvent('ali_gw:cancelWarCleanup', pId, nil)
                        end
                    end
                end

                activeWars[zoneName] = nil
                broadcastStateUpdate()
                return
            end

            currentWar.warStarted = true
            sendToDiscord('warStart', 'Kampf Gestartet', string.format('Der Kampf um **%s** hat offiziell begonnen.\n**Verteidiger:** %s\n**Angreifer:** %s', zoneName, currentWar.defender, currentWar.attacker), 15158332)
            currentWar.initialDefenderCount = currentWar.defenderCount
            currentWar.initialAttackerCount = currentWar.attackerCount

            local defenderVehicles = zoneConfig.vehicle_spawns.defender
            local attackerVehicles = zoneConfig.vehicle_spawns.attacker

            local function spawnVehiclesForTeam(vehicles, teamPlayers, factionJob)
                if not vehicles or #vehicles == 0 or not teamPlayers or #teamPlayers == 0 then return end
                for _, vehicleData in ipairs(vehicles) do
                    local modelHash = GetHashKey(vehicleData.model)
                    local spawnCoords = vehicleData.coords
                    local amountToSpawn = vehicleData.amount or 1
                    if spawnCoords then
                        local baseSpawnPos = vector3(spawnCoords.x, spawnCoords.y, spawnCoords.z)
                        local heading = vehicleData.heading or (spawnCoords and spawnCoords.h) or 0.0
                        for i = 1, amountToSpawn do
                            local distance = 6.2 * (i - 1)
                            local perp_heading_rad = math.rad(heading + 90.0)
                            local offsetX = math.cos(perp_heading_rad) * distance
                            local offsetY = math.sin(perp_heading_rad) * distance
                            local spawnPos = baseSpawnPos + vector3(offsetX, offsetY, 0.0)
                            local vehicle = CreateVehicle(modelHash, spawnPos.x, spawnPos.y, spawnPos.z, heading, true, true)
                            local entityWaitAttempts = 20 
                            while not DoesEntityExist(vehicle) and entityWaitAttempts > 0 do
                                Citizen.Wait(50)
                                entityWaitAttempts = entityWaitAttempts - 1
                            end
                            if DoesEntityExist(vehicle) then
                                local netId = NetworkGetNetworkIdFromEntity(vehicle)
                                SetEntityRoutingBucket(vehicle, currentWar.bucket)
                                table.insert(currentWar.spawnedVehicles, netId)
                                TriggerClientEvent('ali_gw:colorVehicle', -1, netId, factionJob)
                            else

                            end
                        end
                    else

                    end
                end
            end

            spawnVehiclesForTeam(defenderVehicles, currentWar.defenderPlayers, currentWar.defender)
            spawnVehiclesForTeam(attackerVehicles, currentWar.attackerPlayers, currentWar.attacker)
            
            broadcastStateUpdate()

            local startMessage = 'Das Gangwar gegen %s startet!'
            for _, pId in ipairs(currentWar.defenderPlayers) do TriggerClientEvent('IMPULSEV_hud-v2:notify', pId, 'success', string.format(startMessage, currentWar.attacker), 7000) end
            for _, pId in ipairs(currentWar.attackerPlayers) do TriggerClientEvent('IMPULSEV_hud-v2:notify', pId, 'success', string.format(startMessage, currentWar.defender), 7000) end
        end)
    end
end)

function getPlayersFromJob(jobName)
    local players = {}
    local xPlayers = ESX.GetPlayers()

    for i=1, #xPlayers do
        local xPlayer = ESX.GetPlayerFromId(xPlayers[i])
        if xPlayer and xPlayer.job and xPlayer.job.name == jobName then
            table.insert(players, tonumber(xPlayers[i]))
        end
    end
    return players
end

function getZoneIndex(zoneName)
    for i, zone in ipairs(Config.gwgebiete) do
        if zone.name == zoneName then
            return i
        end
    end
    return nil
end

ESX.RegisterServerCallback('ali_gw:restorePlayerInventory', function(source, cb)
    restorePlayerInventory(source, function(success)
        cb(success)
    end)
end)

function getAvailableRoutingBucket()
    local usedBuckets = {}
    for _, warData in pairs(activeWars) do
        usedBuckets[warData.bucket] = true
    end

    for i = 200, 399 do 
        if not usedBuckets[i] then
            return i
        end
    end

    return nil 
end

RegisterNetEvent('ali_gw:playerDiedInGw', function()
    local deadPlayerId = source
    if not deadPlayerId then return end

    for zoneName, warData in pairs(activeWars) do
        local playerFaction = nil
        local playerIndex = table.find(warData.defenderPlayers, deadPlayerId)

        if playerIndex then
            playerFaction = "defender"
            table.remove(warData.defenderPlayers, playerIndex)
            warData.defenderCount = warData.defenderCount - 1
        else
            playerIndex = table.find(warData.attackerPlayers, deadPlayerId)
            if playerIndex then
                playerFaction = "attacker"
                table.remove(warData.attackerPlayers, playerIndex)
                warData.attackerCount = warData.attackerCount - 1
            end
        end

        if playerFaction then


            local xPlayer = ESX.GetPlayerFromId(deadPlayerId)
            if xPlayer then
                local factionName = xPlayer.job.name
                local teleportMarker = nil
                for _, marker in ipairs(Config.interactionMarkers) do
                    if marker.name and factionName and string.lower(marker.name) == string.lower(factionName) then
                        teleportMarker = marker.coords
                        break
                    end
                end

                if not teleportMarker then

                end

                                local deadPlayer = ESX.GetPlayerFromId(deadPlayerId)
                if deadPlayer then
                    local message = string.format('**%s** wurde im Kampf um **%s** eliminiert.', deadPlayer.getName(), zoneName)
                    if killerId and killerId ~= 0 then
                        local killerPlayer = ESX.GetPlayerFromId(killerId)
                        if killerPlayer then
                            message = message .. string.format('\nGetötet von: **%s**', killerPlayer.getName())
                        end
                    end
                    sendToDiscord('playerEliminated', 'Spieler Eliminiert', message, 8359053)
                end
                TriggerClientEvent('ali_gw:playerEliminated', deadPlayerId, teleportMarker)
            end

            broadcastStateUpdate()
        end
    end
end)

RegisterNetEvent('ali_gw:playerWantsToJoinWar', function(zoneName)
    local src = source
    local war = activeWars[zoneName]

    if not war or (os.time() - war.startTime) > Config.JoinTime then
        TriggerClientEvent('IMPULSEV_hud-v2:notify', src, 'error', 'Du kannst dem Kampf nicht mehr beitreten.', 5000)
        return
    end

    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local playerTeam = nil
    if table.find(war.attackerPlayers, src) then
        playerTeam = 'attacker'
    elseif table.find(war.defenderPlayers, src) then
        playerTeam = 'defender'
    end

    if playerTeam then
        local zoneConfig = Config.gwgebiete[getZoneIndex(zoneName)]
        if not zoneConfig then return end
        
        local spawnPool = (playerTeam == 'attacker') and zoneConfig.spawns.attacker or zoneConfig.spawns.defender
        if not spawnPool or #spawnPool == 0 then return end
        
        local spawnPoint = spawnPool[math.random(#spawnPool)]

        TriggerClientEvent('ali_gw:teleportToZone', src, {spawnPoint})
        TriggerClientEvent('ali_gw:startSpawnProtection', src, spawnPoint)
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)

        local activeWarKeys = {}
        for k in pairs(activeWars) do
            table.insert(activeWarKeys, k)
        end

        for _, zoneName in ipairs(activeWarKeys) do
            local warData = activeWars[zoneName]
            if warData then
                local winner = nil
                local reason = ""

                local joinPhaseOver = (os.time() - warData.startTime) > (Config.JoinTime or 15)

                if joinPhaseOver and not warData.initialCountsSet then
                    warData.initialAttackerCount = warData.attackerCount
                    warData.initialDefenderCount = warData.defenderCount
                    warData.initialCountsSet = true

                    broadcastStateUpdate() 
                end

                if warData.attackerCount <= 0 and joinPhaseOver and warData.defenderCount > 0 then
                    winner = warData.defender
                    reason = "Die Angreifer haben das Gebiet verlassen."
                elseif warData.defenderCount <= 0 and joinPhaseOver and warData.attackerCount > 0 then
                    winner = warData.attacker
                    reason = "Die Verteidiger haben das Gebiet verlassen."
                elseif os.time() >= warData.endTime then
                    if warData.defenderCount > warData.attackerCount then
                        winner = warData.defender
                        reason = "Die Zeit ist abgelaufen, die Verteidiger haben gewonnen."
                    elseif warData.attackerCount > warData.defenderCount then
                        winner = warData.attacker
                        reason = "Die Zeit ist abgelaufen, die Angreifer haben gewonnen."
                    else
                        winner = "draw"
                        reason = "Die Zeit ist abgelaufen, es ist ein Unentschieden."
                    end
                end

                if winner then
                    local message
                    if winner == "draw" then
                        message = 'Das Gangwar in ' .. zoneName .. ' ist unentschieden ausgegangen. ' .. reason
                    else
                        local loserFaction = (warData.defender == winner) and warData.attacker or warData.defender
                        message = ('Das Gangwar in %s ist vorbei! %s hat gegen %s gewonnen!'):format(zoneName, winner, loserFaction)
                        
                        exports.oxmysql:execute('INSERT INTO ali_gwmain (faction_name, wins) VALUES (@faction, 1) ON DUPLICATE KEY UPDATE wins = wins + 1', { ['@faction'] = winner })
                        exports.oxmysql:execute('INSERT INTO ali_gwmain (faction_name, loses) VALUES (@faction, 1) ON DUPLICATE KEY UPDATE loses = loses + 1', { ['@faction'] = loserFaction })

                        exports.oxmysql:execute('INSERT INTO ali_gwmain (faction_name, points) VALUES (@faction, 30) ON DUPLICATE KEY UPDATE points = points + 30', {
                            ['@faction'] = winner
                        })
                    end
                    TriggerClientEvent('IMPULSEV_hud-v2:notify', -1, 'inform', message, 10000)

                
                    if warData.allPlayers then
                        for _, pId in ipairs(warData.allPlayers) do
                            local player = ESX.GetPlayerFromId(pId)
                            if player then
                                restorePlayerInventory(pId, nil, true) 
                                SetPlayerRoutingBucket(pId, 0)
                            end
                        end
                    end
                    TriggerClientEvent('ali_gw:resetGwState', -1)

                    if warData.spawnedVehicles then
                        for _, vehicleNetId in ipairs(warData.spawnedVehicles) do
                            local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
                            if DoesEntityExist(vehicle) then
                                DeleteEntity(vehicle)
                            end
                        end
                    end
                
                    activeWars[zoneName] = nil 
                    broadcastStateUpdate()
                    sendToDiscord('warEnd', 'Kampf Beendet', string.format('Der Kampf um **%s** ist vorbei!\n**%s** hat gewonnen!', zoneName, winner), 2067276)
                else
                    broadcastStateUpdate()
                end
            end
        end
    end
end)


function table.find(tbl, val)
    for i, v in ipairs(tbl) do
        if v == val then
            return i
        end
    end
    return nil
end

RegisterNetEvent('ali_gw:playerWantsToJoinWar')
AddEventHandler('ali_gw:playerWantsToJoinWar', function(zoneName)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local warData = activeWars[zoneName]
    if not warData then

        return
    end

    if not table.find(warData.allPlayers, src) then

        TriggerClientEvent('IMPULSEV_hud-v2:notify', src, 'error', 'Du bist nicht für diesen Kampf zugelassen.', 5000)
        return
    end

    if isPlayerInActiveGw(src) then

        return
    end
    local playerJob = xPlayer.job.name
    local isDefender = (playerJob == warData.defender)
    
    if isDefender then
        table.insert(warData.defenderPlayers, src)
        warData.defenderCount = warData.defenderCount + 1
    else
        table.insert(warData.attackerPlayers, src)
        warData.attackerCount = warData.attackerCount + 1
    end

    local zoneConfig = Config.gwgebiete[getZoneIndex(zoneName)]
    local spawnPool = isDefender and zoneConfig.spawns.defender or zoneConfig.spawns.attacker
    if not spawnPool or #spawnPool == 0 then

        return
    end
    local spawnPoint = spawnPool[math.random(#spawnPool)]

    savePlayerInventory(src, function(success)
        if not success then

            return
        end

        clearPlayerInventory(src, function()
            giveWarLoadout(src)
            SetPlayerRoutingBucket(src, warData.bucket)
            TriggerClientEvent('ali_gw:teleportToZone', src, {spawnPoint})
            TriggerClientEvent('ali_gw:startSpawnProtection', src, spawnPoint)
            local playerFaction = isDefender and warData.defender or warData.attacker
            sendToDiscord('playerJoin', 'Spieler beigetreten', string.format('**%s** ist dem Kampf um **%s** für die Fraktion **%s** beigetreten.', xPlayer.getName(), zoneName, playerFaction), 3447003)
            broadcastStateUpdate()

        end)
    end)
end)

AddEventHandler('esx:playerDropped', function(playerId, reason)
    restorePlayerInventory(playerId)

    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer or not xPlayer.job then return end

    for zoneName, warData in pairs(activeWars) do
        local playerIndex = table.find(warData.defenderPlayers, playerId)
        if playerIndex then
            table.remove(warData.defenderPlayers, playerIndex)
            warData.defenderCount = warData.defenderCount - 1
            local xPlayer = ESX.GetPlayerFromId(playerId)
            if xPlayer then
                sendToDiscord('playerLeave', 'Spieler hat verlassen', string.format('**%s** hat die Verbindung getrennt und den Kampf um **%s** als **Verteidiger** verlassen.', xPlayer.getName(), zoneName), 15105570)
            end
            broadcastStateUpdate()

            return 
        end

        playerIndex = table.find(warData.attackerPlayers, playerId)
        if playerIndex then
            table.remove(warData.attackerPlayers, playerIndex)
            warData.attackerCount = warData.attackerCount - 1
            local xPlayer = ESX.GetPlayerFromId(playerId)
            if xPlayer then
                sendToDiscord('playerLeave', 'Spieler hat verlassen', string.format('**%s** hat die Verbindung getrennt und den Kampf um **%s** als **Angreifer** verlassen.', xPlayer.getName(), zoneName), 15105570)
            end
            broadcastStateUpdate()

            return 
        end
    end


    local playerJob = xPlayer.job.name
    for zoneName, queue in pairs(waitingForWar) do
        for i = #queue, 1, -1 do
            local factionData = queue[i]
            if factionData.fraktion == playerJob then
                local playerIndexInFaction = table.find(factionData.players, playerId)
                if playerIndexInFaction then
                     table.remove(factionData.players, playerIndexInFaction)
                    local xPlayer = ESX.GetPlayerFromId(playerId)
                    if xPlayer then
                         sendToDiscord('queueUpdate', 'Warteschlange Update', string.format('**%s** hat die Warteschlange für **%s** verlassen (Verbindung getrennt).', xPlayer.getName(), zoneName), 15105570)
                    end

               
                    if #factionData.players == 0 then
                        table.remove(queue, i)

                    end
                    broadcastStateUpdate()
                    return 
                end
            end
        end
    end
end)


AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    if playersBeingProcessedForWar[playerId] then

        return
    end

    SetPlayerRoutingBucket(playerId, 0) 
    Citizen.CreateThread(function()
        Citizen.Wait(10000) 
        restorePlayerInventory(playerId)
    end)
end)

AddEventHandler('ali_weaponpack:packWeapon', function()
    local _source = source
    if isPlayerInActiveGw(_source) then
        CancelEvent()
        TriggerClientEvent('esx:showNotification', _source, 'You cannot use this during a gang war.')
    end
end)

RegisterNetEvent('ali_gw:setPlayerBucket', function(bucket)
    SetPlayerRoutingBucket(source, tonumber(bucket) or 0)
end)

RegisterNetEvent('ali_gw:playerDiedInGw', function(killerId)
    local victimPlayer = ESX.GetPlayerFromId(source)

    if not victimPlayer then return end

    exports.oxmysql:execute(
        'INSERT INTO ali_gwplayers (identifier, kills, deaths) VALUES (@identifier, 0, 1) ON DUPLICATE KEY UPDATE deaths = deaths + 1',
        { ['@identifier'] = victimPlayer.identifier },
        function(affectedRows) 
        end
    )

    if killerId and killerId ~= -1 and killerId ~= source then
        local killerPlayer = ESX.GetPlayerFromId(killerId)
        if killerPlayer then
            exports.oxmysql:execute(
                'INSERT INTO ali_gwplayers (identifier, kills, deaths) VALUES (@identifier, 1, 0) ON DUPLICATE KEY UPDATE kills = kills + 1',
                { ['@identifier'] = killerPlayer.identifier },
                function(affectedRows) 
                end
            )
        end
    end
end)

function getGangwarStats(cb)
    local stats = {
        topFactions = {},
        topPlayers = {}
    }

    exports.oxmysql:fetch('SELECT faction_name, wins, loses FROM ali_gwmain ORDER BY wins DESC LIMIT 5', {}, function(topFactions)
        if topFactions then
            for _, faction in ipairs(topFactions) do
                local label = (ESX and ESX.Jobs and ESX.Jobs[faction.faction_name] and ESX.Jobs[faction.faction_name].label) or faction.faction_name
                table.insert(stats.topFactions, {
                    label = label,
                    wins = faction.wins,
                    losses = faction.loses
                })
            end
        end

        exports.oxmysql:fetch('SELECT identifier, kills, deaths FROM ali_gwplayers ORDER BY kills DESC LIMIT 5', {}, function(topPlayers)
            if topPlayers and #topPlayers > 0 then
                local playerIdentifiers = {}
                for _, p in ipairs(topPlayers) do
                    table.insert(playerIdentifiers, p.identifier)
                end

                exports.oxmysql:fetch('SELECT identifier, firstname, lastname FROM users WHERE identifier IN (?)', { playerIdentifiers }, function(users)
                    local userNames = {}
                    if users then
                        for _, u in ipairs(users) do
                            userNames[u.identifier] = u.firstname .. ' ' .. u.lastname
                        end
                    end

                    for _, p in ipairs(topPlayers) do
                        local kd = (p.deaths == 0) and p.kills or (p.kills / p.deaths)
                        table.insert(stats.topPlayers, {
                            name = userNames[p.identifier] or 'Unbekannter Spieler',
                            kills = p.kills,
                            deaths = p.deaths,
                            kd = tonumber(string.format("%.2f", kd))
                        })
                    end
                    
                    cb(stats)
                end)
            else
                cb(stats)
            end
        end)
    end)
end

ESX.RegisterServerCallback('ali_gw:getInitialNuiData', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    local data = {
        stats = {},
        overview = nil,
        shopItems = Config.shop
    }

    getGangwarStats(function(stats)
        data.stats = stats

        if xPlayer and xPlayer.job and xPlayer.job.name then
            local faction = xPlayer.job.name
            exports.oxmysql:fetch('SELECT wins, loses, points FROM ali_gwmain WHERE faction_name = @faction', {
                ['@faction'] = faction
            }, function(result)
                local wins, loses, points = 0, 0, 0
                if result and result[1] then
                    wins = tonumber(result[1].wins) or 0
                    loses = tonumber(result[1].loses) or 0
                    points = tonumber(result[1].points) or 0
                end

                exports.oxmysql:scalar('SELECT COUNT(*) + 1 FROM ali_gwmain WHERE points > @points', {
                    ['@points'] = points
                }, function(rank)
                    data.overview = {
                        gangwars = wins + loses,
                        points = points,
                        rank = rank or 1
                    }
                    cb(data)
                end)
            end)
        else
            cb(data)
        end
    end)
end)

RegisterNetEvent('ali_gw:requestInitialJob')
AddEventHandler('ali_gw:requestInitialJob', function()
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer and xPlayer.job then
        TriggerClientEvent('ali_gw:receiveInitialJob', source, xPlayer.job)
    end
end)