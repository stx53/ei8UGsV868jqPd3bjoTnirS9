ESX = exports['es_extended']:getSharedObject()

if not json then
    json = {}
    function json.encode(tbl) return json.encode(tbl) end
    function json.decode(str) return json.decode(str) end
end

local isMenuOpen = false
local isInFFA = false
local hudActive = false
local refreshTimer = nil
local playerStats = {
    kills = 0,
    deaths = 0
}
local currentLobbyBoundary = nil
local hasDied = false 
local currentLobby = nil
local currentLobbyId = nil
local inCombat = false
local lastDamageTime = 0
local outOfBoundsSince = nil
local isRespawnUIVisible = false

local function HealPlayer()
    local playerPed = PlayerPedId()
    SetEntityHealth(playerPed, GetEntityMaxHealth(playerPed))
end

RegisterNetEvent('ali_ffa:healAfterKill')
AddEventHandler('ali_ffa:healAfterKill', function()
    HealPlayer()
end)

RegisterNetEvent('ali_ffa:playerGotKill')
AddEventHandler('ali_ffa:playerGotKill', function()
    updateHUD()
end)

RegisterNetEvent('ali_ffa:playerKilled')
AddEventHandler('ali_ffa:playerKilled', function(killerId)
    updateHUD()
end)

function updateHUD(stats)
    if not isInFFA then return end
    
    if not stats then
        ESX.TriggerServerCallback('ali_ffa:getPlayerStats', function(serverStats)
            if not serverStats then return end
            updateHUD(serverStats)
        end)
        return
    end
    
    
    playerStats.kills = tonumber(stats.kills) or 0
    playerStats.deaths = tonumber(stats.deaths) or 0
    
    local kd = 0
    if playerStats.deaths > 0 then
        kd = playerStats.kills / playerStats.deaths
    elseif playerStats.kills > 0 then
        kd = playerStats.kills
    end
    
    SendNUIMessage({
        action = 'updatePlayerStats',
        kills = playerStats.kills,
        deaths = playerStats.deaths,
        kd = string.format("%.2f", kd)
    })
end

RegisterNetEvent('ali_ffa:updateStats')
AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        playerStats = {kills = 0, deaths = 0, kd = 0}
    end
end)

AddEventHandler('ali_ffa:updateStats', function(stats)
    if not stats then 
        print('No stats received in updateStats event')
        return 
    end
    print('Received stats update:', json.encode(stats))
    updateHUD(stats)
end)

Citizen.CreateThread(function()
    local lastHealth = -1
    while true do
        local wait = 1500 
        if isInFFA then
            wait = 250 
            local playerPed = PlayerPedId()
            if DoesEntityExist(playerPed) and not IsEntityDead(playerPed) then
                if isRespawnUIVisible then
                    SendNUIMessage({action = 'hideRespawnTimer'})
                    isRespawnUIVisible = false
                end
                local currentHealth = GetEntityHealth(playerPed)
                if lastHealth == -1 then
                    lastHealth = currentHealth
                end

                if currentHealth < lastHealth then
                    if not inCombat then
                        TriggerEvent('IMPULSEV_hud-v2:notify', 'info', 'Du bist im Kampf! Du kannst die Lobby für 5 Sekunden nicht verlassen.', 3000)
                    end
                    inCombat = true
                    lastDamageTime = GetGameTimer()
                end

                lastHealth = currentHealth

                if inCombat and (GetGameTimer() - lastDamageTime) > 5000 then
                    inCombat = false
                    TriggerEvent('IMPULSEV_hud-v2:notify', 'success', 'Du bist nicht mehr im Kampf.', 3000)
                end
            else
                lastHealth = -1 
                inCombat = false 
            end
        else
            if inCombat then
                inCombat = false
            end
            lastHealth = -1
        end
        Citizen.Wait(wait)
    end
end)


