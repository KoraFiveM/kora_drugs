-- Production smoke test -- the generic stage-transition engine. Every
-- assertion here exercises the SAME functions for both example drugs (weed,
-- a grown drug; meth, a purely synthesized one) to prove the engine has no
-- per-drug branching hidden in it.
local h = dofile('test/harness.lua')
local mocks = dofile('test/mocks.lua'); local handle = mocks.install()
dofile('config.lua')
dofile('shared/items.lua')
dofile('server/production.lua')

local realRandom = math.random

local function withRandomSequence(values, fn)
    local i = 0
    math.random = function(...)
        if select('#', ...) > 0 then return realRandom(...) end
        i = i + 1
        return values[i] or values[#values]
    end
    local ok, err = pcall(fn)
    math.random = realRandom
    if not ok then error(err, 0) end
end

local SRC = 1

h.test('rollYield with a {min,max} range uses math.random(min,max)', function()
    math.random = function(min, max) return min end
    local amount = Production.rollYield({ min = 3, max = 8 })
    math.random = realRandom
    h.assertEqual(amount, 3)
end)

h.test('rollYield with a weighted list picks deterministically off a seeded roll', function()
    withRandomSequence({ 0.0 }, function()
        local amount = Production.rollYield({ { 1, 1 }, { 5, 1 } })
        h.assertEqual(amount, 1, 'a roll of 0 should land in the first bucket')
    end)
end)

h.test('startGrow fails without the seed item', function()
    local ok, err = Production.startGrow(SRC, 'weed')
    h.assertFalse(ok)
    h.assertEqual(err, 'missing seed item')
end)

h.test('startGrow consumes the seed item and starts the grow timer', function()
    exports.qbcore:addItem(SRC, 'weed_seed', 1)
    local ok = Production.startGrow(SRC, 'weed')
    h.assertTrue(ok)
    h.assertEqual(exports.qbcore:getItemCount(SRC, 'weed_seed'), 0, 'the seed should have been consumed')
end)

h.test('startGrow refuses a second concurrent grow for the same drug', function()
    exports.qbcore:addItem(SRC, 'weed_seed', 1)
    local ok, err = Production.startGrow(SRC, 'weed')
    h.assertFalse(ok)
    h.assertEqual(err, 'already growing')
end)

h.test('meth has no growth phase -- startGrow refuses it generically, not via a per-drug branch', function()
    local ok, err = Production.startGrow(SRC, 'meth')
    h.assertFalse(ok)
    h.assertEqual(err, 'drug has no growth phase')
end)

h.test('completeHarvest refuses before the grow timer elapses', function()
    local ok, err = Production.completeHarvest(SRC, 'weed')
    h.assertFalse(ok)
    h.assertEqual(err, 'not ready to harvest yet')
end)

h.test('completeHarvest grants a rolled amount of the drug\'s item once ready, and clears the grow slot', function()
    -- Config.drugs.weed's growthStages sum to 12 minutes; fast-forward os.time().
    local realTime = os.time
    os.time = function() return realTime() + 12 * 60 + 1 end

    h.assertTrue(Production.isReadyToHarvest(SRC, 'weed'))

    math.random = function(min, max) return max end -- top of the {3,8} yield range
    local ok, err, result = Production.completeHarvest(SRC, 'weed')
    math.random = realRandom
    os.time = realTime

    h.assertTrue(ok, err)
    h.assertEqual(result.item, 'weed_bud')
    h.assertEqual(result.amount, 8)
    h.assertEqual(exports.qbcore:getItemCount(SRC, 'weed_bud'), 8)

    local ok2, err2 = Production.completeHarvest(SRC, 'weed')
    h.assertFalse(ok2, 'the grow slot should have been cleared by the first harvest')
    h.assertEqual(err2, 'nothing planted')
end)

local SRC2 = 2

h.test('completeConvert (weed:process) requires and consumes its recipe input', function()
    local ok, err = Production.completeConvert(SRC2, 'weed', 'process')
    h.assertFalse(ok)
    h.assertEqual(err, 'missing input item')

    exports.qbcore:addItem(SRC2, 'weed_bud', 5)
    local ok2, err2, result = Production.completeConvert(SRC2, 'weed', 'process')
    h.assertTrue(ok2, err2)
    h.assertEqual(exports.qbcore:getItemCount(SRC2, 'weed_bud'), 0)
    h.assertEqual(result.item, 'weed_processed')
    h.assertEqual(result.amount, 1)
end)

h.test('completeConvert (meth:cook) is the SAME function, on a drug with no growth phase at all', function()
    exports.qbcore:addItem(SRC2, 'meth_precursor', 3)
    local ok, err, result = Production.completeConvert(SRC2, 'meth', 'cook')
    h.assertTrue(ok, err)
    h.assertEqual(exports.qbcore:getItemCount(SRC2, 'meth_precursor'), 0)
    h.assertEqual(result.item, 'meth_base')
    h.assertEqual(result.amount, 1)
end)

h.test('completeStage dispatches on station.type, never on drug/stage name', function()
    exports.qbcore:addItem(SRC2, 'weed_processed', 1)
    local ok, err, result = Production.completeStage(SRC2, 'weed', 'package', vector3(0, 0, 0))
    h.assertTrue(ok, err)
    h.assertEqual(result.item, 'weed_baggie')
    h.assertEqual(result.amount, 5)
end)

h.test('completeStage rejects an unknown stage', function()
    local ok, err = Production.completeStage(SRC2, 'weed', 'not_a_real_stage')
    h.assertFalse(ok)
    h.assertEqual(err, 'unknown station')
end)

h.test('rollCopAlert fires exports.qbcore:alert only when enabled and the roll lands under chance', function()
    local before = #handle.alerts

    math.random = function() return 0.99 end -- above chance -- should NOT fire
    Production.rollCopAlert('weed', 'process')
    h.assertEqual(#handle.alerts, before, 'a roll above chance must not alert')

    math.random = function() return 0.0 end -- below chance -- should fire
    local fired = Production.rollCopAlert('weed', 'process')
    math.random = realRandom
    h.assertTrue(fired)
    h.assertEqual(#handle.alerts, before + 1)
    h.assertEqual(handle.alerts[#handle.alerts].jobs[1], 'police')
end)

h.test('rollCopAlert never fires for a disabled/undefined stage', function()
    local before = #handle.alerts
    math.random = function() return 0.0 end
    local fired = Production.rollCopAlert('weed', 'plant') -- no copAlerts entry for 'plant'
    math.random = realRandom
    h.assertFalse(fired)
    h.assertEqual(#handle.alerts, before)
end)

h.report('production')
