ESX = exports['es_extended']:getSharedObject()

local PlayerStats = {}
local ActivePrivateLobbies = {} 

function LoadPlayerStats(identifier, cb)
    MySQL.Async.fetchAll('SELECT * FROM ali_ffastats WHERE identifier = @identifier', {['@identifier'] = identifier}, function(result)
        if result[1] then
            PlayerStats[identifier] = {
                kills = result[1].kills or 0,
                deaths = result[1].deaths or 0
            }
        else
            PlayerStats[identifier] = { kills = 0, deaths = 0 }
            MySQL.Async.execute(
                'INSERT INTO ali_ffastats (identifier, kills, deaths) VALUES (@identifier, 0, 0)',
                {['@identifier'] = identifier}
            )
        end
        if cb then cb(PlayerStats[identifier]) end
    end)
end

function SavePlayerStats(identifier)
    if PlayerStats[identifier] then
        MySQL.Async.execute(
            'UPDATE ali_ffastats SET kills = @kills, deaths = @deaths WHERE identifier = @identifier',
            {
                ['@identifier'] = identifier,
                ['@kills'] = PlayerStats[identifier].kills or 0,
                ['@deaths'] = PlayerStats[identifier].deaths or 0
            }
        )
    end
end

function UpdatePlayerKill(identifier)
    if not PlayerStats[identifier] then
        LoadPlayerStats(identifier, function()
            PlayerStats[identifier].kills = (PlayerStats[identifier].kills or 0) + 1
            SavePlayerStats(identifier)
        end)
    else
        PlayerStats[identifier].kills = (PlayerStats[identifier].kills or 0) + 1
        SavePlayerStats(identifier)
    end
end

function UpdatePlayerDeath(identifier)
    if not PlayerStats[identifier] then
        LoadPlayerStats(identifier, function()
            PlayerStats[identifier].deaths = (PlayerStats[identifier].deaths or 0) + 1
            SavePlayerStats(identifier)
        end)
    else
        PlayerStats[identifier].deaths = (PlayerStats[identifier].deaths or 0) + 1
        SavePlayerStats(identifier)
    end
end

function BroadcastStats(lobbyId)
    local lobbyConfig = Config.Lobbies[lobbyId] or ActivePrivateLobbies[lobbyId]
    if not lobbyConfig then return end

    local playersInLobbySources = {}
    local statsToSend = {}
    local players = ESX.GetPlayers()

    for i=1, #players, 1 do
        local playerSource = players[i]
        if GetPlayerRoutingBucket(playerSource) == lobbyConfig.dimension then
            table.insert(playersInLobbySources, playerSource)
            local player = ESX.GetPlayerFromId(playerSource)
            if player then
                local stats = PlayerStats[player.identifier] or {kills = 0, deaths = 0}
                table.insert(statsToSend, {
                    name = player.getName(),
                    kills = stats.kills,
                    deaths = stats.deaths
                })
            end
        end
    end
    
    table.sort(statsToSend, function(a, b) return a.kills > b.kills end)

    for i=1, #playersInLobbySources, 1 do
        TriggerClientEvent('ali_ffa:updateScoreboard', playersInLobbySources[i], statsToSend)
    end
end

local ActivePrivateLobbies = {}
function IsDimensionInUse(dim)
    for _, lobby in pairs(Config.Lobbies) do
        if lobby.dimension == dim then return true end
    end
    for _, lobby in pairs(ActivePrivateLobbies) do
        if lobby.dimension == dim then return true end
    end
    return false
end



