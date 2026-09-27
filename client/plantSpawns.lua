
local Busy = false

local function returnDisableAnim(name)
    local tbl = {
        anim = Config[name] and Config[name].pickingData and Config[name].pickingData.anim or DefaultProgress.anim,
        disable = Config[name] and Config[name].pickingData and Config[name].pickingData.disable or DefaultProgress.disable,
        time = Config[name] and Config[name].pickingData and Config[name].pickingData.time or DefaultProgress.time
    }
    return tbl
end

local function pickDrugs(name, loc)
    Busy = true
    local tbl = returnDisableAnim(name)
    if QB.progressbar.start({
        label = QB.lang(name..'.pick.progress') or "Picking",
        duration = tbl.time,
        useWhileDead = false,
        canCancel = true,
        disable = tbl.disable,
        anim = tbl.anim
    }) then
        TriggerServerEvent('qb_drugs:server:pick'..name, loc)
    end
    Busy = false
end

local function spawnProps(name, model, coords, id)
    local obj = QB.entities.create(model, coords, { freeze = true, invincible = true})
    exports.qbtarget:addEntity(obj, {
        {
            icon = QB.lang(name..'.pick.icon') or 'coca-leaf',
            label = QB.lang(name..'.pick.target') or 'Pick Drugs',
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
    if v.disabled or k == 'DrugConfig' or k == 'DefaultProgress' then
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
