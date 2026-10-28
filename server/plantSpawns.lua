-- Loads plant types from `kora_drugs` (rows where step = '<Type>:pick'),
-- publishes them to clients, and handles picking.

---@class PlantLocation
---@field coords vector3
---@field taken boolean

---@class PlantType
---@field data table
---@field locations PlantLocation[]

---@type table<string, PlantType>
local Plants = {}
local registered = {}
local published = {}

local function decodeLocations(raw)
    local list = {}
    for _, loc in ipairs(decodeJson(raw, {})) do
        local c = type(loc) == 'table' and loc.coords
        if type(c) == 'table' and tonumber(c.x) and tonumber(c.y) and tonumber(c.z) then
            list[#list + 1] = { coords = vec3(c.x, c.y, c.z), taken = false }
        end
    end
    return list
end

local function loadPlants()
    Plants = {}
    for _, row in ipairs(QB.sql.query('SELECT * FROM `qbdrugs`') or {}) do
        local plantType, kind = row.step:match('^(%w+):([%w_]+)$')
        local data = decodeJson(row.data, {})
        if kind == 'pick' and not data.disabled then
            Plants[plantType] = { data = data, locations = decodeLocations(row.locations) }
        end
    end
end

local function registerPick(plantType)
    RegisterNetEvent('qb_drugs:server:pick' .. plantType, function(id)
        local src = source
        if onCooldown(src, 'pick') then return end

        local plant = Plants[plantType]
        local spot = plant and type(id) == 'number' and plant.locations[id]
        if not spot or spot.taken then return end
        if not isNear(src, spot.coords, 3.0) then return end

        spot.taken = true
        GlobalState[plantType] = plant.locations
        TriggerClientEvent('qb_drugs:client:plantTaken' .. plantType, -1, id)

        CreateThread(function()
            Wait((plant.data.respawnTime or 1) * 1000)
            if Plants[plantType] ~= plant then return end
            spot.taken = false
            GlobalState[plantType] = plant.locations
            TriggerClientEvent('qb_drugs:client:plantRespawned' .. plantType, -1, id)
        end)

        exports.kora_inventory:addItem(src, plant.data.item, math.random(1, plant.data.maxGive or 1))
        startCooldown(src, 'pick', plant.data.pickingData and plant.data.pickingData.time or DefaultProgress.time)
    end)
end

local function refresh()
    loadPlants()

    for plantType in pairs(published) do
        if not Plants[plantType] then
            GlobalState[plantType] = nil
            GlobalState[plantType .. 'Data'] = nil
            published[plantType] = nil
            TriggerClientEvent('qb_drugs:client:plantsRemove', -1, plantType)
        end
    end

    local types = {}
    for plantType, plant in pairs(Plants) do
        GlobalState[plantType] = plant.locations
        GlobalState[plantType .. 'Data'] = plant.data
        published[plantType] = true
        types[#types + 1] = plantType
        if not registered[plantType] then
            registered[plantType] = true
            registerPick(plantType)
        end
    end
    GlobalState.drugPlantTypes = types
end

local function broadcastReload(plantType)
    local plant = Plants[plantType]
    if not plant then return end
    TriggerClientEvent('qb_drugs:client:plantsReload', -1, plantType, plant.data, plant.locations)
end

---@param plantType string?
function ReloadPlants(plantType)
    refresh()
    if plantType then
        broadcastReload(plantType)
        return
    end
    for name in pairs(Plants) do
        broadcastReload(name)
    end
end

exports('ReloadPlants', ReloadPlants)

refresh()