-- FEEDBACK ONLY. Every drug item's screen fx/ptfx/anim/movement is already
-- played back automatically the instant Core.consumables applies it, purely
-- from the `effect` table shared/items.lua registered -- see that file's
-- header, and qblib/modules/status/client.lua's QB.status.apply, which is
-- what actually renders it. This file adds a purely cosmetic toast on TOP of
-- that -- it never calls a screen-fx/ptfx/anim/movement native itself, and
-- must never grow to do so; if a drug needs different use-feedback, that's
-- data on the item (a new `effect.fx`/`effect.anim` entry), not a branch here.

QB.status.onChange(function(name, applied)
    if not applied then return end
    local item = Drugs.itemsByName[name]
    if not item then return end

    QB.notify.send({ title = item.label, message = 'You feel the effects kicking in.', type = 'info' })
end)
