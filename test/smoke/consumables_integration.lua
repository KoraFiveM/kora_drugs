-- THE integration proof this resource's whole design rests on: registering a
-- drug item's `effect` table (shared/items.lua) and simulating a real use
-- routes through the REAL qbcore Core.consumables + the REAL qblib
-- QB.status -- with ZERO qbdrugs-side fx/anim/movement code anywhere in the
-- path. Unlike production.lua/selling.lua's smoke tests (which mock qbcore
-- entirely), this one dofiles qbcore's and qblib's ACTUAL source files
-- (via qbcore's own test/mocks.lua, the same harness its own
-- test/smoke/consumables.lua uses) so a broken wiring in shared/items.lua or
-- server/items.lua would show up here even if a hand-rolled mock would have
-- papered over it. Two things are checked:
--   1. Runtime: using a drug item applies the EXACT fx/anim/movement/
--      duration data that shared/items.lua attached to it, through
--      Core.consumables -> QB.status, with no qbdrugs code in between.
--   2. Static: qbdrugs's own client/server/shared files contain no
--      StartScreenEffect/StartParticleFx/TaskPlayAnim/SetPedMoveRateOverride
--      call at all -- the "confirm via code review" instruction, automated.
local h = dofile('test/harness.lua')

local qbcoreMocks = dofile('../qbcore/test/mocks.lua')
local handle = qbcoreMocks.install()

dofile('../qbcore/config.lua')
dofile('../qbcore/shared/items.lua')
dofile('../qbcore/shared/jobs.lua')
dofile('../qbcore/shared/gangs.lua')
dofile('../qbcore/shared/vehicles.lua')
dofile('../qbcore/shared/weapons.lua')
dofile('../qbcore/shared/locations.lua')
dofile('../qbcore/modules/util/shared.lua')
dofile('../qbcore/modules/registry/shared.lua')
dofile('../qbcore/modules/registry/server.lua')
dofile('../qbcore/modules/player/shared.lua')
dofile('../qbcore/modules/replication/server.lua')
dofile('../qbcore/modules/persistence/server.lua')
dofile('../qbcore/modules/player/server.lua')
dofile('../qbcore/modules/metadata/server.lua')
dofile('../qbcore/modules/inventory/shared.lua')
dofile('../qbcore/modules/inventory/server.lua')

-- Real qblib QB.status (both realms -- server.lua's apply() and client.lua's
-- renderEffect() both consult the same registerEffect def). QB.events.push is
-- the only extra native surface status/server.lua needs beyond what qbcore's
-- own mocks already provide.
QB.status = {}
QB.events = { push = function() end }
dofile('../qblib/modules/status/shared.lua')
dofile('../qblib/modules/status/server.lua')

dofile('../qbcore/modules/consumables/server.lua')

-- Real qbinventory registerHook capture, identical in shape to qbcore's own
-- test/smoke/consumables.lua -- Core.consumables defers registration until
-- qbinventory is seen 'started'.
local registeredHookCallback
handle.resourceStates.qbinventory = 'missing'
_G.exports.qbinventory = {
    registerHook = function(_, eventName, callback)
        h.assertEqual(eventName, 'usingItem')
        registeredHookCallback = callback
    end,
}

-- The one piece of scaffolding this test adds on top of qbcore's own mocks:
-- a REAL exports.qbcore surface that forwards to the Core.* functions just
-- dofiled above, so qbdrugs's own server/items.lua -- called completely
-- unmodified below -- is exercising its actual production code path, not a
-- stand-in.
_G.exports.qbcore = {
    registerShared = function(_, name, key, record) return Core.registry.registerShared(name, key, record) end,
    getShared = function(_, name, key) return Core.registry.getShared(name, key) end,
    createUseable = function(_, name, fn) return Core.inventory.createUseable(name, fn) end,
    incrementMetaData = function(_, src, key, delta, min, max) return Core.metadata.incrementMetaData(src, key, delta, min, max) end,
    removeItem = function(_, src, name, amount, slot, reason) return Core.inventory.removeItem(src, name, amount, slot, reason) end,
}

