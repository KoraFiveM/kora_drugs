local Step = Config.Heroin.steps

local events = {
    {name = "qb-drugs:server:HeroinDrying",  action = function(src)   runEvent(src, Step.drying) end },
    {name = "qb-drugs:server:HeroinVials",   action = function(src)   runEvent(src, Step.vials) end },
    {name = "qb-drugs:server:HeroinSyringe", action = function(src)   runEvent(src, Step.syringe) end },
}

for _, event in pairs(events) do
    RegisterNetEvent(event.name, function()
        local src = source
        event.action(src)
    end)
end

--exports.qbconsumables:addConsumable(Step.syringe.recipe.receive.item, {
--    type = 'inject'
--})