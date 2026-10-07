-- server/Creator.lua
-- Admin-only callbacks behind the plant creator (client/Creator.lua).
-- Reads and writes the `qbdrugs` rows (step = '<Type>:pick') and asks
-- plantSpawns.lua to reload so clients pick up the change.

local MAX_SPOTS = 200 -- most spots one plant type may have

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

-- Animation dictionaries and clips are plain names such as 'mp_arresting' or 'anim@heists@box_carry@'.
local function animName(value)
    local name = trim(value, 64)
    return name and name:match('^[%w_@%-%.]+$') and name or nil
end

-- number in [min, max], or nil. Rejects NaN, inf and non-numbers.
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

-- Row -> what the client edits. Locations are reduced to plain { coords = {x,y,z} }
-- so the runtime-only `taken` flag never leaves the server.
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

-- Applies a whitelist of settings onto the stored data, leaving everything else
-- (pickingData.anim, pickingData.disable, ...) untouched.
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
        data.icon = trim(s.icon, 64) -- empty clears it
    end
    if s.targetLabel ~= nil then
        data.targetLabel = trim(s.targetLabel, 64) -- empty clears it, falls back to the locale text
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
        picking.anim.flags = nil -- older entries used "flags"; one key is enough
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
    -- plant types publish to GlobalState[name] and GlobalState[name .. 'Data']
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
-- Events (rows that are not plants, e.g. step = 'Cocaine:lab')
--
--   Cocaine:lab      locations = [ { enter, exit, gang? } ]
--   Cocaine:powder   locations = [ { coords, object?, gang? } ]   (coords = x,y,z and w when aimed at an object; object = prop model; gang = who may use it)
--   Crack:cook       same layout as powder
--   Crack:bagging    same layout as powder
--   Heroin:drying, Heroin:vials, Heroin:syringe   same layout as powder
--   Cocaine:cutting  locations = { coords, offset, rotation }  (one object, fixed, never edited)
--   Cocaine:bagging  same layout as cutting
--   Meth:tele        same layout as Cocaine:lab (many entrances, one exit)
--   Meth:pour/heat/smash/bag   target text only, locations = []
--   Weed:lab         same layout as Cocaine:lab (many entrances, one exit)
--   Weed:drying, Weed:breakNugs, Weed:bagWeed   same layout as powder
--
-- To add another event: add a row to EVENT_TYPES below and an entry to EVENTS in client/creator.lua.

local MAX_EVENT_LOCATIONS = 50
local COORD_LIMIT = 10000.0 -- GTA's map is well inside this

local function cleanVec(value)
    if type(value) ~= 'table' then return nil end
    local x, y, z = inRange(value.x, -COORD_LIMIT, COORD_LIMIT), inRange(value.y, -COORD_LIMIT, COORD_LIMIT), inRange(value.z, -COORD_LIMIT, COORD_LIMIT)
    if not (x and y and z) then return nil end
    return { x = x, y = y, z = z }
end

-- gang is optional: '' (or nothing) means the entrance is open to everyone.
local function cleanGang(value)
    local gang = trim(value, 32)
    if not gang then return nil end
    return gang:match('^[%w_%-]+$') and gang or false
end

