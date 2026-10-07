
local Busy = false
local Settings = {}   
local Spots = {}      
local Objects = {}    
local registered = {}

local function pickProgress(name)
    local pd = Settings[name] and Settings[name].pickingData or {}
    return {
        anim = pd.anim or DefaultProgress.anim,
        disable = pd.disable or DefaultProgress.disable,
        time = pd.time or DefaultProgress.time,
    }
end

local function pickDrugs(name, id)
    Busy = true
    local tbl = pickProgress(name)
    if QB.progressbar.start({
        label = (Settings[name] and Settings[name].progressLabel) or QB.lang(name .. '.pick.progress') or "Picking",
        duration = tbl.time,
        useWhileDead = false,
        canCancel = true,
        disable = tbl.disable,
        anim = tbl.anim
    }) then
        TriggerServerEvent('qb_drugs:server:pick' .. name, id)
    end
    Busy = false
end

local function spawnProp(name, id, spot)
    local settings = Settings[name]
    if not settings or not settings.model then return end
    local obj = QB.entities.create(settings.model, spot.coords, { freeze = true, invincible = true })
    exports.qbtarget:addEntity(obj, {
        {
            icon = settings.icon or QB.lang(name .. '.pick.icon') or 'coca-leaf',
            label = settings.targetLabel or QB.lang(name .. '.pick.target') or 'Pick Drugs',
            onSelect = function()
                pickDrugs(name, id)
            end,
            canInteract = function()
                return not Busy
            end
        }
    })
    Objects[name][id] = obj
end

local function clearType(name)
    for _, obj in pairs(Objects[name] or {}) do
        if DoesEntityExist(obj) then DeleteEntity(obj) end
    end
    Objects[name] = {}
end

local function buildType(name)
    clearType(name)
    for id, spot in pairs(Spots[name] or {}) do
        if not spot.taken then spawnProp(name, id, spot) end
    end
end

local function registerType(name)
    if registered[name] then return end
    registered[name] = true
    Objects[name] = Objects[name] or {}

    RegisterNetEvent('qb_drugs:client:plantRespawned' .. name, function(id)
        local spot = Spots[name] and Spots[name][id]
        if spot and not Objects[name][id] then
            spot.taken = false
            spawnProp(name, id, spot)
        end
    end)

    RegisterNetEvent('qb_drugs:client:plantTaken' .. name, function(id)
        local spot = Spots[name] and Spots[name][id]
        if spot then spot.taken = true end
        local obj = Objects[name][id]
        if obj and DoesEntityExist(obj) then DeleteEntity(obj) end
        Objects[name][id] = nil
    end)
end

local function initType(name)
    registerType(name)
    local settings = QB.state.awaitGlobal(name .. 'Data', 30000, 100)
    local spots = QB.state.awaitGlobal(name, 30000, 100)
    if not settings or not spots then
        print(('[qbdrugs] timed out waiting for GlobalState.%s'):format(name))
        return
    end
    Settings[name], Spots[name] = settings, spots
    buildType(name)
end

RegisterNetEvent('qb_drugs:client:plantsReload', function(name, settings, spots)
    registerType(name)
    Settings[name], Spots[name] = settings, spots
    buildType(name)
end)

RegisterNetEvent('qb_drugs:client:plantsRemove', function(name)
    clearType(name)
    Settings[name], Spots[name] = nil, nil
end)

CreateThread(function()
    local types = QB.state.awaitGlobal('drugPlantTypes', 30000, 100)
    if not types then
        print('[qbdrugs] timed out waiting for GlobalState.drugPlantTypes')
        return
    end
    for _, name in ipairs(types) do
        CreateThread(function() initType(name) end)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for name in pairs(Objects) do clearType(name) end
end)