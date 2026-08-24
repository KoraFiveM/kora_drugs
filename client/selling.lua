-- Sets up every drug's sellLocations as an interact zone. Not a "station" in
-- Config.stationType's sense (no minigame/recipe) -- selling sells the
-- player's entire held stack of that location's item in one action; the
-- payout range and cop-alert chance are entirely config/server-side (see
-- server/selling.lua).

for drugName, drug in pairs(Config.drugs) do
    for locationIndex, location in ipairs(drug.sellLocations or {}) do
        QB.interact.addCircleZone(
            ('%s:sell:%d'):format(drugName, locationIndex),
            location.coords,
            location.radius or Config.proximity.sellRadius,
            {
                options = {
                    {
                        label = 'Sell ' .. drug.label,
                        action = function() TriggerServerEvent('qbdrugs:server:sell', drugName, locationIndex) end,
                    },
                },
            },
            false
        )
    end
end
