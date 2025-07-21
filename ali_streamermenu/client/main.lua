local menuOpen = false
local ESX = nil
local killfeedActive = false 

CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        TriggerEvent('es_extended:getSharedObject', function(obj) ESX = obj end)
        if ESX ~= nil then
            break
        end
        Wait(100)
    end
end)

RegisterCommand('streamermenu', function()
    if ESX == nil then return end
    
    ESX.TriggerServerCallback('ali_streamermenu:checkGroup', function(hasAccess)
        if not hasAccess then return end
        
        TriggerServerEvent('ali_streamermenu:logAction', 'menuOpen', 'Menü geöffnet')

        ESX.TriggerServerCallback('ali_streamermenu:getJobs', function(jobs)
            menuOpen = not menuOpen
            SetNuiFocus(menuOpen, menuOpen)
            SendNUIMessage({
                type = 'ui',
                status = menuOpen,
                jobs = jobs or {}
            })
        end)
    end)
end, false)

RegisterNUICallback('close', function(data, cb)
    menuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'ui', status = false })
    cb('ok')
end)

RegisterNUICallback('teleportToPlayer', function(data, cb)
    local playerId = tonumber(data.playerId)
    local targetPed = GetPlayerPed(GetPlayerFromServerId(playerId))
    if DoesEntityExist(targetPed) then
        TriggerServerEvent('ali_streamermenu:logAction', 'teleport', 'Teleport zu Spieler', 'Ziel ID: ' .. playerId)
        SetEntityCoords(PlayerPedId(), GetEntityCoords(targetPed))
    end
    cb('ok')
end)

local function closeMenu()
    menuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'ui', status = false })
end

RegisterNUICallback('performControlAction', function(data, cb)
    local control = data.control

    if control == 'rv' then
        TriggerServerEvent('ali_streamermenu:logAction', 'revive', 'Revive genutzt', 'sich selbst')
        ExecuteCommand('rv ' .. GetPlayerServerId(PlayerId()))
        closeMenu()
    elseif control == 'nc' then
        TriggerServerEvent('ali_streamermenu:logAction', 'noclip', 'Noclip umgeschaltet')
        ExecuteCommand('noclip')
        closeMenu()
    elseif control == 'nt' then
        TriggerServerEvent('ali_streamermenu:logAction', 'nametags', 'Namen-Tags umgeschaltet')
        ExecuteCommand('namen+')
        closeMenu()
    elseif control == 'tk' then
        if killfeedActive then
            TriggerServerEvent('ali_streamermenu:logAction', 'killfeed', 'Killfeed deaktiviert')
            ExecuteCommand('killfeed 0')
        else
            TriggerServerEvent('ali_streamermenu:logAction', 'killfeed', 'Killfeed aktiviert')
            ExecuteCommand('killfeed 200')
        end
        killfeedActive = not killfeedActive
        closeMenu()
    elseif control == 'streamerpanic' then
        TriggerServerEvent('ali_streamermenu:logAction', 'streamerpanic', 'Streamer Panic ausgelöst')
        ExecuteCommand('streamerpanic')
        closeMenu()
    end
    cb('ok')
end)

RegisterNUICallback('selectJob', function(data, cb)
    local job = data.job
    TriggerServerEvent('ali_streamermenu:logAction', 'jobFilter', 'Spieler nach Job gefiltert', 'Job: ' .. job)
    ESX.TriggerServerCallback('ali_streamermenu:getPlayersByJob', function(players)
        SendNUIMessage({
            type = 'updatePlayers',
            players = players
        })
    end, job)
    cb('ok')
end)
