-- Selling smoke test -- payout via exports.qbcore:addMoney, and the
-- copAlerts['sell'] roll reaching exports.qbcore:alert (the compat layer
-- that itself fires the real `police:server:policeAlert` legacy event --
-- proven by qbcore's own test/smoke/dispatch.lua; this test only proves
-- qbdrugs calls that ONE integration point correctly, on a sale).
local h = dofile('test/harness.lua')
local mocks = dofile('test/mocks.lua'); local handle = mocks.install()
dofile('config.lua')
dofile('shared/items.lua')
dofile('server/production.lua')
dofile('server/selling.lua')

local realRandom = math.random
local SRC = 1

h.test('selling at an unknown location is a harmless no-op', function()
    handle.fireEvent('qbdrugs:server:sell', SRC, 'weed', 99)
    h.assertEqual(exports.qbcore:getItemCount(SRC, 'weed_baggie'), 0)
end)

h.test('selling too far from the location is refused and nothing is removed/paid', function()
    handle.QB.distance.player = function() return false end
    exports.qbcore:addItem(SRC, 'weed_baggie', 5)

    handle.fireEvent('qbdrugs:server:sell', SRC, 'weed', 1)

    h.assertEqual(exports.qbcore:getItemCount(SRC, 'weed_baggie'), 5, 'nothing should have been sold')
    handle.QB.distance.player = function() return true end
end)

h.test('selling pays out pricePerUnit * count and empties the stack', function()
    math.random = function(min, max)
        if min and max then return min end -- pin pricePerUnit to its floor (15)
        return 0.99 -- copAlerts roll -- keep this test's payout math clean of a dispatch alert
    end

    handle.fireEvent('qbdrugs:server:sell', SRC, 'weed', 1)
    math.random = realRandom

    h.assertEqual(exports.qbcore:getItemCount(SRC, 'weed_baggie'), 0, 'the whole stack should be sold')
    h.assertEqual(handle.money[SRC].cash, 5 * 15)
end)

h.test('selling with nothing held is a harmless no-op', function()
    local before = handle.money[SRC].cash
    handle.fireEvent('qbdrugs:server:sell', SRC, 'weed', 1)
    h.assertEqual(handle.money[SRC].cash, before)
end)

h.test('a sell-stage cop alert roll under chance reaches exports.qbcore:alert with the configured job(s)', function()
    exports.qbcore:addItem(SRC, 'weed_baggie', 3)

    local before = #handle.alerts
    math.random = function(...)
        -- pricePerUnit roll uses math.random(min,max) (2 args); the copAlerts
        -- roll uses math.random() (0 args) -- only the latter needs pinning
        -- under Config.drugs.weed.copAlerts.sell.chance (0.35).
        if select('#', ...) > 0 then return realRandom(...) end
        return 0.0
    end
    handle.fireEvent('qbdrugs:server:sell', SRC, 'weed', 1)
    math.random = realRandom

    h.assertEqual(#handle.alerts, before + 1)
    local alert = handle.alerts[#handle.alerts]
    h.assertEqual(alert.jobs[1], 'police')
    h.assertTrue(alert.title:find('Weed', 1, true) ~= nil)
end)

h.test('a sell-stage roll above chance never reaches exports.qbcore:alert', function()
    exports.qbcore:addItem(SRC, 'weed_baggie', 3)

    local before = #handle.alerts
    math.random = function(...)
        if select('#', ...) > 0 then return realRandom(...) end
        return 0.99
    end
    handle.fireEvent('qbdrugs:server:sell', SRC, 'weed', 1)
    math.random = realRandom

    h.assertEqual(#handle.alerts, before)
end)

h.report('selling')
