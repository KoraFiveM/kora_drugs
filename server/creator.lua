-- The drug creator: everything an admin can change from the in-game UI.
-- Sections: limits, plants, event data rules, event types, saving, then one block per creator page.

local limits = {
    spots = 200,
    eventLocations = 50,
    itemResults = 24,
    cornerItems = 500,
    cornerPrice = 1000000,
    recipeItems = 20,
    recipeAmount = 1000,
}

local patterns = {
    gang = '^[%w_%-]+$',
    name = '^[%w_%-%.]+$', -- items, props and objects
    anim = '^[%w_@%-%.]+$',
}

local gangMessage = 'Gang may only contain letters, numbers, _ and -.'
local objectMessage = 'Object may only contain letters, numbers, _, - and .'

local cornerStep = 'CornerSelling:settings'
local recipesStep = 'Recipes:settings'
local customStep = 'Custom:settings'

local disableAllowed = {}
for _, option in ipairs(ProgressDisableOptions) do disableAllowed[option.value] = true end

local function fail(message)
    return false, message
end

-- Every creator callback is admin only. This is the one place that is checked.
local function adminCallback(name, handler)
    Kora.callback.register(name, function(src, ...)
        if not isAdmin(src) then return fail('Admin permission required.') end
        return handler(src, ...)
    end)
end

local function allItems()
    local ok, items = pcall(function() return exports['qb-core']:GetShared('Items') end)
    if ok and type(items) == 'table' then return items end
    items = exports.kora_core:getShared('items')
    return type(items) == 'table' and items or {}
end

local function itemExists(item)
    return type(allItems()[item]) == 'table'
end

local function itemEntry(shared, name)
    local info = shared[name]
    if type(info) ~= 'table' then return nil end
    local image = type(info.image) == 'string' and info.image ~= '' and ('nui://kora_inventory/images/' .. info.image) or nil
    return { label = tostring(info.label or name), image = image }
end

local function byLabel(a, b)
    local la, lb = a.label:lower(), b.label:lower()
    if la ~= lb then return la < lb end
    return a.name < b.name
end

