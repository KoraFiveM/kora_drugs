local Step = Config.Heroin.steps

local events = {
    {name = "qb-drugs:server:HeroinDrying",  action = function(src, id)
         assert(QB.distance.player(src, Drugs.Heroin.drying.locations[id].coords, 5), 'Player is too far')
         runEvent(src, Step.drying, nil, 'qb-drugs:server:HeroinDrying')
     end },
    {name = "qb-drugs:server:HeroinVials",   action = function(src, id)
         assert(QB.distance.player(src, Drugs.Heroin.vials.locations[id].coords, 5), 'Player is too far')
         runEvent(src, Step.vials, nil, 'qb-drugs:server:HeroinVials')
     end },
    {name = "qb-drugs:server:HeroinSyringe", action = function(src, id)
         assert(QB.distance.player(src, Drugs.Heroin.syringe.locations[id].coords, 5), 'Player is too far')
         runEvent(src, Step.syringe, nil, 'qb-drugs:server:HeroinSyringe')
     end },
}

for _, event in pairs(events) do
    RegisterNetEvent(event.name, function(id)
        local src = source
        event.action(src, id)
    end)
end
