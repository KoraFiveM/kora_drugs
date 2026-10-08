local APP_ID = 'qbdrugs:creator'
local COMMAND = Config.creatorCommand or 'plantcreator'

local selected = nil
local selectedEvent = nil
local currentView = 'plants'
local pendingTool = nil

-- Cornerselling page: the stored settings, a label/image for every priced item, and the last search.
local CORNER_STEP = 'CornerSelling:settings'
local corner = { data = nil, items = {}, query = nil, results = {}, total = 0 }

-- Event types the creator can edit. Add the next event here (and in server/creator.lua).
-- kind picks which editor the event gets:
--   'lab'    many entrances, one exit (`exit` is where every entrance leads)
--   'points' placeable locations with progress bar + animation (text defaults in `points`)
--   'text'   target text only, position fixed (fields in `text`)
--   'station' target text (fields in `text`) plus an editable position: coords, and the parts listed in
--            `station` ('offset', 'rotation', 'size', 'bucket', 'explosion')
local COCAINE_LAB_EXIT = { x = 1088.81, y = -3187.57, z = -38.99 }
local METH_LAB_EXIT = { x = 996.91, y = -3200.83, z = -36.39 }
local WEED_LAB_EXIT = { x = 1066.4, y = -3183.36, z = -39.16 }

