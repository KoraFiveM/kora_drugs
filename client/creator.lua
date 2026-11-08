local APP_ID = 'qbdrugs:creator'

local selected = nil
local selectedEvent = nil
-- Bumped whenever an event is opened or its settings are saved. It is part of every event form id, so
-- the UI builds the forms again from the saved data instead of showing what the last event left in them.
local eventRevision = 0
local currentView = 'plants'
local pendingTool = nil
local CORNER_STEP = 'CornerSelling:settings'
local corner = { data = nil, items = {}, query = nil, results = {}, total = 0 }
local recipes = { list = {}, items = {}, selected = nil, query = nil, results = {}, total = 0 }
local customs = { drugs = {}, removed = {} }

-- removed = base events the admin deleted, as a set: removed['Cocaine:powder'] = true
local function applyCustoms(result)
    customs.drugs = result.drugs or {}
    customs.removed = {}
    for _, step in ipairs(result.removed or {}) do customs.removed[step] = true end
end
local COCAINE_LAB_EXIT = { x = 1088.81, y = -3187.57, z = -38.99 }
local METH_LAB_EXIT = { x = 996.91, y = -3200.83, z = -36.39 }
local WEED_LAB_EXIT = { x = 1066.4, y = -3183.36, z = -39.16 }

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
    { step = 'Weed:drying',     kind = 'points',  label = 'Weed Drying',      icon = 'Wind',      noRecipe = true,
      points = { noun = 'dry weed', progress = 'Drying Weed', label = 'Dry Weed', icon = 'weed' } },
    { step = 'Weed:breakNugs',  kind = 'points',  label = 'Weed Break Down',  icon = 'Scissors',  noRecipe = true,
      points = { noun = 'break down weed', progress = 'Breaking Down Weed', label = 'Break Down Weed', icon = 'weed' } },
    { step = 'Weed:bagWeed',    kind = 'points',  label = 'Weed Bagging',     icon = 'Package',   noRecipe = true,
      points = { noun = 'bag weed', progress = 'Bagging Weed', label = 'Bag Weed', icon = 'weed' } },
    { step = 'Cocaine:cutting', kind = 'text',    label = 'Cocaine Cutting',  icon = 'Scissors',
      text = { noun = 'cutting table', fields = targetFields({ 'Target', 'targetLabel', 'targetIcon', 'cut cocaine', 'knife' }) } },
    { step = 'Cocaine:bagging', kind = 'text',    label = 'Cocaine Bagging',  icon = 'Package',
      text = { noun = 'bagging table', fields = targetFields({ 'Target', 'targetLabel', 'targetIcon', 'bag cocaine', 'box' }) } },
    { step = 'Meth:pour',       kind = 'text',    label = 'Meth Pour & Tray', icon = 'FlaskConical',
      text = { noun = 'pour station (pour and tray targets)', fields = targetFields(
          { 'Pour', 'targetLabel', 'targetIcon', 'Pour Chemicals', 'fa-solid fa-flask' },
          { 'Tray', 'trayLabel', 'trayIcon', 'Grab Tray', 'fa-solid fa-hand-paper' }) } },
    { step = 'Meth:heat',       kind = 'text',    label = 'Meth Heat',        icon = 'Flame',     explosion = true,
      text = { noun = 'heat station', fields = targetFields({ 'Target', 'targetLabel', 'targetIcon', 'Heat Chemicals', 'fa-solid fa-fire' }) } },
    { step = 'Meth:smash',      kind = 'text',    label = 'Meth Smash',       icon = 'Hammer',
      text = { noun = 'smash station', fields = targetFields({ 'Target', 'targetLabel', 'targetIcon', 'Smash Meth', 'fa-solid fa-hammer' }) } },
    { step = 'Meth:bag',        kind = 'text',    label = 'Meth Bag',         icon = 'ShoppingBag',
      text = { noun = 'bagging bucket', fields = targetFields({ 'Target', 'targetLabel', 'targetIcon', 'Bag Meth', 'fa-solid fa-bag-shopping' }) } },
}

table.sort(EVENTS, function(a, b)
    local la, lb = a.label:lower(), b.label:lower()
    if la ~= lb then return la < lb end
    return a.step < b.step
end)

local function customEvent(step)
    for _, drug in ipairs(customs.drugs) do
        for _, event in ipairs(drug.events) do
            if event.step == step then return drug, event end
        end
    end
end

local function eventInfo(step)
    for _, event in ipairs(EVENTS) do
        if event.step == step then return event end
    end
    local drug, event = customEvent(step)
    if event then
        return {
            step = step, kind = 'points', custom = true,
            label = ('%s · %s'):format(drug.name, event.name), icon = 'Package',
            points = { noun = 'use it', progress = event.name, label = event.name, icon = 'BriefCase' },
        }
    end
end

local function notice(message, tone)
    return { tone = tone or 'success', message = message }
end

