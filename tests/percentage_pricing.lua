-- Run from qbdrugs: lua tests/percentage_pricing.lua [corner-source] [resource-root]
-- Production/callback sources are real; inventory, timers and exports are inert boundaries.
local resource = (arg[2] or '.'):gsub('/$', '') .. '/'
local cornerSource = arg[1] or resource .. 'server/Cornerselling.lua'
local checks = 0
local function eq(actual, expected, why)
    checks = checks + 1
    assert(actual == expected, why .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
end
local items, nextSlot = {}, 0
local inventory = {}
function inventory:GetItemByName(src, name)
    assert(src == 28, 'provider receives server source')
    for _, item in pairs(items) do if item.name == name then return item end end
end
function inventory:HasItem(src, name, amount)
    local item = self:GetItemByName(src, name)
    return item ~= nil and item.amount >= (amount or 1)
end
function inventory:AddItem(src, name, amount, slot, info)
    assert(src == 28, 'grant receives server source')
    nextSlot = nextSlot + 1
    items[nextSlot] = { name = name, amount = amount, slot = nextSlot, info = info or {}, label = name, image = name .. '.png' }
    return true
end
function inventory:RemoveItem(src, name, amount, slot)
    local item = slot and items[slot] or self:GetItemByName(src, name)
    if not item or item.name ~= name or item.amount < amount then return false end
    item.amount = item.amount - amount
    if item.amount == 0 then items[item.slot] = nil end
    return true
end
local net, callbacks, useables, timers = {}, {}, {}, {}
exports = {
    ['qb-inventory'] = inventory,
    qbcore = {
        getItemByName = function(_, src, name) return inventory:GetItemByName(src, name) end,
        createUseable = function(_, name, fn) useables[name] = fn end,
    },
}
QB = {
    config = { adopt = function(value) return value end },
    callback = { register = function(name, fn) callbacks[name] = fn end, trigger = function() return true end },
    distance = { player = function() return true end },
    notify = { send = function() end },
}
vector3 = function(x, y, z) return { x = x, y = y, z = z } end
vector4 = function(x, y, z, w) return { x = x, y = y, z = z, w = w } end
vec3, vec4 = vector3, vector4
RegisterNetEvent = function(name, fn) net[name] = fn end
CreateThread = function(fn) timers[#timers + 1] = fn end
Wait = function() end
SetTimeout = function() error('generalized production throttle is outside this check') end
source = 28
for _, path in ipairs({ 'shared/config.lua', 'server/_functions.lua', 'server/Weed.lua' }) do dofile(resource .. path) end
dofile(cornerSource)
local quote = assert(callbacks['qbdrugs:getSellableItem'])
local function clear() items, nextSlot = {}, 0 end
local function grant(name, amount, info) assert(inventory:AddItem(28, name, amount, nil, info)) end
local function step(name)
    eq(assert(net[name])(), nil, 'existing production event returns nil')
    local pending = timers; timers = {}
    for _, fn in ipairs(pending) do fn() end
end
local function percentages(item, thc, cbd)
    eq(item.info.thc, thc, 'THC presentation preserved')
    eq(item.info.cbd, cbd, 'CBD presentation preserved')
end
local originalRandom, draws, drawIndex = math.random
math.random = function() drawIndex = drawIndex + 1; return assert(draws[drawIndex]) end
local seen = {}
for classification = 1, 2 do
    for key = 1, 3 do
        clear(); grant('wet_cola', 1); grant('gram_bag', 10)
        draws, drawIndex = { classification, key, 10, 20, 5 }, 0
        step('qb-drugs:server:dryCola')
        percentages(assert(inventory:GetItemByName(28, 'dried_cola')), '20%', '5%')
        step('qb-drugs:server:breakNugs')
        local raw
        for _, item in pairs(items) do if item.name:find('_weed$') then raw = item end end
        assert(raw); seen[raw.name] = true
        percentages(raw, '20%', '5%')
        step('qb-drugs:server:bagWeed')
        local bagName = raw.name:gsub('_weed$', '_1g')
        local bag = assert(inventory:GetItemByName(28, bagName))
        local offer = assert(quote(28))
        eq(offer.item, bagName, 'produced bag offered')
        eq(offer.singlePrice, 13, 'produced percentages use existing price formula')
        eq(offer.amount, 10, 'produced bag amount preserved')
        eq(offer.total, 130, 'produced bag total preserved')
        eq(offer.itemLabel, bagName, 'existing label field preserved')
        eq(offer.img, 'nui://qb-inventory/html/images/' .. bagName .. '.png', 'existing image field preserved')
        percentages(bag, '20%', '5%')
        clear(); grant(raw.name, 1, { thc = '20%', cbd = '5%' }); grant('rolling_paper', 1)
        eq(useables.rolling_paper(28, inventory:GetItemByName(28, 'rolling_paper')), nil, 'existing usable return preserved')
        local jointName = raw.name:gsub('_weed$', '_joint')
        eq(quote(28).singlePrice, 18, 'rolled percentages use existing joint price')
        percentages(assert(inventory:GetItemByName(28, jointName)), '20%', '5%')
    end
end
math.random = originalRandom
local strains = 0; for _ in pairs(seen) do strains = strains + 1 end
eq(strains, 6, 'all shipped strains preserved through production')
for _, c in ipairs({
    { 10, 5, 12 }, { 20, 12.5, 15 }, { 30, 20, 18 },
    { '10', '5', 12 }, { '20', '12.5', 15 }, { '30', '20', 18 },
    { '10%', '5%', 12 }, { '20%', '12.5%', 15 }, { '30%', '20%', 18 },
    { '20', '12.5%', 15 }, { '20%', 12.5, 15 },
    { -5, -1, 12 }, { 100, 100, 18 }, { '-5%', '-1%', 12 }, { '100%', '100%', 18 },
    { nil, '5%', 15 }, { '20%', nil, 15 }, { false, '5%', 15 },
    { '20%%', '5%', 15 }, { '2%0', '5%', 15 }, { {}, '5%', 15 },
}) do
    clear(); local info = { thc = c[1], cbd = c[2] }; grant('skunk_1g', 20, info)
    local offer = assert(quote(28))
    eq(offer.singlePrice, c[3], 'number/legacy percentage parsing and invalid base-price fallback')
    eq(offer.amount, 15, 'existing sale cap retained')
    eq(offer.total, c[3] * 15, 'existing total retained')
    percentages(assert(inventory:GetItemByName(28, 'skunk_1g')), c[1], c[2])
end
clear(); grant('skunk_1g', 1); CornerSelling.weedPercentAdjustable = false
eq(quote(28).singlePrice, 15, 'disabled percentage pricing uses base price')
CornerSelling.weedPercentAdjustable = true
clear(); grant('cocaine_baggy', 1)
eq(quote(28).singlePrice, 20, 'nonweed base price unchanged')
clear(); eq(quote(28), false, 'empty inventory still returns false')
print(('%d production/callback percentage-pricing assertions passed'):format(checks))
