-- Selling: payout via exports.qbcore:addMoney, cop-alert roll via
-- Production.rollCopAlert (the SAME per-stage-chance helper every production
-- stage uses, keyed by the special stage name 'sell'). One generic handler
-- for every drug's every sell location -- price range and item are config
-- data, never branched on by name here.

RegisterNetEvent('qbdrugs:server:sell', function(drugName, locationIndex)
    local src = source
    local drug = Config.drugs[drugName]
    if not drug then return end
    local location = drug.sellLocations and drug.sellLocations[locationIndex]
    if not location then return end

    if not QB.distance.player(src, location.coords, location.radius or Config.proximity.sellRadius) then
        QB.notify.send(src, { title = 'Too far away', message = 'Get closer to the buyer.', type = 'error' })
        return
    end

    local count = exports.qbcore:getItemCount(src, location.item)
    if count <= 0 then
        QB.notify.send(src, { title = 'Nothing to sell', message = ('You have no %s.'):format(location.item), type = 'error' })
        return
    end

    local ok = exports.qbcore:removeItem(src, location.item, count)
    if not ok then return end

    local pricePerUnit = math.random(location.pricePerUnit.min, location.pricePerUnit.max)
    local total = pricePerUnit * count
    local paid, payErr = exports.qbcore:addMoney(src, 'cash', total, 'drug-sale')
    if not paid then
        local restored, restoreErr = exports.qbcore:addItem(src, location.item, count, nil, nil, 'drug-sale-rollback')
        if not restored then print(('^1[qbdrugs]^7 sale rollback failed for %s: %s'):format(src, tostring(restoreErr))) end
        QB.notify.send(src, { title = 'Sale failed', message = payErr or 'Could not receive payment.', type = 'error' })
        return
    end

    QB.notify.send(src, {
        title = 'Sale complete',
        message = ('Sold %dx %s for $%d.'):format(count, drug.label, total),
        type = 'success',
    })

    Production.rollCopAlert(drugName, 'sell', location.coords)
end)
