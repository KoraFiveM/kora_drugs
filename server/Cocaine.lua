local Step = Config.Cocaine.steps
local events = {
    {name = 'qb-drugs:server:powderCocaine', action = function(src)   runEvent(src, Step.powdering) end},
    {name = 'qb-drugs:server:cutCocaine',    action = function(src)   runEvent(src, Step.cutting) end},
    {name = 'qb-drugs:server:bagCocaine',    action = function(src)   runEvent(src, Step.bagging) end},
}

for _, event in pairs(events) do
    RegisterNetEvent(event.name, function()
        local src = source
        event.action(src)
    end)
end

exports.qbconsumables:addConsumable(Step.bagging.recipe.receive.item, {
    type = 'coke'
})