-- Every step that is "target -> progressbar -> server checks distance -> craft a recipe".
--
--   ['<Drug>:<step>'] = { recipe = '<key in Config.<Drug>.steps>', locale = '<lang prefix>' }
--
-- '<Drug>:<step>' is the row in Drugs (Drugs.Cocaine.powder). recipe is the name in
-- Config.<Drug>.steps, which isn't always the same word (powder -> powdering).
-- recipe is left out when the server handler does its own crafting (Weed:breakNugs).
-- locale is only the fallback text when the creator hasn't saved a targetLabel.
--
-- Anything a step needs beyond that goes in stepHooks['<Drug>:<step>']:
--   client  { check = fn() -> bool, run = fn(data, location) -> bool }
--           check runs after the item check. run replaces the progressbar (scene, minigame)
--           and returns true when the server should be asked to craft.
--   server  { meta = fn() -> table, handler = fn(src, location) }
--           meta is the item metadata for the recipe result. handler replaces the recipe.
craftSteps = {
    ['Cocaine:powder']   = { recipe = 'powdering', locale = 'Cocaine.powder' },
    ['Cocaine:cutting']  = { recipe = 'cutting',   locale = 'Cocaine.cut' },
    ['Cocaine:bagging']  = { recipe = 'bagging',   locale = 'Cocaine.bag' },
    ['Crack:cook']       = { recipe = 'cook',      locale = 'Crack.enter' },
    ['Crack:bagging']    = { recipe = 'bagging',   locale = 'Crack.enter' },
    ['Heroin:drying']    = { recipe = 'drying' },
    ['Heroin:vials']     = { recipe = 'vials' },
    ['Heroin:syringe']   = { recipe = 'syringe' },
    ['Weed:drying']      = { recipe = 'drying',    locale = 'Weed.dry' },
    ['Weed:breakNugs']   = { locale = 'Weed.breakNugs' },
    ['Weed:bagWeed']     = { locale = 'Weed.bag' },
}

stepHooks = {}

-- The recipe id (a key of recipeInfo, e.g. 'Cocaine:powdering') each step runs until the creator
-- picks another one on the events page. That choice is saved as data.recipe on the step's row.
defaultRecipes = {
    ['Meth:pour'] = 'Meth:cook',
    ['Meth:bag']  = 'Meth:bag',
}

for name, info in pairs(craftSteps) do
    if info.recipe then
        defaultRecipes[name] = name:match('^(%w+):') .. ':' .. info.recipe
    end
end

-- stepRecipe('Cocaine:powder', entry.data) -> the recipe table, then its recipeInfo entry.
function stepRecipeId(name, data)
    local chosen = type(data) == 'table' and data.recipe
    return recipeInfo[chosen] and chosen or defaultRecipes[name]
end

function stepRecipe(name, data)
    local info = recipeInfo[stepRecipeId(name, data)]
    return info and info.recipe, info
end