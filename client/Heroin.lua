if Config and Config.Heroin and Config.Heroin.disabled then
    print("Heroin plants are disabled")
    return
end

local steps = Config.Heroin and Config.Heroin.steps
if not steps then
    print("Heroin steps are not defined")
    return
end

basicTarget(steps.drying.coords,   steps.drying.rotation,    steps.drying,   "qb-drugs:server:HeroinDrying", 'Heroin.drying')
basicTarget(steps.vials.coords,    steps.vials.rotation,     steps.vials,    "qb-drugs:server:HeroinVials",  'Heroin.vials')
basicTarget(steps.syringe.coords,  steps.syringe.rotation,   steps.syringe,  "qb-drugs:server:HeroinSyringe",'Heroin.syringe')