-- A form value as trimmed text ('' when it is missing or not text).
local function text(value)
    return type(value) == 'string' and value:match('^%s*(.-)%s*$') or ''
end

-- Same, but nil when empty (for optional fields like gang and object).
local function optionalText(value)
    local result = text(value)
    return result ~= '' and result or nil
end

-- Sorts by lowercase label, then by id.
local function byLabel(a, b)
    local la, lb = a.label:lower(), b.label:lower()
    if la ~= lb then return la < lb end
    return a.id < b.id
end

-- Asks the admin to confirm. True when they did.
local function confirmed(title, message)
    local answer = Kora.nui.openAlert({ title = title, message = message, confirmLabel = 'Delete' })
    return answer and answer.confirmed == true
end

local function toast(title, message)
    Kora.notify.send({ title = title, message = message, type = 'error' })
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

-- The plants page list. Fetched when the creator opens, and again after a plant is saved, created or deleted.
local plantList, plantsStale = {}, false

local function plantsView()
    if plantsStale then
        plantList, plantsStale = Kora.callback.trigger('qbdrugs:creator:list') or plantList, false
    end
    local items = {}
    for _, plant in ipairs(plantList) do
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
    local entrances, events, deleted = {}, {}, {}
    for _, event in ipairs(EVENTS) do
        local item = {
            id = event.step,
            label = event.label,
            icon = event.icon,
            description = event.step,
            action = 'event:select:' .. event.step,
        }
        if event.kind == 'lab' then
            entrances[#entrances + 1] = item
        elseif customs.removed[event.step] then
            item.description = 'Deleted. Click to restore it.'
            item.action = 'event:restore:' .. event.step
            deleted[#deleted + 1] = item
        else
            events[#events + 1] = item
        end
    end

    for _, drug in ipairs(customs.drugs) do
        for _, event in ipairs(drug.events) do
            events[#events + 1] = {
                id = event.step,
                label = ('%s · %s'):format(drug.name, event.name),
                icon = 'Package',
                description = event.step,
                action = 'event:select:' .. event.step,
            }
        end
    end

    table.sort(events, byLabel)

    local drugOptions = {}
    for _, drug in ipairs(customs.drugs) do
        drugOptions[#drugOptions + 1] = { value = drug.name, label = drug.name }
    end

    local blocks = {
        {
            type = 'form', id = 'event-create', title = 'New event',
            fields = {
                { id = 'drug', label = 'Drug', type = 'select', options = drugOptions,
                    default = drugOptions[1] and drugOptions[1].value,
                    description = 'Make drugs on the Custom drugs tab.' },
                { id = 'name', label = 'Name', type = 'text', required = true,
                    description = 'Letters, numbers and _, starting with a letter. e.g. cook' },
            },
            action = { id = 'custom:event:create', label = 'Create event' },
        },
        { type = 'list', id = 'event-entrances', title = 'Entrances', items = entrances, empty = 'No entrances.' },
        { type = 'list', id = 'event-list', title = 'Events', items = events, empty = 'No events. Restore one below, or make drugs on the Custom drugs tab.' },
    }
    if #deleted > 0 then
        blocks[#blocks + 1] = { type = 'list', id = 'event-deleted', title = 'Deleted events', items = deleted, empty = '' }
    end

    return {
        id = 'events', label = 'Events', icon = 'Door',
        content = {
            title = 'Events',
            description = 'Pick an event to edit its settings and locations. Entrances stay; every other event can be deleted and restored.',
            blocks = blocks,
        },
    }
end

local function eventBlockId(name)
    return ('%s:%s:%d'):format(name, selectedEvent.step, eventRevision)
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
                    type = 'form', id = eventBlockId('event-data'), title = 'Target text',
                    fields = {
                        { id = 'enterTarget', label = 'Enter target', type = 'text', default = data.enterTarget or 'Enter Lab' },
                        { id = 'exitTarget', label = 'Exit target', type = 'text', default = data.exitTarget or 'Exit Lab' },
                    },
                    action = { id = 'event:data:save', label = 'Save' },
                },
                {
                    type = 'form', id = eventBlockId('event-add'), title = 'Add entrance',
                    fields = {
                        { id = 'gang', label = 'Gang', type = 'text', default = '',
                            description = 'Only members of this gang can use the entrance. Leave empty for everyone.' },
                    },
                    action = { id = 'event:add', label = 'Aim and place entrance' },
                },
                { type = 'list', id = eventBlockId('event-locations'), layout = 'cards', title = ('Entrances (%d)'):format(#items), items = items, empty = 'No entrances yet.' },
            },
        },
    }
end

local function disableList(map)
    local list = {}
    for key, on in pairs(map or {}) do
        if on == true then list[#list + 1] = key end
    end
    table.sort(list)
    return list
end

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
                    type = 'form', id = eventBlockId('event-data'), title = 'Settings',
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
                    type = 'form', id = eventBlockId('event-place'), title = 'Place locations',
                    fields = {
                        { id = 'gang', label = 'Gang', type = 'text', default = '',
                            description = 'Only members of this gang can use the location. Leave empty for everyone.' },
                        { id = 'object', label = 'Object', type = 'text', default = '',
                            description = 'Optional prop model. When set, you aim at that prop to place the location. Leave empty to aim at any surface.' },
                    },
                    action = { id = 'event:place', label = 'Aim and place locations' },
                },
                { type = 'list', id = eventBlockId('event-locations'), layout = 'cards', title = ('Locations (%d)'):format(#items), items = items, empty = 'No locations yet.' },
            },
        },
    }
end

-- Events that only have target text (position and animation are not edited here).
-- info.explosion adds the "explosion when the dials fail" switch (Meth Heat).
local function textView(info)
    local data = selectedEvent.data or {}

    local fields = {}
    for _, field in ipairs(info.text.fields) do
        fields[#fields + 1] = { id = field.id, label = field.label, type = 'text', default = data[field.id] or field.default }
    end
    if info.explosion then
        local location = selectedEvent.locations or {}
        fields[#fields + 1] = {
            id = 'explosion', label = 'Explosion when the dials are failed', type = 'select',
            default = location.explosion and 'enabled' or 'disabled',
            options = { { value = 'enabled', label = 'Enabled' }, { value = 'disabled', label = 'Disabled' } },
        }
    end

    return {
        id = 'event', label = info.label, icon = info.icon,
        content = {
            title = info.label,
            description = ('Target text for the %s. Its position is fixed and cannot be edited here.'):format(info.text.noun),
            blocks = {
                {
                    type = 'form', id = eventBlockId('event-data'), title = 'Target text',
                    fields = fields,
                    action = { id = 'event:data:save', label = 'Save' },
                },
            },
        },
    }
end

local function recipeField(step, data)
    local default = defaultRecipes[step]
    local custom = data.custom == true
    if not (default or custom) then return end

    local options = {}
    if custom then
        options[1] = { value = 'none', label = 'None (does nothing yet)' }
    end
    for _, id in ipairs(recipeIds) do
        local info = recipeInfo[id]
        local made = info.recipe.receive and info.recipe.receive.item
        options[#options + 1] = { value = id, label = made and ('%s → %s'):format(info.label, made) or info.label }
    end

    return {
        id = 'recipe', label = 'Recipe', type = 'select',
        default = recipeInfo[data.recipe] and data.recipe or default or 'none',
        options = options,
        description = 'The recipe this event runs. Edit its items on the Recipes page.',
    }
end

local function withRecipeField(view, info)
    if info.noRecipe then return view end
    local field = recipeField(info.step, selectedEvent.data or {})
    if not field then return view end
    for _, block in ipairs(view.content.blocks) do
        if block.id == eventBlockId('event-data') then table.insert(block.fields, 1, field) end
    end
    return view
end

local function eventView()
    local info = eventInfo(selectedEvent.step)

    local view
    if info.kind == 'points' then
        view = withRecipeField(pointsView(info), info)
    elseif info.kind == 'text' then
        view = withRecipeField(textView(info), info)
    else
        return labView(info) -- entrances stay
    end

    table.insert(view.content.blocks, {
        type = 'actions',
        actions = { { id = info.custom and 'custom:event:delete' or 'event:delete', label = 'Delete event', variant = 'destructive' } },
    })
    return view
end

local function customsView()
    local items = {}
    for _, drug in ipairs(customs.drugs) do
        items[#items + 1] = {
            id = drug.name,
            label = drug.name,
            icon = 'FlaskConical',
            description = ('%d events'):format(#drug.events),
            actions = { { id = 'custom:delete:' .. drug.name, label = 'Delete', icon = 'Trash2', variant = 'destructive' } },
        }
    end

    return {
        id = 'customs', label = 'Custom drugs', icon = 'Package',
        content = {
            title = 'Custom drugs',
            description = 'Make a new drug, then pick it in the New event form on the Events page. Every event is a copy of Cocaine Powder: same settings, same locations.',
            blocks = {
                {
                    type = 'form', id = 'custom-create', title = 'New drug',
                    fields = {
                        { id = 'name', label = 'Name', type = 'text', required = true,
                            description = 'Letters and numbers only, starting with a letter. e.g. Opium' },
                    },
                    action = { id = 'custom:create', label = 'Create drug' },
                },
                { type = 'list', id = 'custom-list', layout = 'cards', columns = 3, items = items, empty = 'No custom drugs yet.' },
            },
        },
    }
end

-- Search results as cards with an Add button (or a note when the item is already there).
local function foundItems(results, addPrefix, addedText)
    local found = {}
    for _, result in ipairs(results) do
        found[#found + 1] = {
            id = result.name,
            label = result.label,
            description = result.name,
            image = result.image,
            metadata = result.added and { { label = 'Status', value = addedText } } or nil,
            actions = result.added and {} or {
                { id = addPrefix .. result.name, label = 'Add', icon = 'Plus', variant = 'primary' },
            },
        }
    end
    return found
end

-- The search box and the results list that sit on the Cornerselling and Recipe pages.
local function searchBlocks(state, prefix, description, found)
    local blocks = {
        {
            type = 'form', id = prefix .. '-search', title = 'Add items',
            fields = { { id = 'query', label = 'Search all items', type = 'text', default = state.query or '', description = description } },
            action = { id = prefix .. ':search', label = 'Search' },
        },
    }
    if state.query then
        local more = state.total > #found and (' of ' .. state.total) or ''
        blocks[#blocks + 1] = {
            type = 'list', id = prefix .. '-results', layout = 'cards', columns = 3,
            title = ('Results for "%s" (%d%s)'):format(state.query, #found, more),
            items = found, empty = 'No items match that search.',
        }
    end
    return blocks
end

local function money(value)
    return ('$%d'):format(math.floor(tonumber(value) or 0))
end

local function itemLabel(name)
    local info = corner.items[name]
    return info and info.label or name
end

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

    local found = foundItems(corner.results, 'corner:add:', 'Already in the list')

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
    }

    for _, block in ipairs(searchBlocks(corner, 'corner', 'Part of an item name or label. Add the ones you want to sell below.', found)) do
        blocks[#blocks + 1] = block
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

local function recipeEntry(id)
    for _, recipe in ipairs(recipes.list) do
        if recipe.id == id then return recipe end
    end
end

local function recipeItemLabel(name)
    local info = recipes.items[name]
    return info and info.label or name
end

local function makesText(recipe)
    if not recipe.receive then return 'Makes nothing by itself' end
    return ('Makes %dx %s'):format(recipe.receive.amount, recipeItemLabel(recipe.receive.item))
end

local function needsText(recipe)
    local parts = {}
    for _, entry in ipairs(recipe.give) do
        parts[#parts + 1] = ('%dx %s'):format(entry.amount, recipeItemLabel(entry.item))
    end
    return #parts > 0 and table.concat(parts, ', ') or 'Nothing'
end

local function giveCopy(recipe)
    local copy = {}
    for _, entry in ipairs(recipe.give) do
        copy[#copy + 1] = { item = entry.item, amount = entry.amount, keep = entry.keep }
    end
    return copy
end

local function recipeDrugs()
    local seen, drugs = {}, {}
    for _, recipe in ipairs(recipes.list) do
        local drug = recipe.id:match('^(%w+):')
        if drug and not seen[drug] then
            seen[drug] = true
            drugs[#drugs + 1] = { value = drug, label = drug }
        end
    end
    for _, custom in ipairs(customs.drugs) do
        if not seen[custom.name] then
            seen[custom.name] = true
            drugs[#drugs + 1] = { value = custom.name, label = custom.name }
        end
    end
    return drugs
end

local function recipesView()
    local items = {}
    for _, recipe in ipairs(recipes.list) do
        items[#items + 1] = {
            id = recipe.id,
            label = recipe.label,
            description = makesText(recipe),
            metadata = { { label = 'Needs', value = needsText(recipe) } },
            action = 'recipe:select:' .. recipe.id,
        }
    end
    local drugs = recipeDrugs()

    return {
        id = 'recipes', label = 'Recipes', icon = 'FlaskConical',
        content = {
            title = 'Recipes',
            description = 'Pick a recipe to change what it makes and needs, or make a new one.',
            blocks = {
                {
                    type = 'form', id = 'recipe-create', title = 'New recipe',
                    fields = {
                        { id = 'drug', label = 'Drug', type = 'select', options = drugs,
                            default = drugs[1] and drugs[1].value },
                        { id = 'name', label = 'Name', type = 'text', required = true,
                            description = 'Letters and numbers only, starting with a letter. e.g. Snow' },
                        { id = 'item', label = 'Item it makes', type = 'text',
                            description = 'The item name the player receives. Leave empty for a recipe that makes nothing by itself.' },
                        { id = 'amount', label = 'Amount made', type = 'number', min = 1, max = 1000, default = 1 },
                    },
                    action = { id = 'recipe:create', label = 'Create recipe' },
                },
                { type = 'list', id = 'recipe-list', layout = 'cards', columns = 3, items = items, empty = 'No recipes found.' },
            },
        },
    }
end

local function recipeView()
    local recipe = recipeEntry(recipes.selected)
    if not recipe then
        return {
            id = 'recipe', label = 'Recipe', icon = 'FlaskConical',
            content = { title = 'Recipe', blocks = { { type = 'empty', title = 'Pick a recipe first.' } } },
        }
    end

    local required = {}
    for _, entry in ipairs(recipe.give) do
        local info = recipes.items[entry.item]
        required[#required + 1] = {
            id = entry.item,
            label = recipeItemLabel(entry.item),
            description = info and entry.item or (entry.item .. ' · not in the shared items'),
            image = info and info.image or nil,
            metadata = {
                { label = 'Amount', value = ('%dx'):format(entry.amount) },
                entry.keep and { label = 'Used up', value = 'No, kept' } or nil,
            },
            actions = {
                { id = 'recipe:edit:' .. entry.item, label = 'Edit', icon = 'Pencil', variant = 'primary' },
                { id = 'recipe:remove:' .. entry.item, label = 'Remove', icon = 'Trash2', variant = 'destructive' },
            },
        }
    end

    local found = foundItems(recipes.results, 'recipe:add:', 'Already in the recipe')

    local blocks = searchBlocks(recipes, 'recipe', 'Part of an item name or label. Add the ones this recipe should need below.', found)

    blocks[#blocks + 1] = {
        type = 'list', id = 'recipe-required', layout = 'cards', columns = 3,
        title = ('Required items (%d)'):format(#required),
        items = required, empty = 'Nothing is required yet. Search above to add an item.',
    }

    if recipe.custom then
        table.insert(blocks, 1, {
            type = 'form', id = 'recipe-receive', title = 'What it makes',
            fields = {
                { id = 'item', label = 'Item it makes', type = 'text', default = recipe.receive and recipe.receive.item or '',
                    description = 'Leave empty for a recipe that makes nothing by itself.' },
                { id = 'amount', label = 'Amount made', type = 'number', min = 1, max = 1000,
                    default = recipe.receive and recipe.receive.amount or 1 },
            },
            action = { id = 'recipe:receive', label = 'Save' },
        })
        blocks[#blocks + 1] = {
            type = 'actions', title = 'Danger zone',
            actions = { { id = 'recipe:delete', label = 'Delete recipe', variant = 'destructive' } },
        }
    end

    return {
        id = 'recipe', label = recipe.label, icon = 'FlaskConical',
        content = {
            title = recipe.label,
            description = makesText(recipe) .. '. These are the items a player needs to make it.',
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
    if selectedEvent and eventInfo(selectedEvent.step) then
        navigation[#navigation + 1] = eventView()
    end
    navigation[#navigation + 1] = customsView()
    navigation[#navigation + 1] = cornerView()
    navigation[#navigation + 1] = recipesView()
    if recipes.selected then
        navigation[#navigation + 1] = recipeView()
    end
    return navigation
end

local function refresh(message)
    local navigation = buildNavigation()
    Kora.nui.updateApp(APP_ID, { navigation = navigation })
    return { update = { navigation = navigation }, notice = message }
end

local function fail(message)
    return refresh(notice(message, 'destructive'))
end

local function persist(patch)
    local result, err = Kora.callback.trigger('qbdrugs:creator:save', selected.id, patch)
    if not result then return false, err or 'Failed to save.' end
    plantsStale = true
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
    local record, err = Kora.callback.trigger('qbdrugs:creator:create', values.name, values.model, values.item)
    if not record then return fail(err or 'Failed to create plant.') end
    plantsStale = true
    selected, currentView = record, 'data'
    return refresh(notice('Plant created.'))
end

local function selectPlant(id)
    local record, err = Kora.callback.trigger('qbdrugs:creator:get', id)
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
    if not confirmed('Delete plant?', ('This removes %s and all of its spots.'):format(selected.id)) then return refresh() end

    local ok, err = Kora.callback.trigger('qbdrugs:creator:delete', selected.id)
    if not ok then return fail(err or 'Failed to delete plant.') end
    plantsStale = true
    selected, currentView = nil, 'plants'
    return refresh(notice('Plant deleted.'))
end

local function persistEvent(patch)
    local result, err = Kora.callback.trigger('qbdrugs:creator:event:save', selectedEvent.step, patch)
    if not result then return false, err or 'Failed to save.' end
    selectedEvent = result
    return true
end

local function selectEvent(step)
    if not eventInfo(step) then return fail('Unknown event.') end
    local record, err = Kora.callback.trigger('qbdrugs:creator:event:get', step)
    if not record then return fail(err or 'Failed to load event.') end
    selectedEvent, currentView = record, 'event'
    eventRevision = eventRevision + 1
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
    elseif kind == 'text' then
        data = {}
        for _, field in ipairs(eventInfo(selectedEvent.step).text.fields) do
            data[field.id] = values[field.id] or ''
        end
    else
        data = { enterTarget = values.enterTarget or '', exitTarget = values.exitTarget or '' }
    end

    if defaultRecipes[selectedEvent.step] or eventInfo(selectedEvent.step).custom then
        data.recipe = values.recipe ~= 'none' and values.recipe or nil
    end

    local patch = { data = data }
    if eventInfo(selectedEvent.step).explosion then
        -- the switch lives with the station's saved position, so send that along with the new value
        local location = {}
        for key, value in pairs(selectedEvent.locations or {}) do location[key] = value end
        location.explosion = values.explosion == 'enabled'
        patch.locations = location
    end

    local ok, err = persistEvent(patch)
    if not ok then return fail(err) end
    eventRevision = eventRevision + 1
    return refresh(notice('Saved.'))
end

local function startEntrance(values)
    local gang = optionalText(values.gang)

    pendingTool, currentView = { kind = 'entrance', gang = gang, exit = eventInfo(selectedEvent.step).exit }, 'event'
    return { close = true }
end

-- Loads one page's data from the server. apply(result) stores it.
local function loadPage(callback, failMessage, apply)
    local result, err = Kora.callback.trigger(callback)
    if not result then
        toast('Drug Creator', err or failMessage)
        return false
    end
    apply(result)
    return true
end

local function loadCorner()
    return loadPage('qbdrugs:creator:corner:get', 'Could not load the cornerselling settings.', function(result)
        corner.data, corner.items = result.data, result.items or {}
    end)
end

local function persistCorner(data)
    local result, err = Kora.callback.trigger('qbdrugs:creator:event:save', CORNER_STEP, { data = data })
    if not result then return false, err or 'Failed to save.' end
    corner.data = result.data
    return true
end

local function askPrice(label, current, title)
    local result = Kora.nui.openInputDialog({
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
        local query = text(values.query)
        if query == '' then
            corner.query, corner.results, corner.total = nil, {}, 0
            return refresh()
        end

        local result, err = Kora.callback.trigger('qbdrugs:creator:corner:search', query)
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

local function setRecipes(result)
    recipes.list, recipes.items = result.list or {}, result.items or {}
end

local function clearRecipeSearch()
    recipes.query, recipes.results, recipes.total = nil, {}, 0
end

local function loadRecipes()
    return loadPage('qbdrugs:creator:recipes:get', 'Could not load the recipes.', setRecipes)
end

local function askAmount(label, title, current)
    local result = Kora.nui.openInputDialog({
        { id = 'amount', label = 'Amount needed', type = 'number', min = 1, max = 1000, default = current and current.amount or 1, required = true },
        {
            id = 'keep', label = 'Used up when crafting?', type = 'select',
            default = current and current.keep and 'keep' or 'use',
            options = { { value = 'use', label = 'Yes, used up' }, { value = 'keep', label = 'No, the player keeps it' } },
        },
    }, title, label)
    if not result or result.cancelled then return nil end

    local amount = tonumber(result.values and result.values.amount)
    if not amount then return nil end
    return { amount = math.floor(amount), keep = result.values.keep == 'keep' or nil }
end

local function saveRecipe(recipe, give, message)
    local result, err = Kora.callback.trigger('qbdrugs:creator:recipes:set', recipe.id, give)
    if not result then return fail(err or 'Failed to save.') end
    setRecipes(result)

    local updated = recipeEntry(recipe.id)
    local inRecipe = {}
    for _, entry in ipairs(updated and updated.give or {}) do inRecipe[entry.item] = true end
    for _, found in ipairs(recipes.results) do found.added = inRecipe[found.name] == true end
    return refresh(notice(message))
end

local function recipeAction(actionId, values)
    if actionId == 'recipe:reload' then
        loadRecipes()
        return refresh()
    end

    if actionId == 'recipe:create' then
        local drug = text(values.drug)
        local name = text(values.name)
        local item = text(values.item)
        local result, err = Kora.callback.trigger('qbdrugs:creator:recipes:create', drug, name, item, tonumber(values.amount) or 1)
        if not result then return fail(err or 'Failed to create the recipe.') end

        setRecipes(result)
        recipes.selected = result.id
        clearRecipeSearch()
        currentView = 'recipe'
        return refresh(notice('Recipe created. Add the items it needs below.'))
    end

    local selectId = actionId:match('^recipe:select:(.+)$')
    if selectId then
        if not recipeEntry(selectId) then return fail('Unknown recipe.') end
        recipes.selected = selectId
        clearRecipeSearch()
        currentView = 'recipe'
        return refresh()
    end

    local recipe = recipeEntry(recipes.selected)
    if not recipe then return fail('Pick a recipe first.') end

    if actionId == 'recipe:receive' then
        local item = text(values.item)
        local result, err = Kora.callback.trigger('qbdrugs:creator:recipes:receive', recipe.id, item, tonumber(values.amount) or 1)
        if not result then return fail(err or 'Failed to save.') end
        setRecipes(result)
        return refresh(notice('Saved.'))
    end

    if actionId == 'recipe:delete' then
        local message = ('This removes %s. Events that used it go back to their default recipe.'):format(recipe.label)
        if not confirmed('Delete recipe?', message) then return refresh() end

        local result, err = Kora.callback.trigger('qbdrugs:creator:recipes:delete', recipe.id)
        if not result then return fail(err or 'Failed to delete the recipe.') end
        setRecipes(result)
        recipes.selected = nil
        clearRecipeSearch()
        currentView = 'recipes'
        return refresh(notice('Recipe deleted.'))
    end

    if actionId == 'recipe:search' then
        local query = text(values.query)
        if query == '' then
            clearRecipeSearch()
            return refresh()
        end

        local result, err = Kora.callback.trigger('qbdrugs:creator:recipes:search', query, recipe.id)
        if not result then return fail(err or 'The search failed.') end
        recipes.query, recipes.results = query, result.results or {}
        recipes.total = result.total or #recipes.results
        return refresh()
    end

    local addName = actionId:match('^recipe:add:(.+)$')
    if addName then
        local found
        for _, result in ipairs(recipes.results) do
            if result.name == addName then found = result break end
        end
        if not found then return fail('Search for that item again first.') end

        local picked = askAmount(found.label, 'Add to recipe')
        if not picked then return refresh() end

        local give = giveCopy(recipe)
        give[#give + 1] = { item = addName, amount = picked.amount, keep = picked.keep }
        return saveRecipe(recipe, give, ('%dx %s added.'):format(picked.amount, found.label))
    end

    local editName = actionId:match('^recipe:edit:(.+)$')
    if editName then
        local give = giveCopy(recipe)
        local entry
        for _, candidate in ipairs(give) do
            if candidate.item == editName then entry = candidate break end
        end
        if not entry then return refresh() end

        local picked = askAmount(recipeItemLabel(editName), 'Edit item', entry)
        if not picked then return refresh() end

        entry.amount, entry.keep = picked.amount, picked.keep
        return saveRecipe(recipe, give, ('%s now needs %dx.'):format(recipeItemLabel(editName), picked.amount))
    end

    local removeName = actionId:match('^recipe:remove:(.+)$')
    if removeName then
        local give = {}
        for _, entry in ipairs(giveCopy(recipe)) do
            if entry.item ~= removeName then give[#give + 1] = entry end
        end
        return saveRecipe(recipe, give, ('%s removed.'):format(recipeItemLabel(removeName)))
    end

    return refresh()
end

local function loadCustoms()
    return loadPage('qbdrugs:creator:custom:get', 'Could not load the custom drugs.', applyCustoms)
end

local function customAction(actionId, values)
    if actionId == 'custom:create' then
        local name = text(values.name)
        local result, err = Kora.callback.trigger('qbdrugs:creator:custom:drug:create', name)
        if not result then return fail(err or 'Failed to create the drug.') end

        applyCustoms(result)
        return refresh(notice('Drug created. Pick it in the New event form on the Events page.'))
    end

    if actionId == 'custom:event:create' then
        local drugName = text(values.drug)
        if drugName == '' then return fail('Create a drug on the Custom drugs tab first.') end

        local name = text(values.name)
        local result, err = Kora.callback.trigger('qbdrugs:creator:custom:event:create', drugName, name)
        if not result then return fail(err or 'Failed to add the event.') end

        applyCustoms(result)
        return selectEvent(result.step)
    end

    local deleteName = actionId:match('^custom:delete:(.+)$')
    if deleteName then
        local drug
        for _, entry in ipairs(customs.drugs) do
            if entry.name == deleteName then drug = entry end
        end
        if not drug then return fail('Unknown drug.') end

        local message = ('This removes %s and all %d of its events. Its recipes stay on the Recipes page.'):format(drug.name, #drug.events)
        if not confirmed('Delete drug?', message) then return refresh() end

        local result, err = Kora.callback.trigger('qbdrugs:creator:custom:drug:delete', drug.name)
        if not result then return fail(err or 'Failed to delete the drug.') end

        if selectedEvent and selectedEvent.step:match('^' .. drug.name .. ':') then selectedEvent = nil end
        applyCustoms(result)
        currentView = 'customs'
        return refresh(notice('Drug deleted.'))
    end

    if actionId == 'custom:event:delete' then
        if not (selectedEvent and eventInfo(selectedEvent.step) and eventInfo(selectedEvent.step).custom) then return refresh() end

        if not confirmed('Delete event?', ('This removes %s and all of its locations.'):format(selectedEvent.step)) then return refresh() end

        local result, err = Kora.callback.trigger('qbdrugs:creator:custom:event:delete', selectedEvent.step)
        if not result then return fail(err or 'Failed to delete the event.') end

        selectedEvent, currentView = nil, 'events'
        applyCustoms(result)
        return refresh(notice('Event deleted.'))
    end

    return refresh()
end

local function deleteBaseEvent()
    local info = selectedEvent and eventInfo(selectedEvent.step)
    if not (info and info.kind ~= 'lab' and not info.custom) then return refresh() end

    local message = ('This removes %s and all of its locations. You can restore it from the Events page.'):format(info.label)
    if not confirmed('Delete event?', message) then return refresh() end

    local result, err = Kora.callback.trigger('qbdrugs:creator:event:delete', selectedEvent.step)
    if not result then return fail(err or 'Failed to delete the event.') end

    applyCustoms(result)
    selectedEvent, currentView = nil, 'events'
    return refresh(notice('Event deleted.'))
end

local function restoreBaseEvent(step)
    if not eventInfo(step) then return fail('Unknown event.') end

    local result, err = Kora.callback.trigger('qbdrugs:creator:event:restore', step)
    if not result then return fail(err or 'Failed to restore the event.') end

    applyCustoms(result)
    currentView = 'events'
    return refresh(notice('Event restored.'))
end

local function onAction(actionId, context)
    local values = context and context.value or {}

    if actionId == 'create' then return createPlant(values) end
    if actionId:match('^corner:') then return cornerAction(actionId, values) end
    if actionId:match('^recipe:') then return recipeAction(actionId, values) end
    if actionId:match('^custom:') then return customAction(actionId, values) end

    local restoreStep = actionId:match('^event:restore:(.+)$')
    if restoreStep then return restoreBaseEvent(restoreStep) end

    local eventStep = actionId:match('^event:select:(.+)$')
    if eventStep then return selectEvent(eventStep) end

    if actionId:match('^event:') then
        if not selectedEvent then return refresh() end
        if actionId == 'event:data:save' then return saveEventData(values) end
        if actionId == 'event:add' then return startEntrance(values) end
        if actionId == 'event:delete' then return deleteBaseEvent() end
        if actionId == 'event:place' then
            local object = optionalText(values.object)
            if object and not modelExists(object) then return fail('Unknown object model.') end
            local gang = optionalText(values.gang)
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

Kora.nui.registerApp({
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

-- Aims, then saves one placement, until the admin cancels. build(aimed) returns the place's data;
-- save(place) returns ok, err.
local function placeUntilCancelled(aim, build, save, title, once)
    while true do
        local aimed = aim()
        local c = aimed and aimed.coords
        if not c then return end

        local ok, err = save(build(c, aimed))
        if not ok then
            toast(title, err)
            return
        end
        if once then return end
    end
end

local function runPendingTool()
    local tool = pendingTool
    pendingTool = nil

    if tool.kind == 'entrance' then
        placeUntilCancelled(
            function() return Kora.raycast.getCoords({}) end,
            function(c) return { enter = { x = c.x, y = c.y, z = c.z }, exit = tool.exit, gang = tool.gang } end,
            function(place) return persistEvent({ locations = appended(selectedEvent.locations, place) }) end,
            'Drug Creator', true)
    elseif tool.kind == 'point' then
        placeUntilCancelled(
            function() return Kora.raycast.getCoords(tool.object and { type = 'object', object = tool.object } or {}) end,
            function(c, aimed) return { coords = { x = c.x, y = c.y, z = c.z, w = c.w or aimed.heading }, object = tool.object, gang = tool.gang } end,
            function(place) return persistEvent({ locations = appended(selectedEvent.locations, place) }) end,
            'Drug Creator')
    elseif tool.kind == 'spot' then
        placeUntilCancelled(
            function() return Kora.raycast.getCoords({ type = 'object', object = selected.data.model }) end,
            function(c) return { coords = { x = c.x, y = c.y, z = c.z } } end,
            function(place) return persist({ locations = appended(selected.locations, place) }) end,
            'Plant Creator')
    end
end

-- Fills every page from the one server callback. Returns false, err when it fails.
local function loadCreator()
    local data, err = Kora.callback.trigger('qbdrugs:creator:open')
    if not data then return false, err end

    plantList, plantsStale = data.plants or {}, false
    corner.query, corner.results, corner.total = nil, {}, 0
    corner.data, corner.items = data.corner.data, data.corner.items or {}
    applyCustoms(data.customs)
    clearRecipeSearch()
    setRecipes(data.recipes)
    return true
end

local function loadingView(id)
    return {
        id = id, label = 'Drug Creator', icon = 'Leaf',
        content = { title = 'Drug Creator', blocks = { { type = 'empty', title = 'Loading Drug Creator…', icon = 'Leaf' } } },
    }
end

-- Builds the real navigation, falling back to Plants when the remembered page no longer exists.
local function currentNavigation()
    local navigation = buildNavigation()
    for i = 1, #navigation do
        if navigation[i].id == currentView then return navigation end
    end
    currentView = 'plants'
    return navigation
end

local function open()
    -- The window opens at once with a loading page; the data replaces it when it arrives.
    -- It must always contain the app's defaultView ('plants'), or kora_lib rejects the update.
    local loading = { loadingView('plants') }
    if currentView ~= 'plants' then loading[2] = loadingView(currentView) end
    Kora.nui.updateApp(APP_ID, { navigation = loading })

    CreateThread(function()
        local ok, err = loadCreator()
        if not ok then
            Kora.nui.closeApp(APP_ID)
            toast('Plant Creator', err or 'Admin permission required.')
            return
        end
        Kora.nui.updateApp(APP_ID, { navigation = currentNavigation() })
    end)

    while true do
        Kora.nui.openApp(APP_ID, { viewId = currentView })
        if not pendingTool then break end
        runPendingTool()
        Kora.nui.updateApp(APP_ID, { navigation = currentNavigation() })
    end
end

RegisterNetEvent('qbdrugs:creator:open', function()
    if source ~= 65535 then return end
    CreateThread(open)
end)