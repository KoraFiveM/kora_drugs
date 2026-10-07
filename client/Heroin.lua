local STEPS = {
    'drying',
    'vials',
    'syringe'
}

local zones = {}
local function clear(step)
    local z = zones[step]
    if z then
        for _, id in ipairs(z.vec) do
            pcall(function() exports.qbtarget:removeZone(id) end)
        end
        for _, obj in ipairs(z.obs) do
            QB.entities.remove(obj)
        end
    end
    zones[step] = { vec = {}, obs = {} }
end

local function build(step, event)
    return function(entry)
        clear(step)
        if not entry or not entry.locations then return end

        local data = entry.data or {}
        local recipe = Config.Heroin.steps[step].recipe
        local z = zones[step]

        for key, location in ipairs(entry.locations) do
            local options = {
                {
                    label = data.targetLabel,
                    icon = data.targetIcon,
                    onSelect = function()
                        progressTrigger(recipe, data, event, key)
                    end,
                },
            }
            if location.object then
                z.obs[#z.obs + 1] = createObject(location.object, location.coords, 0, options)
            else
                z.vec[#z.vec + 1] = createBox(location.coords, 0, options)
            end
        end
    end
end

for id, event in pairs(STEPS) do
    OnDrugs('Heroin', event, build(event, ('qb-drugs:server:Heroin' .. event:gsub("^%l", string.upper))))
end