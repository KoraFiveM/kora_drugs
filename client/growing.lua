-- Sets up every station tagged phase == 'growing' (a drug's 'growStart'/
-- 'harvest' stations, when it has a growth phase at all -- meth has none).
-- Also defines Drugs.runStation, the ONE generic station-interaction runner
-- processing.lua and packaging.lua reuse (fxmanifest.lua loads this file
-- first). It runs whichever minigame the station's config names, or a plain
-- progressbar when it names none -- never a hardcoded minigame type.

Drugs = Drugs or {}

---@param drugName string
---@param stageName string
---@param station QBDrugsStation
function Drugs.runStation(drugName, stageName, station)
    local started, beginErr = QB.actions.run({
        label = station.label,
        duration = station.duration,
        minigame = station.minigame,
        canCancel = true,
        disable = { move = true, combat = true },
        begin = function(drug, stage)
            return QB.callback.trigger('qbdrugs:server:beginStation', drug, stage)
        end,
        complete = function(result, drug, stage)
            TriggerServerEvent('qbdrugs:server:useStation', drug, stage,
                result.token, result.completed, result.proof)
        end,
    }, drugName, stageName)

    if not started then
        QB.notify.send({ title = station.label, message = beginErr or 'Unable to begin this action.', type = 'error' })
    end
end

---@param drugName string
---@param stageName string
---@param station QBDrugsStation
function Drugs.setupStation(drugName, stageName, station)
    QB.interact.addCircleZone(drugName .. ':' .. stageName, station.coords, station.radius or Config.proximity.stationRadius, {
        options = {
            {
                label = station.label,
                action = function() Drugs.runStation(drugName, stageName, station) end,
            },
        },
    }, false)
end

for drugName, drug in pairs(Config.drugs) do
    for stageName, station in pairs(drug.stations) do
        if station.phase == 'growing' then
            Drugs.setupStation(drugName, stageName, station)
        end
    end
end
