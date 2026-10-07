if Config and Config.Weed and Config.Weed.disabled then
    print("Weed plants are disabled")
    return
end

local steps = Config.Weed.steps

if not steps then
    print("Weed steps are not defined")
    return
end

local busy = false

local function hasWeedItems()
    local items = {'ak47_weed', 'amnesia_weed', 'purple_haze_weed', 'skunk_weed', 'og_kush_weed', 'blue_dream_weed'}
    for _, item in ipairs(items) do
        if exports['qb-inventory']:HasItem(item) then
            return true
        end
    end
    return false
end

local function canDry()
    return not (steps.drying and steps.drying.recipe) or itemCheck(steps.drying.recipe)
end

local function canBreak()
    if exports['qb-inventory']:HasItem('dried_cola') then return true end
    QB.notify.send({title = "qb-drugs", message = "You don't have any dried cola", type = "error"})
end

local function canBag()
    if hasWeedItems() then return true end
    QB.notify.send({title = "qb-drugs", message = "You don't have any to bag", type = "error"})
end

local STEPS = {
    drying    = { event = 'qb-drugs:server:dryCola',   locale = 'Weed.dry',       check = canDry },
    breakNugs = { event = 'qb-drugs:server:breakNugs', locale = 'Weed.breakNugs', check = canBreak },
    bagWeed   = { event = 'qb-drugs:server:bagWeed',   locale = 'Weed.bag',       check = canBag },
}

local function run(data, info, key)
    if busy then return end
    if not info.check() then return end
    busy = true
    local progress = data.progress or {}
    if QB.progressbar.start({
        label = progress.label or QB.lang(info.locale .. '.progress'),
        duration = progress.time or DefaultProgress.time,
        disable = progress.disable or DefaultProgress.disable,
        anim = data.anim or DefaultProgress.anim,
    }) then
        TriggerServerEvent(info.event, key)
    end
    busy = false
end

local zones = {}
local function clear(step)
    local z = zones[step]
    if z then
        for _, id in ipairs(z.vec) do
            pcall(function() exports.qbtarget:removeZone(id) end)
        end
        for _, obj in ipairs(z.obs) do
            pcall(function() QB.entities.remove(obj) end)
        end
    end
    zones[step] = { vec = {}, obs = {} }
end

local function build(step, info)
    return function(entry)
        clear(step)
        if not entry or not entry.locations then return end

        local data = entry.data or {}
        local z = zones[step]

        for key, location in ipairs(entry.locations) do
            local c = location.coords
            if c then
                local options = {
                    {
                        label = data.targetLabel or QB.lang(info.locale .. '.target'),
                        icon = data.targetIcon or QB.lang(info.locale .. '.icon'),
                        onSelect = function()
                            run(data, info, key)
                        end,
                        canInteract = function()
                            return not busy and inGang(location.gang)
                        end,
                    },
                }
                if location.object then
                    z.obs[#z.obs + 1] = createObject(location.object, vector4(c.x, c.y, c.z, c.w or 0.0), 0, options)
                else
                    z.vec[#z.vec + 1] = createBox(vector3(c.x, c.y, c.z), 0, options)
                end
            end
        end
    end
end

for step, info in pairs(STEPS) do
    OnDrugs('Weed', step, build(step, info))
end

OnDrugs('Weed', 'lab', LabTeleport('weed', 'Weed'))

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for step in pairs(zones) do clear(step) end
end)

QB.callback.register('qb-drugs:client:rolling', function()
    return QB.progressbar.start({
        label = QB.lang('Weed.rolling') or 'Rolling A Joint',
        duration = 5000,
        disable = DefaultProgress.disable,
        anim = DefaultProgress.anim,
    })
end)