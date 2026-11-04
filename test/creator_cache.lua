-- Run from kora_drugs: lua test/creator_cache.lua
local now = 0
local updates = 0
Kora = { sql = {
    ready = function() return true end,
    NULL = '\0qbsql:null\0',
    ensureTables = function() return {} end,
    awaitTables = function() return true end,
    query = function() return {} end,
    update = function() updates = updates + 1; return true end,
} }
GetCurrentResourceName = function() return 'kora_drugs' end
LoadResourceFile = function(_, path)
    local file = assert(io.open(path)); local c = file:read('*a'); file:close(); return c
end
AddEventHandler = function() end
GetGameTimer = function() return now end
json = { encode = function() return "{}" end }
Config = { creator = { cacheSeconds = 30 } }

dofile('server/schema.lua')
dofile('server/_functions.lua')

local builds = 0
local function build() builds = builds + 1; return { n = builds } end

assert(CachedCreatorData(build).n == 1)
assert(CachedCreatorData(build).n == 1 and builds == 1, 'second open must reuse the cache')

now = 29999
assert(CachedCreatorData(build).n == 1, 'still fresh just before the ttl')
now = 30000
assert(CachedCreatorData(build).n == 2, 'expired cache is rebuilt')

dbSave('Weed:pick', {}, {})
assert(CachedCreatorData(build).n == 3, 'a save clears the cache')
dbSave('Weed:pick', {}, {})
assert(CachedCreatorData(build).n == 4, 'an update of an existing row clears it too')
dbDelete('Weed:pick')
assert(CachedCreatorData(build).n == 5, 'a delete clears the cache')
assert(CachedCreatorData(build).n == 5)

-- a write that lands while the data is being built must not leave stale data behind
InvalidateCreatorCache()
local stale = CachedCreatorData(function() InvalidateCreatorCache(); return { n = 'stale' } end)
assert(stale.n == 'stale')
InvalidateCreatorCache()
assert(CachedCreatorData(build).n == 6, 'result built across a write is not kept')

-- 0 disables the cache
Config.creator.cacheSeconds = 0
local before = builds
CachedCreatorData(build); CachedCreatorData(build)
assert(builds == before + 2, 'cacheSeconds = 0 builds every time')

-- failures are not cached
Config.creator.cacheSeconds = 30
local calls = 0
local function failing() calls = calls + 1; return false, 'nope' end
local ok, err = CachedCreatorData(failing)
assert(not ok and err == 'nope')
CachedCreatorData(failing)
assert(calls == 2, 'a failed build is retried')
print('creator_cache ok')
