-- Registers every item from shared/items.lua into qbcore's shared registry,
-- and wires ONE generic real-gameplay-effect handler shared by every drug
-- item. This file still contains ZERO screen-fx/ptfx/anim/movement code --
-- that playback is entirely Core.consumables + QB.status, driven by the
-- `effect` table already attached to each item record (see shared/items.lua's
-- header). What lives here is the opposite kind of effect: a REAL overdose
-- (actual HP loss) and addiction-meter accrual, neither of which
-- Core.consumables' cosmetic-only layer touches (it deliberately never denies
-- a use or changes anything beyond hunger/thirst/stress/status -- see
-- qbcore/modules/consumables/server.lua's own header). Registered via
-- exports.qbcore:createUseable, which the inventory gateway forwards straight
-- to qbinventory's own useables table (the one its real Use-button flow
-- actually consults) when qbinventory is running, same as every other
-- Core.inventory method.

---@param src integer
---@param item table
local function onUseDrugItem(src, item)
    local def = exports.qbcore:getShared('items', item.name)
    local effect = def and def.effect
    if not effect then return false end

    local removed, removeErr = exports.qbcore:removeItem(src, item.name, 1, item.slot, 'consumed')
    if not removed then return false, removeErr end

    if effect.overdoseChance and math.random() < effect.overdoseChance then
        local ped = GetPlayerPed(src)
        if ped and ped ~= 0 then
            local newHealth = math.max(GetEntityHealth(ped) - Config.overdoseDamage, 0)
            SetEntityHealth(ped, newHealth)
        end
        QB.notify.send(src, { title = 'Overdose', message = 'You overdosed on ' .. (def.label or item.name) .. '!', type = 'error' })
    end

    if effect.addictionDelta then
        exports.qbcore:incrementMetaData(src, 'addiction', effect.addictionDelta, 0, 100)
    end

    return true
end

for _, item in ipairs(Drugs.items) do
    local ok, err = exports.qbcore:registerShared('items', item.name, item)
    if not ok then
        print(('^1[qbdrugs]^7 failed to register item %s: %s'):format(item.name, tostring(err)))
    end
    if item.effect then
        exports.qbcore:createUseable(item.name, onUseDrugItem)
    end
end
