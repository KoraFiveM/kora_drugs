recipeIds = {}
recipeInfo = {}

local function labelFor(drug, name)
    return ('%s · %s'):format(drug, (name:gsub('^%l', string.upper)))
end

-- Recipes come only from the saved 'Recipes:settings' row. Every saved recipe is rebuilt here,
-- so one that is deleted in the creator disappears and one that is added shows up.
function applyRecipes(saved)
    saved = type(saved) == 'table' and saved or {}

    for id in pairs(recipeInfo) do
        if not saved[id] then recipeInfo[id] = nil end
    end

    for id, entry in pairs(saved) do
        local drug, name
        if type(id) == 'string' then drug, name = id:match('^(%w+):(%w+)$') end
        if drug and type(entry) == 'table' then
            local receive = type(entry.receive) == 'table' and entry.receive.item
                and { item = entry.receive.item, amount = entry.receive.amount or 1 } or nil

            local give = {}
            for index, item in ipairs(type(entry.give) == 'table' and entry.give or {}) do
                give[index] = { item = item.item, amount = item.amount, keep = item.keep }
            end

            local info = recipeInfo[id]
            if not info then
                info = { id = id, drug = drug, label = labelFor(drug, name), recipe = {}, custom = true }
                recipeInfo[id] = info
            end
            -- The recipe table is updated in place so anything holding it sees the change.
            info.recipe.receive = receive
            info.recipe.give = give
        end
    end

    for index = #recipeIds, 1, -1 do recipeIds[index] = nil end
    for id in pairs(recipeInfo) do recipeIds[#recipeIds + 1] = id end
    table.sort(recipeIds)
end

if IsDuplicityVersion() then
    CreateThread(function()
        while not (Drugs and Drugs.Recipes and Drugs.Recipes.settings) do Wait(100) end
        applyRecipes(Drugs.Recipes.settings.data.recipes)
    end)
else
    local function fromEntry(entry)
        applyRecipes(entry and entry.data and entry.data.recipes)
    end

    RegisterNetEvent('qbdrugs:client:drugsReload', function(drug, step, entry)
        if drug == 'Recipes' and step == 'settings' then fromEntry(entry) end
    end)

    CreateThread(function()
        local all = Kora.state.awaitGlobal('Drugs', 30000, 100)
        if all and all.Recipes then fromEntry(all.Recipes.settings) end
    end)
end