
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
    if not QB.distance.player(src, step.coords, 3) then
        QB.print.warn(QB.lang('Functions.distance', src, event or 'unknown'))
        return
    end
    timeout(src, step.progressTime)
    if not craft(src, step.recipe, meta) then return end
    return true
end

