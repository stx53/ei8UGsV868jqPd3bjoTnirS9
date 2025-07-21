ESX = exports['es_extended']:getSharedObject()

local display = false
local currentQueueState = {} 
local activeWarsClient = {} 
local factionLogosClient = {}
local isWarJoinActive = false
local activeJoinZoneName = nil
local hasSpawnedVehicles = false
local currentWarSpawnPoints = nil 
local isPlayerCurrentlyInGw = false
local protectionId = 0
local playerBlips = {}

AddEventHandler('playerDied', function(killer, reason)
    if isPlayerCurrentlyInGw then
        TriggerServerEvent('ali_gw:playerDiedInGw', killer)
        Citizen.CreateThread(function()
            Wait(2000)
            TriggerEvent('esx_ambulancejob:revive')
            Wait(2000)
            TriggerEvent('b-deathtimeout:beenden')
            Wait(2000)
            TriggerEvent('removeCombat')
        end)
    end
end)

RegisterNetEvent('ali_gw:playerEliminated', function(teleportCoords)
    isPlayerCurrentlyInGw = false
    isJoinMarkerActive = false
    activeJoinZoneName = nil


    protectionId = protectionId + 1 

    ESX.TriggerServerCallback('ali_gw:restorePlayerInventory', function(success)
        if success then
            TriggerEvent('IMPULSEV_hud-v2:notify', 'inform', 'Du wurdest getötet und aus dem Gangwar entfernt.', 5000)
        else
            TriggerEvent('IMPULSEV_hud-v2:notify', 'error', 'Fehler bei der Wiederherstellung deines Inventars, Melde dich im Support', 5000)
        end
    end)


    if teleportCoords then
        ESX.Game.Teleport(PlayerPedId(), teleportCoords)
    end
    TriggerServerEvent('ali_gw:setPlayerBucket', 0)
end)

exports('isPlayerInActiveGw', function()
    return isPlayerCurrentlyInGw
end) 


RegisterNetEvent('ali_gw:stateUpdate')
AddEventHandler('ali_gw:stateUpdate', function(queueState, warsState, logos)
    currentQueueState = queueState or {}
    activeWarsClient = warsState or {}
    factionLogosClient = logos or {}

    if not activeWarsClient or type(activeWarsClient) ~= 'table' then
        activeWarsClient = {}
    end

    for zone, warData in pairs(activeWarsClient) do
        if not warData or type(warData) ~= 'table' or not warData.attacker or not warData.defender then
            activeWarsClient[zone] = nil
        end
    end

    local warsToSend = {}
    if isPlayerCurrentlyInGw then
        warsToSend = activeWarsClient
    end

    if display and ESX.PlayerData.job and ESX.PlayerData.job.name then
        local playerJob = ESX.PlayerData.job.name
        for _, warData in pairs(activeWarsClient) do
            if warData.defender == playerJob or warData.attacker == playerJob then
                closeNUI()
                break
            end
        end
    end

    SendNUIMessage({
        type = "stateUpdate",
        queueState = currentQueueState,
        activeWars = warsToSend,
        factionLogos = factionLogosClient
    })
end)

function openNUI()
    if ESX.PlayerData and ESX.PlayerData.job and ESX.PlayerData.job.name then
        local playerJob = ESX.PlayerData.job.name
        for _, warData in pairs(activeWarsClient) do
            if warData.defender == playerJob or warData.attacker == playerJob then
                TriggerEvent('IMPULSEV_hud-v2:notify', 'error', "Deine Fraktion kämpft bereits.", 3500)
                return 
            end
        end
    end

    ESX.TriggerServerCallback('ali_gw:getInitialNuiData', function(data)
        if data then
            if data.stats and data.overview then
                data.stats.overview = data.overview
            end

  
            SendNUIMessage({
                type = "ui",
                status = true,
                areas = Config.gwgebiete,
                queueState = currentQueueState,
                activeWars = activeWarsClient,
                playerFaction = ESX.PlayerData.job and ESX.PlayerData.job.name or "unemployed",
                factionLogos = factionLogosClient,
                shopItems = data.shopItems,
                stats = data.stats
            })

            display = true
            SetNuiFocus(true, true)
        end
    end)
