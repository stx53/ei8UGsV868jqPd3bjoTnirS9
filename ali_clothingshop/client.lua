ESX = exports['es_extended']:getSharedObject()

CreateThread(function()
    for _, store in ipairs(Config.SC) do
        
        local blip = AddBlipForCoord(store.coords.x, store.coords.y, store.coords.z)
        
        SetBlipSprite(blip, store.sprite or Config.Blip.sprite)
        SetBlipDisplay(blip, Config.Blip.display)
        SetBlipScale(blip, store.scale or Config.Blip.scale)
        SetBlipColour(blip, store.color or Config.Blip.color)
        SetBlipAsShortRange(blip, Config.Blip.shortRange)
        
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(store.text or Config.Blip.text)
        EndTextCommandSetBlipName(blip)
        
        store.markerId = #Config.SC + _
    end
    
    local currentStore = nil
    
    while true do
        local sleep = 1000
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local foundStore = false
        
        for _, store in ipairs(Config.SC) do
            local distance = #(playerCoords - store.coords)
            
            if distance < 2.0 then  
                sleep = 0
                foundStore = true
                
                
                if currentStore ~= store then
                    currentStore = store
                    
                    
                    DrawMarker(
                        1, 
                        store.coords.x, store.coords.y, store.coords.z - 1.0,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        4.0, 4.0, 1.0,
                        255, 255, 255, 30,
                        false, true, 2, false, nil, nil, false
                    )
                    
                    
                    TriggerEvent('IMPULSEV_hud-v2:helpNotify', "E", "Drücke, um den Kleidungsladen zu öffnen")
                end
                
                
                if IsControlJustReleased(0, 38) then 
                    showClothingMainMenu()
                    break
                end
                
                break 
            end
        end
        
        
        if not foundStore and currentStore ~= nil then
            currentStore = nil
            TriggerEvent('IMPULSEV_hud-v2:helpNotify', "", "")
        end
        
        Wait(sleep)
    end
end)

local isMenuOpen = false
local originalSkin = {}
local cam = nil
local isRotating = false
local currentCameraIndex = 1
local cameraViews = {
    { name = "front", offset = { x = 0.0, y = 2.0, z = 0.65 }, pointAt = { x = 0.0, y = 0.0, z = 0.0 } },
    { name = "back", offset = { x = 0.0, y = -2.0, z = 0.65 }, pointAt = { x = 0.0, y = 0.0, z = 0.0 } },
    { name = "head", offset = { x = 0.0, y = 0.8, z = 0.6 }, pointAt = { x = 0.0, y = 0.0, z = 0.6 } },
    { name = "feet", offset = { x = 0.0, y = 1.0, z = -0.7 }, pointAt = { x = 0.0, y = 0.0, z = -0.8 } },
}


function getPlayerSkin()
    local playerPed = PlayerPedId()
    local skin = {}
    for category, data in pairs(Config.CC) do
        if not string.find(category, 'FARBE') then
            local componentId, isProp = data[1], data[2]
            if isProp then
                
                local propIndex = GetPedPropIndex(playerPed, componentId)
                if propIndex == -1 then
                   
                    skin[category] = { drawable = -1, texture = 0 }
                else
                    skin[category] = { 
                        drawable = propIndex, 
                        texture = GetPedPropTextureIndex(playerPed, componentId) 
                    }
                end
            else
                skin[category] = { 
                    drawable = GetPedDrawableVariation(playerPed, componentId), 
                    texture = GetPedTextureVariation(playerPed, componentId) 
                }
            end
        end
    end
    return skin
end


function setPlayerSkin(skin)
    local playerPed = PlayerPedId()
    for category, data in pairs(skin) do
        local componentId, isProp = Config.CC[category][1], Config.CC[category][2]
        if isProp then
            
            if componentId == 0 and data.drawable == -1 then
                ClearPedProp(playerPed, componentId)
            else
                SetPedPropIndex(playerPed, componentId, data.drawable, data.texture, true)
            end
        else
            SetPedComponentVariation(playerPed, componentId, data.drawable, data.texture, 2)
        end
    end