-- One entry per entrance: { enter = {x,y,z}, exit = {x,y,z}, gang = 'name' | nil }.
-- Entrances may share the same exit (many doors, one room).
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
        result[#result + 1] = { enter = enter, exit = exit, gang = gang } -- gang = nil is dropped from the JSON
    end
    return result
end

-- Point coords: {x,y,z} plus an optional heading w, so object placements keep the vec4 they were aimed as.
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

-- Prop model name, optional: '' or nothing = none, anything odd = false.
local function cleanObject(value)
    local object = trim(value, 64)
    if not object then return nil end
    return object:match('^[%w_%-%.]+$') and object or false
end

-- One entry per spot: { coords = {x,y,z}, object = 'model' | nil, gang = 'name' | nil }
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
        result[#result + 1] = { coords = coords, object = object, gang = gang } -- nil values are dropped from the JSON
    end
    return result
end

-- Same as cleanPoints, but skips bad entries instead of failing (used when reading a stored row).
local function readPoints(raw)
    local result = {}
    for _, entry in ipairs(decode(raw, {})) do
        local coords = type(entry) == 'table' and cleanPointCoords(entry.coords)
        if coords then result[#result + 1] = { coords = coords, object = cleanObject(entry.object) or nil, gang = cleanGang(entry.gang) or nil } end
    end
    return result
end

-- Keys the progress bar may disable. Accepts { move = true } or { 'move' }.
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

-- Defaults ---------------------------------------------------------------------------

local function labDefaults()
    return { enterTarget = 'Enter Lab', exitTarget = 'Exit Lab' }
end

-- Events with a progress bar and animation (powder, crack cook, crack bagging).
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

-- do not touch | like seriously no touch
local function cuttingLocation()
    return {
        coords = { x = 1095.61, y = -3195.62, z = -39.13 },
        offset = { x = -1.782227, y = 0.445068, z = -0.502701 },
        rotation = { x = 0.0, y = 0.0, z = 0.0 },
    }
end

-- do not touch | like seriously no touch
local function baggingLocation()
    return {
        coords = { x = 1093.16, y = -3195.78, z = -39.19 },
        offset = { x = 4.515137, y = 2.542969, z = -0.814194 },
        rotation = { x = 0.0, y = 0.0, z = 180.0 },
    }
end

-- Data cleaners: take what the creator (or the database) holds, return the clean table
-- with defaults filled in, or nil and a message.

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

-- Events that only have target text (cutting, bagging, meth steps). Every key in the
-- defaults is a trimmed string (max 64) that falls back to its default.
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

-- Defaults for a text-only event: a function that returns a fresh copy of `template`.
local function textDefaults(template)
    return function()
        local copy = {}
        for key, value in pairs(template) do copy[key] = value end
        return copy
    end
end

-- Meth text, same as the locale file.
local methPourDefaults = textDefaults({
    targetLabel = 'Pour Chemicals', targetIcon = 'fa-solid fa-flask',
    trayLabel = 'Grab Tray', trayIcon = 'fa-solid fa-hand-paper',
})
local methHeatDefaults = textDefaults({ targetLabel = 'Heat Chemicals', targetIcon = 'fa-solid fa-fire' })
local methSmashDefaults = textDefaults({ targetLabel = 'Smash Meth', targetIcon = 'fa-solid fa-hammer' })
local methBagDefaults = textDefaults({ targetLabel = 'Bag Meth', targetIcon = 'fa-solid fa-bag-shopping' })

-- The meth lab's current entrance and exit, used to create the first row.
local function methTeleSeed()
    local tele = Config and Config.Meth and Config.Meth.Steps and Config.Meth.Steps.Tele
    if not (tele and tele.outside and tele.inside) then return {} end
    return {
        {
            enter = { x = tele.outside.x, y = tele.outside.y, z = tele.outside.z },
            exit = { x = tele.inside.x, y = tele.inside.y, z = tele.inside.z },
        },
    }
end

-- The weed lab's current entrance and exit, used to create the first row.
local function weedLabSeed()
    local steps = Config and Config.Weed and Config.Weed.steps
    if not (steps and steps.enterLab and steps.exitLab) then return {} end
    return {
        {
            enter = { x = steps.enterLab.x, y = steps.enterLab.y, z = steps.enterLab.z },
            exit = { x = steps.exitLab.x, y = steps.exitLab.y, z = steps.exitLab.z },
        },
    }
end

-- A weed station's current position (steps.drying / breakNugs / bagWeed), used to create the first row.
local function weedPointSeed(step)
    return function()
        local steps = Config and Config.Weed and Config.Weed.steps
        local c = steps and steps[step] and steps[step].coords
        if not c then return {} end
        return { { coords = { x = c.x, y = c.y, z = c.z } } }
    end
end

local function noLocations() return {} end

-- Cornerselling ---------------------------------------------------------------------------
-- One row, 'CornerSelling:settings', holds every cornerselling value:
--   data = { maxSell, ripOff, minPolice, weedPercentAdjustable, weedPercentFlow, pricing = { [item] = cash } }
-- The starting values come from CornerSelling in shared/config.lua (copied once, on first start).

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

-- Any value left out keeps its starting value; `pricing` is replaced as a whole, so the creator
-- always sends the full list.
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

local cleanCuttingData = textCleaner(cuttingDefaults)
local cleanBaggingData = textCleaner(baggingDefaults)

-- One row per event.
--   defaults       fresh default data
--   cleanData      validates data coming from the creator
--   cleanLocations validates locations coming from the creator (nil = locations can't be edited)
--   readLocations  turns the stored locations text into what the creator shows
--   fixedLocations when set, this is always what gets stored, whatever the creator sends
--   seedLocations  when set, the row is created with this on start if it doesn't exist yet
--
-- Shared shapes, so a new event is one line:
--   labEvent(seed)      many entrances, one exit (data = enterTarget / exitTarget)
--   textEvent(defaults) target text only, no locations

local function labEvent(seedLocations)
    return {
        defaults = labDefaults,
        cleanData = cleanLabData,
        cleanLocations = cleanEntrances,
        readLocations = function(raw) return NormalizeEntrances(decode(raw, {})) end,
        seedLocations = seedLocations,
    }
end

local function textEvent(defaultsFn)
    return {
        defaults = defaultsFn,
        cleanData = textCleaner(defaultsFn),
        fixedLocations = noLocations,
        readLocations = noLocations,
    }
end

local EVENT_TYPES = {
    ['CornerSelling:settings'] = {
        defaults = cornerDefaults,
        cleanData = cleanCornerData,
        fixedLocations = noLocations,
        readLocations = noLocations,
    },
    ['Cocaine:lab'] = labEvent(),
    ['Meth:tele'] = labEvent(methTeleSeed),
    ['Meth:pour'] = textEvent(methPourDefaults),
    ['Meth:heat'] = textEvent(methHeatDefaults),
    ['Meth:smash'] = textEvent(methSmashDefaults),
    ['Meth:bag'] = textEvent(methBagDefaults),
    ['Weed:lab'] = labEvent(weedLabSeed),
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

local function validStep(step)
    return type(step) == 'string' and EVENT_TYPES[step] ~= nil
end

local function getEvent(step)
    local kind = EVENT_TYPES[step]
    local rows = QB.sql.query('SELECT * FROM `qbdrugs` WHERE `step` = ? LIMIT 1', { step })
    local row = rows and rows[1]
    if not row then
        return { data = kind.defaults(), locations = kind.readLocations(nil) }, false
    end
    -- a stored row that no longer validates falls back to the defaults
    local data = kind.cleanData(decode(row.data, {})) or kind.defaults()
    return { data = data, locations = kind.readLocations(row.locations) }, true
end

QB.callback.register('qbdrugs:creator:event:get', function(src, step)
    local allowed, err = adminOnly(src)
    if not allowed then return false, err end
    if not validStep(step) then return fail('Unknown event.') end

    local event = getEvent(step)
    return { step = step, data = event.data, locations = event.locations }
end)

QB.callback.register('qbdrugs:creator:event:save', function(src, step, patch)
    local allowed, err = adminOnly(src)
    if not allowed then return false, err end
    if not validStep(step) then return fail('Unknown event.') end
    if type(patch) ~= 'table' then return fail('Nothing to save.') end

    local kind = EVENT_TYPES[step]
    local event, exists = getEvent(step)
    local data, locations = event.data, event.locations

    if patch.data ~= nil then
        local dataErr
        data, dataErr = kind.cleanData(patch.data)
        if not data then return fail(dataErr) end
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
    return { step = step, data = data, locations = locations }
end)

-- Cornerselling item picker -----------------------------------------------------------------
-- The settings and the price list are saved through qbdrugs:creator:event:save
-- ('CornerSelling:settings'). These two callbacks only add what the item picker needs.

local CORNER_STEP = 'CornerSelling:settings'
local MAX_ITEM_RESULTS = 24

-- Every item the server knows about, keyed by item name.
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

-- The stored settings plus the label and image of every priced item.
QB.callback.register('qbdrugs:creator:corner:get', function(src)
    local allowed, err = adminOnly(src)
    if not allowed then return false, err end

    local event = getEvent(CORNER_STEP)
    local shared, items = allItems(), {}
    for name in pairs(event.data.pricing or {}) do
        local info = shared[name]
        if type(info) == 'table' then
            items[name] = { label = tostring(info.label or name), image = itemImage(info) }
        end
    end
    return { step = CORNER_STEP, data = event.data, items = items }
end)

-- Items whose name or label contains `query`, best first, with a flag for the ones already priced.
QB.callback.register('qbdrugs:creator:corner:search', function(src, query)
    local allowed, err = adminOnly(src)
    if not allowed then return false, err end

    query = trim(query, 64)
    if not query then return fail('Type part of an item name or label to search.') end
    local needle = query:lower()

    local priced = getEvent(CORNER_STEP).data.pricing or {}
    local results = {}
    for name, info in pairs(allItems()) do
        if type(name) == 'string' and type(info) == 'table' then
            local label = tostring(info.label or name)
            if name:lower():find(needle, 1, true) or label:lower():find(needle, 1, true) then
                results[#results + 1] = { name = name, label = label, image = itemImage(info), added = priced[name] ~= nil }
            end
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
end)

-- Events with a fixed position (cutting, bagging, meth steps) or a known first entrance
-- (Meth:tele) get their row created on start, so they work without anyone opening the
-- creator. An existing row is never touched.
CreateThread(function()
    Wait(1000) -- let events.lua publish first; ReloadEvents below then pushes the new rows
    for step, kind in pairs(EVENT_TYPES) do
        local initial = kind.fixedLocations or kind.seedLocations
        if initial then
            local rows = QB.sql.query('SELECT `step` FROM `qbdrugs` WHERE `step` = ? LIMIT 1', { step })
            if not (rows and rows[1]) then
                local ok, insertErr = QB.sql.update(
                    'INSERT INTO `qbdrugs` (`step`, `data`, `locations`) VALUES (?, ?, ?)',
                    { step, json.encode(kind.defaults()), json.encode(initial()) }
                )
                if ok then
                    QB.print.warn(('[qbdrugs] created default row %s'):format(step))
                    pcall(function() exports[GetCurrentResourceName()]:ReloadEvents(step) end)
                else
                    QB.print.warn(('[qbdrugs] could not create %s: %s'):format(step, tostring(insertErr)))
                end
            end
        end
    end
end)