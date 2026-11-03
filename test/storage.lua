-- Run from qbdrugs: lua test/storage.lua
local ensured, ready, failure = {}, true, nil
Kora = { sql = {
    NULL = '\0qbsql:null\0',
    ready = function()
        assert(type(RegisterLabTeleport) == 'function', 'helpers must exist before SQL can yield')
        return ready, 'database unavailable'
    end,
    ensureTables = function(specs)
        ensured[#ensured + 1] = specs
        if failure then return nil, failure end
        return { { table = 'qbdrugs', warnings = { 'collation differs' } } }
    end,
    query = function() error('storage must be created through ensureTables') end,
}, print = { warn = function() end } }
GetCurrentResourceName = function() return 'kora_drugs' end
AddEventHandler = function() end

dofile('server/schema.lua')
local tables = {}
for _, spec in ipairs(QBDrugsSchema) do tables[spec.name] = spec end
assert(#QBDrugsSchema == 3 and tables.qbdrugs and tables.qbdrugs_deliveries and tables.dealers, 'schema declares all three tables')
assert(tables.qbdrugs.indexes[1].unique and tables.qbdrugs.indexes[1].columns[1] == 'step', 'steps stay unique')
assert(#tables.qbdrugs.seed.rows == 29 and tables.qbdrugs.seed.rows[1].step == 'Weed:pick', 'example rows are declared as seed rows')
dofile('server/schema.lua')
assert(QBDrugsSchema[1] == tables.qbdrugs, 'glob reload keeps the first declaration')

dofile('server/_functions.lua')
assert(#ensured == 1 and ensured[1] == QBDrugsSchema)
assert(tables.qbdrugs.seed == nil, 'example data must remain opt-in')
dofile('server/_functions.lua')
assert(#ensured == 1, 'glob reload must not initialize twice')

qbdrugsServerFunctionsLoaded = nil
ready = false
local ok, err = pcall(dofile, 'server/_functions.lua')
assert(not ok and err:find('database unavailable', 1, true))
assert(#ensured == 1, 'must not ensure before database readiness')

qbdrugsServerFunctionsLoaded = nil
ready, failure = true, 'CREATE permission denied'
ok, err = pcall(dofile, 'server/_functions.lua')
assert(not ok and err:find('CREATE permission denied', 1, true))

qbdrugsServerFunctionsLoaded = nil
ready, failure = true, nil
QBDrugsSchema = nil
dofile('server/schema.lua')
Config = { storage = { exampleData = true } }
ensured = {}
dofile('server/_functions.lua')
assert(#QBDrugsSchema[1].seed.rows == 29, 'Config.storage.exampleData keeps the example rows')
print('qbdrugs storage: readiness, schema declaration, opt-in example data, duplicate load and failure checks passed')
