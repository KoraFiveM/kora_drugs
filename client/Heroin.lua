if Config and Config.Heroin and Config.Heroin.disabled then
    print("Heroin plants are disabled")
    return
end

local steps = Config.Heroin and Config.Heroin.steps
if not steps then
    print("Heroin steps are not defined")
    return
end


if steps.drying then
    exports.qbtarget:addBoxZone({
        coords = steps.drying.coords,
        size = vector3(2,2,2),
        rotation = steps.drying.rotation,
        options = returnBasicOption(steps.drying, "qb-drugs:server:HeroinDrying")
    })
end
if steps.vials then
    exports.qbtarget:addBoxZone({
        coords = steps.vials.coords,
        size = vector3(2,2,2),
        rotation = steps.vials.rotation,
        options = returnBasicOption(steps.vials, "qb-drugs:server:HeroinVials")
    })
end

if steps.syringe then
    exports.qbtarget:addBoxZone({
        coords = steps.syringe.coords,
        size = vector3(2,2,2),
        rotation = steps.syringe.rotation,
        options = returnBasicOption(steps.syringe, "qb-drugs:server:HeroinSyringe")
    })
end