-- Optional FFT development hooks (client). Listed last in fxmanifest.lua and
-- inert unless `setr fft_kora_hooks true`. No other file references FFT.
--
-- Corner-selling prices live only in the `CornerSelling:settings` row and a
-- server without the example data has none, so /cornerSell cannot be exercised
-- there. This hook lets a scenario price one item and take the price away
-- again through the same admin callbacks the /drugCreator cornerselling page
-- sends (client/creator.lua loadCorner / persistCorner): the server's admin
-- check, cleanCornerData validation and reload all stay in force, and a tester
-- who is not an admin is refused by the server exactly like the creator is.
-- It only ever changes the one price it is asked about; every other setting
-- and price is sent back as it was read.
if GetConvar('fft_kora_hooks', 'false') ~= 'true' then return end

local RUNNER = 'fft'
local VERSION = 1
local CORNER_STEP = 'CornerSelling:settings' -- client/creator.lua CORNER_STEP
local MAX_PRICE = 1000000                    -- server/creator.lua limits.cornerPrice

local function session()
    if GetResourceState(RUNNER) ~= 'started' then return nil end
    local id = LocalPlayer.state.fftSession
    return type(id) == 'string' and id or nil
end

local function itemName(value)
    return type(value) == 'string' and #value <= 64 and value:match('^[%w_%-%.]+$') ~= nil
end

-- What the cornerselling page loads, copied the way cornerCopy() does.
local function load()
    local result, err = Kora.callback.trigger('kora_drugs:creator:corner:get')
    if type(result) ~= 'table' or type(result.data) ~= 'table' then
        return nil, tostring(err or 'Could not load the cornerselling settings.')
    end
    local copy = {}
    for key, value in pairs(result.data) do copy[key] = value end
    copy.pricing = {}
    for name, price in pairs(type(result.data.pricing) == 'table' and result.data.pricing or {}) do
        copy.pricing[name] = price
    end
    return copy
end

-- persistCorner(): the whole settings table goes back, with one price changed.
local function setPrice(item, price)
    local data, err = load()
    if not data then return false, err, 'rejected' end
    local previous = tonumber(data.pricing[item])
    if previous == price then return true, { previous = previous or false, changed = false } end

    data.pricing[item] = price
    local saved, saveErr = Kora.callback.trigger('kora_drugs:creator:event:save', CORNER_STEP, { data = data })
    if type(saved) ~= 'table' or type(saved.data) ~= 'table' or type(saved.data.pricing) ~= 'table' then
        return false, tostring(saveErr or 'Failed to save.'), 'rejected'
    end
    if tonumber(saved.data.pricing[item]) ~= price then
        return false, 'The server saved a different price than the one sent', 'rejected'
    end
    return true, { previous = previous or false, changed = true }
end

local actions = {}

-- Read only: the price one item currently has, or false when it has none.
function actions.cornerPrice(item)
    if not itemName(item) then return false, 'Invalid item name', 'invalid' end
    local data, err = load()
    if not data then return false, err, 'rejected' end
    return true, { price = tonumber(data.pricing[item]) or false }
end

-- The creator's "add item" / "set price" for one item. Returns the price the
-- item had before (false when it was not priced) so the caller can restore it.
function actions.cornerPriceSet(item, price)
    if not itemName(item) then return false, 'Invalid item name', 'invalid' end
    if type(price) ~= 'number' or price ~= math.floor(price) or price < 1 or price > MAX_PRICE then
        return false, 'Invalid price', 'invalid'
    end
    return setPrice(item, price)
end

-- The creator's "remove item" for one item.
function actions.cornerPriceRemove(item)
    if not itemName(item) then return false, 'Invalid item name', 'invalid' end
    return setPrice(item, nil)
end

exports('fftVersion', function() return VERSION end)
exports('fftAction', function(action, ...)
    if GetInvokingResource() ~= RUNNER or not session() then
        return false, 'FFT hooks are disabled or session is not authorised', 'blocked'
    end
    if type(action) ~= 'string' or #action > 64 then return false, 'Unsupported FFT action', 'invalid' end
    local handler = actions[action]
    if not handler then return false, 'Unsupported FFT action: ' .. action, 'invalid' end
    return handler(...)
end)