end


function updateCameraView()
    if not cam then return end
    local playerPed = PlayerPedId()
    local view = cameraViews[currentCameraIndex]
    local camCoords = GetOffsetFromEntityInWorldCoords(playerPed, view.offset.x, view.offset.y, view.offset.z)
    SetCamCoord(cam, camCoords.x, camCoords.y, camCoords.z)
    PointCamAtEntity(cam, playerPed, view.pointAt.x, view.pointAt.y, view.pointAt.z, true)
end


function startCamera()
    local playerPed = PlayerPedId()
    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    currentCameraIndex = 1 
    updateCameraView() 
    RenderScriptCams(true, false, 0, true, true)
end


function stopCamera()
    if cam then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(cam, false)
        cam = nil
    end
end


function openMenu()
    if isMenuOpen then return end
    isMenuOpen = true
    originalSkin = getPlayerSkin()

    FreezeEntityPosition(PlayerPedId(), true)
    startCamera()

    local maxValues = {}
    local playerPed = PlayerPedId()
    
    
    for category, _ in pairs(Config.CC) do
        maxValues[category] = 0
    end
    
    
    for category, data in pairs(Config.CC) do
        local componentId, isProp = data[1], data[2]
        local maxVal = 0
        
        if string.find(category, 'FARBE') then
            local drawableCategory = string.gsub(category, ' FARBE', '')
            if originalSkin[drawableCategory] and originalSkin[drawableCategory].drawable ~= nil then
                local drawableId = originalSkin[drawableCategory].drawable
                if isProp then
                    maxVal = GetNumberOfPedPropTextureVariations(playerPed, componentId, drawableId) or 0
                else
                    maxVal = GetNumberOfPedTextureVariations(playerPed, componentId, drawableId) or 0
                end
            end
        else
            if isProp then
                maxVal = GetNumberOfPedPropDrawableVariations(playerPed, componentId) or 0
            else
                maxVal = GetNumberOfPedDrawableVariations(playerPed, componentId) or 0
            end
        end
        
        
        if category == 'KOPFBEDECKUNG' then
            maxValues[category] = math.max(-1, (maxVal > 0 and (maxVal - 1) or -1))
        else
            
            maxValues[category] = math.max(0, (maxVal > 0 and (maxVal - 1) or 0))
        end
    end
    
    
    SendNUIMessage({ 
        action = 'show', 
        maxValues = maxValues, 
        currentSkin = originalSkin, 
        pricePerItem = Config.Price 
    })
end


function closeMenu(revertSkin)
    isMenuOpen = false
    SetNuiFocus(false, false)
    FreezeEntityPosition(PlayerPedId(), false)
    stopCamera()
    SendNUIMessage({ action = 'hide' })
    if revertSkin then
        setPlayerSkin(originalSkin)
    end
end


local function isPlayerInClothingStore()
    local playerCoords = GetEntityCoords(PlayerPedId())
    for _, store in ipairs(Config.SC) do
        if #(playerCoords - store.coords) < 2.0 then
            return true
        end
    end
    return false
end