end

function closeNUI()
    display = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        type = "ui",
        status = false
    })
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if display and IsControlJustReleased(0, 322) then 
            closeNUI()
        end
    end
end)


AddEventHandler('esx:onPlayerDeath', function(data)
    if isPlayerCurrentlyInGw then
        local killerId = data and data.killerServerId or -1
        TriggerServerEvent('ali_gw:playerDiedInGw', killerId)
        Citizen.CreateThread(function()
            Wait(2000)
            TriggerEvent('esx_ambulancejob:revive')
            Wait(2000)
            TriggerEvent('b-deathtimeout:beenden')
            Wait(2000)
            TriggerEvent('removeCombat')
        end)
    end
end)

RegisterNetEvent('ali_gw:resetGwState')
AddEventHandler('ali_gw:resetGwState', function()
    hasSpawnedVehicles = false 
    currentWarSpawnPoints = nil
    isJoinMarkerActive = false
    isPlayerCurrentlyInGw = false 
end)

RegisterNetEvent('ali_gw:cancelWarCleanup')
AddEventHandler('ali_gw:cancelWarCleanup', function(teleportCoords)
    if not isPlayerCurrentlyInGw then return end

    protectionId = protectionId + 1 
    isPlayerCurrentlyInGw = false
    isJoinMarkerActive = false
    activeJoinZoneName = nil

    if teleportCoords then
        ESX.Game.Teleport(PlayerPedId(), teleportCoords)
    end

    TriggerServerEvent('ali_gw:setPlayerBucket', 0)

    SendNUIMessage({
        action = 'hideWarHud'
    })

    TriggerServerEvent('ali_gw:restorePlayerInventoryOnWarEnd')

    if playerBlips then
        for _, data in pairs(playerBlips) do
            if DoesBlipExist(data.blip) then
                RemoveBlip(data.blip)
            end
        end
        playerBlips = {}
    end
end)

RegisterNetEvent('ali_gw:warEnded')
AddEventHandler('ali_gw:warEnded', function(winner, zoneName)
    if not isPlayerCurrentlyInGw then return end

    isPlayerCurrentlyInGw = false
    isJoinMarkerActive = false
    activeJoinZoneName = nil

    TriggerServerEvent('ali_gw:setPlayerBucket', 0)

    SendNUIMessage({
        action = 'hideWarHud'
    })

    if winner then
        local playerJob = ESX.GetPlayerData().job.name
        local message = 'Ihr habt das Gangwar in ' .. zoneName .. ' gewonnen!'
        if winner ~= playerJob then
            message = 'Ihr habt das Gangwar in ' .. zoneName .. ' verloren!'
        end
        TriggerEvent('IMPULSEV_hud-v2:notify', 'success', message, 10000)
    end

    TriggerServerEvent('ali_gw:restorePlayerInventoryOnWarEnd')

    for _, data in pairs(playerBlips) do
        if DoesBlipExist(data.blip) then
            RemoveBlip(data.blip)
        end
    end
    playerBlips = {}
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
    ESX.PlayerData.job = job
end)

RegisterNetEvent('ali_gw:teleport', function(coords)
    local playerPed = PlayerPedId()
    SetEntityCoords(playerPed, coords.x, coords.y, coords.z)
    SetEntityHeading(playerPed, coords.h or coords.heading)
end)

RegisterNUICallback('startGwRequest', function(data, cb)
    if data and data.zoneName then
        TriggerServerEvent('ali_gw:requestGw', data.zoneName)
    end
    cb('ok')
end)

RegisterNUICallback('close', function(data, cb)
    closeNUI()
    cb('ok')
end)

