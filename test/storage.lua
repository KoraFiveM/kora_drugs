-- Run from kora_drugs: lua test/storage.lua
local ensured, ready, failure = {}, true, nil
Kora = { sql = {
    NULL = '\0kora_sql:null\0',
    ready = function()
        assert(type(RegisterLabTeleport) == 'function', 'helpers must exist before SQL can yield')
        return ready, 'database unavailable'
    end,
    ensureTables = function(specs)
        ensured[#ensured + 1] = specs
        if failure then return nil, failure end
        return { { table = 'kora_drugs', warnings = { 'collation differs' } } }
    end,
    query = function() error('storage must be created through ensureTables') end,
}, print = { warn = function() end } }
GetCurrentResourceName = function() return 'kora_drugs' end
AddEventHandler = function() end

dofile('server/schema.lua')
local tables = {}
for _, spec in ipairs(KoraDrugsSchema) do tables[spec.name] = spec end
assert(#KoraDrugsSchema == 3 and tables.kora_drugs and tables.kora_drugs_deliveries and tables.dealers, 'schema declares all three tables')
assert(tables.kora_drugs.indexes[1].unique and tables.kora_drugs.indexes[1].columns[1] == 'step', 'steps stay unique')
assert(#tables.kora_drugs.seed.rows == 29 and tables.kora_drugs.seed.rows[1].step == 'Weed:pick', 'example rows are declared as seed rows')
dofile('server/schema.lua')
assert(KoraDrugsSchema[1] == tables.kora_drugs, 'glob reload keeps the first declaration')

dofile('server/_functions.lua')
assert(#ensured == 1 and ensured[1] == KoraDrugsSchema)
assert(tables.kora_drugs.seed == nil, 'example data must remain opt-in')
dofile('server/_functions.lua')
assert(#ensured == 1, 'glob reload must not initialize twice')

kora_drugsServerFunctionsLoaded = nil
ready = false
local ok, err = pcall(dofile, 'server/_functions.lua')
assert(not ok and err:find('database unavailable', 1, true))
assert(#ensured == 1, 'must not ensure before database readiness')

kora_drugsServerFunctionsLoaded = nil
ready, failure = true, 'CREATE permission denied'
ok, err = pcall(dofile, 'server/_functions.lua')
assert(not ok and err:find('CREATE permission denied', 1, true))

kora_drugsServerFunctionsLoaded = nil
ready, failure = true, nil
KoraDrugsSchema = nil
dofile('server/schema.lua')
Config = { storage = { exampleData = true } }
ensured = {}
dofile('server/_functions.lua')
assert(#KoraDrugsSchema[1].seed.rows == 29, 'Config.storage.exampleData keeps the example rows')
local waited
Kora.sql.awaitTables = function(names) waited = names; return true end
assert(KoraDrugsAwaitStorage() == true and #waited == 3, 'scripts that read at load wait for all three tables')
print('kora_drugs storage: readiness, schema declaration, opt-in example data, duplicate load and failure checks passed')
