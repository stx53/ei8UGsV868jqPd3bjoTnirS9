ESX = exports["es_extended"]:getSharedObject()

local setRange = 0

RegisterNetEvent("killfeed:setRange", function(range)
  setRange = range
end)

RegisterNetEvent("killfeed:show", function(coords, killer, victim, killDistance)
  local ped       = PlayerPedId()
  local pedCoords = GetEntityCoords(ped)
  local distance  = #(coords - pedCoords)

  if distance > setRange then
    print("out of range", "distance", distance, "setRange", setRange)
    return
  end

  print(killer, "killed", victim)
  SendNUIMessage({
    action = "showKillfeed",
    killer = killer,
    victim = victim .. " (" .. killDistance .. "m)"
  })
end)