function showSavedOutfits()
    ESX.TriggerServerCallback('ali_clothing:getOutfits', function(outfits)
        local elements = {}
        
        if #outfits == 0 then
            table.insert(elements, {label = 'Keine Outfits gefunden', value = 'no_outfits'})
        else
            for _, outfit in ipairs(outfits) do
                table.insert(elements, {
                    label = outfit.name,
                    value = outfit.name,
                    outfit = outfit.outfit
                })
            end
        end
        
        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'outfit_list', {
            title    = 'Meine Outfits',
            align    = 'top-left',
            elements = elements
        }, function(data, menu)
            if data.current.value ~= 'no_outfits' then
                
                local outfitName = data.current.value
                local outfitLabel = data.current.label
                local outfitData = data.current.outfit
                
                local elements = {
                    {label = 'Anziehen', value = 'wear', icon = 'tshirt'},
                    {label = 'Umbenennen', value = 'rename', icon = 'pen'},
                    {label = 'Löschen', value = 'delete', icon = 'trash'}
                }
                
                ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'outfit_options', {
                    title = 'Outfit: ' .. outfitLabel,
                    align = 'top-left',
                    elements = elements
                }, function(data2, menu2)
                    if data2.current.value == 'wear' then
                        wearOutfit(outfitData, outfitLabel)
                        menu2.close()
                        menu.close()
                    elseif data2.current.value == 'rename' then
                        ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'rename_outfit', {
                            title = 'Neuer Name für ' .. outfitLabel
                        }, function(data3, menu3)
                            local newName = tostring(data3.value)
                            if newName == nil or newName == '' then
                                TriggerEvent('IMPULSEV_hud-v2:notify', 'error', 'Ungültiger Name', 3000)
                                return
                            end
                            
                            
                            ESX.TriggerServerCallback('ali_clothing:renameOutfit', function(success)
                                if success then
                                    TriggerEvent('IMPULSEV_hud-v2:notify', 'success', 'Outfit umbenannt zu: ' .. newName, 3000)
                                    menu3.close()
                                    menu2.close()
                                    menu.close()
                                    showSavedOutfits() 
                                else
                                    TriggerEvent('IMPULSEV_hud-v2:notify', 'error', 'Fehler beim Umbenennen des Outfits', 3000)
                                end
                            end, outfitName, newName)
                            
                        end, function(data3, menu3)
                            menu3.close()
                        end)
                    elseif data2.current.value == 'delete' then
                       
                        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'delete_confirm', {
                            title = 'Outfit löschen?',
                            align = 'top-left',
                            elements = {
                                {label = 'Abbrechen', value = 'no'},
                                {label = 'Ja, löschen', value = 'yes'}
                            }
                        }, function(data3, menu3)
                            if data3.current.value == 'yes' then
                                
                                TriggerServerEvent('ali_clothing:deleteOutfit', outfitName)
                                TriggerEvent('IMPULSEV_hud-v2:notify', 'success', 'Outfit gelöscht: ' .. outfitLabel, 3000)
                                menu3.close()
                                menu2.close()
                                menu.close()
                                showSavedOutfits() 
                            else
                                menu3.close()
                            end
                        end, function(data3, menu3)
                            menu3.close()
                        end)
                    end
                end, function(data2, menu2)
                    menu2.close()
                end)
            end
        end, function(data, menu)
            menu.close()
            showClothingMainMenu()
        end)
    end)
end


