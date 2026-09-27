local Step = DrugConfig.Crack.steps
local events = {
    {name= 'qb-drugs:server:cookCrack', action = function(src)   runEvent(src, Step.cook, nil, 'qb-drugs:server:cookCrack')    end},
    {name= 'qb-drugs:server:bagCrack',  action = function(src)   runEvent(src, Step.bagging, nil, 'qb-drugs:server:bagCrack') end},
}

for _, event in pairs(events) do
    RegisterNetEvent(event.name, function()
        local src = source
        event.action(src)
    end)
end