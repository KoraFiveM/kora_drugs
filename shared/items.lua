-- Every drug item this resource knows about, as PURE DATA. This file (and
-- server/items.lua, which feeds these same records into
-- exports.qbcore:registerShared) is the ONLY place qbdrugs's own code
-- describes what a drug item's screen fx/ptfx/anim/movement/hunger/thirst/
-- stress effects are. There is deliberately no `StartScreenEffect`,
-- `StartParticleFx*`, or `TaskPlayAnim` call anywhere else in this resource --
-- consumption playback is entirely qbcore's Core.consumables +
-- qblib's QB.status/QB.fx (see qbcore/modules/consumables/server.lua and
-- qblib/modules/status/{shared,server,client}.lua). If a future change wants
-- a new drug's cosmetic effect, it belongs as a new `effect` table below, not
-- as new Lua logic.
--
-- `effect` is a superset of QBStatusEffectDef (qblib/modules/status/shared.lua):
-- `duration`/`stacking`/`severityLevels`/`fx`/`anim`/`movement` are read by
-- QB.status itself once registered via QB.status.registerEffect (this file,
-- shared realm, so both client and server VMs see the definition -- QB.status
-- looks the def up by NAME on both realms, see status/server.lua's apply()).
-- `hungerDelta`/`thirstDelta`/`stressDelta` are read directly by
-- Core.consumables, never by QB.status.

Drugs = Drugs or {}

---@class QBDrugsItemEffect : QBStatusEffectDef
---@field hungerDelta? number
---@field thirstDelta? number
---@field stressDelta? number
---@field overdoseChance? number 0..1. Read only by server/items.lua's minimal createUseable handler for the real (non-cosmetic) overdose mechanic -- see that file's header for why this stays out of Core.consumables.
---@field addictionDelta? number Added to the 'addiction' metadata key (clamped 0..100) on every use. Same handler as overdoseChance.

---@class QBDrugsItemDef
---@field name string
---@field label string
---@field weight integer
---@field description? string
---@field useable? boolean
---@field effect? QBDrugsItemEffect Present only on the final, consumable form of a drug -- production intermediates (seeds, raw plant matter, precursors, unpackaged base) never have one.

-- Production intermediates: no `effect` table, never marked directly
-- `useable` for a cosmetic effect (the raw plant/chemical isn't something a
-- player "uses" for a high).
Drugs.items = {
    -- weed pipeline
    { name = 'weed_seed',      label = 'Weed Seeds',     weight = 5,   description = 'A handful of cannabis seeds.' },
    { name = 'weed_bud',       label = 'Weed Bud',       weight = 15,  description = 'Freshly harvested cannabis bud, still needs processing.' },
    { name = 'weed_processed', label = 'Processed Weed', weight = 10,  description = 'Dried and cured cannabis, ready to package.' },
    {
        name = 'weed_baggie', label = 'Bag of Weed', weight = 8, useable = true,
        description = 'A small baggie of packaged weed.',
        effect = {
            duration = 180000, stacking = 'extend', severityLevels = 3,
            fx = { screen = 'high_weed', ptfx = { dict = 'scr_fbi04', name = 'scr_fbi04_smoke_train', bone = 'skel_head_top', scale = 0.3 } },
            anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
            movement = { speedMultiplier = 0.9 },
            hungerDelta = 10, thirstDelta = -5, stressDelta = -15,
            overdoseChance = 0.01, addictionDelta = 2,
        },
    },

    -- meth pipeline
    { name = 'meth_precursor', label = 'Meth Precursor',   weight = 6,  description = 'Assorted precursor chemicals.' },
    { name = 'meth_base',      label = 'Meth Base',        weight = 12, description = 'Cooked but unmixed meth base.' },
    { name = 'meth_mixed',     label = 'Mixed Meth',       weight = 12, description = 'Mixed meth, not yet packaged.' },
    {
        name = 'meth_bag', label = 'Bag of Meth', weight = 5, useable = true,
        description = 'A small bag of crystal meth.',
        effect = {
            duration = 120000, stacking = 'replace', severityLevels = 3,
            fx = { screen = 'high_meth', ptfx = { dict = 'core', name = 'ent_dst_elec_fire_sp', bone = 'skel_head_top', scale = 0.2 } },
            anim = { dict = 'mp_suicide', clip = 'pill' },
            movement = { speedMultiplier = 1.15 },
            hungerDelta = -15, thirstDelta = -20, stressDelta = -25,
            overdoseChance = 0.05, addictionDelta = 6,
        },
    },
}

Drugs.itemsByName = {}
for _, item in ipairs(Drugs.items) do
    Drugs.itemsByName[item.name] = item
end

-- Registers every drug item's `effect` table as a QB.status effect def, keyed
-- by the item's own name -- QB.status.apply(target, itemName, ...) (called
-- for us by Core.consumables) looks the def up by that same name on both
-- realms, so this must run here, in a shared_script, not only server-side.
for _, item in ipairs(Drugs.items) do
    if item.effect then
        QB.status.registerEffect(item.name, item.effect)
    end
end
