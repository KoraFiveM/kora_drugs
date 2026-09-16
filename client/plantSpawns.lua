
local Busy = false
local function pickDrugs(name, loc)
    Busy = true
    if QB.progressbar.start({
        label = Config[name].pickingData.progressLabel or "Picking",
        duration = Config[name].pickingData.progressTime or 5000,
        useWhileDead = false,
        canCancel = true,
        disable = Config[name].pickingData.progressDisable or {move = true, combat = true, car = true},
        anim = Config[name].pickingData.progressAnim or {dict = 'mp_arresting', clip = 'a_uncuff', flags = 17}
    }) then
        TriggerServerEvent('qb_drugs:server:pick'..name, loc)
    end
    Busy = false
end

local function spawnProps(name, model, coords, id)
    local obj = QB.entities.create(model, coords, { freeze = true, invincible = true})
    exports.qbtarget:addEntity(obj, {
        {
            icon = Config[name].pickingData.targetIcon or 'cocaine',
            label = Config[name].pickingData.targetLabel or 'Pick Drugs',
            onSelect = function()
                pickDrugs(name, id)
            end,
            canInteract = function()
                return not Busy
            end
        }
    })
    Config[name].plantTbl[id] = obj
end

for k, v in pairs (Config) do
    if v.disabled then
        goto skip
    end
    RegisterNetEvent('qb_drugs:client:plantRespawned'..k, function(loc)
        local plant = GlobalState[k][loc]
        if not v.plantTbl[loc] then
            spawnProps(k, v.model, plant.coords, loc)
        end
    end)

    RegisterNetEvent('qb_drugs:client:plantTaken'..k, function(loc)
        DeleteEntity(v.plantTbl[loc])
        v.plantTbl[loc] = nil
    end)

    RegisterNetEvent('qb_drugs:client:plantInit'..k, function()
        if not v.plantTbl then v.plantTbl = {} end
        local plants = QB.state.awaitGlobal(k, 30000, 100)
        if not plants then
            print(('[qbdrugs] timed out waiting for GlobalState.%s'):format(k))
            return
        end
        for key, value in pairs (plants) do
            if not value.taken then
               spawnProps(k, v.model, value.coords, key)
            end
        end
    end)
    TriggerEvent('qb_drugs:client:plantInit'..k)
    ::skip::
end
