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
local function percentNumber(value)
    if type(value) == 'string' then
        value = value:gsub('%%$', '')
    end
    return tonumber(value)
end

local function settings()
    local entry = Drugs and Drugs.CornerSelling and Drugs.CornerSelling.settings
    local data = entry and entry.data
    if type(data) == 'table' and type(data.pricing) == 'table' then return data end
    return CornerSelling
end

local function calculateWeedPrice(item, thc, cbd, cfg)
    local basePrice = cfg.pricing[item]
    thc, cbd = percentNumber(thc), percentNumber(cbd)
    if not thc or not cbd then return basePrice end

    local thcQuality = (thc - THC.min) / (THC.max - THC.min)
    local cbdQuality = (cbd - CBD.min) / (CBD.max - CBD.min)

    thcQuality = math.max(0, math.min(1, thcQuality))
    cbdQuality = math.max(0, math.min(1, cbdQuality))

    local quality = (thcQuality + cbdQuality) / 2

    local priceModifier = (quality * 2 - 1) * (tonumber(cfg.weedPercentFlow) or 0.2)

    return math.floor(basePrice * (1 + priceModifier))
end

local function getSellableItem(src)
    local item = nil
    local sellData = {}
    local cfg = settings()
    for k, v in pairs(cfg.pricing) do
        local has = exports['qb-inventory']:HasItem(src, k)
        if has then
            item = exports.qbcore:getItemByName(src, k)
            break
        end
    end
    if item == nil then
        QB.notify.send(src, {title = 'qb-drugs', message = 'You have no sellable items.', type = 'error'})
        return false
    end
    if weedItems[item.name] and cfg.weedPercentAdjustable ~= false then
        sellData.singlePrice = calculateWeedPrice(item.name, item.info.thc, item.info.cbd, cfg)
    else
        sellData.singlePrice = cfg.pricing[item.name]
    end
    sellData.item = item.name
    sellData.itemLabel = item.label
    sellData.amount = math.min(item.amount, math.max(1, math.floor(tonumber(cfg.maxSell) or 15)))
    sellData.total = sellData.singlePrice * sellData.amount
    sellData.img = 'nui://qbinventory/images/' .. item.image
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
    local buyer = QB.world.resolveNetworkEntity(src, netId, {
        entityType = 'ped',
        maxDistance = 5.0,
    })
    if not buyer then return end
    local sellData = inProgress[src]
    if not sellData then return end
    if hasSale[src] and hasSale[src][buyer] then return end
    inProgress[src] = nil
    if exports['qb-inventory']:RemoveItem(src, sellData.item, sellData.amount) then
        local total = sellData.total
        exports.qbcore:addMoney(src, 'cash', total)
        hasSale[src] = hasSale[src] or {}
        hasSale[src][buyer] = true
    end
end)