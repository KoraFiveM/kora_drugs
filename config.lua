Config = {}

-- Stage `type` is the ONLY thing server/production.lua branches on -- never a
-- drug name, never a stage name. Every drug's pipeline is built entirely out
-- of these four generic roles:
--   'growStart' -- consumes `growCfg.seedItem`, starts a grow timer summed
--                  from `growCfg.growthStages` durations. Only meaningful for
--                  a drug that sets `growCfg`.
--   'harvest'   -- requires the grow timer (if any) to have elapsed, rolls
--                  `growCfg.harvestYield`, grants the rolled amount of
--                  `growCfg.item`.
--   'convert'   -- generic input(s) -> output(s) recipe (`station.recipe`);
--                  covers "processing" and "packaging" stations alike for a
--                  grown drug, and every station a synthesized drug has.
--   'sell'      -- not a station at all; handled by server/selling.lua
--                  against `sellLocations`, never by server/production.lua.
Config.stationType = {
    growStart = true,
    harvest = true,
    convert = true,
}

-- `phase` is a pure file-organization tag read by client/growing.lua,
-- processing.lua, and packaging.lua to decide which of them sets up a given
-- station's zone -- it changes nothing about how the station behaves
-- server-side (that's `type`, above). A drug with no growth phase (meth)
-- simply has no station tagged 'growing'.
Config.stationPhase = {
    growing = true,
    processing = true,
    packaging = true,
}

Config.proximity = {
    stationRadius = 5.0, -- meters; server-side re-check when a station action is submitted, regardless of the client zone's own radius
    sellRadius = 8.0,
}

-- exports.qbcore:alert's dispatch payload always names these jobs; kept
-- config-level so a server can retarget which job(s) hear drug activity
-- without touching server/production.lua or selling.lua.
Config.copAlertJobs = { 'police' }

-- Real (non-cosmetic) HP loss applied by server/items.lua's overdose roll --
-- deliberately flat and small, not per-drug: overdose SEVERITY is expressed
-- through each item's own `overdoseChance`, not through a second per-item
-- damage number.
Config.overdoseDamage = 40

---@alias QBDrugsStationType "growStart"|"harvest"|"convert"

---@class QBDrugsRecipe
---@field inputItem? string Nil for a station that only produces (e.g. a from-nothing synthesis step).
---@field inputAmount? integer
---@field outputItem string
---@field outputAmount integer

---@class QBDrugsStation
---@field type QBDrugsStationType
---@field phase "growing"|"processing"|"packaging" File-organization tag only, see Config.stationPhase above.
---@field label string
---@field coords vector3
---@field radius? number Zone/target radius. Defaults to Config.proximity.stationRadius.
---@field minigame? "lockpick"|"skillbar"|"circuit"|"mash" Nil = plain QB.progressbar step instead of a minigame.
---@field duration? integer ms. Progressbar duration when `minigame` is nil, or the minigame's own opts.duration override when it isn't.
---@field recipe? QBDrugsRecipe Required for type == 'convert'.

---@class QBDrugsCopAlert
---@field enabled boolean
---@field chance number 0..1 probability rolled on every completion of this stage.

---@class QBDrugsGrowthConfig
---@field seedItem string Consumed by the 'growStart' station.
---@field growthStages { name: string, duration: integer }[] Summed for the total grow time.
---@field item string Item granted by the 'harvest' station.
---@field harvestYield { min: integer, max: integer }|{ [1]: integer, [2]: number }[] Either a {min,max} range or a QB.util.weightedChoice list of {amount, weight} pairs.

---@class QBDrugsConfig
---@field label string
---@field pipeline string[] Ordered stage names -- drives UI ordering only; server/production.lua doesn't require stages to run in this order, it just validates each one independently.
---@field growth? QBDrugsGrowthConfig Omitted entirely for a synthesized drug with no grow phase.
---@field stations table<string, QBDrugsStation>
---@field sellLocations { coords: vector3, radius?: number, item: string, pricePerUnit: { min: number, max: number } }[]
---@field copAlerts table<string, QBDrugsCopAlert> Keyed by stage name, plus the special key 'sell'.

Config.drugs = {}

-- Example 1: a GROWN drug -- plant, wait out a multi-stage grow timer,
-- harvest, process, package, sell. Exercises Config.drugs[name].growth,
-- which the meth config below deliberately has none of.
Config.drugs.weed = {
    label = 'Weed',
    pipeline = { 'plant', 'harvest', 'process', 'package', 'sell' },

    growth = {
        seedItem = 'weed_seed',
        growthStages = {
            { name = 'seedling',   duration = 3 * 60000 },
            { name = 'vegetative', duration = 4 * 60000 },
            { name = 'flowering',  duration = 5 * 60000 },
        },
        item = 'weed_bud',
        harvestYield = { min = 3, max = 8 },
    },

    stations = {
        plant = {
            type = 'growStart', phase = 'growing', label = 'Plant Weed Seeds',
            coords = vector3(2222.6, 5577.5, 53.8), radius = 2.0, duration = 4000,
        },
        harvest = {
            type = 'harvest', phase = 'growing', label = 'Harvest Weed',
            coords = vector3(2222.6, 5577.5, 53.8), radius = 2.0, minigame = 'mash',
        },
        process = {
            type = 'convert', phase = 'processing', label = 'Process Weed',
            coords = vector3(1076.0, -3190.0, -39.0), radius = 2.5, minigame = 'circuit',
            recipe = { inputItem = 'weed_bud', inputAmount = 5, outputItem = 'weed_processed', outputAmount = 1 },
        },
        package = {
            type = 'convert', phase = 'packaging', label = 'Package Weed',
            coords = vector3(1076.0, -3195.0, -39.0), radius = 2.5, minigame = 'skillbar',
            recipe = { inputItem = 'weed_processed', inputAmount = 1, outputItem = 'weed_baggie', outputAmount = 5 },
        },
    },

    sellLocations = {
        { coords = vector3(-158.0, -1524.0, 34.0), radius = 10.0, item = 'weed_baggie', pricePerUnit = { min = 15, max = 35 } },
    },

    copAlerts = {
        harvest = { enabled = true, chance = 0.05 },
        process = { enabled = true, chance = 0.15 },
        package = { enabled = true, chance = 0.10 },
        sell    = { enabled = true, chance = 0.35 },
    },
}

-- Example 2: a SYNTHESIZED drug -- no growth phase at all, purely chemical
-- processing stations back to back. Proves the engine doesn't secretly
-- assume every drug grows -- `Config.drugs.meth.growth` is simply absent, and
-- every station is type='convert'.
Config.drugs.meth = {
    label = 'Meth',
    pipeline = { 'cook', 'mix', 'package', 'sell' },

    stations = {
        cook = {
            type = 'convert', phase = 'processing', label = 'Cook Precursors',
            coords = vector3(1005.0, -3190.0, -35.0), radius = 2.5, minigame = 'circuit',
            recipe = { inputItem = 'meth_precursor', inputAmount = 3, outputItem = 'meth_base', outputAmount = 1 },
        },
        mix = {
            type = 'convert', phase = 'processing', label = 'Mix Meth Base',
            coords = vector3(1010.0, -3190.0, -35.0), radius = 2.5, minigame = 'mash',
            recipe = { inputItem = 'meth_base', inputAmount = 2, outputItem = 'meth_mixed', outputAmount = 1 },
        },
        package = {
            type = 'convert', phase = 'packaging', label = 'Package Meth',
            coords = vector3(1015.0, -3190.0, -35.0), radius = 2.5, minigame = 'skillbar',
            recipe = { inputItem = 'meth_mixed', inputAmount = 1, outputItem = 'meth_bag', outputAmount = 4 },
        },
    },

    sellLocations = {
        { coords = vector3(1959.0, 3740.0, 32.0), radius = 10.0, item = 'meth_bag', pricePerUnit = { min = 25, max = 55 } },
    },

    copAlerts = {
        cook    = { enabled = true, chance = 0.20 },
        mix     = { enabled = true, chance = 0.20 },
        package = { enabled = true, chance = 0.10 },
        sell    = { enabled = true, chance = 0.40 },
    },
}
