local Step = Config.Cocaine.steps
local events = {
    {name = 'qb-drugs:server:powderCocaine', action = function(src, key)
        assert(QB.distance.player(src, Drugs.Cocaine.powder.locations[key].coords, 5.0))
        runEvent(src, Step.powdering, nil, 'qb-drugs:server:powderCocaine')
    end},
    {name = 'qb-drugs:server:cutCocaine',    action = function(src, key)
        assert(QB.distance.player(src, Drugs.Cocaine.cutting.locations.coords, 5.0))
        runEvent(src, Step.cutting,   nil, 'qb-drugs:server:cutCocaine')
    end},
    {name = 'qb-drugs:server:bagCocaine',    action = function(src, key)
        assert(QB.distance.player(src, Drugs.Cocaine.bagging.locations.coords, 5.0))
        runEvent(src, Step.bagging,   nil, 'qb-drugs:server:bagCocaine')
    end},
}

for _, event in pairs(events) do
    RegisterNetEvent(event.name, function(key)
        local src = source
        event.action(src, key)
    end)
end

RegisterLabTeleport('cocaine', 'Cocaine', 'lab')