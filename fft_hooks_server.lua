-- Optional FFT development hooks (server). Listed last in fxmanifest.lua and
-- inert unless `setr fft_kora_hooks true`. No other file references FFT.
--
-- Read only. Corner-selling prices are deliberately kept out of GlobalState
-- and out of the reload event (server/events.lua serverOnly), so the runner
-- has no other way to learn which items the corner seller would accept. The
-- scenarios need that to prove the tester carries none of them before running
-- /cornerSell, and to know the settings row exists at all.
if GetConvar('fft_kora_hooks', 'false') ~= 'true' then return end

local RUNNER = 'fft'
local VERSION = 1
local MAX_ITEMS = 100

local function authorised(src)
    if GetResourceState(RUNNER) ~= 'started' then return false end
    if type(src) ~= 'number' or src <= 0 or src ~= math.floor(src) then return false end
    if not GetPlayerName(src) then return false end
    return type(Player(src).state.fftSession) == 'string'
end

local actions = {}

-- Snapshot of the settings server/Cornerselling.lua settings() reads:
-- Drugs.CornerSelling.settings.data = { pricing = { item = price }, maxSell, ... }.
-- Changes nothing and reveals nothing about any player.
function actions.cornerSelling()
    local entry = type(Drugs) == 'table' and type(Drugs.CornerSelling) == 'table' and Drugs.CornerSelling.settings
    local data = type(entry) == 'table' and entry.data
    local pricing = type(data) == 'table' and data.pricing
    if type(pricing) ~= 'table' then return true, { configured = false, count = 0, items = {} } end

    local names = {}
    for name in pairs(pricing) do
        if type(name) == 'string' then names[#names + 1] = name end
    end
    table.sort(names)
    local items = {}
    for index = 1, math.min(#names, MAX_ITEMS) do
        items[index] = { name = names[index], price = tonumber(pricing[names[index]]) }
    end
    return true, { configured = true, count = #names, maxSell = tonumber(data.maxSell), items = items }
end

exports('fftVersion', function() return VERSION end)
exports('fftAction', function(action, src, ...)
    if GetInvokingResource() ~= RUNNER or not authorised(src) then
        return false, 'FFT hooks are disabled or session is not authorised', 'blocked'
    end
    if type(action) ~= 'string' or #action > 64 then return false, 'Unsupported FFT action', 'invalid' end
    local handler = actions[action]
    if not handler then return false, 'Unsupported FFT action: ' .. action, 'invalid' end
    return handler(src, ...)
end)
