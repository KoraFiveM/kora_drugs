
local THC, CBD = Config.Weed.percents.thc, Config.Weed.percents.cbd
local weedItems = {
    skunk_1g = true,
    purple_haze_1g = true,
    ak47_1g = true,
    amnesia_1g = true,
    og_kush_1g = true,
    blue_dream_1g = true,
    skunk_joint = true,
    purple_haze_joint = true,
    ak47_joint = true,
    amnesia_joint = true,
    og_kush_joint = true,
    blue_dream_joint = true,
}
local hasSale = {}
local inProgress = {}
local function calculateWeedPrice(item, thc, cbd)
    local basePrice = CornerSelling.pricing[item]

    local thcQuality = (thc - THC.min) / (THC.max - THC.min)
    local cbdQuality = (cbd - CBD.min) / (CBD.max - CBD.min)

    thcQuality = math.max(0, math.min(1, thcQuality))
    cbdQuality = math.max(0, math.min(1, cbdQuality))

    local quality = (thcQuality + cbdQuality) / 2

    local priceModifier = (quality * 2 - 1) * 0.20

    return math.floor(basePrice * (1 + priceModifier))
end

local function getSellableItem(src)
    local item = nil
    local sellData = {}
    for k, v in pairs (CornerSelling.pricing) do
        local has = exports['qb-inventory']:HasItem(src, k)
        if has then
            item = exports['qb-core']:GetPlayer(src).Functions.GetItemByName(k)
            break
        end
    end
    if item == nil then
        return false
    end
    if weedItems[item.name] and CornerSelling.weedPercentAdjustable then
        sellData.singlePrice = calculateWeedPrice(item.name, item.info.thc, item.info.cbd)
    else
        sellData.singlePrice = CornerSelling.pricing[item.name]
    end
    sellData.item = item.name
    sellData.itemLabel = item.label
    sellData.amount = math.min(item.amount, 15)
    sellData.total = sellData.singlePrice * sellData.amount
    sellData.img = 'nui://qb-inventory/html/images/' .. item.image
    inProgress[src] = sellData
    return sellData
end

QB.callback.register('qbdrugs:getSellableItem', function(source)
    if not hasSale[source] then
        hasSale[source] = {}
    end
    local sellData = getSellableItem(source)
    return sellData
end)

RegisterNetEvent('qbdrugs:sellToBuyer', function(netId)
    local src = source
    local buyer = NetworkGetEntityFromNetworkId(netId)
    assert(buyer, "Buyer entity could not be found")
    assert(GetNetTypeFromEntity(buyer) == 6, "Buyer entity is not a ped")
    local sellData = inProgress[src]
    if not sellData then return end
    if hasSale[src] and hasSale[src][buyer] then return end
    inProgress[src] = nil
    if exports['qb-inventory']:RemoveItem(src, sellData.item, sellData.amount) then
        local total = sellData.total
        exports['qb-core']:GetPlayer(src).Functions.AddMoney('cash', total)
        hasSale[src] = hasSale[src] or {}
        hasSale[src][buyer] = true
    end
end)