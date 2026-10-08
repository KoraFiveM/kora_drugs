-- The one server event behind every step in craftSteps (shared/steps.lua).
-- The client sends which step and which saved location it used; the position, the recipe and
-- the distance check all come from the server's copy of Drugs, never from the client.
-- The recipe is the one picked on the creator's events page (data.recipe), or the step's default.

local function savedLocation(entry, key)
    local locations = entry and entry.locations
    if type(locations) ~= 'table' then return end
    if locations.coords then return locations end -- cutting / bagging hold one object
    return type(key) == 'number' and locations[key] or nil
end

RegisterNetEvent('qbdrugs:server:craft', function(drug, step, key)
    local src = source
    local name = tostring(drug) .. ':' .. tostring(step)
    local entry = Drugs[drug] and Drugs[drug][step]

    -- a step from shared/steps.lua, or an event made on the creator's Custom drugs page
    local custom = entry and type(entry.data) == 'table' and entry.data.custom == true
    if not (craftSteps[name] or custom) then return end

    local location = savedLocation(entry, key)
    local coords = location and location.coords
    if not coords then return end
    if not QB.distance.player(src, vec3(coords.x, coords.y, coords.z), 5.0) then
        QB.print.warn(('%s tried %s from too far away'):format(src, name))
        return
    end

    local hook = stepHooks[name] or {}
    if hook.handler then return hook.handler(src, location) end

    local recipe, picked = stepRecipe(name, entry.data)
    if not recipe then return end
    if runEvent(src, { recipe = recipe }, hook.meta and hook.meta(), name) and picked.successNotify then
        QB.notify.send(src, picked.successNotify)
    end
end)