-- Run from qbdrugs: lua test/storage.lua
local queries, ready, schema = {}, true, true
QB = { sql = {
    ready = function()
        assert(type(RegisterLabTeleport) == 'function', 'helpers must exist before SQL can yield')
        return ready, 'database unavailable'
    end,
    query = function(sql) queries[#queries + 1] = sql; return {} end,
} }
GetCurrentResourceName = function() return 'qbdrugs' end
LoadResourceFile = function(_, path)
    if not schema then return nil end
    local file = assert(io.open(path))
    local contents = file:read('*a')
    file:close()
    return contents
end
AddEventHandler = function() end

dofile('server/_functions.lua')
assert(#queries == 1)
assert(queries[1]:match('^CREATE TABLE IF NOT EXISTS `qbdrugs`'))
assert(not queries[1]:find('INSERT INTO', 1, true), 'example data must remain opt-in')
dofile('server/_functions.lua')
assert(#queries == 1, 'glob reload must not initialize twice')

qbdrugsServerFunctionsLoaded = nil
ready = false
local ok, err = pcall(dofile, 'server/_functions.lua')
assert(not ok and err:find('database unavailable', 1, true))
assert(#queries == 1, 'must not query before database readiness')

qbdrugsServerFunctionsLoaded = nil
ready, schema = true, false
ok, err = pcall(dofile, 'server/_functions.lua')
assert(not ok and err:find('missing sql/qbdrugs.sql', 1, true))
assert(#queries == 1)
qbdrugsServerFunctionsLoaded = nil
schema = true
QB.sql.query = function() return nil, 'CREATE permission denied' end
ok, err = pcall(dofile, 'server/_functions.lua')
assert(not ok and err:find('CREATE permission denied', 1, true))
print('qbdrugs storage: readiness, schema-only creation, duplicate load and failure checks passed')