-- Items whose name or label contains the query. isAdded(name) marks the ones already in the list.
local function searchItems(query, isAdded)
    query = trim(query, 64)
    if not query then return fail('Type part of an item name or label to search.') end
    local needle = query:lower()

    local shared, results = allItems(), {}
    for name in pairs(shared) do
        local entry = type(name) == 'string' and itemEntry(shared, name)
        if entry and (name:lower():find(needle, 1, true) or entry.label:lower():find(needle, 1, true)) then
            results[#results + 1] = { name = name, label = entry.label, image = entry.image, added = isAdded(name) == true }
        end
    end

    table.sort(results, byLabel)
    local total = #results
    while #results > limits.itemResults do results[#results] = nil end
    return { results = results, total = total }
end

local function cleanDisable(value)
    local disable = {}
    for key, on in pairs(value) do
        local name = type(key) == 'string' and on == true and key or type(key) == 'number' and on
        if disableAllowed[name] then disable[name] = true end
    end
    return disable
end

-- Copies the valid parts of input ({ dict, clip, flag }) onto anim. Returns an error message or nil.
local function applyAnim(anim, input)
    if input.dict ~= nil then
        anim.dict = cleanName(input.dict, 64, patterns.anim)
        if not anim.dict then return 'Enter a valid animation dictionary.' end
    end
    if input.clip ~= nil then
        anim.clip = cleanName(input.clip, 64, patterns.anim)
        if not anim.clip then return 'Enter a valid animation clip.' end
    end
    if input.flag ~= nil then
        anim.flag = inRange(input.flag, 0, 65535, true)
        if not anim.flag then return 'Animation flag must be between 0 and 65535.' end
        anim.flags = nil
    end
end

local function cleanPointCoords(value)
    local coords = cleanVec(value)
    if coords and value.w ~= nil then
        coords.w = inRange(value.w, -720.0, 720.0)
        if not coords.w then return nil end
    end
    return coords
end

-- Lists of locations share the same shape: a count limit, then one cleaner per entry.
-- cleanEntry returns the clean entry, or nil and an error message.
local function cleanList(list, cleanEntry)
    if type(list) ~= 'table' then return nil, 'Invalid locations.' end
    local result = {}
    for _, entry in ipairs(list) do
        if #result >= limits.eventLocations then break end
        local clean, err = cleanEntry(entry)
        if not clean then return nil, err end
        result[#result + 1] = clean
    end
    return result
end

-- Reads the optional gang (and object) of an entry. Returns nil and an error message when one is bad.
local function cleanTags(entry, withObject)
    local gang = cleanName(entry.gang, 32, patterns.gang)
    if gang == false then return nil, gangMessage end
    if not withObject then return { gang = gang } end

    local object = cleanName(entry.object, 64, patterns.name)
    if object == false then return nil, objectMessage end
    return { gang = gang, object = object }
end

-- Entrances: { enter, exit, gang }
local function cleanEntrances(list)
    return cleanList(list, function(entry)
        local enter = type(entry) == 'table' and cleanVec(entry.enter)
        local exit = type(entry) == 'table' and cleanVec(entry.exit)
        if not (enter and exit) then return nil, 'Every location needs an enter and an exit.' end
        local tags, err = cleanTags(entry)
        if not tags then return nil, err end
        return { enter = enter, exit = exit, gang = tags.gang }
    end)
end

-- Work spots: { coords, object, gang }
local function cleanPoints(list)
    return cleanList(list, function(entry)
        local coords = type(entry) == 'table' and cleanPointCoords(entry.coords)
        if not coords then return nil, 'Every location needs coordinates.' end
        local tags, err = cleanTags(entry, true)
        if not tags then return nil, err end
        return { coords = coords, object = tags.object, gang = tags.gang }
    end)
end

-- Same as cleanPoints for rows already in the database: bad entries are skipped instead of refused.
local function readPoints(raw)
    local result = {}
    for _, entry in ipairs(decodeJson(raw, {})) do
        local coords = type(entry) == 'table' and cleanPointCoords(entry.coords)
        if coords then
            result[#result + 1] = {
                coords = coords,
                object = cleanName(entry.object, 64, patterns.name) or nil,
                gang = cleanName(entry.gang, 32, patterns.gang) or nil,
            }
        end
    end
    return result
end

local function noLocations()
    return {}
end

local function defaultPicking()
    return {
        time = 5000,
        disable = { move = true, combat = true, vehicle = true },
        anim = { dict = 'mp_arresting', clip = 'a_uncuff', flag = 49 },
    }
end

local function cleanSpots(list)
    if type(list) ~= 'table' then return nil, 'Invalid spots.' end
    local result = {}
    for _, entry in ipairs(list) do
        if #result >= limits.spots then break end
        local coords = type(entry) == 'table' and cleanVec(entry.coords)
        if coords then result[#result + 1] = { coords = coords } end
    end
    return result
end

local function plantRow(id)
    local valid = type(id) == 'string' and #id <= 32 and id:match('^%w+$')
    return valid and dbRow(id .. ':pick') or nil
end

local function toRecord(row)
    return {
        id = row.step:match('^(%w+):pick$'),
        data = decodeJson(row.data, {}),
        locations = cleanSpots(decodeJson(row.locations, {})),
    }
end

local pickingKeys = { 'pickTime', 'animDict', 'animClip', 'animFlag', 'disable' }

-- Applies the settings the creator sent onto the plant's data. Returns data, or nil and an error.
local function applySettings(data, s)
    if type(s) ~= 'table' then return data end

    if s.model ~= nil then
        data.model = cleanName(s.model, 64, patterns.name)
        if not data.model then return nil, 'Enter a valid prop model.' end
    end
    if s.item ~= nil then
        local item = trim(s.item, 64)
        if not (item and itemExists(item)) then return nil, 'That item does not exist.' end
        data.item = item
    end
    for _, key in ipairs({ 'icon', 'targetLabel', 'progressLabel' }) do
        if s[key] ~= nil then data[key] = trim(s[key], 64) end
    end
    if s.maxGive ~= nil then
        data.maxGive = inRange(s.maxGive, 1, 100, true)
        if not data.maxGive then return nil, 'Max give must be between 1 and 100.' end
    end
    if s.respawnTime ~= nil then
        data.respawnTime = inRange(s.respawnTime, 1, 3600)
        if not data.respawnTime then return nil, 'Respawn time must be between 1 and 3600 seconds.' end
    end

    local touchesPicking = false
    for _, key in ipairs(pickingKeys) do touchesPicking = touchesPicking or s[key] ~= nil end
    if touchesPicking then
        local picking = data.pickingData or defaultPicking()
        picking.anim = picking.anim or defaultPicking().anim
        data.pickingData = picking

        if s.pickTime ~= nil then
            picking.time = inRange(s.pickTime, 500, 60000, true)
            if not picking.time then return nil, 'Pick time must be between 500 and 60000 ms.' end
        end
        local animErr = applyAnim(picking.anim, { dict = s.animDict, clip = s.animClip, flag = s.animFlag })
        if animErr then return nil, animErr end
        if s.disable ~= nil then
            if type(s.disable) ~= 'table' then return nil, 'Invalid disable list.' end
            picking.disable = cleanDisable(s.disable)
        end
    end

    if s.disabled ~= nil then data.disabled = s.disabled == true or nil end
    return data
end

local function plantList()
    local list = {}
    for _, row in ipairs(Kora.sql.query('SELECT * FROM `qbdrugs`', {}) or {}) do
        if row.step:match('^%w+:pick$') then
            local record = toRecord(row)
            list[#list + 1] = {
                id = record.id,
                model = record.data.model,
                item = record.data.item,
                count = #record.locations,
                disabled = record.data.disabled == true,
            }
        end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

adminCallback('qbdrugs:creator:list', plantList)

adminCallback('qbdrugs:creator:get', function(_, id)
    local row = plantRow(id)
    if not row then return fail('Unknown plant.') end
    return toRecord(row)
end)

adminCallback('qbdrugs:creator:create', function(_, name, model, item)
    name = trim(name, 32)
    if not (name and name:match('^%a%w*$')) then
        return fail('Name must be letters and numbers only, starting with a letter.')
    end
    if plantRow(name) then return fail('That plant already exists.') end
    if GlobalState[name] ~= nil or GlobalState[name .. 'Data'] ~= nil then
        return fail('That name is already in use by something else.')
    end

    model = cleanName(model, 64, patterns.name)
    if not model then return fail('Enter a valid prop model.') end
    item = trim(item, 64)
    if not (item and itemExists(item)) then return fail('That item does not exist.') end

    local data = { model = model, item = item, respawnTime = 1, maxGive = 2, pickingData = defaultPicking() }
    local ok, err = dbSave(name .. ':pick', data, {})
    if not ok then return fail(err or 'Failed to create plant.') end

    ReloadPlants(name)
    return { id = name, data = data, locations = {} }
end)

adminCallback('qbdrugs:creator:save', function(_, id, patch)
    if type(patch) ~= 'table' then return fail('Nothing to save.') end
    local row = plantRow(id)
    if not row then return fail('Unknown plant.') end

    local record = toRecord(row)
    local data, locations = record.data, record.locations
    local err

    if patch.settings ~= nil then
        data, err = applySettings(data, patch.settings)
        if not data then return fail(err) end
    end
    if patch.locations ~= nil then
        locations, err = cleanSpots(patch.locations)
        if not locations then return fail(err) end
    end

    local ok, saveErr = dbSave(id .. ':pick', data, locations)
    if not ok then return fail(saveErr or 'Failed to save.') end

    ReloadPlants(id)
    return { id = id, data = data, locations = locations }
end)

adminCallback('qbdrugs:creator:delete', function(_, id)
    if not plantRow(id) then return fail('Unknown plant.') end

    local ok, err = dbDelete(id .. ':pick')
    if not ok then return fail(err or 'Failed to delete plant.') end

    ReloadPlants(id)
    return true
end)

-- Event data rules. Every event type below is built from these.

-- Returns defaults() and clean(data) for events that only have target text. `template` holds the
-- default for each text field.
local function textRules(template)
    local function defaults() return copyTable(template) end
    local function clean(data)
        if type(data) ~= 'table' then return nil, 'Invalid data.' end
        local result = defaults()
        for key, default in pairs(template) do result[key] = trim(data[key], 64) or default end
        return result
    end
    return defaults, clean
end

-- Events with a progress bar, an animation and target text.
local function progressRules(defaults)
    return function(data)
        if type(data) ~= 'table' then return nil, 'Invalid data.' end
        local clean = defaults()
        local progress = type(data.progress) == 'table' and data.progress or {}

        if progress.time ~= nil then
            clean.progress.time = inRange(progress.time, 500, 60000, true)
            if not clean.progress.time then return nil, 'Progress time must be between 500 and 60000 ms.' end
        end
        clean.progress.label = trim(progress.label, 64) or clean.progress.label
        if type(progress.disable) == 'table' then clean.progress.disable = cleanDisable(progress.disable) end

        local animErr = applyAnim(clean.anim, type(data.anim) == 'table' and data.anim or {})
        if animErr then return nil, animErr end

        clean.targetLabel = trim(data.targetLabel, 64) or clean.targetLabel
        clean.targetIcon = trim(data.targetIcon, 64) or clean.targetIcon
        return clean
    end
end

-- Meth stations. Each saves a position, and some also an offset, rotation, size, bucket or explosion.
local stationParts = {
    pour = { 'coords', 'offset', 'rotation' },
    heat = { 'coords', 'explosion' },
    smash = { 'coords', 'offset', 'rotation', 'size', 'bucket' },
    bag = { 'coords', 'offset', 'rotation', 'size' },
}

local stationDefaults = {
    pour = {
        coords = { x = 1006.09, y = -3200.59, z = -38.52 },
        offset = { x = 4.79, y = 2.13, z = -0.41 },
        rotation = { x = 0.0, y = 0.0, z = 0.0 },
    },
    heat = {
        coords = { x = 1007.89, y = -3201.17, z = -38.99 },
        explosion = true,
    },
    smash = {
        coords = { x = 1012.04, y = -3194.96, z = -38.99 },
        bucket = { x = 1012.86, y = -3194.13, z = -39.20, w = 90.0 },
        size = { x = 1.0, y = 1.0, z = 2.0 },
        offset = { x = -3.143311, y = -1.666748, z = -1.010128 },
        rotation = { x = 0.0, y = 0.0, z = 0.0 },
    },
    bag = {
        coords = { x = 1014.25, y = -3194.93, z = -38.99 },
        size = { x = 1.0, y = 1.0, z = 2.0 },
        offset = { x = -4.9, y = -1.70, z = -1.01 },
        rotation = { x = 0.0, y = 0.0, z = 0.0 },
    },
}

local stationRules = {
    coords = { message = 'The position needs x, y and z.', required = true, clean = cleanVec },
    offset = { message = 'The offset needs x, y and z.', clean = function(v) return cleanVec(v, 500.0) end },
    rotation = { message = 'The rotation needs x, y and z (degrees).', clean = function(v) return cleanVec(v, 720.0) end },
    size = {
        message = 'The size needs x, y and z above 0.',
        clean = function(v)
            local size = cleanVec(v, 100.0)
            if size and size.x > 0 and size.y > 0 and size.z > 0 then return size end
        end,
    },
    bucket = {
        message = 'The bucket needs x, y, z and a heading.',
        clean = function(v)
            local bucket = cleanVec(v)
            local heading = type(v) == 'table' and (v.w == nil and 0.0 or inRange(v.w, -720.0, 720.0))
            if not (bucket and heading) then return nil end
            bucket.w = heading
            return bucket
        end,
    },
}

local function cleanStation(name)
    return function(value)
        if type(value) ~= 'table' then return nil, 'Invalid location.' end
        local defaults = stationDefaults[name]
        local clean = {}
        for _, part in ipairs(stationParts[name]) do
            local given = value[part]
            if part == 'explosion' then
                if given == nil then
                    clean.explosion = defaults.explosion == true
                elseif type(given) == 'boolean' then
                    clean.explosion = given
                else
                    return nil, 'Explosion must be on or off.'
                end
            else
                local rule = stationRules[part]
                local result = given == nil and not rule.required and copyTable(defaults[part]) or rule.clean(given)
                if not result then return nil, rule.message end
                clean[part] = result
            end
        end
        return clean
    end
end

-- Cornerselling settings. The config file provides the defaults.
local cornerNumbers = {
    { key = 'maxSell', min = 1, max = 1000, whole = true, message = 'Max sell must be between 1 and 1000.' },
    { key = 'ripOff', min = 0, max = 1, message = 'Rip-off must be between 0 and 1 (0.2 is 20%).' },
    { key = 'minPolice', min = 0, max = 100, whole = true, message = 'Minimum police must be between 0 and 100.' },
    { key = 'weedPercentFlow', min = 0, max = 1, message = 'THC / CBD swing must be between 0 and 1 (0.2 is 20%).' },
}

local function cornerDefaults()
    local source = type(CornerSelling) == 'table' and CornerSelling or {}
    return {
        maxSell = source.maxSell or 15,
        ripOff = source.ripOff or 0.2,
        minPolice = source.minPolice or 0,
        weedPercentAdjustable = source.weedPercentAdjustable ~= false,
        weedPercentFlow = source.weedPercentFlow or 0.2,
        pricing = copyTable(source.pricing or {}),
    }
end

local function cleanCornerData(data)
    if type(data) ~= 'table' then return nil, 'Invalid data.' end
    local clean = cornerDefaults()

    for _, rule in ipairs(cornerNumbers) do
        if data[rule.key] ~= nil then
            clean[rule.key] = inRange(data[rule.key], rule.min, rule.max, rule.whole)
            if not clean[rule.key] then return nil, rule.message end
        end
    end
    if data.weedPercentAdjustable ~= nil then
        clean.weedPercentAdjustable = data.weedPercentAdjustable == true
    end

    if data.pricing ~= nil then
        if type(data.pricing) ~= 'table' then return nil, 'Invalid pricing.' end
        local pricing, count = {}, 0
        for item, price in pairs(data.pricing) do
            if not (type(item) == 'string' and #item <= 64 and item:match(patterns.name)) then
                return nil, 'Invalid item name in the price list.'
            end
            local amount = inRange(price, 0, limits.cornerPrice, true)
            if not amount then
                return nil, ('The price for %s must be between 0 and %d.'):format(item, limits.cornerPrice)
            end
            count = count + 1
            if count > limits.cornerItems then return nil, 'Too many items in the price list.' end
            pricing[item] = amount
        end
        clean.pricing = pricing
    end
    return clean
end

-- Recipes: items a player needs (give) and what they get (receive).
local function validRecipeId(id)
    return type(id) == 'string' and #id <= 48 and id:match('^%a%w*:%a%w*$') ~= nil
end

local function cleanGive(list)
    if type(list) ~= 'table' then return nil, 'Invalid item list.' end
    local clean, seen = {}, {}
    for _, entry in ipairs(list) do
        if #clean >= limits.recipeItems then return nil, 'Too many items in one recipe.' end
        local item = type(entry) == 'table' and cleanName(entry.item, 64, patterns.name)
        if not item then return nil, 'Invalid item name.' end
        if seen[item] then return nil, ('%s is in the recipe twice.'):format(item) end
        seen[item] = true

        local amount = inRange(entry.amount, 1, limits.recipeAmount, true)
        if not amount then
            return nil, ('The amount for %s must be between 1 and %d.'):format(item, limits.recipeAmount)
        end
        clean[#clean + 1] = { item = item, amount = amount, keep = entry.keep == true or nil }
    end
    return clean
end

-- { item, amount } or nil when no item was given.
local function cleanReceive(receive)
    if type(receive) ~= 'table' then return nil end
    local item = cleanName(receive.item, 64, patterns.name)
    if item == false then return nil, 'Invalid item name.' end
    if not item then return nil end

    local amount = receive.amount == nil and 1 or inRange(receive.amount, 1, limits.recipeAmount, true)
    if not amount then return nil, ('The amount made must be between 1 and %d.'):format(limits.recipeAmount) end
    return { item = item, amount = amount }
end

-- cleanReceive plus a check that the item exists. Returns receive (nil = makes nothing) and an error.
local function checkedReceive(item, amount)
    local receive, err = cleanReceive({ item = item, amount = amount })
    if err then return nil, err end
    if receive and not itemExists(receive.item) then return nil, ('%s does not exist.'):format(receive.item) end
    return receive
end

local function cleanRecipeData(data)
    if type(data) ~= 'table' then return nil, 'Invalid data.' end
    local clean = { recipes = {} }
    for id, entry in pairs(type(data.recipes) == 'table' and data.recipes or {}) do
        if type(entry) == 'table' and validRecipeId(id) then
            local give, giveErr = cleanGive(entry.give)
            if not give then return nil, giveErr end
            local receive, receiveErr = cleanReceive(entry.receive)
            if receiveErr then return nil, receiveErr end
            clean.recipes[id] = { custom = true, receive = receive, give = give }
        end
    end
    return clean
end

-- Custom drugs: the names made on the Custom drugs page, plus the base events the admin deleted.
local function cleanCustomDrugs(data)
    if type(data) ~= 'table' then return nil, 'Invalid data.' end
    local clean, seen = { drugs = {}, removed = {} }, {}
    for _, name in ipairs(type(data.drugs) == 'table' and data.drugs or {}) do
        if type(name) == 'string' and #name <= 24 and name:match('^%a%w*$') and not seen[name:lower()] then
            seen[name:lower()] = true
            clean.drugs[#clean.drugs + 1] = name
        end
    end
    for _, step in ipairs(type(data.removed) == 'table' and data.removed or {}) do
        if type(step) == 'string' and #step <= 49 and step:match('^%w+:[%w_]+$') and not seen[step] then
            seen[step] = true
            clean.removed[#clean.removed + 1] = step
        end
    end
    return clean
end

-- Event types. Each entry says how an event's data and locations are made, cleaned and read.
--   permanent       can never be deleted
--   fixedLocations  the position is fixed; the creator cannot change it
--   seedLocations   the row is created with these when it does not exist
--   fillLocations   an existing row without a position gets seedLocations

local function labEvent(seedLocations)
    local defaults, clean = textRules({ enterTarget = 'Enter Lab', exitTarget = 'Exit Lab' })
    return {
        permanent = true,
        defaults = defaults,
        cleanData = clean,
        cleanLocations = cleanEntrances,
        readLocations = function(raw) return NormalizeEntrances(decodeJson(raw, {})) end,
        seedLocations = seedLocations,
    }
end

-- pointsEvent{ progressLabel, targetLabel, targetIcon, seed = fn, custom = true }
local function pointsEvent(options)
    local function defaults()
        return {
            progress = {
                time = 5000,
                label = options[1],
                disable = { move = true, combat = true, vehicle = true },
            },
            anim = { dict = 'mp_arresting', clip = 'a_uncuff', flag = 49 },
            targetLabel = options[2],
            targetIcon = options[3],
            custom = options.custom,
        }
    end
    return {
        defaults = defaults,
        cleanData = progressRules(defaults),
        cleanLocations = cleanPoints,
        readLocations = readPoints,
        seedLocations = options.seed,
    }
end

local function fixedEvent(template, location)
    local defaults, clean = textRules(template)
    return {
        defaults = defaults,
        cleanData = clean,
        fixedLocations = location,
        readLocations = location,
    }
end

local function stationEvent(name, template)
    local defaults, clean = textRules(template)
    local cleanLocations = cleanStation(name)
    return {
        defaults = defaults,
        cleanData = clean,
        cleanLocations = cleanLocations,
        readLocations = function(raw) return cleanLocations(decodeJson(raw, {})) or copyTable(stationDefaults[name]) end,
        seedLocations = function() return copyTable(stationDefaults[name]) end,
        fillLocations = true,
    }
end

local function settingsEvent(defaults, cleanData, afterSave)
    return {
        permanent = true,
        defaults = defaults,
        cleanData = cleanData,
        fixedLocations = noLocations,
        readLocations = noLocations,
        afterSave = afterSave,
    }
end

local function cuttingLocation()
    return {
        coords = { x = 1095.61, y = -3195.62, z = -39.13 },
        offset = { x = -1.782227, y = 0.445068, z = -0.502701 },
        rotation = { x = 0.0, y = 0.0, z = 0.0 },
    }
end

local function baggingLocation()
    return {
        coords = { x = 1093.16, y = -3195.78, z = -39.19 },
        offset = { x = 4.515137, y = 2.542969, z = -0.814194 },
        rotation = { x = 0.0, y = 0.0, z = 180.0 },
    }
end

local eventTypes = {
    [customStep] = settingsEvent(function() return { drugs = {}, removed = {} } end, cleanCustomDrugs),
    [cornerStep] = settingsEvent(cornerDefaults, cleanCornerData),
    [recipesStep] = settingsEvent(function() return { recipes = {} } end, cleanRecipeData, function(data) applyRecipes(data.recipes) end),

    ['Cocaine:lab'] = labEvent(),
    ['Meth:tele'] = labEvent(noLocations),
    ['Weed:lab'] = labEvent(noLocations),

    ['Cocaine:powder'] = pointsEvent{ 'Making Raw Cocaine', 'make powder', 'BriefCase' },
    ['Crack:cook'] = pointsEvent{ 'Cooking Crack', 'cook crack', 'crack' },
    ['Crack:bagging'] = pointsEvent{ 'Bagging Crack', 'bag crack', 'crack' },
    ['Heroin:drying'] = pointsEvent{ 'Drying Poppies', 'Dry Poppies', 'poppy' },
    ['Heroin:vials'] = pointsEvent{ 'Filling Heroin Vials', 'Fill Heroin Vials', 'poppy' },
    ['Heroin:syringe'] = pointsEvent{ 'Making Heroin Syringe', 'Make Heroin Syringe', 'poppy' },
    ['Weed:drying'] = pointsEvent{ 'Drying Weed', 'Dry Weed', 'weed', seed = noLocations },
    ['Weed:breakNugs'] = pointsEvent{ 'Breaking Down Weed', 'Break Down Weed', 'weed', seed = noLocations },
    ['Weed:bagWeed'] = pointsEvent{ 'Bagging Weed', 'Bag Weed', 'weed', seed = noLocations },

    ['Cocaine:cutting'] = fixedEvent({ targetLabel = 'cut cocaine', targetIcon = 'knife' }, cuttingLocation),
    ['Cocaine:bagging'] = fixedEvent({ targetLabel = 'bag cocaine', targetIcon = 'box' }, baggingLocation),

    ['Meth:pour'] = stationEvent('pour', {
        targetLabel = 'Pour Chemicals', targetIcon = 'fa-solid fa-flask',
        trayLabel = 'Grab Tray', trayIcon = 'fa-solid fa-hand-paper',
    }),
    ['Meth:heat'] = stationEvent('heat', { targetLabel = 'Heat Chemicals', targetIcon = 'fa-solid fa-fire' }),
    ['Meth:smash'] = stationEvent('smash', { targetLabel = 'Smash Meth', targetIcon = 'fa-solid fa-hammer' }),
    ['Meth:bag'] = stationEvent('bag', { targetLabel = 'Bag Meth', targetIcon = 'fa-solid fa-bag-shopping' }),
}

-- Events made on the Custom drugs page all share this type.
local customEvent = pointsEvent{ 'Working', 'interact', 'BriefCase', custom = true }

local reservedNames = { pick = true, settings = true }

-- 'Opium:cook' -> 'Opium', 'cook'. Nothing when the step is not shaped like a custom event.
local function splitCustomStep(step)
    if type(step) ~= 'string' or #step > 49 then return end
    local drug, name = step:match('^(%a%w*):(%a[%w_]*)$')
    if drug and #drug <= 24 and #name <= 24 and not reservedNames[name] then return drug, name end
end

-- What the Custom drugs page saved: { drugs = {...}, removed = {...} }.
local function customRegistry()
    local row = dbRow(customStep)
    return row and cleanCustomDrugs(decodeJson(row.data, {})) or { drugs = {}, removed = {} }
end

local function kindFor(step)
    if eventTypes[step] then return eventTypes[step] end
    local drug = splitCustomStep(step)
    if not drug then return end
    for _, known in ipairs(customRegistry().drugs) do
        if known == drug then return customEvent end
    end
end

-- Events that have a recipe store which one they run in data.recipe.
local function withRecipe(step, data, chosen)
    if defaultRecipes[step] then
        data.recipe = recipeInfo[chosen] and chosen or defaultRecipes[step]
    elseif data.custom then
        data.recipe = recipeInfo[chosen] and chosen or nil
    end
    return data
end

local function getEvent(step)
    local kind = kindFor(step)
    local row = dbRow(step)
    if not row then
        return { data = withRecipe(step, kind.defaults()), locations = kind.readLocations(nil) }
    end
    local stored = decodeJson(row.data, {})
    local data = withRecipe(step, kind.cleanData(stored) or kind.defaults(), stored.recipe)
    return { data = data, locations = kind.readLocations(row.locations) }
end

local function saveEvent(step, patch)
    local kind = kindFor(step)
    if not kind then return fail('Unknown event.') end
    if type(patch) ~= 'table' then return fail('Nothing to save.') end

    local event = getEvent(step)
    local data, locations = event.data, event.locations
    local err

    if patch.data ~= nil then
        data, err = kind.cleanData(patch.data)
        if not data then return fail(err) end
        withRecipe(step, data, patch.data.recipe)
    end
    if kind.fixedLocations then
        locations = kind.fixedLocations()
    elseif patch.locations ~= nil then
        locations, err = kind.cleanLocations(patch.locations)
        if not locations then return fail(err) end
    end

    local ok, saveErr = dbSave(step, data, locations)
    if not ok then return fail(saveErr or 'Failed to save.') end

    ReloadEvents(step)
    if kind.afterSave then kind.afterSave(data) end
    return { step = step, data = data, locations = locations }
end

adminCallback('qbdrugs:creator:event:get', function(_, step)
    if not kindFor(step) then return fail('Unknown event.') end
    local event = getEvent(step)
    return { step = step, data = event.data, locations = event.locations }
end)

adminCallback('qbdrugs:creator:event:save', function(_, step, patch)
    return saveEvent(step, patch)
end)

-- Deletes an event's row and tells the clients.
local function dropEvent(step)
    local ok, err = dbDelete(step)
    if not ok then return false, err end
    ReloadEvents(step)
    return true
end

local function cornerPayload()
    local event = getEvent(cornerStep)
    local shared, items = allItems(), {}
    for name in pairs(event.data.pricing) do
        items[name] = itemEntry(shared, name)
    end
    return { step = cornerStep, data = event.data, items = items }
end

adminCallback('qbdrugs:creator:corner:get', cornerPayload)

adminCallback('qbdrugs:creator:corner:search', function(_, query)
    local priced = getEvent(cornerStep).data.pricing
    return searchItems(query, function(name) return priced[name] ~= nil end)
end)

local function effectiveGive(saved, id)
    local entry = saved[id]
    return entry and entry.give or {}
end

local function recipesPayload()
    local saved = getEvent(recipesStep).data.recipes
    local shared, list, items = allItems(), {}, {}

    local function track(name)
        if not items[name] then items[name] = itemEntry(shared, name) end
    end

    for _, id in ipairs(recipeIds) do
        local info = recipeInfo[id]
        local receive = info.recipe.receive
        local makes = receive and receive.item and { item = receive.item, amount = receive.amount or 1 } or nil
        local give = effectiveGive(saved, id)

        if makes then track(makes.item) end
        for _, entry in ipairs(give) do track(entry.item) end
        list[#list + 1] = {
            id = id, label = info.label, receive = makes, give = give,
            custom = true,
        }
    end
    return { list = list, items = items }
end

-- Runs change(savedRecipes), which returns an error message or nil, then saves and returns the page.
local function updateRecipes(change)
    local data = getEvent(recipesStep).data
    local err = change(data.recipes)
    if err then return fail(err) end

    local saved, saveErr = saveEvent(recipesStep, { data = data })
    if not saved then return fail(saveErr) end
    return recipesPayload()
end

adminCallback('qbdrugs:creator:recipes:get', recipesPayload)

adminCallback('qbdrugs:creator:recipes:search', function(_, query, id)
    if not recipeInfo[id] then return fail('Unknown recipe.') end

    local inRecipe = {}
    for _, entry in ipairs(effectiveGive(getEvent(recipesStep).data.recipes, id)) do
        inRecipe[entry.item] = true
    end
    return searchItems(query, function(name) return inRecipe[name] == true end)
end)

adminCallback('qbdrugs:creator:recipes:set', function(_, id, give)
    if not recipeInfo[id] then return fail('Unknown recipe.') end
    local clean, err = cleanGive(give)
    if not clean then return fail(err) end

    return updateRecipes(function(saved)
        local current = {}
        for _, entry in ipairs(effectiveGive(saved, id)) do current[entry.item] = true end
        for _, entry in ipairs(clean) do
            if not current[entry.item] and not itemExists(entry.item) then
                return ('%s does not exist.'):format(entry.item)
            end
        end
        saved[id] = saved[id] or {}
        saved[id].give = clean
    end)
end)

adminCallback('qbdrugs:creator:recipes:create', function(_, drug, name, item, amount)
    drug, name = trim(drug, 24), trim(name, 24)
    local id = drug and name and (drug .. ':' .. name)
    if not validRecipeId(id) then return fail('Name must be letters and numbers only, starting with a letter.') end
    if recipeInfo[id] then return fail('That recipe already exists.') end

    local receive, err = checkedReceive(item, amount)
    if err then return fail(err) end

    local payload, updateErr = updateRecipes(function(saved)
        saved[id] = { custom = true, receive = receive, give = {} }
    end)
    if not payload then return fail(updateErr) end

    payload.id = id
    return payload
end)

adminCallback('qbdrugs:creator:recipes:receive', function(_, id, item, amount)
    if not recipeInfo[id] then return fail('Unknown recipe.') end
    local receive, err = checkedReceive(item, amount)
    if err then return fail(err) end

    return updateRecipes(function(saved)
        if not saved[id] then return 'Unknown recipe.' end
        saved[id].receive = receive
    end)
end)

adminCallback('qbdrugs:creator:recipes:delete', function(_, id)
    if not recipeInfo[id] then return fail('Unknown recipe.') end

    return updateRecipes(function(saved)
        if not saved[id] then return 'Unknown recipe.' end
        saved[id] = nil
    end)
end)

-- Custom drugs, custom events, and deleting or restoring base events

local function customPayload()
    local registry = customRegistry()
    local drugs, byName = {}, {}
    for _, name in ipairs(registry.drugs) do
        byName[name] = { name = name, events = {} }
        drugs[#drugs + 1] = byName[name]
    end

    for _, row in ipairs(Kora.sql.query('SELECT `step`, `data` FROM `qbdrugs`') or {}) do
        local drug, name = splitCustomStep(row.step)
        if drug and byName[drug] and decodeJson(row.data, {}).custom == true then
            table.insert(byName[drug].events, { step = row.step, name = name })
        end
    end

    for _, entry in ipairs(drugs) do
        table.sort(entry.events, function(a, b) return a.name < b.name end)
    end
    return { drugs = drugs, removed = registry.removed }
end

-- Runs change(registry), which returns an error message or nil, then saves and returns the payload.
local function updateCustoms(change)
    local data = getEvent(customStep).data
    local err = change(data)
    if err then return fail(err) end

    local saved, saveErr = saveEvent(customStep, { data = data })
    if not saved then return fail(saveErr) end
    return customPayload()
end

local function takenDrugName(name)
    local lower = name:lower()
    for _, known in ipairs(customRegistry().drugs) do
        if known:lower() == lower then return true end
    end
    for step in pairs(eventTypes) do
        local drug = step:match('^(%w+):')
        if drug and drug:lower() == lower then return true end
    end
    return false
end

adminCallback('qbdrugs:creator:custom:get', customPayload)

adminCallback('qbdrugs:creator:custom:drug:create', function(_, name)
    name = trim(name, 25)
    if not (name and #name <= 24 and name:match('^%a%w*$')) then
        return fail('Name must be letters and numbers only, starting with a letter, 24 at most.')
    end
    if takenDrugName(name) then return fail('That name is already used.') end

    local payload, err = updateCustoms(function(data)
        data.drugs[#data.drugs + 1] = name
    end)
    if not payload then return fail(err) end

    payload.name = name
    return payload
end)

adminCallback('qbdrugs:creator:custom:drug:delete', function(_, name)
    return updateCustoms(function(data)
        local kept, found = {}, false
        for _, known in ipairs(data.drugs) do
            if known == name then found = true else kept[#kept + 1] = known end
        end
        if not found then return 'Unknown drug.' end

        for _, drug in ipairs(customPayload().drugs) do
            if drug.name == name then
                for _, event in ipairs(drug.events) do
                    local ok, err = dropEvent(event.step)
                    if not ok then return err or 'Failed to delete an event.' end
                end
            end
        end
        data.drugs = kept
    end)
end)

adminCallback('qbdrugs:creator:custom:event:create', function(_, drug, name)
    name = trim(name, 25)
    if not (name and #name <= 24 and name:match('^%a[%w_]*$')) then
        return fail('Name must be letters, numbers and _, starting with a letter, 24 at most.')
    end

    local step = tostring(drug) .. ':' .. name
    if kindFor(step) ~= customEvent then return fail('Unknown drug, or that name is not allowed.') end

    for _, entry in ipairs(customPayload().drugs) do
        if entry.name == drug then
            for _, event in ipairs(entry.events) do
                if event.name:lower() == name:lower() then return fail('That event already exists.') end
            end
        end
    end

    local saved, err = saveEvent(step, { data = { targetLabel = name, progress = { label = name } } })
    if not saved then return fail(err) end

    local payload = customPayload()
    payload.step = step
    return payload
end)

adminCallback('qbdrugs:creator:custom:event:delete', function(_, step)
    if kindFor(step) ~= customEvent then return fail('Only custom events can be deleted.') end
    local ok, err = dropEvent(step)
    if not ok then return fail(err or 'Failed to delete the event.') end
    return customPayload()
end)

-- Creates (or fills in) the row of an event that has a fixed or known first position. A row that is
-- already complete is left alone.
local function seedEvent(step, kind)
    local initial = kind.fixedLocations or kind.seedLocations
    if not initial then return end

    local row = dbRow(step)
    local ok, err, what
    if not row then
        what = 'created default row'
        ok, err = dbSave(step, kind.defaults(), initial())
    elseif kind.fillLocations and not decodeJson(row.locations, {}).coords then
        what = 'filled the position of'
        ok, err = Kora.sql.update('UPDATE `qbdrugs` SET `locations` = ? WHERE `step` = ?', { json.encode(initial()), step })
        InvalidateCreatorCache()
    else
        return
    end

    if not ok then error(err or 'the write failed') end
    Kora.print.warn(('[qbdrugs] %s %s'):format(what, step))
    ReloadEvents(step)
end

-- Base events can be deleted too: the row is removed and the step is remembered, so it stays hidden
-- and is not re-created on start. Entrances and settings are permanent.
local function removable(step)
    local kind = type(step) == 'string' and eventTypes[step]
    return kind and not kind.permanent
end

adminCallback('qbdrugs:creator:event:delete', function(_, step)
    if not removable(step) then return fail('This event cannot be deleted.') end

    return updateCustoms(function(data)
        for _, known in ipairs(data.removed) do
            if known == step then return end
        end
        local ok, err = dropEvent(step)
        if not ok then return err or 'Failed to delete the event.' end
        data.removed[#data.removed + 1] = step
    end)
end)

adminCallback('qbdrugs:creator:event:restore', function(_, step)
    if not removable(step) then return fail('This event cannot be restored.') end

    local payload, err = updateCustoms(function(data)
        local kept = {}
        for _, known in ipairs(data.removed) do
            if known ~= step then kept[#kept + 1] = known end
        end
        data.removed = kept
    end)
    if not payload then return fail(err) end

    pcall(seedEvent, step, eventTypes[step]) -- events with a fixed position get their row back right away
    ReloadEvents(step)
    return payload
end)

CreateThread(function()
    Wait(1000)
    while GetResourceState('kora_sql') ~= 'started' do Wait(500) end

    local removed = {}
    local registryOk, registry = pcall(customRegistry)
    for _, step in ipairs(registryOk and registry.removed or {}) do removed[step] = true end

    for step, kind in pairs(eventTypes) do
        if not removed[step] then
            local ok, err = pcall(seedEvent, step, kind)
            if not ok then Kora.print.warn(('[qbdrugs] could not set up %s: %s'):format(step, tostring(err))) end
        end
    end
end)

-- Everything the creator shows when it opens, in one callback. The four pages load side by side.
local function runTogether(tasks)
    local promises, results = {}, {}
    for i, task in ipairs(tasks) do
        local p = promise.new()
        promises[i] = p
        CreateThread(function()
            local ok, value = pcall(task)
            p:resolve({ ok = ok, value = value })
        end)
    end
    for i, p in ipairs(promises) do
        local outcome = Citizen.Await(p)
        if not outcome.ok then error(outcome.value, 0) end
        results[i] = outcome.value
    end
    return results
end

adminCallback('qbdrugs:creator:open', function()
    return CachedCreatorData(function()
        local ok, r = pcall(runTogether, { plantList, cornerPayload, customPayload, recipesPayload })
        if not ok then return fail('Could not load the creator data.') end
        return { plants = r[1], corner = r[2], customs = r[3], recipes = r[4] }
    end)
end)

RegisterCommand('drugCreator', function(source)
    if not isAdmin(source) then
        Kora.print.warn(('[qbdrugs] player %s was denied /drugCreator: they do not have the "%s" ace'):format(source, 'command'))
        Kora.notify.send(source, { title = 'Drug Creator', message = 'Admin permission required.', type = 'error' })
        return
    end
    TriggerClientEvent('qbdrugs:creator:open', source)
end, false)
