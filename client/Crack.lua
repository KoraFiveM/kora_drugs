
if DrugConfig and DrugConfig.Crack and DrugConfig.Crack.disabled then
    print("Crack is disabled")
    return
end

local steps = DrugConfig.Crack.steps
if not steps then
    print("No steps defined for Crack")
    return
end

if steps.cook then
    local ped = QB.entities.create(steps.cook.prop, steps.cook.coords, {freeze = true, invincible = true})
    exports.qbtarget:addEntity(ped,  returnBasicOption(steps.cook, "qb-drugs:server:cookCrack", 'crack.cook'))
end
if steps.bagging then
    local ped = QB.entities.create(steps.bagging.prop, steps.bagging.coords, {freeze = true, invincible = true})
    exports.qbtarget:addEntity(ped, returnBasicOption(steps.bagging, "qb-drugs:server:bagCrack", 'crack.bagging'))
end