Citizen.CreateThread(function()
    while true do
        local wait = 1500 
        if isInFFA and currentLobbyBoundary then
            wait = 500 
            local playerPed = PlayerPedId()
            if DoesEntityExist(playerPed) then
                local playerCoords = GetEntityCoords(playerPed)
                local boundaryCenter = vector3(currentLobbyBoundary.center.x, currentLobbyBoundary.center.y, currentLobbyBoundary.center.z)
                local distance = #(playerCoords - boundaryCenter)

                if distance > currentLobbyBoundary.radius then
                    if not outOfBoundsSince then
                        outOfBoundsSince = GetGameTimer()
                    elseif (GetGameTimer() - outOfBoundsSince) > 3000 then
                        if currentLobby and currentLobby.spawnpoints and #currentLobby.spawnpoints > 0 then
                            TriggerEvent('IMPULSEV_hud-v2:notify', 'success', 'Du wurdest zurück in die Zone teleportiert.', 3000)
                            local spawnPoint = currentLobby.spawnpoints[math.random(#currentLobby.spawnpoints)]
                            ESX.Game.Teleport(playerPed, spawnPoint)
                            outOfBoundsSince = nil
                        end
                    end
                else
                    if outOfBoundsSince then
                        outOfBoundsSince = nil
                    end
                end
            end
        else
            if outOfBoundsSince then
                outOfBoundsSince = nil
            end
        end
        Citizen.Wait(wait)
    end
end)

RegisterNetEvent('ali_ffa:updateScoreboard')
AddEventHandler('ali_ffa:updateScoreboard', function(players)
    SendNUIMessage({
        action = 'updateScoreboard',
        players = players
    })
end)

RegisterNetEvent('ali_ffa:client_leftLobby')
AddEventHandler('ali_ffa:client_leftLobby', function(savedLoadout)
    local playerPed = PlayerPedId()
    
    if isInFFA then
        SendNUIMessage({ 
            action = 'toggleHUD',
            show = false 
        })
    end
    
    RemoveAllPedWeapons(playerPed, true)

    if savedLoadout and #savedLoadout > 0 then
        for i=1, #savedLoadout, 1 do
            GiveWeaponToPed(playerPed, GetHashKey(savedLoadout[i].name), savedLoadout[i].ammo, false, true)
        end
    end
    
    SetEntityCoords(playerPed, Config.QuitLocation.x, Config.QuitLocation.y, Config.QuitLocation.z, true, false, false, true)
    
    isInFFA = false
    currentLobbyBoundary = nil
    TriggerServerEvent('ali_ffa:setKillfeedRange', 0)
end)

RegisterCommand('quitffa', function()
    if IsEntityDead(PlayerPedId()) then
        TriggerEvent('IMPULSEV_hud-v2:notify', 'error', 'Du kannst die Lobby nicht verlassen, während du tot bist.', 3000)
        return
    end

    if not isInFFA then
        TriggerEvent('IMPULSEV_hud-v2:notify', 'error', 'Du befindest dich in keiner FFA-Lobby.', 3000)
        return
    end

    if inCombat then
        local timeLeft = 5 - math.floor((GetGameTimer() - lastDamageTime) / 1000)
        TriggerEvent('IMPULSEV_hud-v2:notify', 'error', 'Du kannst im Kampf nicht gehen. Bitte warte noch ' .. timeLeft .. ' Sekunden.', 3000)
        return
    end

    TriggerServerEvent('ali_ffa:leaveLobby')
end, false)

Citizen.CreateThread(function()
    while true do
        local wait = 1500
        if isInFFA then
            wait = 500
            if IsPedArmed(PlayerPedId(), 7) then
                local _, currentWeapon = GetCurrentPedWeapon(PlayerPedId(), true)
                SetAmmoInClip(PlayerPedId(), currentWeapon, 250)
            end
        end
        Citizen.Wait(wait)
    end
end)

function ToggleLobbyMenu(state)
    isMenuOpen = state
    SetNuiFocus(isMenuOpen, isMenuOpen)
    SendNUIMessage({ action = 'setVisible', status = isMenuOpen })

    if isMenuOpen then
        TriggerServerEvent('ali_ffa:requestInitialLobbyList')
    end
end

RegisterCommand('lobby', function()
    ToggleLobbyMenu(not isMenuOpen)
end, false)

RegisterNUICallback('closeMenu', function(data, cb)
    ToggleLobbyMenu(false)
    cb('ok')
end)

RegisterNUICallback('closeLobby', function(data, cb)
    if data.id then
        TriggerServerEvent('ali_ffa:closePrivateLobby', data.id)
    end
    cb('ok')
end)

RegisterNUICallback('hideUI', function(data, cb)
    ToggleLobbyMenu(false)
    cb('ok')
end)

RegisterNUICallback('getLobbies', function(data, cb)
    local publicLobbies = {}
    for id, lobby in pairs(Config.Lobbies) do
        publicLobbies[id] = {
            id = id,
            name = lobby.name,
            image = lobby.image,
            type = 'Public'
        }
    end
    cb(publicLobbies)
end)

RegisterNUICallback('getPlayers', function(data, cb)
    cb({})
end)

RegisterNUICallback('createPrivateLobby', function(data, cb)
    if not data.lobbyName or data.lobbyName == '' then
        ESX.ShowNotification('Bitte gib einen Lobby-Namen ein')
        cb('error: no lobby name')
        return
    end
    
    if not data.mapName then
        ESX.ShowNotification('Bitte wähle eine Map aus')
        cb('error: no map selected')
        return
    end
    

    
    TriggerServerEvent('ali_ffa:createPrivateLobby', {
        lobbyName = data.lobbyName,
        password = data.password or '',
        mapName = data.mapName
    })
    
    ToggleLobbyMenu(false)
    cb('ok')
end)

RegisterNUICallback('joinLobby', function(data, cb)
    if data.lobbyId then
        TriggerServerEvent('ali_ffa:joinLobby', data.lobbyId, data.password)
        ToggleLobbyMenu(false)
        cb('ok')
    else
        cb('error: no lobbyId provided')
    end
end)

AddEventHandler('esx:playerLoaded', function(playerData)
    ESX.PlayerData = playerData
    TriggerServerEvent('ali_ffa:requestLobbies')
end)

RegisterNetEvent('ali_ffa:updateLobbies')
AddEventHandler('ali_ffa:updateLobbies', function(lobbies)
    SendNUIMessage({
        action = 'updateLobbies',
        lobbies = lobbies,
        playerIdentifier = ESX.PlayerData.id
    })
end)

RegisterNetEvent('ali_ffa:enterLobby')
AddEventHandler('ali_ffa:enterLobby', function(lobbyConfig, lobbyId, stats)
    ToggleLobbyMenu(false)
    isInFFA = true
    currentLobby = lobbyConfig
    currentLobbyId = lobbyId
    
    updateHUD()
    

    
    local function refreshHUD()
        if not isInFFA then

            return
        end
        
        updateHUD()
        refreshTimer = Citizen.SetTimeout(5000, refreshHUD)
    end
    
    refreshHUD()
    
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    
    Citizen.Wait(100)
    
    SendNUIMessage({ 
        action = 'toggleHUD',
        show = true 
    })
    currentLobbyBoundary = lobbyConfig.boundary
    local playerPed = PlayerPedId()
    local coords = lobbyConfig.spawnpoints[math.random(1, #lobbyConfig.spawnpoints)]

    ESX.Game.Teleport(playerPed, coords)
    
    RemoveAllPedWeapons(playerPed, true)
    TriggerServerEvent('ali_ffa:removeInventoryWeapons')

    SetPlayerHealthRechargeMultiplier(PlayerId(), 0.0)
end)
RegisterNetEvent('ali_ffa:giveLobbyWeapons')
AddEventHandler('ali_ffa:giveLobbyWeapons', function()
    if not isInFFA or not currentLobby then return end

    local playerPed = PlayerPedId()
    for _, weaponData in ipairs(currentLobby.weapons) do
        GiveWeaponToPed(playerPed, GetHashKey(weaponData.name), weaponData.ammo, false, true)
    end
end)

RegisterNetEvent('ali_ffa:forceLeaveLobby')
AddEventHandler('ali_ffa:forceLeaveLobby', function()
    if not isInFFA then return end

    local playerPed = PlayerPedId()
    ESX.Game.Teleport(playerPed, Config.QuitLocation)
    SetPlayerRoutingBucket(0)

    if currentLobbyId then
        TriggerServerEvent('ali_ffa:restorePlayerLoadout', currentLobbyId)
    end

    isInFFA = false
    currentLobbyId = nil
    currentLobby = nil
    hasDied = false
    ClearBoundary()

    ESX.ShowNotification("Die Lobby wurde vom Besitzer geschlossen.")
    ToggleLobbyMenu(false)
end)

local isPlayerDead = false

Citizen.CreateThread(function()
    while true do
        Wait(100) 
        local playerPed = PlayerPedId()

        if IsEntityDead(playerPed) and isInFFA and not hasDied then
            hasDied = true 
            Wait(300)
            TriggerEvent('b-deathtimeout:beenden')
            TriggerEvent('removeCombat')
            local killer = GetPedSourceOfDeath(playerPed)
            local killerServerId = -1
            if DoesEntityExist(killer) and IsEntityAPed(killer) and IsPedAPlayer(killer) then
                local killerPlayer = NetworkGetPlayerIndexFromPed(killer)
                if killerPlayer ~= -1 then
                    killerServerId = GetPlayerServerId(killerPlayer)
                end
            end
            TriggerServerEvent('ali_ffa:playerDied', killerServerId, currentLobbyId)
            TriggerEvent('b-deathtimeout:beenden')
        end
    end
end)

RegisterNetEvent('ali_ffa:updateScoreboard')
AddEventHandler('ali_ffa:updateScoreboard', function(players)
    SendNUIMessage({
        action = 'updateScoreboard',
        players = players
    })
end)

RegisterNUICallback('closeMenu', function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'setVisible', status = false })
    cb('ok')
end)

RegisterNetEvent('ali_ffa:handleCustomRespawn')
AddEventHandler('ali_ffa:handleCustomRespawn', function(lobbyConfig)
    local respawnTime = 3

    SendNUIMessage({action = 'showRespawnTimer', duration = respawnTime})
    isRespawnUIVisible = true

    Citizen.CreateThread(function()
        Citizen.Wait(respawnTime * 1000)

        DoScreenFadeOut(500)
        Citizen.Wait(500)

        local playerPed = PlayerPedId()
        
        if lobbyConfig.spawnpoints and #lobbyConfig.spawnpoints > 0 then
            local randomIndex = math.random(1, #lobbyConfig.spawnpoints)
            local spawnPoint = lobbyConfig.spawnpoints[randomIndex]
            
            local x, y, z = spawnPoint.x, spawnPoint.y, spawnPoint.z
            local heading = ((type(spawnPoint) == 'vector4' or type(spawnPoint) == 'table') and spawnPoint.w) or 0.0
            
            NetworkResurrectLocalPlayer(x, y, z, heading, true, false)
            
            SetEntityCoordsNoOffset(playerPed, x, y, z, false, false, false, true)
            SetEntityHeading(playerPed, heading)
        else
            local x, y, z = table.unpack(GetEntityCoords(playerPed))
            NetworkResurrectLocalPlayer(x, y, z + 1.0, 0.0, true, false)
        end
        
        Wait(100)
        
        local playerPed = PlayerPedId()
        
        TriggerServerEvent('ali_ffa:resetPlayerStatus')
        
        SetPlayerControl(PlayerId(), true, 0)
        
        ESX.SetPlayerData('isDead', false)
        
        Wait(300)
        TriggerEvent('b-deathtimeout:beenden')
        Wait(100)
        TriggerEvent('esx_ambulancejob:revive')
        Wait(300)
        TriggerEvent('b-deathtimeout:beenden')
        Wait(300)
        TriggerEvent('removeCombat')
        Wait(300)
        TriggerEvent('b-deathtimeout:beenden')
        
        FreezeEntityPosition(playerPed, false)
        ClearPedTasksImmediately(playerPed)
        SetEntityInvincible(playerPed, true)

        RemoveAllPedWeapons(playerPed, true)
        for _, weapon in ipairs(lobbyConfig.weapons) do
            GiveWeaponToPed(playerPed, GetHashKey(weapon.name), weapon.ammo, false, true)
        end

        hasDied = false
        DoScreenFadeIn(500)
        ShutdownLoadingScreen()
        SendNUIMessage({action = 'hideRespawnTimer'})
        isRespawnUIVisible = false


        Citizen.CreateThread(function()
            Citizen.Wait(5000)
            SetEntityInvincible(playerPed, false)
        end)

        TriggerEvent('b-deathtimeout:beenden')
        Wait(100)
        TriggerServerEvent('ali_ffa:playerRespawned')
        isPlayerDead = false
        Wait(100)
        TriggerEvent('b-deathtimeout:beenden')
        
    end)
end)

RegisterNetEvent('ali_ffa:client_leftLobby')
AddEventHandler('ali_ffa:client_leftLobby', function(savedLoadout)
    local playerPed = PlayerPedId()
    
    if isInFFA then
        SendNUIMessage({ 
            action = 'toggleHUD',
            show = false 
        })
    end
    
    RemoveAllPedWeapons(playerPed, true)

    if savedLoadout and #savedLoadout > 0 then
        for i=1, #savedLoadout, 1 do
            GiveWeaponToPed(playerPed, GetHashKey(savedLoadout[i].name), savedLoadout[i].ammo, false, true)
        end
    end
    
    SetEntityCoords(playerPed, Config.QuitLocation.x, Config.QuitLocation.y, Config.QuitLocation.z, true, false, false, true)
    
    isInFFA = false
    currentLobbyBoundary = nil
    TriggerServerEvent('ali_ffa:setKillfeedRange', 0)
end)

Citizen.CreateThread(function()
    while true do
        local wait = 1500
        if isInFFA and currentLobbyBoundary then
            wait = 1
            DrawSphere(currentLobbyBoundary.center.x, currentLobbyBoundary.center.y, currentLobbyBoundary.center.z, currentLobbyBoundary.radius, currentLobbyBoundary.color.r, currentLobbyBoundary.color.g, currentLobbyBoundary.color.b, 0.2)
        end
        Citizen.Wait(wait)
    end
end)

Citizen.CreateThread(function()
    local blip = AddBlipForCoord(Config.MainBlip.coords)
    SetBlipSprite(blip, Config.MainBlip.sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, Config.MainBlip.scale)
    SetBlipColour(blip, Config.MainBlip.color)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(Config.MainBlip.text)
    EndTextCommandSetBlipName(blip)

    while true do
        local wait = 1500
        if not isInFFA then
            local playerPed = PlayerPedId()
            local coords = GetEntityCoords(playerPed)
            local distance = #(coords - Config.MainBlip.coords)

            if distance < 4.0 then
                wait = 5 
                DrawMarker(1, Config.MainBlip.coords.x, Config.MainBlip.coords.y, Config.MainBlip.coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 4.5, 4.5, 0.1, 0, 255, 0, 100, false, true, 2, nil, nil, false)
                if distance < 2.0 then
                    ESX.ShowHelpNotification('Press ~INPUT_CONTEXT~ to open the FFA menu.')
                    if IsControlJustReleased(0, 38) then
                        ToggleLobbyMenu(true)
                    end
                end
            end
        end
        Citizen.Wait(wait)
    end
end)

Citizen.CreateThread(function()
    Wait(1000)
    ToggleLobbyMenu(false)
end)