function wearOutfit(outfit, label)
    if type(outfit) ~= 'table' then
        return
    end
    
    
    local componentMap = {
        ['T-SHIRT'] = 'tshirt_1',
        ['T-SHIRT FARBE'] = 'tshirt_2',
        ['OBERKÖRPER'] = 'torso_1',
        ['OBERKÖRPER FARBE'] = 'torso_2',
        ['HOSEN'] = 'pants_1',
        ['HOSEN FARBE'] = 'pants_2',
        ['SCHUHE'] = 'shoes_1',
        ['SCHUHE FARBE'] = 'shoes_2',
        ['WESTE'] = 'bproof_1',
        ['WESTE FARBE'] = 'bproof_2',
        ['KETTE'] = 'chain_1',
        ['KETTE FARBE'] = 'chain_2',
        ['MASKE'] = 'mask_1',
        ['MASKE FARBE'] = 'mask_2',
        ['KOPFBEDECKUNG'] = 'helmet_1',
        ['KOPFBEDECKUNG FARBE'] = 'helmet_2',
        ['BRILLE'] = 'glasses_1',
        ['BRILLE FARBE'] = 'glasses_2',
        ['ARMBÄNDER'] = 'bracelets_1',
        ['ARMBÄNDER FARBE'] = 'bracelets_2',
        ['TASCHE'] = 'bags_1',
        ['TASCHE FARBE'] = 'bags_2',
        ['ARME'] = 'arms',
        ['ARME FARBE'] = 'arms_2',
        ['AUFKLEBER'] = 'decals_1',
        ['AUFKLEBER FARBE'] = 'decals_2'
    }
    
    
    local componentsApplied = false
    for category, data in pairs(outfit) do
        local skinchangerComponent = componentMap[category]
        if skinchangerComponent then
            TriggerEvent('skinchanger:change', skinchangerComponent, data.drawable)
            
            if skinchangerComponent:match('_1$') then
                local textureComponent = skinchangerComponent:gsub('_1$', '_2')
                if componentMap[category .. ' FARBE'] then
                    TriggerEvent('skinchanger:change', textureComponent, data.texture or 0)
                end
            end
            
            componentsApplied = true
        end
    end
    
    if componentsApplied then
        TriggerEvent('skinchanger:getSkin', function(updatedSkin)
            TriggerServerEvent('esx_skin:save', updatedSkin)
            TriggerEvent('IMPULSEV_hud-v2:notify', 'success', 'Outfit ' .. (label or '') .. ' angezogen', 3000)
        end)
    else
        TriggerEvent('IMPULSEV_hud-v2:notify', 'error', 'Fehler: Keine gültigen Kleidungskomponenten gefunden', 3000)
    end
end

function showClothingMainMenu()
    ESX.UI.Menu.CloseAll()
    
    local elements = {
        {label = 'Kleidung wechseln', value = 'change_clothes'},
        {label = 'Outfits verwalten', value = 'manage_outfits'}
    }
    
    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'clothing_main_menu', {
        title    = 'Kleidungsladen',
        align    = 'top-left',
        elements = elements
    }, function(data, menu)
        if data.current.value == 'change_clothes' then
            menu.close()
            openMenu()
        elseif data.current.value == 'manage_outfits' then
            menu.close()
            showSavedOutfits()
        end
    end, function(data, menu)
        menu.close()
    end)
end

CreateThread(function()
    while true do
        local wait = 1000
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local inStore = false
        
        for _, store in ipairs(Config.SC) do
            local distance = #(playerCoords - store.coords)
            if distance < 2.0 then
                inStore = true
                wait = 0
                
                ESX.ShowHelpNotification('Drücke ~INPUT_CONTEXT~ um den Kleidungsladen zu öffnen')
                
                if IsControlJustReleased(0, 38) then 
                    if not ESX.UI.Menu.IsOpen('default', GetCurrentResourceName(), 'clothing_main_menu') then
                        showClothingMainMenu()
                    end
                end
                
                break
            end
        end
        
        if not inStore and ESX.UI.Menu.IsOpen('default', GetCurrentResourceName(), 'clothing_main_menu') then
            ESX.UI.Menu.CloseAll()
        end
        
        Wait(wait)
    end
end)


RegisterNUICallback('close', function(data, cb)
    closeMenu(true) 
    cb('ok')
end)

RegisterNUICallback('updateClothing', function(data, cb)
    local category, value, playerPed = data.category, tonumber(data.value), PlayerPedId()
    if Config.CC[category] then
        local componentId, isProp = Config.CC[category][1], Config.CC[category][2]
        if string.find(category, 'FARBE') then
            if isProp then
                SetPedPropIndex(playerPed, componentId, GetPedPropIndex(playerPed, componentId), value, true)
            else
                SetPedComponentVariation(playerPed, componentId, GetPedDrawableVariation(playerPed, componentId), value, 2)
            end
        else
            if isProp then
                
                if componentId == 0 and value == -1 then  
                    ClearPedProp(playerPed, componentId)
                else
                    SetPedPropIndex(playerPed, componentId, value, 0, true)
                end
            else
                SetPedComponentVariation(playerPed, componentId, value, 0, 2)
            end
            
            
            if value >= 0 then
                local textureCategoryName = category .. ' FARBE'
                if Config.CC[textureCategoryName] then
                    local newMaxTexture = (isProp and GetNumberOfPedPropTextureVariations(playerPed, componentId, value) or GetNumberOfPedTextureVariations(playerPed, componentId, value)) - 1
                    SendNUIMessage({ action = 'updateMaxValues', maxValues = { [textureCategoryName] = newMaxTexture } })
                end
            end
        end
    end
    cb('ok')
end)

