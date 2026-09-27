local Step = Config.Cocaine.steps
local events = {
    {name = 'qb-drugs:server:powderCocaine', action = function(src)   runEvent(src, Step.powdering, nil, 'qb-drugs:server:powderCocaine') end},
    {name = 'qb-drugs:server:cutCocaine',    action = function(src)   runEvent(src, Step.cutting,   nil, 'qb-drugs:server:cutCocaine') end},
    {name = 'qb-drugs:server:bagCocaine',    action = function(src)   runEvent(src, Step.bagging,   nil, 'qb-drugs:server:bagCocaine') end},
}

for _, event in pairs(events) do
    RegisterNetEvent(event.name, function()
        local src = source
        event.action(src)
    end)
end
