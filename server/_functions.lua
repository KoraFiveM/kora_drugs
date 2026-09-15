
function hasItems(src, itemList)
    local need, has = 0, 0
    local missing = {}
    for _, item in pairs(itemList) do
        need = need + 1
        if exports['qb-inventory']:HasItem(src, item.item, item.amount) then
            has = has + 1
        else
            table.insert(missing, {title = 'qb-drugs', message = 'You Need ' .. item.amount .. ' ' .. item.item, type = 'error'})
        end
    end
    if has ~= need then
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
    CreateThread(function()
        Wait(duration)
        timeouts[src] = nil
    end)
end

function runEvent(src, step, notify, meta)
    if timeouts[src] then
        return
    end
    if not QB.distance.player(src, step.coords, 3) then
        return
    end
    timeout(src, step.progressTime)
    if craft(src, step.recipe, meta) then
        if step.successNotify then
            QB.notify.send(src, step.successNotify)
        end
    end
end