handle.resourceStates.qbinventory = 'started'
handle.fireEvent('onResourceStart', nil, 'qbinventory')
h.test('Core.consumables registered against the (mocked) qbinventory hook', function()
    h.assertTrue(Core.consumables.isRegistered())
    h.assertTrue(registeredHookCallback ~= nil)
end)

-- qbdrugs's OWN files, run completely unmodified.
dofile('shared/items.lua')
dofile('server/items.lua')

h.test('shared/items.lua registered weed_baggie as a real QB.status effect def', function()
    local def = QB.status.getEffectDef('weed_baggie')
    h.assertTrue(def ~= nil)
    h.assertEqual(def.fx.screen, 'high_weed')
    h.assertEqual(def.movement.speedMultiplier, 0.9)
end)

h.test('server/items.lua registered weed_baggie into qbcore\'s real shared item registry, effect table intact', function()
    local def = Core.registry.getShared('items', 'weed_baggie')
    h.assertTrue(def ~= nil)
    h.assertEqual(def.effect.hungerDelta, 10)
    h.assertEqual(def.effect.fx.ptfx.dict, 'scr_fbi04')
end)

local data = CoreInternal.player.freshData('CID1', 'license:abc', 1, { firstname = 'A', lastname = 'B' })
Core.player.login(1, 'CID1', data)
Core.metadata.setMetaData(1, 'hunger', 50)
Core.metadata.setMetaData(1, 'thirst', 50)
Core.metadata.setMetaData(1, 'stress', 50)

h.test('using weed_baggie applies its status effect and metadata deltas through Core.consumables/QB.status alone', function()
    h.assertFalse(QB.status.isActive(1, 'weed_baggie'))

    local allowed = registeredHookCallback({ itemName = 'weed_baggie', inventoryId = 'player:1', inventoryType = 'player' }, 1)

    h.assertTrue(allowed, 'the hook must never deny an item use')
    h.assertTrue(QB.status.isActive(1, 'weed_baggie'), 'QB.status itself (not qbdrugs) must now consider the effect active')
    h.assertEqual(Core.metadata.getMetaData(1, 'hunger'), 60)
    h.assertEqual(Core.metadata.getMetaData(1, 'thirst'), 45)
    h.assertEqual(Core.metadata.getMetaData(1, 'stress'), 35)

    local active = QB.status.getActive(1)
    local found
    for _, entry in ipairs(active) do if entry.name == 'weed_baggie' then found = entry end end
    h.assertTrue(found ~= nil, 'weed_baggie should be in QB.status.getActive(1)')
end)

h.test('meth_bag is wired through the identical, unmodified path', function()
    local allowed = registeredHookCallback({ itemName = 'meth_bag', inventoryId = 'player:1', inventoryType = 'player' }, 1)
    h.assertTrue(allowed)
    h.assertTrue(QB.status.isActive(1, 'meth_bag'))
    h.assertEqual(QB.status.getEffectDef('meth_bag').movement.speedMultiplier, 1.15)
end)

-- --- static proof: no qbdrugs file contains a forbidden fx/anim/movement call ---

local FORBIDDEN = { 'StartScreenEffect(', 'StartParticleFx', 'TaskPlayAnim(', 'SetPedMoveRateOverride(' }
local SCANNED_FILES = {
    'shared/items.lua',
    'server/items.lua', 'server/production.lua', 'server/stations.lua', 'server/selling.lua',
    'client/growing.lua', 'client/processing.lua', 'client/packaging.lua', 'client/selling.lua', 'client/use.lua',
}

h.test('no qbdrugs file contains a consumption-effect native call outside a comment', function()
    for _, path in ipairs(SCANNED_FILES) do
        local f = assert(io.open(path, 'r'))
        local lineNo = 0
        for line in f:lines() do
            lineNo = lineNo + 1
            local code = line:match('^(.-)%-%-') or line
            for _, forbidden in ipairs(FORBIDDEN) do
                h.assertFalse(code:find(forbidden, 1, true) ~= nil,
                    ('%s:%d contains forbidden call %s'):format(path, lineNo, forbidden))
            end
        end
        f:close()
    end
end)

h.report('consumables_integration')