RegisterNUICallback('purchase', function(data, cb)
    TriggerServerEvent('ali_clothing:purchaseOutfit', data.changedOutfit, data.method)
    cb('ok')
end)

RegisterNUICallback('toggleCamera', function(data, cb)
    currentCameraIndex = (currentCameraIndex % #cameraViews) + 1
    updateCameraView()
    cb('ok')
end)

RegisterNUICallback('rotateCharacter', function(data, cb)
    local playerPed = PlayerPedId()
    if data.movementX then
        local currentHeading = GetEntityHeading(playerPed)
        local newHeading = currentHeading - (data.movementX * 2.0)
        SetEntityHeading(playerPed, newHeading)
    end
    cb('ok')
end)

RegisterNUICallback('setRotationStatus', function(data, cb)
    isRotating = data.status
    SendNUIMessage({ action = 'setCursor', visible = not isRotating })
    cb('ok')
end)



local purchaseProcessed = false

if not purchaseSuccessHandlerRegistered then
    RegisterNetEvent('ali_clothing:purchaseSuccess')
    AddEventHandler('ali_clothing:purchaseSuccess', function()
            
        if purchaseProcessed then return end
        purchaseProcessed = true
        
        closeMenu(false)
        
        
        local menuId = 'clothing_save_menu_' .. GetGameTimer()
        
        ESX.UI.Menu.CloseAll() 
        
        ESX.UI.Menu.Open('default', GetCurrentResourceName(), menuId, {
            title    = 'Outfit speichern?',
            align    = 'top-left',
            elements = {
                {label = 'Ja', value = 'yes'},
                {label = 'Nein', value = 'no'}
            }
        }, function(data, menu)
            if data.current.value == 'yes' then
                menu.close()
                ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'clothing_save_input_' .. GetGameTimer(), {
                    title = 'Outfit Name'
                }, function(data2, menu2)
                    local outfitName = data2.value
                    menu2.close()

                    if outfitName and outfitName ~= '' then
                        TriggerServerEvent('ali_clothing:saveOutfit', outfitName, getPlayerSkin())
                        purchaseProcessed = false 
                    else
                        TriggerEvent('IMPULSEV_hud-v2:notify', 'error', 'Ungültiger Name!', 5000)
                        purchaseProcessed = false 
                    end
                end, function(data2, menu2)
                    menu2.close()
                    purchaseProcessed = false 
                end)
            else
                menu.close()
                purchaseProcessed = false 
            end
        end, function(data, menu)
            menu.close()
            purchaseProcessed = false 
        end)
    end)
    
    purchaseSuccessHandlerRegistered = true 
end


CreateThread(function()
    while true do
        local wait = 500
        if isMenuOpen then
            wait = 0
            SetNuiFocus(true, true)

            if isRotating then
                DisableControlAction(0, 1, true) 
                DisableControlAction(0, 2, true) 
            end

            
            DisableControlAction(0, 24, true)    
            DisableControlAction(0, 25, true)   
            DisableControlAction(0, 142, true)   

            
            DisableControlAction(0, 19, true)    
            DisableControlAction(0, 157, true)   
            DisableControlAction(0, 158, true)  
            DisableControlAction(0, 162, true)   
            DisableControlAction(0, 163, true)  

           
            DisableControlAction(0, 51, true)    
            DisableControlAction(0, 73, true)    
            DisableControlAction(0, 200, true)   
            DisableControlAction(0, 202, true)   
            DisableControlAction(2, 202, true)   
        end
        Wait(wait)
    end
end)
