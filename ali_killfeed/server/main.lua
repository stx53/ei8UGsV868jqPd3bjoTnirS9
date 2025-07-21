ESX = exports["es_extended"]:getSharedObject()
local playerCache = {}

local function getPlayerName(source)
    if playerCache[source] then
        return playerCache[source]
    end

    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return GetPlayerName(source) end

    local result = MySQL.Sync.fetchAll('SELECT firstname, lastname FROM users WHERE identifier = ?', {
        xPlayer.getIdentifier()
    })

    if result and result[1] then
        local fullName = result[1].firstname .. ' ' .. result[1].lastname
        playerCache[source] = fullName
        return fullName
    end

    return GetPlayerName(source)
end

AddEventHandler('playerDropped', function()
    playerCache[source] = nil
end)

RegisterCommand(Config.Command, function(source, args)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer or Config.BlacklistedGroups[xPlayer.getGroup()] then
        TriggerClientEvent('IMPULSEV_hud-v2:notify', source, 'error', 'Keine Berechtigung', 5000)
        return
    end

    local range = tonumber(args[1])
    if not range then
        TriggerClientEvent('IMPULSEV_hud-v2:notify', source, 'error', 'Bitte gib eine gültige Reichweite an', 5000)
        return
    end

    TriggerClientEvent('killfeed:setRange', source, range)
    TriggerClientEvent('IMPULSEV_hud-v2:notify', source, 'success', 'Reichweite auf ' .. range .. 'm gesetzt', 5000)
end)

RegisterNetEvent('killfeed:setRangeForFFA')
AddEventHandler('killfeed:setRangeForFFA', function(range)
    TriggerClientEvent('killfeed:setRange', -1, range)
end)

RegisterServerEvent('baseevents:onPlayerDeath')
AddEventHandler('baseevents:onPlayerDeath', function(killerServerId, deathData)
    local victimServerId = source
    local victimPed = GetPlayerPed(victimServerId)
    local victimCoords = GetEntityCoords(victimPed)
    local victimName = getPlayerName(victimServerId)
    
    if killerServerId == -1 or killerServerId == victimServerId then
        TriggerClientEvent('killfeed:show', -1, victimCoords, nil, victimName, 0)
        return
    end
    
    local killerName = getPlayerName(killerServerId)
    local killerPed = GetPlayerPed(killerServerId)
    local killerCoords = GetEntityCoords(killerPed)
    local killDistance = math.floor(#(victimCoords - killerCoords))
    
    TriggerClientEvent('killfeed:show', -1, victimCoords, killerName, victimName, killDistance)
end)

RegisterCommand('simulatekill', function(source, args)
    local xPlayer = ESX.GetPlayerFromId(source)
    
    if not xPlayer or xPlayer.getGroup() ~= 'projektleitung' then
        TriggerClientEvent('IMPULSEV_hud-v2:notify', source, 'error', 'Keine Berechtigung', 5000)
        return
    end
    
    local victimName = args[1] or 'TestVictim'
    local killerName = args[2] or 'TestKiller'
    local distance = tonumber(args[3]) or 100
    
    TriggerClientEvent('killfeed:show', -1, GetEntityCoords(GetPlayerPed(source)), killerName, victimName, distance)
    TriggerClientEvent('IMPULSEV_hud-v2:notify', source, 'info', 'Kill simuliert: ' .. killerName .. ' tötete ' .. victimName .. ' (' .. distance .. 'm)', 5000)
end)