RegisterNUICallback('buyShopItem', function(data, cb)
    if data and data.item then
        TriggerServerEvent('ali_gw:buyShopItem', data.item)
    end
    cb('ok')
end)

RegisterNetEvent('ali_gw:teleportToZone')
AddEventHandler('ali_gw:teleportToZone', function(spawnPool)
    isPlayerCurrentlyInGw = true
    if not spawnPool or type(spawnPool) ~= 'table' or #spawnPool == 0 then

        TriggerEvent('IMPULSEV_hud-v2:notify', 'error', 'Keine Spawnpunkte für den Kampf gefunden!', 10000)
        return
    end

    if not ESX.PlayerData or not ESX.PlayerData.job or not ESX.PlayerData.job.name then

        TriggerEvent('IMPULSEV_hud-v2:notify', 'error', 'Keine Fraktion!', 5000)
        return
    end

    local spawnPoint = spawnPool[1]
    if not spawnPoint or type(spawnPoint) ~= 'table' or not spawnPoint.x or not spawnPoint.y or not spawnPoint.z then

        TriggerEvent('IMPULSEV_hud-v2:notify', 'error', 'Ungültiger Spawnpunkt!', 5000)
        return
    end

    local playerPed = PlayerPedId()
    SetEntityCoords(playerPed, spawnPoint.x, spawnPoint.y, spawnPoint.z, false, false, false, true)
    SetEntityHeading(playerPed, spawnPoint.h or 0.0)
    FreezeEntityPosition(playerPed, true)

    Citizen.Wait(500) 
    FreezeEntityPosition(playerPed, false)
end)



local isShowingHelpNotify = false

local currentBlip = nil
local currentPlayerJob = nil

function UpdateBlipForJob(job)
    if currentBlip and DoesBlipExist(currentBlip) then
        RemoveBlip(currentBlip)
        currentBlip = nil
    end

    if not job or not job.name then
        return
    end
    local factionMarkerInfo = nil
    for _, marker in ipairs(Config.interactionMarkers) do
        if string.lower(marker.name) == string.lower(job.name) then
            factionMarkerInfo = marker
            break
        end
    end

    if factionMarkerInfo then
        local coords = factionMarkerInfo.coords
        currentBlip = AddBlipForCoord(coords.x, coords.y, coords.z)

        if DoesBlipExist(currentBlip) then
            SetBlipSprite(currentBlip, 475)
            SetBlipScale(currentBlip, 0.6)
            SetBlipColour(currentBlip, 4)
            SetBlipAsShortRange(currentBlip, false)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString("Gangwar: " .. factionMarkerInfo.name)
            EndTextCommandSetBlipName(currentBlip)
        end
    end
end

Citizen.CreateThread(function()
    while not ESX.IsPlayerLoaded() do
        Citizen.Wait(500)
    end
    TriggerServerEvent('ali_gw:requestInitialJob')
end)

RegisterNetEvent('ali_gw:receiveInitialJob')
AddEventHandler('ali_gw:receiveInitialJob', function(job)
    currentPlayerJob = job
    UpdateBlipForJob(job)
end)

AddEventHandler('esx:setJob', function(job)
    currentPlayerJob = job
    UpdateBlipForJob(job)
end)

