-- Helpers shared by every server script. fxmanifest loads this first, and the server/**.lua glob
-- matches it a second time, so the guard below keeps it from registering things twice.
if qbdrugsServerFunctionsLoaded then return end
qbdrugsServerFunctionsLoaded = true

-- Validation. Anything that comes from a player or from the creator goes through these.

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

function isAdmin(src)
    src = tonumber(src)
    return src ~= nil and src > 0 and IsPlayerAceAllowed(src, 'command')
end

function isNear(src, coords, radius)
    if not coords then return false end
    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    if not (x and y and z) then return false end
    return Kora.distance.player(src, vec3(x, y, z), radius or 5.0)
end

local cooldowns = {}
local blocked = {} -- key -> src -> how many times the player was stopped by this cooldown

function onCooldown(src, key)
    local active = cooldowns[key] ~= nil and cooldowns[key][src] == true
    if active then
        blocked[key] = blocked[key] or {}
        blocked[key][src] = (blocked[key][src] or 0) + 1
        Kora.print.warn(('[qbdrugs] player %s hit the "%s" cooldown %d time(s)'):format(src, key, blocked[key][src]))
        if blocked[key][src] == 5 then
            Kora.print.error(('[qbdrugs] player %s hit the "%s" cooldown 5 times, consider taking action'):format(src, key))
            DropPlayer(src, 'You have hit the "' .. key .. '" cooldown 5 times.')
        end
    end
    return active
end

function startCooldown(src, key, duration)
    cooldowns[key] = cooldowns[key] or {}
    cooldowns[key][src] = true
    SetTimeout(duration, function() cooldowns[key][src] = nil end)
end

AddEventHandler('playerDropped', function()
    local src = source
    for _, timers in pairs(cooldowns) do timers[src] = nil end
    for _, counts in pairs(blocked) do counts[src] = nil end
end)

-- The `kora_drugs` table: one row per step ('Cocaine:lab', 'Weed:pick', ...)

-- Creator open data is cached for Config.creator.cacheSeconds. Every write to the table clears it.
local creatorCache, creatorGeneration = nil, 0

function InvalidateCreatorCache()
    creatorCache, creatorGeneration = nil, creatorGeneration + 1
end

-- Returns build()'s result, reusing it while fresh. A write that lands while build() is running
-- bumps the generation, so that result is returned but not kept.
function CachedCreatorData(build)
    local seconds = Config and Config.creator and tonumber(Config.creator.cacheSeconds) or 0
    if seconds <= 0 then
        creatorCache = nil
        return build()
    end

    local now = GetGameTimer()
    if creatorCache and now - creatorCache.at < seconds * 1000 then return creatorCache.value end

    local generation = creatorGeneration
    local value, err = build()
    if value and generation == creatorGeneration then creatorCache = { at = now, value = value } end
    return value, err
end

function dbRow(step)
    local rows = Kora.sql.query('SELECT * FROM `qbdrugs` WHERE `step` = ? LIMIT 1', { step })
    return rows and rows[1] or nil
end

-- Inserts the row, or updates it when it already exists. Returns ok, err.
function dbSave(step, data, locations)
    InvalidateCreatorCache()
    local function done(...) InvalidateCreatorCache() return ... end
    if dbRow(step) then
        return done(Kora.sql.update(
            'UPDATE `qbdrugs` SET `data` = ?, `locations` = ? WHERE `step` = ?',
            { json.encode(data), json.encode(locations), step }
        ))
    end
    return done(Kora.sql.update(
        'INSERT INTO `qbdrugs` (`step`, `data`, `locations`) VALUES (?, ?, ?)',
        { step, json.encode(data), json.encode(locations) }
    ))
end

function dbDelete(step)
    InvalidateCreatorCache()
    local ok, err = Kora.sql.update('DELETE FROM `qbdrugs` WHERE `step` = ?', { step })
    InvalidateCreatorCache()
    return ok, err
end

function hasItems(src, itemList)
    if #itemList == 0 then return true end
    local hasAll = true
    for _, item in pairs(itemList) do
        if not exports['qb-inventory']:HasItem(src, item.item, item.amount) then
            hasAll = false
            Kora.notify.send(src, { title = 'qb-drugs', message = Kora.lang('Functions.no_items', item.amount, item.item), type = 'error' })
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

    Kora.callback.register(('qbdrugs:%s:Tele'):format(name), function(source, key)
        local location = lab() and type(key) == 'number' and lab().locations[key]
        if not (location and isNear(source, location.enter)) then return false end

        local old = inside[source] and inside[source].old or GetPlayerRoutingBucket(source)
        inside[source] = { old = old, enter = location.enter, exit = location.exit }
        SetPlayerRoutingBucket(source, old + key)
        return true
    end)

    Kora.callback.register(('qbdrugs:%s:TeleOut'):format(name), function(source)
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

-- Create storage before the other server scripts read it; keep the example rows opt-in.
local sqlReady, sqlError = Kora.sql.ready()
assert(sqlReady, sqlError)
local installSql = assert(LoadResourceFile(GetCurrentResourceName(), 'sql/qbdrugs.sql'), 'qbdrugs: missing sql/qbdrugs.sql')
local schemaSql = assert(installSql:match('^(CREATE TABLE.-;)'), 'qbdrugs: missing table definition')
local created, createError = Kora.sql.query(schemaSql)
assert(created ~= nil, createError or 'qbdrugs: could not create storage')
