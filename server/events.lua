EventSteps = {
    'Cocaine:lab',
    'Cocaine:powder',
    'Cocaine:cutting',
    'Cocaine:bagging',
    'Crack:cook',
    'Crack:bagging',
    'Heroin:drying',
    'Heroin:vials',
    'Heroin:syringe',
    'Meth:tele',
    'Meth:pour',
    'Meth:heat',
    'Meth:smash',
    'Meth:bag',
    'Weed:lab',
    'Weed:drying',
    'Weed:breakNugs',
    'Weed:bagWeed',
    'CornerSelling:settings',
    'Recipes:settings',
}

Drugs = {}

-- Settings only the server reads (prices, custom drug names). They are kept out of GlobalState and
-- out of the reload event, so clients never receive them.
local serverOnly = { CornerSelling = true, Custom = true }

local function publicDrugs()
    local visible = {}
    for drug, steps in pairs(Drugs) do
        if not serverOnly[drug] then visible[drug] = steps end
    end
    return visible
end

local function splitStep(name)
    return name:match('^(%w+):([%w_]+)$')
end

local function isVec(v)
    return type(v) == 'table' and tonumber(v.x) and tonumber(v.y) and tonumber(v.z)
end

-- Entrances are saved as { enter = vec or { vec, ... }, exit = vec, gang }; this returns one entry per door.
function NormalizeEntrances(list)
    local result = {}
    for _, entry in ipairs(type(list) == 'table' and list or {}) do
        if type(entry) == 'table' and isVec(entry.exit) then
            local doors = isVec(entry.enter) and { entry.enter } or (type(entry.enter) == 'table' and entry.enter or {})
            for _, door in ipairs(doors) do
                if isVec(door) then
                    result[#result + 1] = { enter = door, exit = entry.exit, gang = entry.gang }
                end
            end
        end
    end
    return result
end

local normalizers = { lab = NormalizeEntrances, tele = NormalizeEntrances }

local function emptyEntry()
    return { data = {}, locations = {} }
end

local function entryFromRow(step, row)
    local locations = decodeJson(row.locations, {})
    if normalizers[step] then locations = normalizers[step](locations) end
    return { data = decodeJson(row.data, {}), locations = locations }
end

-- What each step looked like the last time it was read, so an unchanged row is not sent to everyone again.
local seen = {}

local function signature(row)
    return row and (tostring(row.data) .. '|' .. tostring(row.locations)) or ''
end

local function build()
    assert(QBDrugsAwaitStorage())
    local all = {}
    local function put(drug, step, entry)
        all[drug] = all[drug] or {}
        all[drug][step] = entry
    end

    for _, name in ipairs(EventSteps) do
        local drug, step = splitStep(name)
        put(drug, step, emptyEntry())
        seen[name] = ''
    end

    for _, row in ipairs(Kora.sql.query('SELECT * FROM `qbdrugs`') or {}) do
        local drug, step = splitStep(row.step)
        if drug and step ~= 'pick' then
            put(drug, step, entryFromRow(step, row))
            seen[row.step] = signature(row)
        end
    end
    return all
end

local function refreshStep(name)
    local drug, step = splitStep(name)
    if not drug or step == 'pick' then return false end

    local row = dbRow(name)
    if seen[name] == signature(row) then return false end
    seen[name] = signature(row)

    Drugs[drug] = Drugs[drug] or {}
    Drugs[drug][step] = row and entryFromRow(step, row) or emptyEntry()

    if not serverOnly[drug] then
        GlobalState.Drugs = publicDrugs() -- keeps players who join later up to date
        TriggerClientEvent('qbdrugs:client:drugsReload', -1, drug, step, Drugs[drug][step])
    end
    return true
end

-- Reloads one step from the database, or every step when no name is given.
function ReloadEvents(name)
    if name then return refreshStep(name) end

    local names = {}
    for known in pairs(seen) do names[known] = true end
    for _, row in ipairs(Kora.sql.query('SELECT `step` FROM `qbdrugs`') or {}) do
        names[row.step] = true
    end
    for each in pairs(names) do refreshStep(each) end
end

exports('ReloadEvents', ReloadEvents)

Drugs = build()
GlobalState.Drugs = publicDrugs()
