local Inventory = exports['qb-inventory']
local strains = {
    sativa = {
        purple_haze_weed = 'Purple Haze',
        ak47_weed = 'AK-47',
        amnesia_weed = 'Amnesia'
    },
    indica = {
        skunk_weed = 'Skunk',
        og_kush_weed = 'OG Kush',
        blue_dream_weed = 'Blue Dream'
    }
}
local bagged = {
    purple_haze_weed = 'purple_haze_1g',
    ak47_weed = 'ak47_1g',
    amnesia_weed = 'amnesia_1g',
    skunk_weed = 'skunk_1g',
    og_kush_weed = 'og_kush_1g',
    blue_dream_weed = 'blue_dream_1g'
}

local classificationKeys = {}
local labelToItem = {}
local allItems = {}

for classification, strainData in pairs(strains) do
    local keys = {}
    for item, label in pairs(strainData) do
        keys[#keys + 1] = item
        labelToItem[label] = item
        allItems[#allItems + 1] = item
    end
    classificationKeys[classification] = keys
end

-- The first weed item the player is carrying, or nil.
local function findWeedItem(src)
    for _, name in ipairs(allItems) do
        local item = Inventory:GetItemByName(src, name)
        if item then return item end
    end
end

local function getWeedData()
    local classification = math.random(1, 2) == 1 and 'sativa' or 'indica'
    local keys = classificationKeys[classification]
    local item = keys[math.random(#keys)]
    return {
        strain = strains[classification][item],
        classification = classification,
        grams = math.random(10, 28) .. 'g',
        thc = math.random(WeedPercents.thc.min, WeedPercents.thc.max) .. '%',
        cbd = math.random(WeedPercents.cbd.min, WeedPercents.cbd.max) .. '%'
    }
end

local function getNumberFromWeight(weight)
    if not weight then
        return 0
    end
    return tonumber(weight:match("(%d+)"))
end

stepHooks['Weed:drying'] = { meta = getWeedData }

stepHooks['Weed:breakNugs'] = {
    handler = function(src)
        local item = Inventory:GetItemByName(src, 'dried_cola')
        if not item then return end

        local itemName = labelToItem[item.info.strain]
        local weight = getNumberFromWeight(item.info.grams)
        if not (itemName and weight) then return end

        local info = { cbd = item.info.cbd, thc = item.info.thc }
        if Inventory:RemoveItem(src, 'dried_cola', 1, item.slot) then
            Inventory:AddItem(src, itemName, weight, nil, info)
        end
    end,
}

stepHooks['Weed:bagWeed'] = {
    handler = function(src)
        local hasItem = findWeedItem(src)
        if not hasItem then return end

        local receive = { item = bagged[hasItem.name], amount = hasItem.amount }
        local give = {
            { item = hasItem.name, amount = hasItem.amount },
            { item = 'gram_bag', amount = hasItem.amount }
        }
        craft(src, { receive = receive, give = give }, { cbd = hasItem.info.cbd, thc = hasItem.info.thc })
    end,
}

local jointItem = {
    blue_dream_weed = 'blue_dream_joint',
    purple_haze_weed = 'purple_haze_joint',
    og_kush_weed = 'og_kush_joint',
    skunk_weed = 'skunk_joint',
    ak47_weed = 'ak47_joint',
    amnesia_weed = 'amnesia_joint',
}
exports.kora_core:createUseable('rolling_paper', function(source, item)
    local src = source
    local hasItem = findWeedItem(src)
    if not hasItem then QB.notify.send(src, {title = 'qb-drugs', message = 'You need a weed item to roll', type = 'error'}) return end
    local finished = QB.callback.trigger(src, 'qb-drugs:client:rolling')
    if not finished then return end
    if Inventory:RemoveItem(src, hasItem.name, 1, hasItem.slot) and Inventory:RemoveItem(src, 'rolling_paper', 1, item.slot) then
        Inventory:AddItem(src, jointItem[hasItem.name], 1, nil, { cbd = hasItem.info.cbd, thc = hasItem.info.thc })
    end
end)

RegisterLabTeleport('weed', 'Weed', 'lab')