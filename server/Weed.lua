local Step = Config.Weed.steps
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

local function getWeedData()
    local classification = math.random(1, 2) == 1 and 'sativa' or 'indica'
    local keys = classificationKeys[classification]
    local item = keys[math.random(#keys)]
    return {
        strain = strains[classification][item],
        classification = classification,
        weight = math.random(10, 28) .. 'g',
        thc = math.random(10, 30) .. '%',
        cbd = math.random(5, 20) .. '%'
    }
end

local function getNumberFromWeight(weight)
    if not weight then
        return 0
    end
    return tonumber(weight:match("(%d+)"))
end

local timeout = {}

local function onCooldown(src)
    if timeout[src] then
        return true
    end
    timeout[src] = true
    CreateThread(function()
        Wait(5000)
        timeout[src] = nil
    end)
    return false
end

local function checkDistance(src, coords, distance)
    return QB.distance.player(src, coords, distance)
end

local function verify(src, coords, distance)
    if onCooldown(src) then
        return false
    end
    if not checkDistance(src, coords, distance) then
        return false
    end
    return true
end

RegisterNetEvent('qb-drugs:server:dryCola', function()
    local src = source
    assert(verify(src, Step.drying.coords, 5.0), "Player is not in the correct location or on cooldown") 
    if craft(src, Step.drying.recipe, getWeedData()) and Step.drying.successNotify then
        QB.notify.send(src, Step.drying.successNotify)
    end
end)

RegisterNetEvent('qb-drugs:server:breakNugs', function()
    local src = source
    assert(verify(src, Step.breakNugs.coords, 5.0), "Player is not in the correct location or on cooldown")
    local item = Inventory:GetItemByName(src, 'dried_cola')
    if not item then
        return
    end

    local itemName = labelToItem[item.info.strain]
    local weight = getNumberFromWeight(item.info.weight)
    if not (itemName and weight) then
        return
    end

    local info = { cbd = item.info.cbd, thc = item.info.thc }
    if Inventory:RemoveItem(src, 'dried_cola', 1, item.slot) then
        Inventory:AddItem(src, itemName, weight, nil, info)
    end
end)

RegisterNetEvent('qb-drugs:server:bagWeed', function()
    local src = source
    assert(verify(src, Step.bagWeed.coords, 5.0), "Player is not in the correct location or on cooldown")

    local hasItem
    for i = 1, #allItems do
        hasItem = Inventory:GetItemByName(src, allItems[i])
        if hasItem then
            break
        end
    end
    if not hasItem then
        return
    end

    local receive = { item = bagged[hasItem.name], amount = hasItem.amount }
    local give = {
        { item = hasItem.name, amount = hasItem.amount },
        { item = 'gram_bag', amount = hasItem.amount }
    }

    if craft(src, { receive = receive, give = give }, { cbd = hasItem.info.cbd, thc = hasItem.info.thc }) then
        if Step.bagWeed.successNotify then
            QB.notify.send(src, Step.bagWeed.successNotify)
        end
    end
end)

local jointItem = {
    blue_dream_weed = 'blue_dream_joint',
    purple_haze_weed = 'purple_haze_joint',
    og_kush_weed = 'og_kush_joint',
    skunk_weed = 'skunk_joint',
    ak47_weed = 'ak47_joint',
    amnesia_weed = 'amnesia_joint',
}
exports['qb-core']:CreateUseableItem('rolling_paper', function(source, item)
    local src = source
    local hasItem = nil
    for i = 1, #allItems do
        hasItem = Inventory:GetItemByName(src, allItems[i])
        if hasItem then
            break
        end
    end
    if not hasItem then return end
    local finished = QB.callback.trigger(src, 'qb-drugs:client:rolling')
    if not finished then return end
    if Inventory:RemoveItem(src, hasItem.name, 1, hasItem.slot) and Inventory:RemoveItem(src, 'rolling_paper', 1, item.slot) then
        Inventory:AddItem(src, jointItem[hasItem.name], 1, nil, { cbd = hasItem.info.cbd, thc = hasItem.info.thc })
    end
end)

for k, itemName in pairs(jointItem) do
    if itemName ~= 'blue_dream_joint' then
        exports.qbconsumables:addConsumable(itemName, {
            type = 'smoke'
        })
    end
end