function GetAllLobbies()
    local allLobbies = {}

    for id, lobby in pairs(Config.Lobbies) do
        table.insert(allLobbies, {
            id = id,
            name = lobby.name,
            image = lobby.image,
            isPrivate = false,
            dimension = lobby.dimension
        })
    end
    for id, lobby in pairs(ActivePrivateLobbies) do
        table.insert(allLobbies, {
            id = id,
            name = lobby.name,
            image = lobby.image,
            isPrivate = true,
            password = (lobby.password and #lobby.password > 0),
            owner = lobby.owner,
            dimension = lobby.dimension
        })
    end
    return allLobbies
end

RegisterNetEvent('ali_ffa:createPrivateLobby')
AddEventHandler('ali_ffa:createPrivateLobby', function(data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    
    if not xPlayer then 
        return 
    end

    for _, lobby in pairs(ActivePrivateLobbies) do
        if lobby.owner == xPlayer.identifier then
            TriggerClientEvent('esx:showNotification', src, "Du besitzt bereits eine private Lobby.")
            return
        end
    end

    local baseLobbyConfig = nil
    for id, lobby in pairs(Config.Lobbies) do
        if id == data.mapName then
            baseLobbyConfig = lobby
            break
        end
    end

    if not baseLobbyConfig then
        TriggerClientEvent('esx:showNotification', src, 'Ungültige Map-Auswahl')
        return 
    end

    local newDimension
    local attempts = 0
    repeat
        newDimension = math.random(8000, 10000)
        attempts = attempts + 1
        if attempts > 100 then
            TriggerClientEvent('esx:showNotification', src, 'Fehler: Keine freie Dimension gefunden')
            return
        end
    until not IsDimensionInUse(newDimension)

    local newLobbyId = 'private_' .. os.time() .. '_' .. src
    local newLobby = {
        id = newLobbyId,
        name = data.lobbyName or ('Private Lobby von ' .. GetPlayerName(src)),
        image = baseLobbyConfig.image,
        dimension = newDimension,
        boundary = baseLobbyConfig.boundary,
        spawnpoints = baseLobbyConfig.spawnpoints,
        weapons = baseLobbyConfig.weapons,
        isPrivate = true,
        password = data.password or '',
        owner = xPlayer.identifier
    }

    ActivePrivateLobbies[newLobbyId] = newLobby
    
    TriggerClientEvent('ali_ffa:updateLobbies', -1, GetAllLobbies())
    
    TriggerClientEvent('ali_ffa:joinLobby', src, newLobbyId, data.password or '')
end)

RegisterNetEvent('ali_ffa:closePrivateLobby')
AddEventHandler('ali_ffa:closePrivateLobby', function(lobbyId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local lobbyToClose = ActivePrivateLobbies[lobbyId]

    if not lobbyToClose then
        TriggerClientEvent('esx:showNotification', src, "Diese Lobby existiert nicht mehr.")
        return
    end

    if lobbyToClose.owner ~= xPlayer.identifier then
        TriggerClientEvent('esx:showNotification', src, "Du bist nicht der Besitzer dieser Lobby.")
        return
    end

    local players = ESX.GetPlayers()
    for i=1, #players, 1 do
        local targetSrc = players[i]
        local targetPlayer = ESX.GetPlayerFromId(targetSrc)
        if targetPlayer and GetPlayerRoutingBucket(targetSrc) == lobbyToClose.dimension then
            TriggerClientEvent('ali_ffa:forceLeaveLobby', targetSrc)
        end
    end

    ActivePrivateLobbies[lobbyId] = nil
    TriggerClientEvent('ali_ffa:updateLobbies', -1, GetAllLobbies())
    TriggerClientEvent('esx:showNotification', src, "Deine Lobby wurde geschlossen.")
end)

RegisterNetEvent('ali_ffa:joinLobby')
AddEventHandler('ali_ffa:joinLobby', function(lobbyId, password)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local lobbyConfig = Config.Lobbies[lobbyId] or ActivePrivateLobbies[lobbyId]

    if not lobbyConfig then
        TriggerClientEvent('esx:showNotification', src, "Lobby nicht gefunden.")
        return
    end

    if lobbyConfig.isPrivate then
        if lobbyConfig.password and lobbyConfig.password ~= "" and lobbyConfig.password ~= password then
            TriggerClientEvent('esx:showNotification', src, "Falsches Passwort.")
            return
        end
    end

    local currentLoadout = xPlayer.getLoadout()
    

    
    MySQL.Async.execute(
        'INSERT INTO ali_ffaweapons (identifier, loadout) VALUES (@identifier, @loadout) ON DUPLICATE KEY UPDATE loadout = @loadout',
        {
            ['@identifier'] = xPlayer.identifier,
            ['@loadout'] = json.encode(currentLoadout) 
        },
        function(affectedRows)
            SetPlayerRoutingBucket(src, lobbyConfig.dimension)
            TriggerEvent('killfeed:setRangeForFFA', lobbyConfig.dimension)
            
            if not PlayerStats[xPlayer.identifier] then
                LoadPlayerStats(xPlayer.identifier)
            end
            BroadcastStats(lobbyId)

            TriggerClientEvent('ali_ffa:enterLobby', src, lobbyConfig, lobbyId)
        end
    )
end)

RegisterNetEvent('ali_ffa:removeInventoryWeapons')
AddEventHandler('ali_ffa:removeInventoryWeapons', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    Citizen.CreateThread(function()
        local currentLoadout = xPlayer.getLoadout()
        for i = 1, #currentLoadout, 1 do
            local weapon = currentLoadout[i]
            if weapon.name ~= 'WEAPON_UNARMED' then
                xPlayer.removeWeapon(weapon.name)
                Citizen.Wait(50)
            end
        end
        TriggerClientEvent('ali_ffa:giveLobbyWeapons', src)
    end)
end)

RegisterNetEvent('ali_ffa:leaveLobby')
AddEventHandler('ali_ffa:leaveLobby', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)

    if not xPlayer then return end

    if PlayerStats and PlayerStats[xPlayer.identifier] then
        SavePlayerStats(xPlayer.identifier)
        PlayerStats[xPlayer.identifier] = nil
    end

    local currentDimension = GetPlayerRoutingBucket(src)
    if currentDimension == 0 then return end

    local allLobbies = GetAllLobbies()
    local isInFFADimension = false
    for _, lobby in pairs(allLobbies) do
        if lobby.dimension == currentDimension then
            isInFFADimension = true
            break
        end
    end

    if isInFFADimension then
        SetPlayerRoutingBucket(src, 0)
        
        Citizen.Wait(500)
        
        MySQL.Async.fetchAll('SELECT loadout FROM ali_ffaweapons WHERE identifier = @identifier', 
        {['@identifier'] = xPlayer.identifier}, 
        function(result)
            MySQL.Async.execute('DELETE FROM ali_ffaweapons WHERE identifier = @identifier', 
            {['@identifier'] = xPlayer.identifier}, 
            function(rowsChanged)
                if result[1] and result[1].loadout then
                    local savedData = json.decode(result[1].loadout)
                    local loadoutToRestore = {}
                    
                    loadoutToRestore = savedData
                    
                    if type(loadoutToRestore) ~= "table" then
                        return
                    end
                    
                    local currentLoadout = xPlayer.getLoadout()
                    for i=1, #currentLoadout, 1 do
                        xPlayer.removeWeapon(currentLoadout[i].name)
                    end
                    
                    for i=1, #loadoutToRestore, 1 do
                        local weapon = loadoutToRestore[i]
                        if weapon and weapon.name then
                            xPlayer.addWeapon(weapon.name, weapon.ammo or 1000)
                            
                            if weapon.components then
                                for j=1, #weapon.components, 1 do
                                    if weapon.components[j] then
                                        xPlayer.addWeaponComponent(weapon.name, weapon.components[j])
                                    end
                                end
                            end
                            print("Added weapon: " .. weapon.name)
                        end
                    end
                    
                    MySQL.Async.execute(
                        'UPDATE users SET loadout = @loadout WHERE identifier = @identifier',
                        {
                            ['@identifier'] = xPlayer.identifier,
                            ['@loadout'] = json.encode(loadoutToRestore)
                        },
                        function(rowsChanged)
    
                            xPlayer.set('loadout', loadoutToRestore)
                        end
                    )
                end
                
                TriggerClientEvent('esx:showNotification', src, 'Deine Waffen wurden wiederhergestellt.')

                TriggerClientEvent('ali_ffa:client_leftLobby', src, {})
            end)
        end)
    end
end)


RegisterNetEvent('ali_ffa:playerGotKill')
AddEventHandler('ali_ffa:playerGotKill', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer then
        UpdatePlayerKill(xPlayer.identifier)
        LoadPlayerStats(xPlayer.identifier, function(stats)
            TriggerClientEvent('ali_ffa:updatePlayerStats', src, stats)
        end)
    end
end)

RegisterNetEvent('ali_ffa:playerKilled')
AddEventHandler('ali_ffa:playerKilled', function(killerId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    
    if not xPlayer then return end
    
    if killerId and killerId ~= src then
        local killerXPlayer = ESX.GetPlayerFromId(killerId)
        if killerXPlayer then
            UpdatePlayerKill(killerXPlayer.identifier)
            local killerStats = PlayerStats[killerXPlayer.identifier] or {kills = 0, deaths = 0}
            killerStats.kd = killerStats.deaths > 0 and (killerStats.kills / killerStats.deaths) or killerStats.kills
            TriggerClientEvent('ali_ffa:updateStats', killerId, killerStats)
        end
    end
end)

RegisterNetEvent('ali_ffa:getPlayerStats')
AddEventHandler('ali_ffa:getPlayerStats', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer then
        LoadPlayerStats(xPlayer.identifier, function(stats)
            TriggerClientEvent('ali_ffa:updatePlayerStats', src, stats)
        end)
    end
end)

RegisterNetEvent('ali_ffa:requestInitialLobbyList')
AddEventHandler('ali_ffa:requestInitialLobbyList', function()
    local src = source
    TriggerClientEvent('ali_ffa:updateLobbies', src, GetAllLobbies())
    
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer then
        LoadPlayerStats(xPlayer.identifier, function(stats)
            TriggerClientEvent('ali_ffa:updatePlayerStats', src, stats)
        end)
    end
    
    MySQL.Async.fetchAll(
        'SELECT s.kills, s.deaths, u.firstname, u.lastname FROM ali_ffastats AS s JOIN users AS u ON s.identifier = u.identifier ORDER BY s.kills DESC LIMIT 10',
        {},
        function(result)
            if result and #result > 0 then
                local statsToSend = {}
                for i=1, #result do
                    local player = result[i]
                    table.insert(statsToSend, {
                        name = player.firstname .. ' ' .. player.lastname,
                        kills = player.kills or 0,
                        deaths = player.deaths or 0
                    })
                end
                TriggerClientEvent('ali_ffa:updateScoreboard', src, statsToSend)
            end
        end
    )
end)

RegisterNetEvent('ali_ffa:requestLobbies')
AddEventHandler('ali_ffa:requestLobbies', function()
    local source = source
    TriggerClientEvent('ali_ffa:updateLobbies', source, GetAllLobbies())
end)

RegisterNetEvent('ali_ffa:resetPlayerStatus')
AddEventHandler('ali_ffa:resetPlayerStatus', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    
    if xPlayer then
        xPlayer.set('isDead', false)
        MySQL.Async.execute('UPDATE users SET is_dead = 0 WHERE identifier = @identifier', {
            ['@identifier'] = xPlayer.identifier
        })
    end
end)

RegisterNetEvent('ali_ffa:playerDied')
AddEventHandler('ali_ffa:playerDied', function(killerServerId, lobbyId)
    local victimId = source
    local victimPlayer = ESX.GetPlayerFromId(victimId)
    
    if not victimPlayer then return end

    if PlayerStats[victimPlayer.identifier] then
        PlayerStats[victimPlayer.identifier].deaths = PlayerStats[victimPlayer.identifier].deaths + 1
        SavePlayerStats(victimPlayer.identifier)
    else
        LoadPlayerStats(victimPlayer.identifier, function(stats)
            stats.deaths = (stats.deaths or 0) + 1
            SavePlayerStats(victimPlayer.identifier)
        end)
    end

    if killerServerId and killerServerId ~= -1 and killerServerId ~= victimId then
        local killerPlayer = ESX.GetPlayerFromId(killerServerId)
        if killerPlayer then
            if PlayerStats[killerPlayer.identifier] then
                PlayerStats[killerPlayer.identifier].kills = PlayerStats[killerPlayer.identifier].kills + 1
                SavePlayerStats(killerPlayer.identifier)
            else
                 LoadPlayerStats(killerPlayer.identifier, function(stats)
                    stats.kills = (stats.kills or 0) + 1
                    SavePlayerStats(killerPlayer.identifier)
                end)
            end
        end
    end

    local lobbyConfig = Config.Lobbies[lobbyId]
    if lobbyConfig then
        TriggerClientEvent('ali_killfeed:onPlayerDied', -1, killerServerId, victimId) 
        TriggerClientEvent('ali_ffa:handleCustomRespawn', victimId, lobbyConfig)
    end

    Citizen.Wait(250) 
    BroadcastStats(lobbyId)
end)

ESX.RegisterServerCallback('ali_ffa:getPlayerStats', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb(nil) end
    
    LoadPlayerStats(xPlayer.identifier, function(stats)
        cb({
            kills = stats.kills or 0,
            deaths = stats.deaths or 0,
            kd = (stats.kills or 0) / math.max(1, stats.deaths or 0)
        })
    end)
end)

ESX.RegisterServerCallback('ali_ffa:isPlayerInFFAA', function(source, cb)
    local src = source
    local inFFA = false
    local currentDimension = GetPlayerRoutingBucket(src)

    if currentDimension ~= 0 then
        local allLobbies = GetAllLobbies()
        for _, lobby in pairs(allLobbies) do
            if lobby.dimension == currentDimension then
                inFFA = true
                break
            end
        end
    end
    cb(inFFA)
end)

RegisterNetEvent('ali_ffa:playerRespawned')
AddEventHandler('ali_ffa:playerRespawned', function()
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        xPlayer.set('isDead', false)
    end
end)

AddEventHandler('esx:playerDropped', function(playerId, reason)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return end

    MySQL.Async.fetchAll('SELECT loadout FROM ali_ffaweapons WHERE identifier = @identifier', {['@identifier'] = xPlayer.identifier}, function(result)
        if result[1] and result[1].loadout then
            local savedData = json.decode(result[1].loadout)

            if savedData.loadout then
                MySQL.Async.execute(
                    'UPDATE users SET loadout = @loadout WHERE identifier = @identifier',
                    {
                        ['@identifier'] = xPlayer.identifier,
                        ['@loadout'] = json.encode(savedData.loadout)
                    }
                )
            end

            MySQL.Async.execute('DELETE FROM ali_ffaweapons WHERE identifier = @identifier', {['@identifier'] = xPlayer.identifier})
        
        end
    end)
end)

RegisterNetEvent('ali_ffa:setKillfeedRange')
AddEventHandler('ali_ffa:setKillfeedRange', function(range)
    TriggerEvent('killfeed:setRangeForFFA', range)
end)