-- { 'Pour', 'targetLabel', 'targetIcon', 'Pour Chemicals', 'fa-solid fa-flask' }, ... -> label + icon field per entry
local function targetFields(...)
    local fields = {}
    for _, t in ipairs({ ... }) do
        fields[#fields + 1] = { id = t[2], label = t[1] .. ' label', default = t[4] }
        fields[#fields + 1] = { id = t[3], label = t[1] .. ' icon', default = t[5] }
    end
    return fields
end

local EVENTS = {
    { step = 'Cocaine:lab',     kind = 'lab',     label = 'Cocaine Entrance', icon = 'Door', exit = COCAINE_LAB_EXIT },
    { step = 'Meth:tele',       kind = 'lab',     label = 'Meth Entrance',    icon = 'Door', exit = METH_LAB_EXIT },
    { step = 'Weed:lab',        kind = 'lab',     label = 'Weed Entrance',    icon = 'Door', exit = WEED_LAB_EXIT },
    { step = 'Cocaine:powder',  kind = 'points',  label = 'Cocaine Powder',   icon = 'Briefcase',
      points = { noun = 'make powder', progress = 'Making Raw Cocaine', label = 'make powder', icon = 'BriefCase' } },
    { step = 'Crack:cook',      kind = 'points',  label = 'Crack Cook',       icon = 'Flame',
      points = { noun = 'cook crack', progress = 'Cooking Crack', label = 'cook crack', icon = 'crack' } },
    { step = 'Crack:bagging',   kind = 'points',  label = 'Crack Bagging',    icon = 'Package',
      points = { noun = 'bag crack', progress = 'Bagging Crack', label = 'bag crack', icon = 'crack' } },
    { step = 'Heroin:drying',   kind = 'points',  label = 'Heroin Drying',    icon = 'Wind',
      points = { noun = 'dry poppies', progress = 'Drying Poppies', label = 'Dry Poppies', icon = 'poppy' } },
    { step = 'Heroin:vials',    kind = 'points',  label = 'Heroin Vials',     icon = 'FlaskConical',
      points = { noun = 'fill heroin vials', progress = 'Filling Heroin Vials', label = 'Fill Heroin Vials', icon = 'poppy' } },
    { step = 'Heroin:syringe',  kind = 'points',  label = 'Heroin Syringe',   icon = 'Syringe',
      points = { noun = 'make heroin syringes', progress = 'Making Heroin Syringe', label = 'Make Heroin Syringe', icon = 'poppy' } },
    { step = 'Weed:drying',     kind = 'points',  label = 'Weed Drying',      icon = 'Wind',
      points = { noun = 'dry weed', progress = 'Drying Weed', label = 'Dry Weed', icon = 'weed' } },
    { step = 'Weed:breakNugs',  kind = 'points',  label = 'Weed Break Down',  icon = 'Scissors',
      points = { noun = 'break down weed', progress = 'Breaking Down Weed', label = 'Break Down Weed', icon = 'weed' } },
    { step = 'Weed:bagWeed',    kind = 'points',  label = 'Weed Bagging',     icon = 'Package',
      points = { noun = 'bag weed', progress = 'Bagging Weed', label = 'Bag Weed', icon = 'weed' } },
    { step = 'Cocaine:cutting', kind = 'text',    label = 'Cocaine Cutting',  icon = 'Scissors',
      text = { noun = 'cutting table', fields = targetFields({ 'Target', 'targetLabel', 'targetIcon', 'cut cocaine', 'knife' }) } },
    { step = 'Cocaine:bagging', kind = 'text',    label = 'Cocaine Bagging',  icon = 'Package',
      text = { noun = 'bagging table', fields = targetFields({ 'Target', 'targetLabel', 'targetIcon', 'bag cocaine', 'box' }) } },
    { step = 'Meth:pour',       kind = 'station', label = 'Meth Pour & Tray', icon = 'FlaskConical',
      station = { 'coords', 'offset', 'rotation' },
      text = { noun = 'pour station (pour and tray targets)', fields = targetFields(
          { 'Pour', 'targetLabel', 'targetIcon', 'Pour Chemicals', 'fa-solid fa-flask' },
          { 'Tray', 'trayLabel', 'trayIcon', 'Grab Tray', 'fa-solid fa-hand-paper' }) } },
    { step = 'Meth:heat',       kind = 'station', label = 'Meth Heat',        icon = 'Flame',
      station = { 'coords', 'explosion' },
      text = { noun = 'heat station', fields = targetFields({ 'Target', 'targetLabel', 'targetIcon', 'Heat Chemicals', 'fa-solid fa-fire' }) } },
    { step = 'Meth:smash',      kind = 'station', label = 'Meth Smash',       icon = 'Hammer',
      station = { 'coords', 'offset', 'rotation', 'size', 'bucket' },
      text = { noun = 'smash station', fields = targetFields({ 'Target', 'targetLabel', 'targetIcon', 'Smash Meth', 'fa-solid fa-hammer' }) } },
    { step = 'Meth:bag',        kind = 'station', label = 'Meth Bag',         icon = 'ShoppingBag',
      station = { 'coords', 'offset', 'rotation', 'size' },
      text = { noun = 'bagging bucket', fields = targetFields({ 'Target', 'targetLabel', 'targetIcon', 'Bag Meth', 'fa-solid fa-bag-shopping' }) } },
}

local function eventInfo(step)
    for _, event in ipairs(EVENTS) do
        if event.step == step then return event end
    end
end

local function notice(message, tone)
    return { tone = tone or 'success', message = message }
end

local function appended(list, entry)
    local copy = {}
    for _, value in ipairs(list or {}) do copy[#copy + 1] = value end
    copy[#copy + 1] = entry
    return copy
end

local function removedAt(list, index)
    local kept = {}
    for position, value in ipairs(list or {}) do
        if position ~= index then kept[#kept + 1] = value end
    end
    return kept
end

local function coordsLabel(c)
    return ('%.2f, %.2f, %.2f'):format(c.x, c.y, c.z)
end

local function modelExists(model)
    return type(model) == 'string' and model ~= '' and IsModelInCdimage(GetHashKey(model))
end


local function plantsView()
    local list = QB.callback.trigger('qbdrugs:creator:list') or {}
    local items = {}
    for _, plant in ipairs(list) do
        items[#items + 1] = {
            id = plant.id,
            label = plant.id,
            icon = 'Leaf',
            description = ('%d spots · %s%s'):format(plant.count, plant.item or '?', plant.disabled and ' · disabled' or ''),
            action = 'select:' .. plant.id,
        }
    end

    return {
        id = 'plants', label = 'Plants', icon = 'Leaf',
        content = {
            title = 'Plants',
            description = 'Pick a plant type to edit its settings and spots.',
            blocks = {
                { type = 'list', id = 'plant-list', items = items, empty = 'No plants yet.' },
                {
                    type = 'form', id = 'create', title = 'Create plant',
                    fields = {
                        { id = 'name', label = 'Name', type = 'text', required = true },
                        { id = 'model', label = 'Prop model', type = 'text', required = true },
                        { id = 'item', label = 'Item given', type = 'text', required = true },
                    },
                    action = { id = 'create', label = 'Create' },
                },
            },
        },
    }
end

local function pickingValues(data)
    local picking = data.pickingData or {}
    local anim = picking.anim or DefaultProgress.anim
    local disable = {}
    for key, on in pairs(picking.disable or DefaultProgress.disable) do
        if on then disable[#disable + 1] = key end
    end
    table.sort(disable)

    return {
        time = picking.time or DefaultProgress.time,
        dict = anim.dict or '',
        clip = anim.clip or '',
        flag = anim.flag or anim.flags or 49,
        disable = disable,
    }
end

local function dataView()
    local data = selected.data
    local picking = pickingValues(data)
    return {
        id = 'data', label = 'Settings', icon = 'Settings',
        content = {
            title = selected.id,
            description = 'Prop, reward and timing for this plant.',
            blocks = {
                {
                    type = 'form', id = 'data', title = 'Settings',
                    fields = {
                        { id = 'model', label = 'Prop model', type = 'text', default = data.model or '', required = true },
                        { id = 'item', label = 'Item given', type = 'text', default = data.item or '', required = true },
                        { id = 'icon', label = 'Target icon', type = 'text', default = data.icon or '' },
                        { id = 'targetLabel', label = 'Target label', type = 'text', default = data.targetLabel or '' },
                        { id = 'progressLabel', label = 'Progress bar label', type = 'text', default = data.progressLabel or '' },
                        { id = 'maxGive', label = 'Max given per pick', type = 'number', default = data.maxGive or 1 },
                        { id = 'respawnTime', label = 'Respawn time (seconds)', type = 'number', default = data.respawnTime or 1 },
                        { id = 'pickTime', label = 'Pick time (ms)', type = 'number', default = picking.time },
                        { id = 'animDict', label = 'Animation dictionary', type = 'text', default = picking.dict, required = true,
                            description = 'The animation dictionary played while picking, e.g. mp_arresting.' },
                        { id = 'animClip', label = 'Animation clip', type = 'text', default = picking.clip, required = true,
                            description = 'The clip inside that dictionary, e.g. a_uncuff.' },
                        { id = 'animFlag', label = 'Animation flag', type = 'number', min = 0, max = 65535, default = picking.flag,
                            description = 'GTA animation flags. 49 keeps the upper body animating while allowing movement.' },
                        { id = 'disable', label = 'Disable while picking', type = 'multiselect', options = ProgressDisableOptions,
                            default = picking.disable,
                            description = 'Controls blocked while the progress bar runs.' },
                        {
                            id = 'status', label = 'Status', type = 'select',
                            default = data.disabled and 'disabled' or 'enabled',
                            options = {
                                { value = 'enabled', label = 'Enabled' },
                                { value = 'disabled', label = 'Disabled' },
                            },
                        },
                    },
                    action = { id = 'data:save', label = 'Save' },
                },
                {
                    type = 'actions', title = 'Danger zone',
                    actions = { { id = 'delete', label = 'Delete plant', variant = 'destructive' } },
                },
            },
        },
    }
end

local function spotsView()
    local items = {}
    for index, spot in ipairs(selected.locations or {}) do
        items[#items + 1] = {
            id = tostring(index),
            label = ('Spot %d'):format(index),
            icon = 'MapPin',
            description = coordsLabel(spot.coords),
            actions = { { id = 'spots:remove:' .. index, label = 'Delete', icon = 'Trash2', variant = 'destructive' } },
        }
    end

    return {
        id = 'spots', label = 'Spots', icon = 'MapPin',
        content = {
            title = 'Spots',
            description = 'Aim and place the plant where players can pick it. Keep placing until you cancel.',
            blocks = {
                { type = 'actions', actions = { { id = 'spots:add', label = 'Place spots', variant = 'primary' } } },
                { type = 'list', id = 'spot-list', layout = 'cards', title = ('Spots (%d)'):format(#items), items = items, empty = 'No spots yet.' },
            },
        },
    }
end

local function eventsView()
    local items = {}
    for _, event in ipairs(EVENTS) do
        items[#items + 1] = {
            id = event.step,
            label = event.label,
            icon = event.icon,
            description = event.step,
            action = 'event:select:' .. event.step,
        }
    end

    return {
        id = 'events', label = 'Events', icon = 'Door',
        content = {
            title = 'Events',
            description = 'Pick an event to edit its settings and locations.',
            blocks = { { type = 'list', id = 'event-list', items = items, empty = 'No events.' } },
        },
    }
end

local function labView(info)
    local data = selectedEvent.data or {}

    local items = {}
    for index, location in ipairs(selectedEvent.locations or {}) do
        items[#items + 1] = {
            id = tostring(index),
            label = ('Entrance %d%s'):format(index, location.gang and (' · ' .. location.gang) or ''),
            icon = 'MapPin',
            description = coordsLabel(location.enter),
            actions = { { id = 'event:remove:' .. index, label = 'Delete', icon = 'Trash2', variant = 'destructive' } },
        }
    end

    return {
        id = 'event', label = info.label, icon = info.icon,
        content = {
            title = info.label,
            description = 'Target text, and the entrances that lead into the lab.',
            blocks = {
                {
                    type = 'form', id = 'event-data', title = 'Target text',
                    fields = {
                        { id = 'enterTarget', label = 'Enter target', type = 'text', default = data.enterTarget or 'Enter Lab' },
                        { id = 'exitTarget', label = 'Exit target', type = 'text', default = data.exitTarget or 'Exit Lab' },
                    },
                    action = { id = 'event:data:save', label = 'Save' },
                },
                {
                    type = 'form', id = 'event-add', title = 'Add entrance',
                    fields = {
                        { id = 'gang', label = 'Gang', type = 'text', default = '',
                            description = 'Only members of this gang can use the entrance. Leave empty for everyone.' },
                    },
                    action = { id = 'event:add', label = 'Aim and place entrance' },
                },
                { type = 'list', id = 'event-locations', layout = 'cards', title = ('Entrances (%d)'):format(#items), items = items, empty = 'No entrances yet.' },
            },
        },
    }
end

-- { move = true, combat = true } -> { 'combat', 'move' } for the multiselect
local function disableList(map)
    local list = {}
    for key, on in pairs(map or {}) do
        if on == true then list[#list + 1] = key end
    end
    table.sort(list)
    return list
end

-- { 'move', 'combat' } -> { move = true, combat = true } for saving
local function disableMap(list)
    local map = {}
    for _, key in ipairs(type(list) == 'table' and list or {}) do map[key] = true end
    return map
end

local function pointsView(info)
    local data = selectedEvent.data or {}
    local progress = data.progress or {}
    local anim = data.anim or {}
    local text = info.points

    local items = {}
    for index, location in ipairs(selectedEvent.locations or {}) do
        items[#items + 1] = {
            id = tostring(index),
            label = ('Location %d%s%s'):format(index,
                location.gang and (' · ' .. location.gang) or '',
                location.object and (' · ' .. location.object) or ''),
            icon = 'MapPin',
            description = coordsLabel(location.coords),
            actions = { { id = 'event:remove:' .. index, label = 'Delete', icon = 'Trash2', variant = 'destructive' } },
        }
    end

    return {
        id = 'event', label = info.label, icon = info.icon,
        content = {
            title = info.label,
            description = ('Target text, progress bar and animation, and where players can %s.'):format(text.noun),
            blocks = {
                {
                    type = 'form', id = 'event-data', title = 'Settings',
                    fields = {
                        { id = 'targetLabel', label = 'Target label', type = 'text', default = data.targetLabel or text.label },
                        { id = 'targetIcon', label = 'Target icon', type = 'text', default = data.targetIcon or text.icon },
                        { id = 'progressLabel', label = 'Progress bar label', type = 'text', default = progress.label or text.progress },
                        { id = 'progressTime', label = 'Progress time (ms)', type = 'number', default = progress.time or 5000 },
                        { id = 'animDict', label = 'Animation dictionary', type = 'text', default = anim.dict or 'mp_arresting', required = true,
                            description = 'The animation dictionary played while working, e.g. mp_arresting.' },
                        { id = 'animClip', label = 'Animation clip', type = 'text', default = anim.clip or 'a_uncuff', required = true,
                            description = 'The clip inside that dictionary, e.g. a_uncuff.' },
                        { id = 'animFlag', label = 'Animation flag', type = 'number', min = 0, max = 65535, default = anim.flag or 49,
                            description = 'GTA animation flags. 49 keeps the upper body animating while allowing movement.' },
                        { id = 'disable', label = 'Disable while working', type = 'multiselect', options = ProgressDisableOptions,
                            default = disableList(progress.disable),
                            description = 'Controls blocked while the progress bar runs.' },
                    },
                    action = { id = 'event:data:save', label = 'Save' },
                },
                {
                    type = 'form', id = 'event-place', title = 'Place locations',
                    fields = {
                        { id = 'gang', label = 'Gang', type = 'text', default = '',
                            description = 'Only members of this gang can use the location. Leave empty for everyone.' },
                        { id = 'object', label = 'Object', type = 'text', default = '',
                            description = 'Optional prop model. When set, you aim at that prop to place the location. Leave empty to aim at any surface.' },
                    },
                    action = { id = 'event:place', label = 'Aim and place locations' },
                },
                { type = 'list', id = 'event-locations', layout = 'cards', title = ('Locations (%d)'):format(#items), items = items, empty = 'No locations yet.' },
            },
        },
    }
end

-- Events that only have target text and a fixed position (kind = 'text').
local function textView(info)
    local data = selectedEvent.data or {}

    local fields = {}
    for _, field in ipairs(info.text.fields) do
        fields[#fields + 1] = { id = field.id, label = field.label, type = 'text', default = data[field.id] or field.default }
    end

    return {
        id = 'event', label = info.label, icon = info.icon,
        content = {
            title = info.label,
            description = ('Target text for the %s. Its position is fixed and cannot be edited here.'):format(info.text.noun),
            blocks = {
                {
                    type = 'form', id = 'event-data', title = 'Target text',
                    fields = fields,
                    action = { id = 'event:data:save', label = 'Save' },
                },
            },
        },
    }
end

-- Meth stations (kind = 'station'): target text plus where the station is and how its animation lines up.
local STATION_PARTS = {
    coords = { label = 'Position', min = -10000, max = 10000 },
    offset = { label = 'Scene offset', min = -500, max = 500 },
    rotation = { label = 'Scene rotation', min = -720, max = 720 },
    size = { label = 'Target size', min = 0.01, max = 100 },
    bucket = { label = 'Bucket', min = -10000, max = 10000 },
}

local function stationView(info)
    local data = selectedEvent.data or {}
    local location = selectedEvent.locations or {}

    local textFields = {}
    for _, field in ipairs(info.text.fields) do
        textFields[#textFields + 1] = { id = field.id, label = field.label, type = 'text', default = data[field.id] or field.default }
    end

    local fields = {}
    for _, part in ipairs(info.station) do
        if part == 'explosion' then
            fields[#fields + 1] = {
                id = 'explosion', label = 'Explosion when the dials are failed', type = 'select',
                default = location.explosion and 'enabled' or 'disabled',
                options = { { value = 'enabled', label = 'Enabled' }, { value = 'disabled', label = 'Disabled' } },
            }
        else
            local rule, value = STATION_PARTS[part], location[part] or {}
            for _, axis in ipairs({ 'x', 'y', 'z' }) do
                fields[#fields + 1] = {
                    id = part .. axis:upper(), label = ('%s %s'):format(rule.label, axis:upper()), type = 'number',
                    step = 0.01, min = rule.min, max = rule.max, default = value[axis] or 0,
                }
            end
            if part == 'bucket' then
                fields[#fields + 1] = {
                    id = 'bucketW', label = 'Bucket heading', type = 'number',
                    step = 0.01, min = -720, max = 720, default = value.w or 0,
                }
            end
        end
    end

    return {
        id = 'event', label = info.label, icon = info.icon,
        content = {
            title = info.label,
            description = ('Target text and position for the %s. Scene offset and rotation line the animation up with the props.'):format(info.text.noun),
            blocks = {
                {
                    type = 'form', id = 'event-data', title = 'Target text',
                    fields = textFields,
                    action = { id = 'event:data:save', label = 'Save' },
                },
                {
                    type = 'actions', title = 'Position',
                    actions = { { id = 'event:station:aim', label = 'Set position where I aim', icon = 'Crosshair', variant = 'primary' } },
                },
                {
                    type = 'form', id = 'station-position', title = 'Position and animation',
                    fields = fields,
                    action = { id = 'event:station:save', label = 'Save position' },
                },
            },
        },
    }
end

local function eventView()
    local info = eventInfo(selectedEvent.step)
    if info.kind == 'points' then return pointsView(info) end
    if info.kind == 'text' then return textView(info) end
    if info.kind == 'station' then return stationView(info) end
    return labView(info)
end

-- Cornerselling -----------------------------------------------------------------------------

local function money(value)
    return ('$%d'):format(math.floor(tonumber(value) or 0))
end

local function itemLabel(name)
    local info = corner.items[name]
    return info and info.label or name
end

-- A copy of the stored settings that can be changed and sent back.
local function cornerCopy()
    local copy = {}
    for key, value in pairs(corner.data or {}) do copy[key] = value end
    copy.pricing = {}
    for name, price in pairs((corner.data and corner.data.pricing) or {}) do copy.pricing[name] = price end
    return copy
end

local function cornerView()
    if not corner.data then
        return {
            id = 'cornerselling', label = 'Cornerselling', icon = 'DollarSign',
            content = {
                title = 'Cornerselling',
                blocks = {
                    { type = 'empty', title = 'The cornerselling settings could not be loaded.' },
                    { type = 'actions', actions = { { id = 'corner:reload', label = 'Try again', variant = 'primary' } } },
                },
            },
        }
    end

    local data = corner.data

    local names = {}
    for name in pairs(data.pricing or {}) do names[#names + 1] = name end
    table.sort(names, function(a, b)
        local la, lb = itemLabel(a):lower(), itemLabel(b):lower()
        if la ~= lb then return la < lb end
        return a < b
    end)

    local priced = {}
    for _, name in ipairs(names) do
        local info = corner.items[name]
        priced[#priced + 1] = {
            id = name,
            label = itemLabel(name),
            description = info and name or (name .. ' · not in the shared items'),
            image = info and info.image or nil,
            metadata = { { label = 'Price', value = money(data.pricing[name]) } },
            actions = {
                { id = 'corner:price:' .. name, label = 'Set price', icon = 'Pencil', variant = 'primary' },
                { id = 'corner:remove:' .. name, label = 'Remove', icon = 'Trash2', variant = 'destructive' },
            },
        }
    end

    local found = {}
    for _, result in ipairs(corner.results) do
        found[#found + 1] = {
            id = result.name,
            label = result.label,
            description = result.name,
            image = result.image,
            metadata = result.added and { { label = 'Status', value = 'Already in the list' } } or nil,
            actions = result.added and {} or {
                { id = 'corner:add:' .. result.name, label = 'Add', icon = 'Plus', variant = 'primary' },
            },
        }
    end

    local blocks = {
        {
            type = 'form', id = 'corner-settings', title = 'Settings',
            fields = {
                { id = 'maxSell', label = 'Max sold at once', type = 'number', min = 1, max = 1000, default = data.maxSell,
                    description = 'The most of one item a player can sell to a single buyer.' },
                { id = 'ripOff', label = 'Rip-off', type = 'number', min = 0, max = 1, step = 0.05, default = data.ripOff,
                    description = 'Share of the price lost to a rip-off, as a number from 0 to 1 (0.2 is 20%).' },
                { id = 'minPolice', label = 'Minimum police', type = 'number', min = 0, max = 100, default = data.minPolice,
                    description = 'Police that must be on duty before players can cornersell.' },
                {
                    id = 'weedPercentAdjustable', label = 'THC / CBD changes weed price', type = 'select',
                    default = data.weedPercentAdjustable and 'enabled' or 'disabled',
                    options = { { value = 'enabled', label = 'Enabled' }, { value = 'disabled', label = 'Disabled' } },
                },
                { id = 'weedPercentFlow', label = 'THC / CBD price swing', type = 'number', min = 0, max = 1, step = 0.05,
                    default = data.weedPercentFlow,
                    description = 'How far quality moves a weed price up or down, from 0 to 1 (0.2 is 20%).' },
            },
            action = { id = 'corner:save', label = 'Save' },
        },
        {
            type = 'form', id = 'corner-search', title = 'Add items',
            fields = {
                { id = 'query', label = 'Search all items', type = 'text', default = corner.query or '',
                    description = 'Part of an item name or label. Add the ones you want to sell below.' },
            },
            action = { id = 'corner:search', label = 'Search' },
        },
    }

    if corner.query then
        local more = corner.total > #found and (' of ' .. corner.total) or ''
        blocks[#blocks + 1] = {
            type = 'list', id = 'corner-results', layout = 'cards', columns = 3,
            title = ('Results for "%s" (%d%s)'):format(corner.query, #found, more),
            items = found, empty = 'No items match that search.',
        }
    end

    blocks[#blocks + 1] = {
        type = 'list', id = 'corner-pricing', layout = 'cards',  columns = 3,
        searchable = #priced > 6,
        title = ('Selling prices (%d)'):format(#priced),
        items = priced, empty = 'No items yet. Search above to add one.',
    }

    return {
        id = 'cornerselling', label = 'Cornerselling', icon = 'DollarSign',
        content = {
            title = 'Cornerselling',
            description = 'What players can sell to buyers on the street, and for how much.',
            blocks = blocks,
        },
    }
end

local function buildNavigation()
    local navigation = { plantsView() }
    if selected then
        navigation[#navigation + 1] = dataView()
        navigation[#navigation + 1] = spotsView()
    end
    navigation[#navigation + 1] = eventsView()
    if selectedEvent then
        navigation[#navigation + 1] = eventView()
    end
    navigation[#navigation + 1] = cornerView()
    return navigation
end

local function refresh(message)
    local navigation = buildNavigation()
    QB.nui.updateApp(APP_ID, { navigation = navigation })
    return { update = { navigation = navigation }, notice = message }
end

local function fail(message)
    return refresh(notice(message, 'destructive'))
end

-- Actions

-- Saves a patch and keeps the server's copy. Returns true, or false and a message.
local function persist(patch)
    local result, err = QB.callback.trigger('qbdrugs:creator:save', selected.id, patch)
    if not result then return false, err or 'Failed to save.' end
    selected = result
    return true
end

local function saveSelected(patch)
    local ok, err = persist(patch)
    if not ok then return fail(err) end
    return refresh(notice('Saved.'))
end

local function createPlant(values)
    if not modelExists(values.model) then return fail('Unknown prop model.') end
    local record, err = QB.callback.trigger('qbdrugs:creator:create', values.name, values.model, values.item)
    if not record then return fail(err or 'Failed to create plant.') end
    selected, currentView = record, 'data'
    return refresh(notice('Plant created.'))
end

local function selectPlant(id)
    local record, err = QB.callback.trigger('qbdrugs:creator:get', id)
    if not record then return fail(err or 'Failed to load plant.') end
    selected, currentView = record, 'data'
    return refresh()
end

local function saveSettings(values)
    if not modelExists(values.model) then return fail('Unknown prop model.') end
    if not DoesAnimDictExist(values.animDict or '') then return fail('Unknown animation dictionary.') end
    return saveSelected({
        settings = {
            model = values.model,
            item = values.item,
            icon = values.icon or '',
            targetLabel = values.targetLabel or '',
            progressLabel = values.progressLabel or '',
            maxGive = tonumber(values.maxGive),
            respawnTime = tonumber(values.respawnTime),
            pickTime = tonumber(values.pickTime),
            animDict = values.animDict,
            animClip = values.animClip,
            animFlag = tonumber(values.animFlag),
            disable = values.disable or {},
            disabled = values.status == 'disabled',
        },
    })
end

local function deleteSelected()
    local confirmation = QB.nui.openAlert({
        title = 'Delete plant?',
        message = ('This removes %s and all of its spots.'):format(selected.id),
        confirmLabel = 'Delete',
    })
    if not confirmation or not confirmation.confirmed then return refresh() end

    local ok, err = QB.callback.trigger('qbdrugs:creator:delete', selected.id)
    if not ok then return fail(err or 'Failed to delete plant.') end
    selected, currentView = nil, 'plants'
    return refresh(notice('Plant deleted.'))
end

-- Events

local function persistEvent(patch)
    local result, err = QB.callback.trigger('qbdrugs:creator:event:save', selectedEvent.step, patch)
    if not result then return false, err or 'Failed to save.' end
    selectedEvent = result
    return true
end

local function selectEvent(step)
    if not eventInfo(step) then return fail('Unknown event.') end
    local record, err = QB.callback.trigger('qbdrugs:creator:event:get', step)
    if not record then return fail(err or 'Failed to load event.') end
    selectedEvent, currentView = record, 'event'
    return refresh()
end

local function saveEventData(values)
    local kind = eventInfo(selectedEvent.step).kind
    local data

    if kind == 'points' then
        if not DoesAnimDictExist(values.animDict or '') then return fail('Unknown animation dictionary.') end
        data = {
            targetLabel = values.targetLabel or '',
            targetIcon = values.targetIcon or '',
            progress = {
                label = values.progressLabel or '',
                time = tonumber(values.progressTime),
                disable = disableMap(values.disable),
            },
            anim = {
                dict = values.animDict,
                clip = values.animClip,
                flag = tonumber(values.animFlag),
            },
        }
    elseif kind == 'text' or kind == 'station' then
        data = {}
        for _, field in ipairs(eventInfo(selectedEvent.step).text.fields) do
            data[field.id] = values[field.id] or ''
        end
    else
        data = { enterTarget = values.enterTarget or '', exitTarget = values.exitTarget or '' }
    end

    local ok, err = persistEvent({ data = data })
    if not ok then return fail(err) end
    return refresh(notice('Saved.'))
end

-- The position form -> a location object. Returns it, or nil and a message.
local function stationFromValues(values, parts)
    local location = {}
    for _, part in ipairs(parts) do
        if part == 'explosion' then
            location.explosion = values.explosion == 'enabled'
        else
            local x, y, z = tonumber(values[part .. 'X']), tonumber(values[part .. 'Y']), tonumber(values[part .. 'Z'])
            if not (x and y and z) then
                return nil, ('Fill in every number for the %s.'):format(STATION_PARTS[part].label:lower())
            end
            location[part] = { x = x, y = y, z = z }
            if part == 'bucket' then
                local w = tonumber(values.bucketW)
                if not w then return nil, 'Fill in the bucket heading.' end
                location.bucket.w = w
            end
        end
    end
    return location
end

local function saveStation(values)
    local location, err = stationFromValues(values, eventInfo(selectedEvent.step).station)
    if not location then return fail(err) end

    local ok, saveErr = persistEvent({ locations = location })
    if not ok then return fail(saveErr) end
    return refresh(notice('Saved.'))
end

local function startEntrance(values)
    local gang = type(values.gang) == 'string' and values.gang:match('^%s*(.-)%s*$') or ''
    if gang == '' then gang = nil end

    pendingTool, currentView = { kind = 'entrance', gang = gang, exit = eventInfo(selectedEvent.step).exit }, 'event'
    return { close = true }
end

-- Cornerselling

local function loadCorner()
    local result, err = QB.callback.trigger('qbdrugs:creator:corner:get')
    if not result then
        QB.notify.send({ title = 'Drug Creator', message = err or 'Could not load the cornerselling settings.', type = 'error' })
        return false
    end
    corner.data, corner.items = result.data, result.items or {}
    return true
end

-- Saves the whole settings table through the same callback every event uses.
local function persistCorner(data)
    local result, err = QB.callback.trigger('qbdrugs:creator:event:save', CORNER_STEP, { data = data })
    if not result then return false, err or 'Failed to save.' end
    corner.data = result.data
    return true
end

-- Small price prompt. Returns a whole number, or nil if it was cancelled.
local function askPrice(label, current, title)
    local result = QB.nui.openInputDialog({
        { id = 'price', label = 'Price (cash each)', type = 'number', min = 0, max = 1000000, default = current, required = true },
    }, title, label)
    if not result or result.cancelled then return nil end

    local price = tonumber(result.values and result.values.price)
    return price and math.floor(price) or nil
end

local function cornerAction(actionId, values)
    if actionId == 'corner:reload' then
        loadCorner()
        return refresh()
    end
    if not corner.data then return fail('The cornerselling settings are not loaded.') end

    if actionId == 'corner:save' then
        local data = cornerCopy()
        for _, key in ipairs({ 'maxSell', 'ripOff', 'minPolice', 'weedPercentFlow' }) do
            local n = tonumber(values[key])
            if n ~= nil then data[key] = n end
        end
        data.weedPercentAdjustable = values.weedPercentAdjustable ~= 'disabled'

        local ok, err = persistCorner(data)
        if not ok then return fail(err) end
        return refresh(notice('Saved.'))
    end

    if actionId == 'corner:search' then
        local query = type(values.query) == 'string' and values.query:match('^%s*(.-)%s*$') or ''
        if query == '' then
            corner.query, corner.results, corner.total = nil, {}, 0
            return refresh()
        end

        local result, err = QB.callback.trigger('qbdrugs:creator:corner:search', query)
        if not result then return fail(err or 'The search failed.') end
        corner.query, corner.results = query, result.results or {}
        corner.total = result.total or #corner.results
        return refresh()
    end

    local addName = actionId:match('^corner:add:(.+)$')
    if addName then
        local found
        for _, result in ipairs(corner.results) do
            if result.name == addName then found = result break end
        end
        if not found then return fail('Search for that item again first.') end

        local price = askPrice(found.label, 15, 'Add to cornerselling')
        if not price then return refresh() end

        local data = cornerCopy()
        data.pricing[addName] = price
        local ok, err = persistCorner(data)
        if not ok then return fail(err) end

        corner.items[addName] = { label = found.label, image = found.image }
        found.added = true
        return refresh(notice(('%s added for %s.'):format(found.label, money(price))))
    end

    local priceName = actionId:match('^corner:price:(.+)$')
    if priceName then
        local current = corner.data.pricing and corner.data.pricing[priceName]
        if current == nil then return refresh() end

        local price = askPrice(itemLabel(priceName), current, 'Set price')
        if not price then return refresh() end

        local data = cornerCopy()
        data.pricing[priceName] = price
        local ok, err = persistCorner(data)
        if not ok then return fail(err) end
        return refresh(notice(('%s now sells for %s.'):format(itemLabel(priceName), money(price))))
    end

    local removeName = actionId:match('^corner:remove:(.+)$')
    if removeName then
        local label = itemLabel(removeName)
        local data = cornerCopy()
        data.pricing[removeName] = nil

        local ok, err = persistCorner(data)
        if not ok then return fail(err) end

        for _, result in ipairs(corner.results) do
            if result.name == removeName then result.added = false end
        end
        return refresh(notice(('%s removed.'):format(label)))
    end

    return refresh()
end

local function onAction(actionId, context)
    local values = context and context.value or {}

    if actionId == 'create' then return createPlant(values) end
    if actionId:match('^corner:') then return cornerAction(actionId, values) end

    local eventStep = actionId:match('^event:select:(.+)$')
    if eventStep then return selectEvent(eventStep) end

    if actionId:match('^event:') then
        if not selectedEvent then return refresh() end
        if actionId == 'event:data:save' then return saveEventData(values) end
        if actionId == 'event:add' then return startEntrance(values) end
        if actionId == 'event:station:save' then return saveStation(values) end
        if actionId == 'event:station:aim' then
            pendingTool, currentView = { kind = 'station' }, 'event'
            return { close = true }
        end
        if actionId == 'event:place' then
            local object = type(values.object) == 'string' and values.object:match('^%s*(.-)%s*$') or ''
            if object ~= '' and not modelExists(object) then return fail('Unknown object model.') end
            if object == '' then object = nil end
            local gang = type(values.gang) == 'string' and values.gang:match('^%s*(.-)%s*$') or ''
            if gang == '' then gang = nil end
            pendingTool, currentView = { kind = 'point', object = object, gang = gang }, 'event'
            return { close = true }
        end

        local entrance = actionId:match('^event:remove:(%d+)$')
        if entrance then
            local ok, err = persistEvent({ locations = removedAt(selectedEvent.locations, tonumber(entrance)) })
            if not ok then return fail(err) end
            return refresh(notice('Deleted.'))
        end
        return refresh()
    end

    local selectId = actionId:match('^select:(.+)$')
    if selectId then return selectPlant(selectId) end

    if not selected then return refresh() end

    if actionId == 'delete' then return deleteSelected() end
    if actionId == 'data:save' then return saveSettings(values) end

    if actionId == 'spots:add' then
        pendingTool, currentView = { kind = 'spot' }, 'spots'
        return { close = true }
    end

    local index = actionId:match('^spots:remove:(%d+)$')
    if index then
        return saveSelected({ locations = removedAt(selected.locations, tonumber(index)) })
    end

    return refresh()
end

-- The initial navigation is static: the open loop below fills in the real one
-- right before each open, so nothing calls the server at resource start.
QB.nui.registerApp({
    id = APP_ID,
    title = 'Drug Creator',
    icon = 'Leaf',
    layout = 'standard',
    width = 1200,
    height = 800,
    defaultView = 'plants',
    navigation = { { id = 'plants', label = 'Plants', icon = 'Leaf', content = { title = 'Plants', blocks = {} } } },
    onAction = onAction,
})

local function runPendingTool()
    local tool = pendingTool
    pendingTool = nil

    if tool.kind == 'entrance' then
        local aimed = QB.raycast.getCoords({})
        local c = aimed and aimed.coords
        if not c then return end

        local ok, err = persistEvent({
            locations = appended(selectedEvent.locations, {
                enter = { x = c.x, y = c.y, z = c.z },
                exit = tool.exit,
                gang = tool.gang,
            }),
        })
        if not ok then
            QB.notify.send({ title = 'Drug Creator', message = err, type = 'error' })
        end
        return
    end

    if tool.kind == 'station' then
        local aimed = QB.raycast.getCoords({})
        local c = aimed and aimed.coords
        if not c then return end

        local location = {}
        for key, value in pairs(selectedEvent.locations or {}) do location[key] = value end
        location.coords = { x = c.x, y = c.y, z = c.z }

        local ok, err = persistEvent({ locations = location })
        if not ok then
            QB.notify.send({ title = 'Drug Creator', message = err, type = 'error' })
        end
        return
    end

    if tool.kind == 'point' then
        while true do
            local aimed
            if tool.object then
                aimed = QB.raycast.getCoords({ type = 'object', object = tool.object })
            else
                aimed = QB.raycast.getCoords({})
            end
            local c = aimed and aimed.coords
            if not c then return end

            local ok, err = persistEvent({
                locations = appended(selectedEvent.locations, {
                    -- an object raycast returns a vec4: keep its w (heading) too
                    coords = { x = c.x, y = c.y, z = c.z, w = c.w or aimed.heading },
                    object = tool.object,
                    gang = tool.gang,
                }),
            })
            if not ok then
                QB.notify.send({ title = 'Drug Creator', message = err, type = 'error' })
                return
            end
        end
    end

    if tool.kind == 'spot' then
        while true do
            local aimed = QB.raycast.getCoords({ type = 'object', object = selected.data.model })
            local c = aimed and aimed.coords
            if not c then return end

            local ok, err = persist({
                locations = appended(selected.locations, { coords = { x = c.x, y = c.y, z = c.z } }),
            })
            if not ok then
                QB.notify.send({ title = 'Plant Creator', message = err, type = 'error' })
                return
            end
        end
    end
end

local function open()
    local list, err = QB.callback.trigger('qbdrugs:creator:list')
    if not list then
        QB.notify.send({ title = 'Plant Creator', message = err or 'Admin permission required.', type = 'error' })
        return
    end

    corner.query, corner.results, corner.total = nil, {}, 0
    loadCorner()

    while true do
        QB.nui.updateApp(APP_ID, { navigation = buildNavigation() })
        QB.nui.openApp(APP_ID, { viewId = currentView })
        if not pendingTool then break end
        runPendingTool()
    end
end

RegisterCommand(COMMAND, function()
    CreateThread(open)
end, false)