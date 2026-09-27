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
local function makeTele(lab, type, coords)
    exports.qbtarget:addBoxZone({
        coords = lab,
        size = vector3(3.0, 3.0, 3.0),
        options = {
            {
                label = QB.lang('Weed.' .. type .. '.target'),
                icon = QB.lang('Weed.' .. type .. '.icon'),
                onSelect = function()
                    QB.visuals.fade(coords, 500)
                end
            }
        }
    })
end

local function hasWeedItems()
    local items = {'ak47_weed', 'amnesia_weed', 'purple_haze_weed', 'skunk_weed', 'og_kush_weed', 'blue_dream_weed'}
    for _, item in ipairs(items) do
        if exports['qb-inventory']:HasItem(item) then
            return true
        end
    end
    return false
end

if steps.enterLab then makeTele(steps.enterLab, 'enter',    steps.exitLab) end
if steps.exitLab then makeTele(steps.exitLab,   'exit',      steps.enterLab) end

if steps.drying then
    basicTarget(steps.drying.coords, steps.drying.rotation, steps.drying, "qb-drugs:server:dryCola", 'Weed.dry')
end

if steps.breakNugs then
    local data = steps.breakNugs
     exports.qbtarget:addBoxZone({
        coords = data.coords,
        size = vector3(1.5, 1.5, 1.5),
        rotation = 180.0,
        distance = 2.0,
        options = {
            {
                label = QB.lang('Weed.breakNugs.target'),
                icon = QB.lang('Weed.breakNugs.icon'),
                onSelect = function()
                    if busy then
                        return
                    end
                    if not exports['qb-inventory']:HasItem('dried_cola') then
                        QB.notify.send({title = "qb-drugs", message  = "You don't have any dried cola", type = "error"})
                        return
                    end
                    busy = true
                    if QB.progressbar.start({
                        label = QB.lang('Weed.breakNugs.progress') or 'Breaking Down',
                        duration = data and data.progress and data.progress.time or 5000,
                        disable = data and data.progress and data.progress.disable or DefaultProgress.disable,
                        anim = data and data.progress and data.progress.anim or DefaultProgress.anim,
                    }) then
                        TriggerServerEvent("qb-drugs:server:breakNugs")
                    end
                    busy = false
                end,
                canInteract = function()
                    return not busy
                end,
            }
        }
    })
end

if steps.bagWeed then
    local data = steps.bagWeed
     exports.qbtarget:addBoxZone({
        coords = data.coords,
        size = vector3(1.5, 1.5, 1.5),
        rotation = 180.0,
        distance = 2.0,
        options = {
            {
                label = QB.lang('Weed.bag.target'),
                icon = QB.lang('Weed.bag.icon'),
                onSelect = function()
                    if busy then
                        return
                    end
                    if not hasWeedItems() then
                        QB.notify.send({title = "qb-drugs", message  = "You don't have any to bag", type = "error"})
                        return
                    end
                    busy = true
                    if QB.progressbar.start({
                        label = QB.lang('Weed.bag.progress') or 'Bagging Weed',
                        duration = data and data.progress and data.progress.time or DefaultProgress.time,
                        disable = data and data.progress and data.progress.disable or DefaultProgress.disable,
                        anim = data and data.progress and data.progress.anim or DefaultProgress.anim,
                    }) then
                        TriggerServerEvent("qb-drugs:server:bagWeed")
                    end
                    busy = false
                end,
                canInteract = function()
                    return not busy 
                end,
            }
        }
    })
end

QB.callback.register('qb-drugs:client:rolling', function()
    return QB.progressbar.start({
        label = QB.lang('Weed.rolling') or 'Rolling A Joint',
        duration = 5000,
        disable = DefaultProgress.disable,
        anim = DefaultProgress.anim,
    })
end)