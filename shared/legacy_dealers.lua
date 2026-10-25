-- Dealer defaults adapted from qbcore-fivem/qb-drugs 51052d139bc482d9d0e94d4f47680b241e866bba (GPL-3.0).
-- Lab and corner-selling configuration remains independent.
LegacyDealerConfig = {
    deliverySeconds = 300,
    UseMarkedBills = false,
    DeliveryRepGain = 1,
    DeliveryRepLoss = 1,
    PoliceDeliveryModifier = 2,
    WrongAmountFee = 2,
    OverdueDeliveryFee = 4,
    Products = {},
    DeliveryItems = {
        { item = 'weed_brick', minrep = 0, payout = 1000 },
        { item = 'coke_brick', minrep = 0, payout = 1000 },
    },
    DeliveryLocations = {
        { label = 'Stripclub', coords = { x = 106.24, y = -1280.32, z = 29.24 } },
        { label = 'Vinewood Video', coords = { x = 223.98, y = 121.53, z = 102.76 } },
        { label = 'Taxi', coords = { x = 882.67, y = -160.26, z = 77.11 } },
        { label = 'Resort', coords = { x = -1245.63, y = 376.21, z = 75.34 } },
        { label = 'Bahama Mamas', coords = { x = -1383.1, y = -639.99, z = 28.67 } },
    },
}
for slot, name in ipairs({ 'weed_whitewidow', 'weed_skunk', 'weed_purplehaze', 'weed_ogkush', 'weed_amnesia',
    'weed_whitewidow_seed', 'weed_skunk_seed', 'weed_purplehaze_seed', 'weed_ogkush_seed', 'weed_amnesia_seed' }) do
    LegacyDealerConfig.Products[slot] = {
        name = name, price = 15, amount = 150, info = {}, type = 'item', slot = slot, minrep = (slot - 1) * 20,
    }
end
