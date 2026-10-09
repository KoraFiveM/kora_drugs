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

local function decode(raw, fallback)
    if type(raw) ~= 'string' or raw == '' then return fallback end
    local ok, decoded = pcall(json.decode, raw)
    return (ok and type(decoded) == 'table' and decoded) or fallback
end

function NormalizeEntrances(list)
    local function isVec(v)
        return type(v) == 'table' and tonumber(v.x) and tonumber(v.y) and tonumber(v.z)
    end
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

local normalizers = {
    lab = NormalizeEntrances,
    tele = NormalizeEntrances,
}

local function entryFromRow(step, row)
    local locations = decode(row.locations, {})
    if normalizers[step] then locations = normalizers[step](locations) end
    return { data = decode(row.data, {}), locations = locations }
end

local seen = {}

local function signature(row)
    return row and (tostring(row.data) .. '|' .. tostring(row.locations)) or ''
end

local function build()
    local all = {}

    for _, name in ipairs(EventSteps) do
        local drug, step = name:match('^(%w+):([%w_]+)$')
        all[drug] = all[drug] or {}
        all[drug][step] = { data = {}, locations = {} }
        seen[name] = ''
    end

    for _, row in ipairs(QB.sql.query('SELECT * FROM `qbdrugs`') or {}) do
        local drug, step = row.step:match('^(%w+):([%w_]+)$')
        if drug and step ~= 'pick' then
            all[drug] = all[drug] or {}
            all[drug][step] = entryFromRow(step, row)
            seen[row.step] = signature(row)
        end
    end

    return all
end

local function refreshStep(name)
    local drug, step = name:match('^(%w+):([%w_]+)$')
    if not drug or step == 'pick' then return false end

    local rows = QB.sql.query('SELECT * FROM `qbdrugs` WHERE `step` = ? LIMIT 1', { name })
    local row = rows and rows[1]
    if seen[name] == signature(row) then return false end
    seen[name] = signature(row)

    Drugs[drug] = Drugs[drug] or {}
    Drugs[drug][step] = row and entryFromRow(step, row) or { data = {}, locations = {} }
    GlobalState.Drugs = Drugs -- keeps players who join later up to date
    TriggerClientEvent('qbdrugs:client:drugsReload', -1, drug, step, Drugs[drug][step])
    return true
end

local function reload(name)
    if name then return refreshStep(name) end

    local names = {}
    for known in pairs(seen) do names[known] = true end
    for _, row in ipairs(QB.sql.query('SELECT `step` FROM `qbdrugs`') or {}) do
        names[row.step] = true
    end
    for each in pairs(names) do refreshStep(each) end
end

exports('ReloadEvents', reload)

Drugs = build()
GlobalState.Drugs = Drugs