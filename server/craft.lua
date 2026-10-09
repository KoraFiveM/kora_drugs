local craftCooldown = 5000

-- Where the player is crafting: a single saved location, or one entry out of a list.
local function savedLocation(entry, key)
    local locations = entry and entry.locations
    if type(locations) ~= 'table' then return end
    if locations.coords then return locations end
    return type(key) == 'number' and locations[key] or nil
end

RegisterNetEvent('qbdrugs:server:craft', function(drug, step, key)
    local src = source
    local name = tostring(drug) .. ':' .. tostring(step)
    local entry = Drugs[drug] and Drugs[drug][step]

    local isCustom = entry and type(entry.data) == 'table' and entry.data.custom == true
    if not (craftSteps[name] or isCustom) then return end

    local location = savedLocation(entry, key)
    if not (location and location.coords) then return end
    if not isNear(src, location.coords) then
        QB.print.warn(('%s tried %s from too far away'):format(src, name))
        return
    end

    -- One craft at a time per player, whether the step has a recipe or runs its own handler.
    if onCooldown(src, 'craft') then
        QB.print.warn(QB.lang('Functions.timeout', src, name))
        return
    end
    startCooldown(src, 'craft', craftCooldown)

    local hook = stepHooks[name] or {}
    if hook.handler then return hook.handler(src, location) end

    local recipe, info = stepRecipe(name, entry.data)
    if not recipe then return end
    if craft(src, recipe, hook.meta and hook.meta()) and info.successNotify then
        QB.notify.send(src, info.successNotify)
    end
end)