Citizen.CreateThread(function()
    while true do
        local waitTime = 1000

        if currentBlip and DoesBlipExist(currentBlip) then
            local playerCoords = GetEntityCoords(PlayerPedId())
            local blipCoords = GetBlipCoords(currentBlip)
            local distance = #(playerCoords - blipCoords)

            if distance < 50.0 then
                waitTime = 100
                if distance < 4.0 then
                    waitTime = 5
                    local playerJob = currentPlayerJob
                    
                    if playerJob and playerJob.name then
                        if isWarJoinActive then
                            local scale = 2.0 + (math.sin(GetGameTimer() / 200) * 0.2)
                            DrawMarker(1, blipCoords.x, blipCoords.y, blipCoords.z - 0.98, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, scale, scale, scale, 0, 255, 0, 100, false, true, 2, false, nil, nil, false)
                            if distance < 2.0 then
                                ESX.ShowHelpNotification("Drücke ~INPUT_CONTEXT~, um dem Kampf beizutreten.")
                                if IsControlJustReleased(0, 38) then
                                    TriggerServerEvent('ali_gw:playerWantsToJoinWar', activeJoinZoneName)
                                end
                            end
                        else
                            local isWarOngoingForFaction = false
                            for _, warData in pairs(activeWarsClient) do
                                if warData.defender == playerJob.name or warData.attacker == playerJob.name then
                                    isWarOngoingForFaction = true
                                    break
                                end
                            end

                            if not isWarOngoingForFaction then
                                DrawMarker(1, blipCoords.x, blipCoords.y, blipCoords.z - 0.98, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.5, 1.5, 1.0, 0, 255, 0, 100, false, true, 2, false, nil, nil, false)
                                if distance < 2.0 then
                                    local requiredGrade = Config.gwfraks[playerJob.name]
                                    if requiredGrade and playerJob.grade >= requiredGrade then
                                        ESX.ShowHelpNotification("Drücke ~INPUT_CONTEXT~, um das Gangwar Menü zu öffnen.")
                                        if IsControlJustReleased(0, 38) then
                                            openNUI()
                                        end
                                    else
                                        ESX.ShowHelpNotification("Du hast nicht den nötigen Rang, um das Menü zu öffnen. Benötigt: Rang " .. (requiredGrade or 'N/A'))
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        Citizen.Wait(waitTime)
    end
end)

RegisterNetEvent('ali_gw:prepareForGw')
AddEventHandler('ali_gw:prepareForGw', function(zoneName)
    isWarJoinActive = true
    activeJoinZoneName = zoneName

    Citizen.CreateThread(function()
        Citizen.Wait(15000)
        if activeJoinZoneName == zoneName then 
            isWarJoinActive = false
            activeJoinZoneName = nil
        end
    end)
end)

RegisterNetEvent('ali_gw:startSpawnProtection')
AddEventHandler('ali_gw:startSpawnProtection', function(spawnCoords)

    TriggerEvent('IMPULSEV_hud-v2:notify', 'inform', 'Wartezone für 15 Sekunden aktiv!', 5000)
    

    protectionId = protectionId + 1
    local currentProtectionId = protectionId

    Citizen.CreateThread(function()

        local found, groundZ = GetGroundZFor_3dCoord(spawnCoords.x, spawnCoords.y, spawnCoords.z, false)
        local safeSpawnPoint
        if found then
            safeSpawnPoint = vector3(spawnCoords.x, spawnCoords.y, groundZ + 0.5)
        else

            safeSpawnPoint = vector3(spawnCoords.x, spawnCoords.y, spawnCoords.z)

        end

        local playerPed = PlayerPedId()
        SetEntityCoords(playerPed, safeSpawnPoint.x, safeSpawnPoint.y, safeSpawnPoint.z, false, false, false, true)
        SetEntityHeading(playerPed, spawnCoords.h or 0.0)

        local endTime = GetGameTimer() + 15000
        local protectionRadius = 10.0
        local bubbleColor = { r = 0, g = 255, b = 0, a = 100 } 

        SetPedCanSwitchWeapon(playerPed, false)

        while GetGameTimer() < endTime and protectionId == currentProtectionId do
            playerPed = PlayerPedId() 
            local currentCoords = GetEntityCoords(playerPed)

            local distance = #(vector2(currentCoords.x, currentCoords.y) - vector2(safeSpawnPoint.x, safeSpawnPoint.y))

            DrawMarker(
                28,
                safeSpawnPoint.x, safeSpawnPoint.y, safeSpawnPoint.z - 0.5, 
                0.0, 0.0, 0.0,
                0.0, 0.0, 0.0,
                protectionRadius * 2.0, protectionRadius * 2.0, protectionRadius * 2.0,
                bubbleColor.r, bubbleColor.g, bubbleColor.b, bubbleColor.a,
                false, false, 2, false, nil, nil, false
            )

            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)

            if distance > protectionRadius then

                SetEntityCoords(playerPed, safeSpawnPoint.x, safeSpawnPoint.y, safeSpawnPoint.z, false, false, false, true)
                SetEntityHeading(playerPed, spawnCoords.h or 0.0)
            end

            Citizen.Wait(0) 
        end
        if protectionId == currentProtectionId then
            SetPedCanSwitchWeapon(PlayerPedId(), true)
        end
    end)
