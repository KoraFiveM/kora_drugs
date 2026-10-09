if qbdrugsFunctionsLoaded then return end
qbdrugsFunctionsLoaded = true

local Busy = false

-- Notifies for every item the recipe asks for that the player does not have. True when they have all of them.
function itemCheck(recipe)
    local hasAll = true
    for _, v in pairs(recipe.give) do
        if not exports['qb-inventory']:HasItem(v.item, v.amount) then
            hasAll = false
            local itemData = exports.qbcore:getShared('items', v.item)
            QB.notify.send({ title = 'qb-drugs', message = 'You Need ' .. v.amount .. ' ' .. (itemData and itemData.label or v.item), type = 'error' })
        end
    end
    return hasAll
end

Drugs = {}

local drugsLoaded = false
local watchCustom -- set below: builds the targets of events made on the creator's Custom drugs page
local drugsListeners = {} -- 'Cocaine:lab' -> { fn, ... }

local function notifyDrugs(key)
    local drug, step = key:match('^(%w+):([%w_]+)$')
    local entry = Drugs[drug] and Drugs[drug][step]
    for _, listener in ipairs(drugsListeners[key]) do listener(entry) end
end

function OnDrugs(drug, step, listener)
    local key = drug .. ':' .. step
    drugsListeners[key] = drugsListeners[key] or {}
    table.insert(drugsListeners[key], listener)
    if drugsLoaded then listener(Drugs[drug] and Drugs[drug][step]) end
end

RegisterNetEvent('qbdrugs:client:drugsReload', function(drug, step, entry)
    Drugs[drug] = Drugs[drug] or {}
    Drugs[drug][step] = entry
    if not drugsLoaded then return end
    local key = drug .. ':' .. step
    if drugsListeners[key] then notifyDrugs(key) elseif watchCustom then watchCustom(drug, step) end
end)

CreateThread(function()
    local all = QB.state.awaitGlobal('Drugs', 30000, 100)
    if not all then
        print('[qbdrugs] timed out waiting for GlobalState.Drugs')
        return
    end
    Drugs = all
    drugsLoaded = true
    for key in pairs(drugsListeners) do notifyDrugs(key) end
    if watchCustom then
        for drug, steps in pairs(Drugs) do
            for step in pairs(steps) do watchCustom(drug, step) end
        end
    end
end)

function inGang(gang)
    if not gang then return true end
    local player = exports.qbcore:getPlayerData()
    return player and player.gang and player.gang.name == gang or false
end

function craftTrigger(drug, step, data, location, key)
    local name = drug .. ':' .. step
    local info = craftSteps[name] or {} -- a custom event has no entry
    local hook = stepHooks[name] or {}
    local recipe = stepRecipe(name, data)

    if Busy then return end
    if recipe and not itemCheck(recipe) then return end
    if hook.check and not hook.check() then return end

    Busy = true
    local done
    if hook.run then
        done = hook.run(data, location)
    else
        local progress = data.progress or {}
        done = QB.progressbar.start({
            label = progress.label or (info.locale and QB.lang(info.locale .. '.progress')) or '',
            duration = progress.time or DefaultProgress.time,
            disable = progress.disable or DefaultProgress.disable,
            anim = data.anim or DefaultProgress.anim,
        })
    end
    Busy = false

    if done then TriggerServerEvent('qbdrugs:server:craft', drug, step, key) end
end

function createBox(coords, rotation, options)
    return exports.qbtarget:addBoxZone({
        coords = coords,
        size = vector3(2,2,2),
        rotation = rotation,
        options = options,
    })
end

function createObject(object, coords, rotation, options)
    local ped = QB.entities.create(object, coords, {freeze = true, invincible = true})
    SetEntityHeading(ped, coords.w)
    exports.qbtarget:addEntity(ped, options)
    return ped
end

local function removeZones(ids)
    for _, id in ipairs(ids) do
        pcall(function() exports.qbtarget:removeZone(id) end)
    end
end

function LabTeleport(name, locale)
    local zones = {}

    local function clear()
        removeZones(zones)
        zones = {}
    end

    local function zone(coords, label, icon, onSelect, canInteract)
        zones[#zones + 1] = exports.qbtarget:addBoxZone({
            coords = vector3(coords.x, coords.y, coords.z),
            size = vector3(1.5, 1.5, 1.5),
            options = { { label = label, icon = icon, onSelect = onSelect, canInteract = canInteract } },
        })
    end

    AddEventHandler('onResourceStop', function(res)
        if res == GetCurrentResourceName() then clear() end
    end)

    return function(lab)
        clear()
        if not lab or not lab.locations or #lab.locations == 0 then return end
        local data = lab.data or {}

        for key, location in ipairs(lab.locations) do
            if location.enter and location.exit then
                zone(location.enter,
                    data.enterTarget or QB.lang(locale .. '.enter.target'),
                    QB.lang(locale .. '.enter.icon'),
                    function()
                        if not QB.callback.trigger(('qbdrugs:%s:Tele'):format(name), key) then return end
                        QB.visuals.fade(vector3(location.exit.x, location.exit.y, location.exit.z), 500)
                    end,
                    function() return inGang(location.gang) end)
            end
        end

        zone(lab.locations[1].exit,
            data.exitTarget or QB.lang(locale .. '.exit.target'),
            QB.lang(locale .. '.exit.icon'),
            function()
                local back = QB.callback.trigger(('qbdrugs:%s:TeleOut'):format(name))
                if not back then return end
                QB.visuals.fade(back, 500)
            end)
    end
end

local craftZones = {}

local function clearCraft(name)
    local zones = craftZones[name]
    if zones then
        removeZones(zones.boxes)
        for _, object in ipairs(zones.objects) do
            pcall(function() QB.entities.remove(object) end)
        end
    end
    craftZones[name] = { boxes = {}, objects = {} }
end

local function buildCraft(drug, step)
    local name = drug .. ':' .. step
    local locale = (craftSteps[name] or {}).locale

    return function(entry)
        clearCraft(name)
        if not entry or type(entry.locations) ~= 'table' then return end

        local data = entry.data or {}
        local zones = craftZones[name]
        local list = entry.locations.coords and { entry.locations } or entry.locations

        for key, location in ipairs(list) do
            local c = location.coords
            if c then
                local options = {
                    {
                        label = data.targetLabel or (locale and QB.lang(locale .. '.target')),
                        icon = data.targetIcon or (locale and QB.lang(locale .. '.icon')),
                        onSelect = function()
                            craftTrigger(drug, step, data, location, key)
                        end,
                        canInteract = function()
                            return not Busy and inGang(location.gang)
                        end,
                    },
                }
                if location.object then
                    zones.objects[#zones.objects + 1] = createObject(location.object, vector4(c.x, c.y, c.z, c.w or 0.0), 0, options)
                else
                    zones.boxes[#zones.boxes + 1] = createBox(vector3(c.x, c.y, c.z), 0, options)
                end
            end
        end
    end
end

for name in pairs(craftSteps) do
    local drug, step = name:match('^(%w+):([%w_]+)$')
    if not (Config[drug] and Config[drug].disabled) then
        OnDrugs(drug, step, buildCraft(drug, step))
    end
end

watchCustom = function(drug, step)
    local name = drug .. ':' .. step
    if craftSteps[name] or drugsListeners[name] then return end

    local entry = Drugs[drug] and Drugs[drug][step]
    if not (entry and type(entry.data) == 'table' and entry.data.custom == true) then return end
    OnDrugs(drug, step, buildCraft(drug, step))
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for name in pairs(craftZones) do clearCraft(name) end
end)