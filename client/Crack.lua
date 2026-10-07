local cookZone, baggingZone, cookPeds, baggingPeds = {}, {}, {}, {}

local function clearCook()
    for _, id in ipairs(cookZone) do
        pcall(function() exports.qbtarget:removeZone(id) end)
    end
    for _, ped in ipairs(cookPeds) do
        pcall(function() QB.entities.remove(ped) end)
    end
    cookZone = {}
    cookPeds = {}
end

local function clearBagging()
    for _, id in ipairs(baggingZone) do
        pcall(function() exports.qbtarget:removeZone(id) end)
    end
    for _, ped in ipairs(baggingPeds) do
        pcall(function() QB.entities.remove(ped) end)
    end
    baggingZone = {}
    baggingPeds = {}
end

local function buildCook(cook)
    clearCook()
    local targ = cook.data
    for key, location in ipairs(cook.locations) do
        local options = {
            {
                label = targ.targetLabel or QB.lang('Crack.enter.target'),
                icon = targ.targetIcon or QB.lang('Crack.enter.icon'),
                onSelect = function()
                    progressTrigger(Config.Crack.steps.cook.recipe, targ, 'qb-drugs:server:cookCrack', key)
                end
            }
        }
        if location.object then
            cookPeds[#cookPeds + 1] = createObject(location.object, location.coords, 0, options)
        else
            cookZone[#cookZone + 1] = createBox(location.coords, 0, options)
        end
    end
end

local function buildBagging(bagging)
    clearBagging()
    local targ = bagging
    for key, location in ipairs(bagging.locations) do
        local options = {
            {
                label = targ.targetLabel or QB.lang('Crack.enter.target'),
                icon = targ.targetIcon or QB.lang('Crack.enter.icon'),
                onSelect = function()
                    progressTrigger(Config.Crack.steps.bagging.recipe, targ, 'qb-drugs:server:bagCrack', key)
                end
            }
        }
        if location.object then
            baggingPeds[#baggingPeds + 1] = createObject(location.object, location.coords, 0, options)
        else
            baggingZone[#baggingZone + 1] = createBox(location.coords, 0, options)
        end
    end
end
OnDrugs('Crack', 'cook', buildCook)
OnDrugs('Crack', 'bagging', buildBagging)