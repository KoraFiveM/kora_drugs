recipeIds = {}
recipeInfo = {}

function copyGive(list)
    local copy = {}
    for _, entry in ipairs(list or {}) do
        copy[#copy + 1] = { item = entry.item, amount = entry.amount, keep = entry.keep }
    end
    return copy
end

local function addRecipe(drug, name, recipe, successNotify)
    if type(recipe) ~= 'table' then return end
    recipe.give = recipe.give or {}

    local id = drug .. ':' .. name
    recipeIds[#recipeIds + 1] = id
    recipeInfo[id] = {
        id = id,
        drug = drug,
        label = ('%s · %s'):format(drug, (name:gsub('^%l', string.upper))),
        recipe = recipe,
        defaultGive = copyGive(recipe.give),
        successNotify = successNotify,
    }
end

local function findRecipes()
    for drug, settings in pairs(Config) do
        if type(drug) == 'string' and type(settings) == 'table' then
            for name, step in pairs(type(settings.steps) == 'table' and settings.steps or {}) do
                if type(step) == 'table' then addRecipe(drug, name, step.recipe, step.successNotify) end
            end
            for key, value in pairs(settings) do
                local name = type(key) == 'string' and key:match('^(.+)_recipe$')
                if name then addRecipe(drug, name, value) end
            end
        end
    end
    table.sort(recipeIds)
end

findRecipes()

local function rebuildIds()
    for index = #recipeIds, 1, -1 do recipeIds[index] = nil end
    for id in pairs(recipeInfo) do recipeIds[#recipeIds + 1] = id end
    table.sort(recipeIds)
end

local function syncCustomRecipes(saved)
    for id, info in pairs(recipeInfo) do
        if info.custom and not (type(saved[id]) == 'table' and saved[id].custom) then
            recipeInfo[id] = nil
        end
    end

    for id, entry in pairs(saved) do
        local existing = recipeInfo[id]
        if type(entry) == 'table' and entry.custom and not (existing and not existing.custom) then
            local drug, name = id:match('^(%w+):(%w+)$')
            if drug then
                local receive = type(entry.receive) == 'table' and entry.receive.item
                    and { item = entry.receive.item, amount = entry.receive.amount or 1 } or nil
                if existing then
                    existing.recipe.receive = receive
                else
                    recipeInfo[id] = {
                        id = id,
                        drug = drug,
                        label = ('%s · %s'):format(drug, (name:gsub('^%l', string.upper))),
                        recipe = { receive = receive, give = {} },
                        defaultGive = {},
                        custom = true,
                    }
                end
            end
        end
    end

    rebuildIds()
end

function applyRecipes(saved)
    saved = type(saved) == 'table' and saved or {}
    syncCustomRecipes(saved)
    for _, id in ipairs(recipeIds) do
        local info = recipeInfo[id]
        local override = type(saved[id]) == 'table' and saved[id].give
        local give = type(override) == 'table' and override or info.defaultGive

        local live = info.recipe.give
        for index = #live, 1, -1 do live[index] = nil end
        for index, entry in ipairs(give) do
            live[index] = { item = entry.item, amount = entry.amount, keep = entry.keep }
        end
    end
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
        local all = QB.state.awaitGlobal('Drugs', 30000, 100)
        if all and all.Recipes then fromEntry(all.Recipes.settings) end
    end)
end