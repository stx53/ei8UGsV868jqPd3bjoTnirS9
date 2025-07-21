ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

function SendToDiscord(webhookUrl, name, message, color)
    if not webhookUrl or webhookUrl == 'SCHWANZ' then return end

    local embed = {
        {
            ["color"] = 65280,
            ["title"] = name,
            ["description"] = message,
            ["footer"] = {
                ["text"] = "ali_streamermenu | " .. os.date("%d.%m.%Y %H:%M:%S")
            }
        }
    }

    PerformHttpRequest(webhookUrl, function(err, text, headers) end, 'POST', json.encode({embeds = embed}), { ['Content-Type'] = 'application/json' })
end

RegisterNetEvent('ali_streamermenu:logAction', function(logType, actionName, details)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local webhookUrl = Config.Webhooks[logType]
    if not webhookUrl then
        return
    end

    local message = string.format("**Spieler:** %s (`%s`)\n**Aktion:** %s", xPlayer.getName(), src, actionName)
    if details then
        message = message .. "\n**Details:** " .. details
    end

    SendToDiscord(webhookUrl, "Streamer Menü Log", message, 15158332)
end)

ESX.RegisterServerCallback('ali_streamermenu:checkGroup', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    local allowed = false
    
    if xPlayer then
        local groups = {'streamer', 'projektleitung', 'management'}
        local playerGroup = xPlayer.getGroup()
        
        for _, group in ipairs(groups) do
            if playerGroup == group then
                allowed = true
                break
            end
        end
    end
    
    cb(allowed)
end)

ESX.RegisterServerCallback('ali_streamermenu:getJobs', function(source, cb)
    local jobs = {}
    local players = ESX.GetPlayers()
    
    for _, playerId in ipairs(players) do
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer then
            jobs[xPlayer.job.name] = (jobs[xPlayer.job.name] or 0) + 1
        end
    end
    
    cb(jobs)
end)

ESX.RegisterServerCallback('ali_streamermenu:getPlayersByJob', function(source, cb, jobName)
    local playersWithJob = {}
    local players = ESX.GetPlayers()

    for _, playerId in ipairs(players) do
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer and xPlayer.job.name == jobName then
            local ped = GetPlayerPed(xPlayer.source)
            local health = GetEntityHealth(ped)
            local armor = GetPedArmour(ped)

            table.insert(playersWithJob, {
                id = xPlayer.source,
                name = xPlayer.name,
                health = health,
                armor = armor
            })
        end
    end

    cb(playersWithJob)
end)
