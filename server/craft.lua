local craftCooldown = 2500

local function savedLocation(entry, key)
    local locations = entry and entry.locations
    if type(locations) ~= 'table' then return end
    if locations.coords then return locations end
    return type(key) == 'number' and locations[key] or nil
end

RegisterNetEvent('kora_drugs:server:craft', function(drug, step, key)
    local src = source
    local name = tostring(drug) .. ':' .. tostring(step)
    local entry = Drugs[drug] and Drugs[drug][step]

    local isCustom = entry and type(entry.data) == 'table' and entry.data.custom == true
    if not (craftSteps[name] or isCustom) then return end

    local location = savedLocation(entry, key)
    if not (location and location.coords) then return end
    if not isNear(src, location.coords) then
        Kora.logging.warn('craft.too_far_away', 'Player tried to craft from too far away', { playerId = src, step = name })
        return
    end

    if onCooldown(src, 'craft') then
        Kora.logging.warn('craft.on_cooldown', 'Player tried to craft while on cooldown', { playerId = src, step = name })
        return
    end
    startCooldown(src, 'craft', craftCooldown)

    local hook = stepHooks[name] or {}
    if hook.handler then return hook.handler(src, location) end

    local recipe, info = stepRecipe(name, entry.data)
    if not recipe then return end
    if craft(src, recipe, hook.meta and hook.meta()) and info.successNotify then
        Kora.bridge.sendNotify(src, info.successNotify)
    end
end)
