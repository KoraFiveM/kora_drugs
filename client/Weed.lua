
local function hasWeedItems()
    local items = {'ak47_weed', 'amnesia_weed', 'purple_haze_weed', 'skunk_weed', 'og_kush_weed', 'blue_dream_weed'}
    for _, item in ipairs(items) do
        if exports['qb-inventory']:HasItem(item) then
            return true
        end
    end
    return false
end

stepHooks['Weed:breakNugs'] = {
    check = function()
        if exports['qb-inventory']:HasItem('dried_cola') then return true end
        Kora.notify.send({title = Kora.lang('Drugs.title'), message = Kora.lang('Drugs.no_weed_to_roll'), type = "error"})
    end,
}

stepHooks['Weed:bagWeed'] = {
    check = function()
        if hasWeedItems() then return true end
        Kora.notify.send({title = Kora.lang('Drugs.title'), message = Kora.lang('Drugs.no_weed_to_bag'), type = "error"})
    end,
}

OnDrugs('Weed', 'lab', LabTeleport('weed', 'Weed'))

Kora.callback.register('qb-drugs:client:rolling', function()
    return Kora.progressbar.start({
        label = Kora.lang('Weed.rolling'),
        duration = 5000,
        disable = DefaultProgress.disable,
        anim = DefaultProgress.anim,
    })
end)