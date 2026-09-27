local Step = Config.Heroin.steps

local events = {
    {name = "qb-drugs:server:HeroinDrying",  action = function(src)   runEvent(src, Step.drying, nil, 'qb-drugs:server:HeroinDrying') end },
    {name = "qb-drugs:server:HeroinVials",   action = function(src)   runEvent(src, Step.vials, nil, 'qb-drugs:server:HeroinVials') end },
    {name = "qb-drugs:server:HeroinSyringe", action = function(src)   runEvent(src, Step.syringe, nil, 'qb-drugs:server:HeroinSyringe') end },
}

for _, event in pairs(events) do
    RegisterNetEvent(event.name, function()
        local src = source
        event.action(src)
    end)
end
