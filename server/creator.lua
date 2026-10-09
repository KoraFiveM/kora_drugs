local MAX_SPOTS = 200
local maxRecipeItems = 20
local maxRecipeAmount = 1000
local recipesStep = 'Recipes:settings'

local function fail(message)
    return false, message
end

local function adminOnly(src)
    if IsPlayerAceAllowed(src, 'command') then return true end
    return fail('Admin permission required.')
end

local function trim(value, max)
    if type(value) ~= 'string' or not value:match('%S') then return nil end
    return value:match('^%s*(.-)%s*$'):sub(1, max)
end

local function decode(value, fallback)
    if type(value) ~= 'string' or value == '' then return fallback end
    local ok, decoded = pcall(json.decode, value)
    return (ok and type(decoded) == 'table' and decoded) or fallback
end

local function animName(value)
    local name = trim(value, 64)
    return name and name:match('^[%w_@%-%.]+$') and name or nil
end

local function inRange(value, min, max)
    local n = tonumber(value)
    if not n or n ~= n or n < min or n > max then return nil end
    return n
end

local function itemExists(item)
    local ok, shared = pcall(function() return exports.qbcore:getShared('items', item) end)
    return ok and type(shared) == 'table'
end

local function reload(id)
    local ok, err = pcall(function() exports[GetCurrentResourceName()]:ReloadPlants(id) end)
    if not ok then
        QB.print.warn(('[qbdrugs] creator could not reload plants: %s'):format(tostring(err)))
    end
end

local function defaultPicking()
    return {
        time = 5000,
        disable = { move = true, combat = true, vehicle = true },
        anim = { dict = 'mp_arresting', clip = 'a_uncuff', flag = 49 },
    }
end

local function validId(id)
    return type(id) == 'string' and #id <= 32 and id:match('^%w+$') ~= nil
end

local function getRow(id)
    local rows = QB.sql.query('SELECT * FROM `qbdrugs` WHERE `step` = ? LIMIT 1', { id .. ':pick' })
    return rows and rows[1] or nil
end

