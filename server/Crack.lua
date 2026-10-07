local Step = Config.Crack.steps
local events = {
    {name= 'qb-drugs:server:cookCrack', action = function(src, key)   
        assert(QB.distance.player(src, Drugs.Crack.cook.locations[key].coords, 5), 'Player is too far from the cook location')
        runEvent(src, Step.cook, nil, 'qb-drugs:server:cookCrack')    end},
    {name= 'qb-drugs:server:bagCrack',  action = function(src, key) 
        assert(QB.distance.player(src, Drugs.Crack.bagging.locations[key].coords, 5), 'Player is too far from the bagging location')
        runEvent(src, Step.bagging, nil, 'qb-drugs:server:bagCrack') end},
}

for _, event in pairs(events) do
    RegisterNetEvent(event.name, function(key)
        local src = source
        event.action(src, key)
    end)
end