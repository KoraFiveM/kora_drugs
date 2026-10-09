-- Helpers shared by every server script. fxmanifest loads this first, and the server/**.lua glob
-- matches it a second time, so the guard below keeps it from registering things twice.
if qbdrugsServerFunctionsLoaded then return end
qbdrugsServerFunctionsLoaded = true

-- ----------------------------------------------------------------------------
-- Validation. Anything that comes from a player or from the creator goes through these.
-- ----------------------------------------------------------------------------

function decodeJson(raw, fallback)
    if type(raw) ~= 'string' or raw == '' then return fallback end
    local ok, decoded = pcall(json.decode, raw)
    return ok and type(decoded) == 'table' and decoded or fallback
end

-- A trimmed string of at most `max` characters, or nil when it is empty or not a string.
function trim(value, max)
    if type(value) ~= 'string' or not value:match('%S') then return nil end
    return value:match('^%s*(.-)%s*$'):sub(1, max)
end

-- A number inside [min, max] (rounded down when `whole`), or nil. Rejects NaN.
function inRange(value, min, max, whole)
    local n = tonumber(value)
    if not n or n ~= n or n < min or n > max then return nil end
    return whole and math.floor(n) or n
end

-- trim() plus a character check. nil = empty, false = it has characters the pattern does not allow.
function cleanName(value, max, pattern)
    local text = trim(value, max)
    if not text then return nil end
    return text:match(pattern) and text or false
end

-- { x, y, z } with every part a real number inside +-limit, or nil.
function cleanVec(value, limit)
    if type(value) ~= 'table' then return nil end
    limit = limit or 10000.0
    local x, y, z = inRange(value.x, -limit, limit), inRange(value.y, -limit, limit), inRange(value.z, -limit, limit)
    if x and y and z then return { x = x, y = y, z = z } end
end

function copyTable(value)
    if type(value) ~= 'table' then return value end
    local copy = {}
    for key, inner in pairs(value) do copy[key] = copyTable(inner) end
    return copy
end

-- ----------------------------------------------------------------------------
-- Players
-- ----------------------------------------------------------------------------

function isAdmin(src)
    src = tonumber(src)
    return src ~= nil and src > 0 and IsPlayerAceAllowed(src, Config.creatorAce or 'command')
end

-- coords is anything with x, y and z (a saved location or a vector). False when it has none.
function isNear(src, coords, radius)
    if not coords then return false end
    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    if not (x and y and z) then return false end
    return QB.distance.player(src, vec3(x, y, z), radius or 5.0)
end

-- One timer per player and key, so a player cannot repeat an action faster than it can be done.
local cooldowns = {}

function onCooldown(src, key)
    return cooldowns[key] ~= nil and cooldowns[key][src] == true
end

function startCooldown(src, key, duration)
    cooldowns[key] = cooldowns[key] or {}
    cooldowns[key][src] = true
    SetTimeout(duration, function() cooldowns[key][src] = nil end)
end

AddEventHandler('playerDropped', function()
    local src = source
    for _, timers in pairs(cooldowns) do timers[src] = nil end
end)

-- ----------------------------------------------------------------------------
-- The `qbdrugs` table: one row per step ('Cocaine:lab', 'Weed:pick', ...)
-- ----------------------------------------------------------------------------

function dbRow(step)
    local rows = QB.sql.query('SELECT * FROM `qbdrugs` WHERE `step` = ? LIMIT 1', { step })
    return rows and rows[1] or nil
end

-- Inserts the row, or updates it when it already exists. Returns ok, err.
function dbSave(step, data, locations)
    if dbRow(step) then
        return QB.sql.update(
            'UPDATE `qbdrugs` SET `data` = ?, `locations` = ? WHERE `step` = ?',
            { json.encode(data), json.encode(locations), step }
        )
    end
    return QB.sql.update(
        'INSERT INTO `qbdrugs` (`step`, `data`, `locations`) VALUES (?, ?, ?)',
        { step, json.encode(data), json.encode(locations) }
    )
end

function dbDelete(step)
    return QB.sql.update('DELETE FROM `qbdrugs` WHERE `step` = ?', { step })
end

function hasItems(src, itemList)
    if #itemList == 0 then return true end
    local hasAll = true
    for _, item in pairs(itemList) do
        if not exports['qb-inventory']:HasItem(src, item.item, item.amount) then
            hasAll = false
            QB.notify.send(src, { title = 'qb-drugs', message = QB.lang('Functions.no_items', item.amount, item.item), type = 'error' })
        end
    end
    return hasAll
end

function craft(src, recipe, meta)
    local give = recipe.give or {}
    if not hasItems(src, give) then return end
    for _, item in pairs(give) do
        if not item.keep and not exports['qb-inventory']:RemoveItem(src, item.item, item.amount) then
            return
        end
    end
    if not recipe.receive or not recipe.receive.item then return true end
    return exports['qb-inventory']:AddItem(src, recipe.receive.item, recipe.receive.amount, nil, meta)
end


function RegisterLabTeleport(name, drug, step)
    local inside = {} -- source -> { old = bucket before entering, enter = vec, exit = vec }

    local function lab()
        return Drugs[drug] and Drugs[drug][step]
    end

    QB.callback.register(('qbdrugs:%s:Tele'):format(name), function(source, key)
        local location = lab() and type(key) == 'number' and lab().locations[key]
        if not (location and isNear(source, location.enter)) then return false end

        local old = inside[source] and inside[source].old or GetPlayerRoutingBucket(source)
        inside[source] = { old = old, enter = location.enter, exit = location.exit }
        SetPlayerRoutingBucket(source, old + key)
        return true
    end)

    QB.callback.register(('qbdrugs:%s:TeleOut'):format(name), function(source)
        local first = lab() and lab().locations[1]
        local session = inside[source]

        -- Without a session (the resource restarted while they were inside) the first lab is used.
        local exit = session and session.exit or first and first.exit
        if not isNear(source, exit) then return false end

        if session then SetPlayerRoutingBucket(source, session.old) end
        inside[source] = nil
        return session and session.enter or first and first.enter or false
    end)

    AddEventHandler('playerDropped', function()
        inside[source] = nil
    end)
end