end)

RegisterNetEvent('ali_gw:colorVehicle')
AddEventHandler('ali_gw:colorVehicle', function(netId, factionJob)
    local vehicle = NetToVeh(netId)
    
    local attempts = 0
    while not DoesEntityExist(vehicle) and attempts < 20 do
        Citizen.Wait(100)
        vehicle = NetToVeh(netId)
        attempts = attempts + 1
    end

    if DoesEntityExist(vehicle) then

        local color = Config.FactionColors[factionJob]
        if color then
            SetVehicleCustomPrimaryColour(vehicle, color.r, color.g, color.b)
            SetVehicleCustomSecondaryColour(vehicle, color.r, color.g, color.b)
        end


        if factionJob then
            SetVehicleNumberPlateText(vehicle, string.upper(factionJob))
        end


        SetVehicleModKit(vehicle, 0)
        for i = 0, 49 do
            local numMods = GetNumVehicleMods(vehicle, i)
            if numMods > 0 then
                SetVehicleMod(vehicle, i, GetNumVehicleMods(vehicle, i) - 1, false)
            end
        end
        ToggleVehicleMod(vehicle, 18, true)
        ToggleVehicleMod(vehicle, 22, true)
        SetVehicleWindowTint(vehicle, 1)
        SetVehicleTyresCanBurst(vehicle, false)

    else

    end
end)

local isJoinMarkerActive = false

RegisterNetEvent('ali_gw:showFactionJoinMarkers')
AddEventHandler('ali_gw:showFactionJoinMarkers', function(zoneName, markers)
    if isJoinMarkerActive then return end
    isJoinMarkerActive = true

    local playerJob = ESX.PlayerData.job.name
    local myMarker = nil

    if playerJob == markers.defender.faction then
        myMarker = markers.defender
    elseif playerJob == markers.attacker.faction then
        myMarker = markers.attacker
    end

    if not myMarker then
        isJoinMarkerActive = false
        return
    end

    local markerPos = vector3(myMarker.coords.x, myMarker.coords.y, myMarker.coords.z)
    local joinEndTime = GetGameTimer() + (Config.JoinTime * 1000)

    Citizen.CreateThread(function()
        while isJoinMarkerActive and GetGameTimer() < joinEndTime do
            local waitTime = 500
            local playerCoords = GetEntityCoords(PlayerPedId())
            local distance = #(markerPos - playerCoords)

            if distance < 50.0 then
                waitTime = 100
                if distance < 15.0 then
                    waitTime = 5
                    DrawMarker(1, markerPos.x, markerPos.y, markerPos.z - 0.98, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 6.0, 6.0, 1.0, 0, 255, 0, 100, false, true, 2, false, nil, nil, false)
                    if distance < 2.0 then
                        local timeLeft = math.max(0, math.floor((joinEndTime - GetGameTimer()) / 1000))
                        ESX.ShowHelpNotification("Drücke ~INPUT_CONTEXT~, um dem Kampf beizutreten. Verbleibende Zeit: " .. timeLeft .. "s")
                        if IsControlJustReleased(0, 38) then
                            TriggerServerEvent('ali_gw:playerWantsToJoinWar', zoneName)
                            isJoinMarkerActive = false
                        end
                    end
                end
            end
            Citizen.Wait(waitTime)
        end
        isJoinMarkerActive = false
    end)
end)




