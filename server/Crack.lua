local Step = DrugConfig.Crack.steps
local events = {
    {name= 'qb-drugs:server:cookCrack', action = function(src)   runEvent(src, Step.cook)    end},
    {name= 'qb-drugs:server:bagCrack',  action = function(src)   runEvent(src, Step.bagging) end},
}

for _, event in pairs(events) do
    RegisterNetEvent(event.name, function()
        local src = source
        event.action(src)
    end)
end
--exports.qbconsumables:addConsumable(Step.bagging.recipe.receive.item, {
--    type = 'smoke'
--})