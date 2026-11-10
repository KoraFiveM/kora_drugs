local THC, CBD = WeedPercents.thc, WeedPercents.cbd
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

AddEventHandler('playerDropped', function()
    local src = source
    hasSale[src], inProgress[src] = nil, nil
end)

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
    local cfg = settings()
    local item
    for name in pairs(cfg.pricing) do
        if exports['qb-inventory']:HasItem(src, name) then
            item = exports.kora_core:getItemByName(src, name)
            break
        end
    end
    if not item then
        Kora.notify.send(src, {title = 'qb-drugs', message = 'You have no sellable items.', type = 'error'})
        return false
    end

    local info = item.info or {}
    local singlePrice = cfg.pricing[item.name]
    if weedItems[item.name] and cfg.weedPercentAdjustable ~= false then
        singlePrice = calculateWeedPrice(item.name, info.thc, info.cbd, cfg)
    end

    local amount = math.min(item.amount, math.max(1, math.floor(tonumber(cfg.maxSell) or 15)))
    local sellData = {
        item = item.name,
        itemLabel = item.label,
        singlePrice = singlePrice,
        amount = amount,
        total = singlePrice * amount,
        img = 'nui://kora_inventory/images/' .. (item.image or ''),
    }
    inProgress[src] = sellData
    return sellData
end

Kora.callback.register('kora_drugs:getSellableItem', function(source)
    hasSale[source] = hasSale[source] or {}
    return getSellableItem(source)
end)

RegisterNetEvent('kora_drugs:sellToBuyer', function(netId)
    local src = source
    local buyer = Kora.world.resolveNetworkEntity(src, netId, {
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
        exports.kora_core:addMoney(src, 'cash', total)
        hasSale[src] = hasSale[src] or {}
        hasSale[src][buyer] = true
    end
end)