local function toRecord(row)
    local locations = {}
    for _, loc in ipairs(decode(row.locations, {})) do
        local c = type(loc) == 'table' and loc.coords
        if type(c) == 'table' and tonumber(c.x) and tonumber(c.y) and tonumber(c.z) then
            locations[#locations + 1] = { coords = { x = c.x, y = c.y, z = c.z } }
        end
    end
    return {
        id = row.step:match('^(%w+):pick$'),
        data = decode(row.data, {}),
        locations = locations,
    }
end

local function cleanLocations(list)
    if type(list) ~= 'table' then return nil, 'Invalid spots.' end
    local result = {}
    for _, entry in ipairs(list) do
        if #result >= MAX_SPOTS then break end
        local c = type(entry) == 'table' and type(entry.coords) == 'table' and entry.coords
        local x, y, z = c and tonumber(c.x), c and tonumber(c.y), c and tonumber(c.z)
        if x and y and z and x == x and y == y and z == z then
            result[#result + 1] = { coords = { x = x, y = y, z = z } }
        end
    end
    return result
end

local function applySettings(data, s)
    if type(s) ~= 'table' then return data end

    if s.model ~= nil then
        local model = trim(s.model, 64)
        if not model then return nil, 'A prop model is required.' end
        data.model = model
    end
    if s.item ~= nil then
        local item = trim(s.item, 64)
        if not item or not itemExists(item) then return nil, 'That item does not exist.' end
        data.item = item
    end
    if s.icon ~= nil then
        data.icon = trim(s.icon, 64)
    end
    if s.targetLabel ~= nil then
        data.targetLabel = trim(s.targetLabel, 64)
    end
    if s.progressLabel ~= nil then
        data.progressLabel = trim(s.progressLabel, 64)
    end
    if s.maxGive ~= nil then
        local n = inRange(s.maxGive, 1, 100)
        if not n then return nil, 'Max give must be between 1 and 100.' end
        data.maxGive = math.floor(n)
    end
    if s.respawnTime ~= nil then
        local n = inRange(s.respawnTime, 1, 3600)
        if not n then return nil, 'Respawn time must be between 1 and 3600 seconds.' end
        data.respawnTime = n
    end
    if s.pickTime ~= nil or s.animDict ~= nil or s.animClip ~= nil or s.animFlag ~= nil or s.disable ~= nil then
        data.pickingData = data.pickingData or defaultPicking()
    end
    local picking = data.pickingData

    if s.pickTime ~= nil then
        local n = inRange(s.pickTime, 500, 60000)
        if not n then return nil, 'Pick time must be between 500 and 60000 ms.' end
        picking.time = math.floor(n)
    end
    if s.animDict ~= nil or s.animClip ~= nil or s.animFlag ~= nil then
        picking.anim = picking.anim or defaultPicking().anim
    end
    if s.animDict ~= nil then
        picking.anim.dict = animName(s.animDict)
        if not picking.anim.dict then return nil, 'Enter a valid animation dictionary.' end
    end
    if s.animClip ~= nil then
        picking.anim.clip = animName(s.animClip)
        if not picking.anim.clip then return nil, 'Enter a valid animation clip.' end
    end
    if s.animFlag ~= nil then
        local n = inRange(s.animFlag, 0, 65535)
        if not n then return nil, 'Animation flag must be between 0 and 65535.' end
        picking.anim.flag = math.floor(n)
        picking.anim.flags = nil
    end
    if s.disable ~= nil then
        if type(s.disable) ~= 'table' then return nil, 'Invalid disable list.' end
        local allowed = {}
        for _, option in ipairs(ProgressDisableOptions) do allowed[option.value] = true end

        local disable = {}
        for _, key in ipairs(s.disable) do
            if allowed[key] then disable[key] = true end
        end
        picking.disable = disable
    end
    if s.disabled ~= nil then
        data.disabled = s.disabled == true or nil
    end
    return data
end

QB.callback.register('qbdrugs:creator:list', function(src)
    local allowed, err = adminOnly(src)
    if not allowed then return false, err end

    local list = {}
    for _, row in ipairs(QB.sql.query('SELECT * FROM `qbdrugs`', {}) or {}) do
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
end)

QB.callback.register('qbdrugs:creator:get', function(src, id)
    local allowed, err = adminOnly(src)
    if not allowed then return false, err end

    local row = validId(id) and getRow(id)
    if not row then return fail('Unknown plant.') end
    return toRecord(row)
end)

QB.callback.register('qbdrugs:creator:create', function(src, name, model, item)
    local allowed, err = adminOnly(src)
    if not allowed then return false, err end

    name = trim(name, 32)
    if not name or not name:match('^%a%w*$') then
        return fail('Name must be letters and numbers only, starting with a letter.')
    end
    if getRow(name) then return fail('That plant already exists.') end

    if GlobalState[name] ~= nil or GlobalState[name .. 'Data'] ~= nil then
        return fail('That name is already in use by something else.')
    end

    model = trim(model, 64)
    if not model then return fail('A prop model is required.') end
    item = trim(item, 64)
    if not item or not itemExists(item) then return fail('That item does not exist.') end

    local data = { model = model, item = item, respawnTime = 1, maxGive = 2, pickingData = defaultPicking() }
    local ok, insertErr = QB.sql.update(
        'INSERT INTO `qbdrugs` (`step`, `data`, `locations`) VALUES (?, ?, ?)',
        { name .. ':pick', json.encode(data), '[]' }
    )
    if not ok then return fail(insertErr or 'Failed to create plant.') end

    reload(name)
    return { id = name, data = data, locations = {} }
end)

QB.callback.register('qbdrugs:creator:save', function(src, id, patch)
    local allowed, err = adminOnly(src)
    if not allowed then return false, err end
    if type(patch) ~= 'table' then return fail('Nothing to save.') end

    local row = validId(id) and getRow(id)
    if not row then return fail('Unknown plant.') end

    local record = toRecord(row)
    local data, locations = record.data, record.locations

    if patch.settings ~= nil then
        local applyErr
        data, applyErr = applySettings(data, patch.settings)
        if not data then return fail(applyErr) end
    end
    if patch.locations ~= nil then
        local cleanErr
        locations, cleanErr = cleanLocations(patch.locations)
        if not locations then return fail(cleanErr) end
    end

    local ok, saveErr = QB.sql.update(
        'UPDATE `qbdrugs` SET `data` = ?, `locations` = ? WHERE `step` = ?',
        { json.encode(data), json.encode(locations), id .. ':pick' }
    )
    if not ok then return fail(saveErr or 'Failed to save.') end

    reload(id)
    return { id = id, data = data, locations = locations }
end)

QB.callback.register('qbdrugs:creator:delete', function(src, id)
    local allowed, err = adminOnly(src)
    if not allowed then return false, err end

    if not validId(id) or not getRow(id) then return fail('Unknown plant.') end

    local ok, deleteErr = QB.sql.update('DELETE FROM `qbdrugs` WHERE `step` = ?', { id .. ':pick' })
    if not ok then return fail(deleteErr or 'Failed to delete plant.') end

    reload(id)
    return true
end)

local MAX_EVENT_LOCATIONS = 50
local COORD_LIMIT = 10000.0

local function cleanVec(value)
    if type(value) ~= 'table' then return nil end
    local x, y, z = inRange(value.x, -COORD_LIMIT, COORD_LIMIT), inRange(value.y, -COORD_LIMIT, COORD_LIMIT), inRange(value.z, -COORD_LIMIT, COORD_LIMIT)
    if not (x and y and z) then return nil end
    return { x = x, y = y, z = z }
end

local function cleanGang(value)
    local gang = trim(value, 32)
    if not gang then return nil end
    return gang:match('^[%w_%-]+$') and gang or false
end

local function cleanEntrances(list)
    if type(list) ~= 'table' then return nil, 'Invalid locations.' end
    local result = {}
    for _, entry in ipairs(list) do
        if #result >= MAX_EVENT_LOCATIONS then break end
        local enter = type(entry) == 'table' and cleanVec(entry.enter)
        local exit = type(entry) == 'table' and cleanVec(entry.exit)
        if not enter or not exit then return nil, 'Every location needs an enter and an exit.' end
        local gang = cleanGang(entry.gang)
        if gang == false then return nil, 'Gang may only contain letters, numbers, _ and -.' end
        result[#result + 1] = { enter = enter, exit = exit, gang = gang }
    end
    return result
end

local function cleanPointCoords(value)
    local coords = cleanVec(value)
    if not coords then return nil end
    if value.w ~= nil then
        local w = inRange(value.w, -720.0, 720.0)
        if not w then return nil end
        coords.w = w
    end
    return coords
end

local function cleanObject(value)
    local object = trim(value, 64)
    if not object then return nil end
    return object:match('^[%w_%-%.]+$') and object or false
end

local function cleanPoints(list)
    if type(list) ~= 'table' then return nil, 'Invalid locations.' end
    local result = {}
    for _, entry in ipairs(list) do
        if #result >= MAX_EVENT_LOCATIONS then break end
        local coords = type(entry) == 'table' and cleanPointCoords(entry.coords)
        if not coords then return nil, 'Every location needs coordinates.' end
        local object = cleanObject(entry.object)
        if object == false then return nil, 'Object may only contain letters, numbers, _, - and .' end
        local gang = cleanGang(entry.gang)
        if gang == false then return nil, 'Gang may only contain letters, numbers, _ and -.' end
        result[#result + 1] = { coords = coords, object = object, gang = gang }
    end
    return result
end

local function readPoints(raw)
    local result = {}
    for _, entry in ipairs(decode(raw, {})) do
        local coords = type(entry) == 'table' and cleanPointCoords(entry.coords)
        if coords then result[#result + 1] = { coords = coords, object = cleanObject(entry.object) or nil, gang = cleanGang(entry.gang) or nil } end
    end
    return result
end

local function cleanDisable(value)
    local allowed = {}
    for _, option in ipairs(ProgressDisableOptions) do allowed[option.value] = true end

    local disable = {}
    for key, on in pairs(value) do
        if type(key) == 'string' and on == true and allowed[key] then
            disable[key] = true
        elseif type(key) == 'number' and type(on) == 'string' and allowed[on] then
            disable[on] = true
        end
    end
    return disable
end


local function labDefaults()
    return { enterTarget = 'Enter Lab', exitTarget = 'Exit Lab' }
end

local function progressDefaults(progressLabel, targetLabel, targetIcon)
    return function()
        return {
            progress = {
                time = 5000,
                label = progressLabel,
                disable = { move = true, combat = true, vehicle = true },
            },
            anim = { dict = 'mp_arresting', clip = 'a_uncuff', flag = 49 },
            targetLabel = targetLabel,
            targetIcon = targetIcon,
        }
    end
end

local powderDefaults = progressDefaults('Making Raw Cocaine', 'make powder', 'BriefCase')
local crackCookDefaults = progressDefaults('Cooking Crack', 'cook crack', 'crack')
local crackBaggingDefaults = progressDefaults('Bagging Crack', 'bag crack', 'crack')
local heroinDryingDefaults = progressDefaults('Drying Poppies', 'Dry Poppies', 'poppy')
local heroinVialsDefaults = progressDefaults('Filling Heroin Vials', 'Fill Heroin Vials', 'poppy')
local heroinSyringeDefaults = progressDefaults('Making Heroin Syringe', 'Make Heroin Syringe', 'poppy')
local weedDryingDefaults = progressDefaults('Drying Weed', 'Dry Weed', 'weed')
local weedBreakNugsDefaults = progressDefaults('Breaking Down Weed', 'Break Down Weed', 'weed')
local weedBagDefaults = progressDefaults('Bagging Weed', 'Bag Weed', 'weed')

local function cuttingDefaults()
    return { targetLabel = 'cut cocaine', targetIcon = 'knife' }
end

local function baggingDefaults()
    return { targetLabel = 'bag cocaine', targetIcon = 'box' }
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

local function cleanLabData(data)
    if type(data) ~= 'table' then return nil, 'Invalid data.' end
    local defaults = labDefaults()
    return {
        enterTarget = trim(data.enterTarget, 64) or defaults.enterTarget,
        exitTarget = trim(data.exitTarget, 64) or defaults.exitTarget,
    }
end

local function cleanProgressData(defaultsFn, data)
    if type(data) ~= 'table' then return nil, 'Invalid data.' end
    local clean = defaultsFn()
    local progress = type(data.progress) == 'table' and data.progress or {}
    local anim = type(data.anim) == 'table' and data.anim or {}

    if progress.time ~= nil then
        local n = inRange(progress.time, 500, 60000)
        if not n then return nil, 'Progress time must be between 500 and 60000 ms.' end
        clean.progress.time = math.floor(n)
    end
    clean.progress.label = trim(progress.label, 64) or clean.progress.label
    if type(progress.disable) == 'table' then
        clean.progress.disable = cleanDisable(progress.disable)
    end

    if anim.dict ~= nil then
        clean.anim.dict = animName(anim.dict)
        if not clean.anim.dict then return nil, 'Enter a valid animation dictionary.' end
    end
    if anim.clip ~= nil then
        clean.anim.clip = animName(anim.clip)
        if not clean.anim.clip then return nil, 'Enter a valid animation clip.' end
    end
    if anim.flag ~= nil then
        local n = inRange(anim.flag, 0, 65535)
        if not n then return nil, 'Animation flag must be between 0 and 65535.' end
        clean.anim.flag = math.floor(n)
    end

    clean.targetLabel = trim(data.targetLabel, 64) or clean.targetLabel
    clean.targetIcon = trim(data.targetIcon, 64) or clean.targetIcon
    return clean
end

local function progressCleaner(defaultsFn)
    return function(data) return cleanProgressData(defaultsFn, data) end
end

local cleanPowderData = progressCleaner(powderDefaults)
local cleanCrackCookData = progressCleaner(crackCookDefaults)
local cleanCrackBaggingData = progressCleaner(crackBaggingDefaults)
local cleanHeroinDryingData = progressCleaner(heroinDryingDefaults)
local cleanHeroinVialsData = progressCleaner(heroinVialsDefaults)
local cleanHeroinSyringeData = progressCleaner(heroinSyringeDefaults)
local cleanWeedDryingData = progressCleaner(weedDryingDefaults)
local cleanWeedBreakNugsData = progressCleaner(weedBreakNugsDefaults)
local cleanWeedBagData = progressCleaner(weedBagDefaults)

local function textCleaner(defaultsFn)
    return function(data)
        if type(data) ~= 'table' then return nil, 'Invalid data.' end
        local clean = defaultsFn()
        for key, default in pairs(clean) do
            clean[key] = trim(data[key], 64) or default
        end
        return clean
    end
end

local function textDefaults(template)
    return function()
        local copy = {}
        for key, value in pairs(template) do copy[key] = value end
        return copy
    end
end

local methPourDefaults = textDefaults({
    targetLabel = 'Pour Chemicals', targetIcon = 'fa-solid fa-flask',
    trayLabel = 'Grab Tray', trayIcon = 'fa-solid fa-hand-paper',
})
local methHeatDefaults = textDefaults({ targetLabel = 'Heat Chemicals', targetIcon = 'fa-solid fa-fire' })
local methSmashDefaults = textDefaults({ targetLabel = 'Smash Meth', targetIcon = 'fa-solid fa-hammer' })
local methBagDefaults = textDefaults({ targetLabel = 'Bag Meth', targetIcon = 'fa-solid fa-bag-shopping' })

local function weedPointSeed(step)
    return function()
        local steps = Config and Config.Weed and Config.Weed.steps
        local c = steps and steps[step] and steps[step].coords
        if not c then return {} end
        return { { coords = { x = c.x, y = c.y, z = c.z } } }
    end
end

local function noLocations() return {} end

local METH_STATION_PARTS = {
    pour = { 'coords', 'offset', 'rotation' },
    heat = { 'coords', 'explosion' },
    smash = { 'coords', 'offset', 'rotation', 'size', 'bucket' },
    bag = { 'coords', 'offset', 'rotation', 'size' },
}

local function methStationLocation(name)
    if name == 'pour' then
        return {
            coords = { x = 1006.09, y = -3200.59, z = -38.52 },
            offset = { x = 4.79, y = 2.13, z = -0.41 },
            rotation = { x = 0.0, y = 0.0, z = 0.0 },
        }
    elseif name == 'heat' then
        return {
            coords = { x = 1007.89, y = -3201.17, z = -38.99 },
            explosion = true,
        }
    elseif name == 'smash' then
        return {
            coords = { x = 1012.04, y = -3194.96, z = -38.99 },
            bucket = { x = 1012.86, y = -3194.13, z = -39.20, w = 90.0 },
            size = { x = 1.0, y = 1.0, z = 2.0 },
            offset = { x = -3.143311, y = -1.666748, z = -1.010128 },
            rotation = { x = 0.0, y = 0.0, z = 0.0 },
        }
    end
    return {
        coords = { x = 1014.25, y = -3194.93, z = -38.99 },
        size = { x = 1.0, y = 1.0, z = 2.0 },
        offset = { x = -4.9, y = -1.70, z = -1.01 },
        rotation = { x = 0.0, y = 0.0, z = 0.0 },
    }
end

local function limitedVec(value, limit)
    if type(value) ~= 'table' then return nil end
    local x, y, z = inRange(value.x, -limit, limit), inRange(value.y, -limit, limit), inRange(value.z, -limit, limit)
    if not (x and y and z) then return nil end
    return { x = x, y = y, z = z }
end

local methStationRules = {
    coords = { message = 'The position needs x, y and z.', required = true, clean = cleanVec },
    offset = { message = 'The offset needs x, y and z.', clean = function(v) return limitedVec(v, 500.0) end },
    rotation = { message = 'The rotation needs x, y and z (degrees).', clean = function(v) return limitedVec(v, 720.0) end },
    size = {
        message = 'The size needs x, y and z above 0.',
        clean = function(v)
            local size = limitedVec(v, 100.0)
            if size and size.x > 0 and size.y > 0 and size.z > 0 then return size end
        end,
    },
    bucket = {
        message = 'The bucket needs x, y, z and a heading.',
        clean = function(v)
            local bucket = cleanVec(v)
            local w = type(v) == 'table' and (v.w == nil and 0.0 or inRange(v.w, -720.0, 720.0))
            if not bucket or not w then return nil end
            bucket.w = w
            return bucket
        end,
    },
}

local function cleanMethStation(name)
    return function(value)
        if type(value) ~= 'table' then return nil, 'Invalid location.' end
        local defaults = methStationLocation(name)
        local clean = {}
        for _, part in ipairs(METH_STATION_PARTS[name]) do
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
                local rule = methStationRules[part]
                local result
                if given == nil and not rule.required then
                    result = defaults[part]
                else
                    result = rule.clean(given)
                end
                if not result then return nil, rule.message end
                clean[part] = result
            end
        end
        return clean
    end
end

local function readMethStation(name, raw)
    local clean = cleanMethStation(name)(decode(raw, {}))
    return clean or methStationLocation(name)
end

local function methStationEvent(name, defaultsFn)
    return {
        defaults = defaultsFn,
        cleanData = textCleaner(defaultsFn),
        cleanLocations = cleanMethStation(name),
        readLocations = function(raw) return readMethStation(name, raw) end,
        seedLocations = function() return methStationLocation(name) end,
        fillLocations = true,
    }
end


local MAX_CORNER_ITEMS = 500
local MAX_CORNER_PRICE = 1000000
local function cornerDefaults()
    local source = type(CornerSelling) == 'table' and CornerSelling or {}
    local pricing = {}
    for item, price in pairs(source.pricing or {}) do pricing[item] = price end
    return {
        maxSell = source.maxSell or 15,
        ripOff = source.ripOff or 0.2,
        minPolice = source.minPolice or 0,
        weedPercentAdjustable = source.weedPercentAdjustable ~= false,
        weedPercentFlow = source.weedPercentFlow or 0.2,
        pricing = pricing,
    }
end

local function cleanCornerData(data)
    if type(data) ~= 'table' then return nil, 'Invalid data.' end
    local clean = cornerDefaults()

    if data.maxSell ~= nil then
        local n = inRange(data.maxSell, 1, 1000)
        if not n then return nil, 'Max sell must be between 1 and 1000.' end
        clean.maxSell = math.floor(n)
    end
    if data.ripOff ~= nil then
        local n = inRange(data.ripOff, 0, 1)
        if not n then return nil, 'Rip-off must be between 0 and 1 (0.2 is 20%).' end
        clean.ripOff = n
    end
    if data.minPolice ~= nil then
        local n = inRange(data.minPolice, 0, 100)
        if not n then return nil, 'Minimum police must be between 0 and 100.' end
        clean.minPolice = math.floor(n)
    end
    if data.weedPercentAdjustable ~= nil then
        clean.weedPercentAdjustable = data.weedPercentAdjustable == true
    end
    if data.weedPercentFlow ~= nil then
        local n = inRange(data.weedPercentFlow, 0, 1)
        if not n then return nil, 'THC / CBD swing must be between 0 and 1 (0.2 is 20%).' end
        clean.weedPercentFlow = n
    end
    if data.pricing ~= nil then
        if type(data.pricing) ~= 'table' then return nil, 'Invalid pricing.' end
        local pricing, count = {}, 0
        for item, price in pairs(data.pricing) do
            if type(item) ~= 'string' or #item > 64 or not item:match('^[%w_%-%.]+$') then
                return nil, 'Invalid item name in the price list.'
            end
            local n = inRange(price, 0, MAX_CORNER_PRICE)
            if not n then
                return nil, ('The price for %s must be between 0 and %d.'):format(item, MAX_CORNER_PRICE)
            end
            count = count + 1
            if count > MAX_CORNER_ITEMS then return nil, 'Too many items in the price list.' end
            pricing[item] = math.floor(n)
        end
        clean.pricing = pricing
    end
    return clean
end

local function recipesDefaults()
    return { recipes = {} }
end

local function cleanGive(list)
    if type(list) ~= 'table' then return nil, 'Invalid item list.' end
    local clean, seen = {}, {}
    for _, entry in ipairs(list) do
        if #clean >= maxRecipeItems then return nil, 'Too many items in one recipe.' end
        local item = type(entry) == 'table' and trim(entry.item, 64)
        if not item or not item:match('^[%w_%-%.]+$') then return nil, 'Invalid item name.' end
        if seen[item] then return nil, ('%s is in the recipe twice.'):format(item) end
        seen[item] = true

        local amount = inRange(entry.amount, 1, maxRecipeAmount)
        if not amount then
            return nil, ('The amount for %s must be between 1 and %d.'):format(item, maxRecipeAmount)
        end
        clean[#clean + 1] = { item = item, amount = math.floor(amount), keep = entry.keep == true or nil }
    end
    return clean
end

local function cleanReceive(receive)
    if type(receive) ~= 'table' then return nil end
    local item = trim(receive.item, 64)
    if not item then return nil end
    if not item:match('^[%w_%-%.]+$') then return nil, 'Invalid item name.' end

    local amount = receive.amount == nil and 1 or inRange(receive.amount, 1, maxRecipeAmount)
    if not amount then return nil, ('The amount made must be between 1 and %d.'):format(maxRecipeAmount) end
    return { item = item, amount = math.floor(amount) }
end

local function validRecipeId(id)
    return type(id) == 'string' and #id <= 48 and id:match('^%a%w*:%a%w*$') ~= nil
end

local function cleanRecipeData(data)
    if type(data) ~= 'table' then return nil, 'Invalid data.' end
    local clean = recipesDefaults()
    for id, entry in pairs(type(data.recipes) == 'table' and data.recipes or {}) do
        if type(entry) == 'table' then
            local config = recipeInfo[id] and not recipeInfo[id].custom
            if entry.custom == true and validRecipeId(id) and not config then
                local give, giveErr = cleanGive(entry.give)
                if not give then return nil, giveErr end
                local receive, receiveErr = cleanReceive(entry.receive)
                if receiveErr then return nil, receiveErr end
                clean.recipes[id] = { custom = true, receive = receive, give = give }
            elseif config then
                local give, giveErr = cleanGive(entry.give)
                if not give then return nil, giveErr end
                clean.recipes[id] = { give = give }
            end
        end
    end
    return clean
end

local cleanCuttingData = textCleaner(cuttingDefaults)
local cleanBaggingData = textCleaner(baggingDefaults)

local customStep = 'Custom:settings'

local function customDrugsDefaults()
    return { drugs = {}, removed = {} }
end

-- drugs   = names made on the Custom drugs page
-- removed = base events (like 'Cocaine:powder') the admin deleted; they stay hidden and are not re-created on start
local function cleanCustomDrugs(data)
    if type(data) ~= 'table' then return nil, 'Invalid data.' end
    local clean, seen = customDrugsDefaults(), {}
    for _, name in ipairs(type(data.drugs) == 'table' and data.drugs or {}) do
        if type(name) == 'string' and #name <= 24 and name:match('^%a%w*$') and not seen[name:lower()] then
            seen[name:lower()] = true
            clean.drugs[#clean.drugs + 1] = name
        end
    end

    local gone = {}
    for _, step in ipairs(type(data.removed) == 'table' and data.removed or {}) do
        if type(step) == 'string' and #step <= 49 and step:match('^%w+:[%w_]+$') and not gone[step] then
            gone[step] = true
            clean.removed[#clean.removed + 1] = step
        end
    end
    return clean
end

local function customEventDefaults()
    local data = progressDefaults('Working', 'interact', 'BriefCase')()
    data.custom = true
    return data
end

local CUSTOM_EVENT = {
    defaults = customEventDefaults,
    cleanData = progressCleaner(customEventDefaults),
    cleanLocations = cleanPoints,
    readLocations = readPoints,
}

-- What the Custom drugs page saved: { drugs = {...}, removed = {...} }.
local function customRegistry()
    local rows = QB.sql.query('SELECT `data` FROM `qbdrugs` WHERE `step` = ? LIMIT 1', { customStep })
    local row = rows and rows[1]
    return (row and cleanCustomDrugs(decode(row.data, {}))) or customDrugsDefaults()
end

local function customDrugNames()
    return customRegistry().drugs
end

local function labEvent(seedLocations)
    return {
        permanent = true, -- entrances are never deleted
        defaults = labDefaults,
        cleanData = cleanLabData,
        cleanLocations = cleanEntrances,
        readLocations = function(raw) return NormalizeEntrances(decode(raw, {})) end,
        seedLocations = seedLocations,
    }
end


local EVENT_TYPES = {
    [customStep] = {
        permanent = true,
        defaults = customDrugsDefaults,
        cleanData = cleanCustomDrugs,
        fixedLocations = noLocations,
        readLocations = noLocations,
    },
    ['CornerSelling:settings'] = {
        permanent = true,
        defaults = cornerDefaults,
        cleanData = cleanCornerData,
        fixedLocations = noLocations,
        readLocations = noLocations,
    },
    [recipesStep] = {
        permanent = true,
        defaults = recipesDefaults,
        cleanData = cleanRecipeData,
        fixedLocations = noLocations,
        readLocations = noLocations,
        afterSave = function(data) applyRecipes(data.recipes) end,
    },
    ['Cocaine:lab'] = labEvent(),
    ['Meth:tele'] = labEvent(noLocations),
    ['Meth:pour'] = methStationEvent('pour', methPourDefaults),
    ['Meth:heat'] = methStationEvent('heat', methHeatDefaults),
    ['Meth:smash'] = methStationEvent('smash', methSmashDefaults),
    ['Meth:bag'] = methStationEvent('bag', methBagDefaults),
    ['Weed:lab'] = labEvent(noLocations),
    ['Weed:drying'] = {
        defaults = weedDryingDefaults,
        cleanData = cleanWeedDryingData,
        cleanLocations = cleanPoints,
        readLocations = readPoints,
        seedLocations = weedPointSeed('drying'),
    },
    ['Weed:breakNugs'] = {
        defaults = weedBreakNugsDefaults,
        cleanData = cleanWeedBreakNugsData,
        cleanLocations = cleanPoints,
        readLocations = readPoints,
        seedLocations = weedPointSeed('breakNugs'),
    },
    ['Weed:bagWeed'] = {
        defaults = weedBagDefaults,
        cleanData = cleanWeedBagData,
        cleanLocations = cleanPoints,
        readLocations = readPoints,
        seedLocations = weedPointSeed('bagWeed'),
    },
    ['Cocaine:powder'] = {
        defaults = powderDefaults,
        cleanData = cleanPowderData,
        cleanLocations = cleanPoints,
        readLocations = readPoints,
    },
    ['Crack:cook'] = {
        defaults = crackCookDefaults,
        cleanData = cleanCrackCookData,
        cleanLocations = cleanPoints,
        readLocations = readPoints,
    },
    ['Crack:bagging'] = {
        defaults = crackBaggingDefaults,
        cleanData = cleanCrackBaggingData,
        cleanLocations = cleanPoints,
        readLocations = readPoints,
    },
    ['Heroin:drying'] = {
        defaults = heroinDryingDefaults,
        cleanData = cleanHeroinDryingData,
        cleanLocations = cleanPoints,
        readLocations = readPoints,
    },
    ['Heroin:vials'] = {
        defaults = heroinVialsDefaults,
        cleanData = cleanHeroinVialsData,
        cleanLocations = cleanPoints,
        readLocations = readPoints,
    },
    ['Heroin:syringe'] = {
        defaults = heroinSyringeDefaults,
        cleanData = cleanHeroinSyringeData,
        cleanLocations = cleanPoints,
        readLocations = readPoints,
    },
    ['Cocaine:cutting'] = {
        defaults = cuttingDefaults,
        cleanData = cleanCuttingData,
        fixedLocations = cuttingLocation,
        readLocations = function() return cuttingLocation() end,
    },
    ['Cocaine:bagging'] = {
        defaults = baggingDefaults,
        cleanData = cleanBaggingData,
        fixedLocations = baggingLocation,
        readLocations = function() return baggingLocation() end,
    },
}

local RESERVED_STEPS = { pick = true, settings = true }

local function splitCustomStep(step)
    if type(step) ~= 'string' or #step > 49 then return end
    local drug, name = step:match('^(%a%w*):(%a[%w_]*)$')
    if drug and #drug <= 24 and #name <= 24 and not RESERVED_STEPS[name] then return drug, name end
end

local function takenDrugName(name)
    local lower = name:lower()
    for _, known in ipairs(customDrugNames()) do
        if known:lower() == lower then return true end
    end
    for drug in pairs(Config) do
        if type(drug) == 'string' and drug:lower() == lower then return true end
    end
    for step in pairs(EVENT_TYPES) do
        local drug = step:match('^(%w+):')
        if drug and drug:lower() == lower then return true end
    end
    return false
end

local function kindFor(step)
    if EVENT_TYPES[step] then return EVENT_TYPES[step] end
    local drug = splitCustomStep(step)
    if not drug then return end
    for _, known in ipairs(customDrugNames()) do
        if known == drug then return CUSTOM_EVENT end
    end
end

local function validStep(step)
    return kindFor(step) ~= nil
end

local function withRecipe(step, data, chosen)
    local default = defaultRecipes[step]
    if default then
        data.recipe = recipeInfo[chosen] and chosen or default
    elseif data.custom then
        data.recipe = recipeInfo[chosen] and chosen or nil
    end
    return data
end

local function getEvent(step)
    local kind = kindFor(step)
    local rows = QB.sql.query('SELECT * FROM `qbdrugs` WHERE `step` = ? LIMIT 1', { step })
    local row = rows and rows[1]
    if not row then
        return { data = withRecipe(step, kind.defaults()), locations = kind.readLocations(nil) }, false
    end
    local stored = decode(row.data, {})
    local data = withRecipe(step, kind.cleanData(stored) or kind.defaults(), stored.recipe)
    return { data = data, locations = kind.readLocations(row.locations) }, true
end

local function saveEvent(step, patch)
    if not validStep(step) then return fail('Unknown event.') end
    if type(patch) ~= 'table' then return fail('Nothing to save.') end

    local kind = kindFor(step)
    local event, exists = getEvent(step)
    local data, locations = event.data, event.locations

    if patch.data ~= nil then
        local dataErr
        data, dataErr = kind.cleanData(patch.data)
        if not data then return fail(dataErr) end
        withRecipe(step, data, patch.data.recipe)
    end
    if kind.fixedLocations then
        locations = kind.fixedLocations()
    elseif patch.locations ~= nil then
        local locErr
        locations, locErr = kind.cleanLocations(patch.locations)
        if not locations then return fail(locErr) end
    end

    local ok, saveErr
    if exists then
        ok, saveErr = QB.sql.update(
            'UPDATE `qbdrugs` SET `data` = ?, `locations` = ? WHERE `step` = ?',
            { json.encode(data), json.encode(locations), step }
        )
    else
        ok, saveErr = QB.sql.update(
            'INSERT INTO `qbdrugs` (`step`, `data`, `locations`) VALUES (?, ?, ?)',
            { step, json.encode(data), json.encode(locations) }
        )
    end
    if not ok then return fail(saveErr or 'Failed to save.') end

    local reloaded, reloadErr = pcall(function() exports[GetCurrentResourceName()]:ReloadEvents(step) end)
    if not reloaded then
        QB.print.warn(('[qbdrugs] creator could not reload events: %s'):format(tostring(reloadErr)))
    end
    if kind.afterSave then kind.afterSave(data) end
    return { step = step, data = data, locations = locations }
end

local function adminCallback(name, handler)
    QB.callback.register(name, function(src, ...)
        local allowed, err = adminOnly(src)
        if not allowed then return false, err end
        return handler(src, ...)
    end)
end

adminCallback('qbdrugs:creator:event:get', function(_, step)
    if not validStep(step) then return fail('Unknown event.') end

    local event = getEvent(step)
    return { step = step, data = event.data, locations = event.locations }
end)

adminCallback('qbdrugs:creator:event:save', function(_, step, patch)
    return saveEvent(step, patch)
end)


local CORNER_STEP = 'CornerSelling:settings'
local MAX_ITEM_RESULTS = 24

local function allItems()
    local ok, items = pcall(function() return exports['qb-core']:GetShared('Items') end)
    if ok and type(items) == 'table' then return items end
    ok, items = pcall(function() return exports.qbcore:getShared('items') end)
    if ok and type(items) == 'table' then return items end
    return {}
end

local function itemImage(info)
    return type(info.image) == 'string' and info.image ~= '' and ('nui://qbinventory/images/' .. info.image) or nil
end

local function itemEntry(shared, name)
    local info = shared[name]
    if type(info) ~= 'table' then return nil end
    return { label = tostring(info.label or name), image = itemImage(info) }
end

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

    table.sort(results, function(a, b)
        local la, lb = a.label:lower(), b.label:lower()
        if la ~= lb then return la < lb end
        return a.name < b.name
    end)

    local total = #results
    while #results > MAX_ITEM_RESULTS do results[#results] = nil end
    return { results = results, total = total }
end

adminCallback('qbdrugs:creator:corner:get', function()
    local event = getEvent(CORNER_STEP)
    local shared, items = allItems(), {}
    for name in pairs(event.data.pricing or {}) do
        items[name] = itemEntry(shared, name)
    end
    return { step = CORNER_STEP, data = event.data, items = items }
end)

adminCallback('qbdrugs:creator:corner:search', function(_, query)
    local priced = getEvent(CORNER_STEP).data.pricing or {}
    return searchItems(query, function(name) return priced[name] ~= nil end)
end)

local function effectiveGive(saved, id)
    local entry = saved[id]
    return entry and entry.give or copyGive(recipeInfo[id].defaultGive)
end

local function recipesPayload()
    local saved = getEvent(recipesStep).data.recipes or {}
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
            edited = saved[id] ~= nil and not info.custom, custom = info.custom == true,
        }
    end
    return { list = list, items = items }
end

adminCallback('qbdrugs:creator:recipes:get', recipesPayload)

adminCallback('qbdrugs:creator:recipes:search', function(_, query, id)
    if not recipeInfo[id] then return fail('Unknown recipe.') end

    local inRecipe = {}
    for _, entry in ipairs(effectiveGive(getEvent(recipesStep).data.recipes or {}, id)) do
        inRecipe[entry.item] = true
    end
    return searchItems(query, function(name) return inRecipe[name] == true end)
end)

adminCallback('qbdrugs:creator:recipes:set', function(_, id, give)
    if not recipeInfo[id] then return fail('Unknown recipe.') end

    local clean, cleanErr = cleanGive(give)
    if not clean then return fail(cleanErr) end

    local data = getEvent(recipesStep).data
    data.recipes = data.recipes or {}

    local current = {}
    for _, entry in ipairs(effectiveGive(data.recipes, id)) do current[entry.item] = true end
    for _, entry in ipairs(clean) do
        if not current[entry.item] and not itemExists(entry.item) then
            return fail(('%s does not exist.'):format(entry.item))
        end
    end

    local entry = data.recipes[id] or {}
    entry.give = clean
    data.recipes[id] = entry
    local saved, saveErr = saveEvent(recipesStep, { data = data })
    if not saved then return fail(saveErr) end
    return recipesPayload()
end)

adminCallback('qbdrugs:creator:recipes:create', function(_, drug, name, item, amount)
    drug, name = trim(drug, 24), trim(name, 24)
    local id = drug and name and (drug .. ':' .. name)
    if not validRecipeId(id) then
        return fail('Name must be letters and numbers only, starting with a letter.')
    end
    if recipeInfo[id] then return fail('That recipe already exists.') end

    local receive, receiveErr = cleanReceive({ item = item, amount = amount })
    if receiveErr then return fail(receiveErr) end
    if receive and not itemExists(receive.item) then return fail(('%s does not exist.'):format(receive.item)) end

    local data = getEvent(recipesStep).data
    data.recipes = data.recipes or {}
    data.recipes[id] = { custom = true, receive = receive, give = {} }

    local saved, saveErr = saveEvent(recipesStep, { data = data })
    if not saved then return fail(saveErr) end

    local payload = recipesPayload()
    payload.id = id
    return payload
end)

adminCallback('qbdrugs:creator:recipes:receive', function(_, id, item, amount)
    if not (recipeInfo[id] and recipeInfo[id].custom) then return fail('Only recipes made here can change what they make.') end

    local receive, receiveErr = cleanReceive({ item = item, amount = amount })
    if receiveErr then return fail(receiveErr) end
    if receive and not itemExists(receive.item) then return fail(('%s does not exist.'):format(receive.item)) end

    local data = getEvent(recipesStep).data
    local entry = data.recipes and data.recipes[id]
    if not entry then return fail('Unknown recipe.') end
    entry.receive = receive

    local saved, saveErr = saveEvent(recipesStep, { data = data })
    if not saved then return fail(saveErr) end
    return recipesPayload()
end)

adminCallback('qbdrugs:creator:recipes:delete', function(_, id)
    if not (recipeInfo[id] and recipeInfo[id].custom) then return fail('Only recipes made here can be deleted.') end

    local data = getEvent(recipesStep).data
    if not (data.recipes and data.recipes[id]) then return fail('Unknown recipe.') end
    data.recipes[id] = nil

    local saved, saveErr = saveEvent(recipesStep, { data = data })
    if not saved then return fail(saveErr) end
    return recipesPayload()
end)

local function customPayload()
    local drugs, byName = {}, {}
    for _, name in ipairs(customDrugNames()) do
        byName[name] = { name = name, events = {} }
        drugs[#drugs + 1] = byName[name]
    end

    for _, row in ipairs(QB.sql.query('SELECT `step`, `data` FROM `qbdrugs`') or {}) do
        local drug, name = splitCustomStep(row.step)
        if drug and byName[drug] and decode(row.data, {}).custom == true then
            table.insert(byName[drug].events, { step = row.step, name = name })
        end
    end

    for _, entry in ipairs(drugs) do
        table.sort(entry.events, function(a, b) return a.name < b.name end)
    end
    return { drugs = drugs, removed = customRegistry().removed }
end

local function dropEvent(step)
    local ok, err = QB.sql.update('DELETE FROM `qbdrugs` WHERE `step` = ?', { step })
    if not ok then return false, err end
    pcall(function() exports[GetCurrentResourceName()]:ReloadEvents(step) end)
    return true
end

adminCallback('qbdrugs:creator:custom:get', function()
    return customPayload()
end)

adminCallback('qbdrugs:creator:custom:drug:create', function(_, name)
    name = trim(name, 25)
    if not (name and #name <= 24 and name:match('^%a%w*$')) then
        return fail('Name must be letters and numbers only, starting with a letter, 24 at most.')
    end
    if takenDrugName(name) then return fail('That name is already used.') end

    local data = getEvent(customStep).data
    data.drugs[#data.drugs + 1] = name
    local saved, saveErr = saveEvent(customStep, { data = data })
    if not saved then return fail(saveErr) end

    local payload = customPayload()
    payload.name = name
    return payload
end)

adminCallback('qbdrugs:creator:custom:drug:delete', function(_, name)
    local data = getEvent(customStep).data
    local kept, found = {}, false
    for _, known in ipairs(data.drugs) do
        if known == name then found = true else kept[#kept + 1] = known end
    end
    if not found then return fail('Unknown drug.') end

    for _, drug in ipairs(customPayload().drugs) do
        if drug.name == name then
            for _, event in ipairs(drug.events) do
                local ok, err = dropEvent(event.step)
                if not ok then return fail(err or 'Failed to delete an event.') end
            end
        end
    end

    data.drugs = kept
    local saved, saveErr = saveEvent(customStep, { data = data })
    if not saved then return fail(saveErr) end
    return customPayload()
end)

adminCallback('qbdrugs:creator:custom:event:create', function(_, drug, name)
    name = trim(name, 25)
    if not (name and #name <= 24 and name:match('^%a[%w_]*$')) then
        return fail('Name must be letters, numbers and _, starting with a letter, 24 at most.')
    end

    local step = tostring(drug) .. ':' .. name
    if kindFor(step) ~= CUSTOM_EVENT then return fail('Unknown drug, or that name is not allowed.') end

    for _, entry in ipairs(customPayload().drugs) do
        if entry.name == drug then
            for _, event in ipairs(entry.events) do
                if event.name:lower() == name:lower() then return fail('That event already exists.') end
            end
        end
    end

    local saved, saveErr = saveEvent(step, { data = { targetLabel = name, progress = { label = name } } })
    if not saved then return fail(saveErr) end

    local payload = customPayload()
    payload.step = step
    return payload
end)

-- Creates (or fills in) the row of an event that has a fixed or known first location. A row that is
-- already complete is never touched.
local function seedEvent(step, kind)
    local initial = kind.fixedLocations or kind.seedLocations
    if not initial then return end

    local readOk, rows = pcall(QB.sql.query, 'SELECT * FROM `qbdrugs` WHERE `step` = ? LIMIT 1', { step })
    if not readOk then
        QB.print.warn(('[qbdrugs] could not read %s: %s'):format(step, tostring(rows)))
        return
    end

    local row = rows and rows[1]
    local sql, params, what

    if not row then
        what = 'created default row'
        sql = 'INSERT INTO `qbdrugs` (`step`, `data`, `locations`) VALUES (?, ?, ?)'
        params = { step, json.encode(kind.defaults()), json.encode(initial()) }
    elseif kind.fillLocations and not decode(row.locations, {}).coords then
        what = 'filled the position of'
        sql = 'UPDATE `qbdrugs` SET `locations` = ? WHERE `step` = ?'
        params = { json.encode(initial()), step }
    end
    if not what then return end

    local writeOk, ok, writeErr = pcall(QB.sql.update, sql, params)
    if writeOk and ok then
        QB.print.warn(('[qbdrugs] %s %s'):format(what, step))
        pcall(function() exports[GetCurrentResourceName()]:ReloadEvents(step) end)
    else
        QB.print.warn(('[qbdrugs] could not write %s: %s'):format(step, tostring(writeOk and writeErr or ok)))
    end
end

-- Base events (everything in EVENT_TYPES except entrances and settings) can be deleted too: the row is
-- removed and the step is remembered, so it stays hidden and isn't re-created on start.
local function removable(step)
    local kind = type(step) == 'string' and EVENT_TYPES[step]
    return kind and not kind.permanent
end

adminCallback('qbdrugs:creator:event:delete', function(_, step)
    if not removable(step) then return fail('This event cannot be deleted.') end

    local data = customRegistry()
    for _, known in ipairs(data.removed) do
        if known == step then return customPayload() end
    end

    local ok, err = dropEvent(step)
    if not ok then return fail(err or 'Failed to delete the event.') end

    data.removed[#data.removed + 1] = step
    local saved, saveErr = saveEvent(customStep, { data = data })
    if not saved then return fail(saveErr) end
    return customPayload()
end)

adminCallback('qbdrugs:creator:event:restore', function(_, step)
    if not removable(step) then return fail('This event cannot be restored.') end

    local data = customRegistry()
    local kept = {}
    for _, known in ipairs(data.removed) do
        if known ~= step then kept[#kept + 1] = known end
    end
    data.removed = kept

    local saved, saveErr = saveEvent(customStep, { data = data })
    if not saved then return fail(saveErr) end

    seedEvent(step, EVENT_TYPES[step]) -- events with a fixed position get their row back right away
    pcall(function() exports[GetCurrentResourceName()]:ReloadEvents(step) end)
    return customPayload()
end)

adminCallback('qbdrugs:creator:custom:event:delete', function(_, step)
    if kindFor(step) ~= CUSTOM_EVENT then return fail('Only custom events can be deleted.') end
    local ok, err = dropEvent(step)
    if not ok then return fail(err or 'Failed to delete the event.') end
    return customPayload()
end)

CreateThread(function()
    Wait(1000)
    while GetResourceState('qbsql') ~= 'started' do Wait(500) end

    -- events the admin deleted stay deleted
    local skip = {}
    local okRegistry, registry = pcall(customRegistry)
    for _, step in ipairs(okRegistry and registry.removed or {}) do skip[step] = true end

    for step, kind in pairs(EVENT_TYPES) do
        if not skip[step] then seedEvent(step, kind) end
    end
end)

RegisterCommand('drugCreator', function(source, args)
    assert(adminOnly(source), 'Player: ' .. tostring(source) .. ' Tried To Open The Drug Creator')
    TriggerClientEvent('qbdrugs:creator:open', source)
end, false)