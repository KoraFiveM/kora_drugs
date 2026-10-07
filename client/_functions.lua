local Busy = false

local function getItemLabel(item)
    local itemData = exports.qbcore:getShared('items', item)
    return itemData and itemData.label or item
end

function itemCheck(recipe)
    local missing = {}
    for _, v in pairs(recipe.give) do
        if not exports['qb-inventory']:HasItem(v.item, v.amount) then
            missing[#missing + 1] = {title = 'qb-drugs', message = 'You Need ' .. v.amount .. ' ' .. getItemLabel(v.item), type = 'error'}
        end
    end
    if #missing > 0 then
        for _, notify in pairs(missing) do
            QB.notify.send(notify)
        end
        return
    end
    return true
end


function returnBasicOption(step, event, key)
    return {
        {
            label = QB.lang(key .. '.target'),
            icon = QB.lang(key .. '.icon'),
            onSelect = function()
                    if Busy then return end
                    if not itemCheck(step.recipe) then return end
                    Busy = true
                    local progress = QB.progressbar.start({
                        label = QB.lang(key .. '.progress') or "Missing Text, IDK What youre doing",
                        duration = step.progress and step.progress.time or DefaultProgress.time,
                        disable = step.progress and step.progress.disable or DefaultProgress.disable,
                        anim = step.progress and step.progress.anim or DefaultProgress.anim
                    })
                    if progress then
                        TriggerServerEvent(event)
                    end
                    Busy = false
            end,
            canInteract = function()
                return not Busy
            end
        }
    }
end
function basicTarget(coords, rotation, step, event, key)
   return exports.qbtarget:addBoxZone({
        coords = coords,
        size = vector3(2,2,2),
        rotation = rotation,
        options = returnBasicOption(step, event, key)
    })
end

-- Drugs[Type][step] = { data = {...}, locations = {...} }, e.g. Drugs.Cocaine.lab.
-- Filled once from GlobalState.Drugs. After that the server sends only the entry that
-- changed, so a lab save never touches plants (or any other step).
--
-- OnDrugs('Cocaine', 'lab', function(entry) ... end) runs once the data is in and again
-- only when THAT entry changes, so a file rebuilds just its own zones.
Drugs = {}

local drugsLoaded = false
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
    if drugsLoaded and drugsListeners[drug .. ':' .. step] then notifyDrugs(drug .. ':' .. step) end
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
end)

function inGang(gang)
    if not gang then return true end
    local player = exports.qbcore:getPlayerData()
    return player and player.gang and player.gang.name == gang or false
end

function progressTrigger(recipe, data, event, index)
    if Busy then return end
    if not itemCheck(recipe) then return end
    Busy = true
    local progress = QB.progressbar.start({
        label = data.progress.label,
        duration =  data.progress.time or DefaultProgress.time,
        disable =  data.progress.disable or DefaultProgress.disable,
        anim =  data.anim or DefaultProgress.anim
    })
    if progress then
        TriggerServerEvent(event, index)
    end
    Busy = false
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

function LabTeleport(name, locale)
    local zones = {}

    local function clear()
        for _, id in ipairs(zones) do
            pcall(function() exports.qbtarget:removeZone(id) end)
        end
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