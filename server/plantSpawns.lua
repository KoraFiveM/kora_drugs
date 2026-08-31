local timed = {}
local function timeout(src, time)
    timed[src] = true
    CreateThread(function()
        Wait(time)
        timed[src] = nil
    end)
end

for plantType, data in pairs (Config) do
    if data.disabled then
        goto continue
    end
    GlobalState[plantType] = data.locations
    RegisterNetEvent('qb_drugs:server:pick'..plantType, function(id)
        local src = source
        if timed[src] then return end
        assert(Config[plantType] and Config[plantType].locations[id], "Invalid plant ID")
        local plant = Config[plantType].locations[id]
        if plant.taken then
            return
        end
        if not QB.distance.player(src, plant.coords, 3.0) then
            return
        end
        plant.taken = true
        GlobalState[plantType] = Config[plantType].locations
        TriggerClientEvent('qb_drugs:client:plantTaken'..plantType, -1, id)
        CreateThread(function()
            Wait(data.respawnTime * 1000)
            plant.taken = false
            GlobalState[plantType] = Config[plantType].locations
            TriggerClientEvent('qb_drugs:client:plantRespawned'..plantType, -1, id)
        end)
        exports['qb-inventory']:AddItem(src, data.item, math.random(1, (data.maxGive or 1)))
        timeout(src, data.respawnTime * 1000)
    end)
    ::continue::
end

