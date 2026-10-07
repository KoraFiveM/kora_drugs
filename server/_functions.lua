function hasItems(src, itemList)
    local missing = {}
    for _, item in pairs(itemList) do
        if not exports['qb-inventory']:HasItem(src, item.item, item.amount) then
            missing[#missing + 1] = {title = 'qb-drugs', message = QB.lang('Functions.no_items', item.amount, item.item), type = 'error'}
        end
    end
    if #missing > 0 then
        for _, notify in pairs(missing) do
            QB.notify.send(src, notify)
        end
        return false
    end
    return true
end

function craft(src, recipe, meta)
    if not hasItems(src, recipe.give) then return end
    for _, item in pairs(recipe.give) do
        if not item.keep then
            if not exports['qb-inventory']:RemoveItem(src, item.item, item.amount) then
                return
            end
        end
    end
    if not recipe.receive or not recipe.receive.item then
        return true
    end
    return exports['qb-inventory']:AddItem(src, recipe.receive.item, recipe.receive.amount, nil, meta)
end

local timeouts = {}
function timeout(src, duration)
    if timeouts[src] then
        return
    end
    timeouts[src] = true
    SetTimeout(duration, function()
        timeouts[src] = nil
    end)
end

function runEvent(src, step, meta, event)
    if timeouts[src] then
        QB.print.warn(QB.lang('Functions.timeout', src, event or 'unknown'))
        return
    end
    timeout(src, 5000)
    if not craft(src, step.recipe, meta) then return end
    return true
end

function RegisterLabTeleport(name, drug, step)
    local buckets = {}

    local function lab()
        return Drugs[drug] and Drugs[drug][step]
    end

    QB.callback.register(('qbdrugs:%s:Tele'):format(name), function(source, key)
        local location = lab() and type(key) == 'number' and lab().locations[key]
        if not location then return false end
        if not QB.distance.player(source, vec3(location.enter.x, location.enter.y, location.enter.z), 5.0) then
            return false
        end

        local old = buckets[source] and buckets[source].old or GetPlayerRoutingBucket(source)
        buckets[source] = {
            index = key,
            old = old,
            new = old + key,
            enter = location.enter,
            exit = location.exit,
        }
        SetPlayerRoutingBucket(source, buckets[source].new)
        return true
    end)

    QB.callback.register(('qbdrugs:%s:TeleOut'):format(name), function(source)
        local first = lab() and lab().locations[1]
        if not buckets[source] then return first and first.enter or false end
        assert(QB.distance.player(source, vec3(buckets[source].exit.x, buckets[source].exit.y, buckets[source].exit.z), 5.0), "Player is not near the exit")

        SetPlayerRoutingBucket(source, buckets[source].old or 0)
        local enter = buckets[source].enter or (first and first.enter)
        buckets[source] = nil
        return enter
    end)

    AddEventHandler('playerDropped', function()
        buckets[source] = nil
    end)
end