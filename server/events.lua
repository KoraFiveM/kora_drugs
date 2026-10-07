-- server/events.lua
-- One pull of the `qbdrugs` table into a single global:
--
--   Drugs[Type][step] = { data = {...}, locations = {...} }
--
-- A row's step is '<Type>:<step>', so 'Cocaine:lab' becomes Drugs.Cocaine.lab.
-- Plant rows ('<Type>:pick') are skipped: plantSpawns.lua keeps handling those.
--
-- The whole table is published as GlobalState.Drugs for players joining. When the
-- creator saves one row, only that row is re-read and only that entry is sent, as
-- 'qbdrugs:client:drugsReload' (drug, step, entry); nothing is sent if it didn't change.
--
-- Row layout for 'Cocaine:lab':
--   data      { enterTarget = 'Enter Lab', exitTarget = 'Exit Lab' }
--   locations [ { enter = {x,y,z}, exit = {x,y,z}, gang = 'name' | absent }, ... ]
--
-- Row layout for 'Cocaine:powder':
--   data      { progress = { time, label, disable = { move = true, ... } },
--               anim = { dict, clip, flag }, targetLabel, targetIcon }
--   locations [ { coords = {x,y,z}, object = 'model' | absent, gang = 'name' | absent }, ... ]
--   ('Crack:cook', 'Crack:bagging', 'Heroin:drying', 'Heroin:vials' and 'Heroin:syringe' use this same layout)
--   'Weed:drying', 'Weed:breakNugs' and 'Weed:bagWeed' use it too; 'Weed:lab' uses the 'Cocaine:lab' layout.
--
-- 'Meth:tele' uses the 'Cocaine:lab' layout. 'Meth:pour', 'Meth:heat', 'Meth:smash' and
-- 'Meth:bag' only hold target text (locations = []): the positions stay in DrugConfig.Meth.Steps.
--   Meth:pour data { targetLabel, targetIcon, trayLabel, trayIcon }   the others { targetLabel, targetIcon }
--
-- Row layout for 'Cocaine:cutting':
--   data      { targetLabel, targetIcon }
--   locations { coords = {x,y,z}, offset = {x,y,z}, rotation = {x,y,z} }   (one object, not an array)

-- Row layout for 'CornerSelling:settings' (Drugs.CornerSelling.settings):
--   data      { maxSell, ripOff, minPolice, weedPercentAdjustable, weedPercentFlow, pricing = { [item] = cash } }
--   locations []
--
-- Steps that always exist in Drugs, even before their row does, so callers never
-- have to nil-check Drugs.Cocaine.lab.
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