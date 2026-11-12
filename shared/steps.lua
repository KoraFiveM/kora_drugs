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

defaultRecipes = {
    ['Meth:pour'] = 'Meth:cook',
    ['Meth:bag']  = 'Meth:bag',
}

for name, info in pairs(craftSteps) do
    if info.recipe then
        defaultRecipes[name] = name:match('^(%w+):') .. ':' .. info.recipe
    end
end

function stepRecipeId(name, data)
    local chosen = type(data) == 'table' and data.recipe
    return recipeInfo[chosen] and chosen or defaultRecipes[name]
end

function stepRecipe(name, data)
    local info = recipeInfo[stepRecipeId(name, data)]
    return info and info.recipe, info
end