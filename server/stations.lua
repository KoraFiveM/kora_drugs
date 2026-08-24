-- Server-side proximity/ownership validation for every station action. The
-- client already ran the progressbar/minigame locally (qblib's own
-- QB.minigames session is independently validated server-side inside qblib
-- itself -- see modules/minigames/docs.md); what this file re-checks is the
-- one thing a modified client could still lie about cheaply: whether the
-- player is actually standing at the station they claim to have used.

local stationActions = {}

QB.callback.register('qbdrugs:server:beginStation', function(src, drugName, stageName)
    local drug = Config.drugs[drugName]
    local station = drug and drug.stations[stageName]
    if not station then return nil, 'unknown station' end
    if stationActions[src] then return nil, 'another station action is already in progress' end
    if not QB.distance.player(src, station.coords, station.radius or Config.proximity.stationRadius) then
        return nil, 'too far from station'
    end

    local now = GetGameTimer()
    local token = ('%s:%s:%s:%s'):format(src, drugName, now, math.random(100000, 999999))
    stationActions[src] = {
        token = token,
        drugName = drugName,
        stageName = stageName,
        readyAt = station.minigame and now or now + (station.duration or 5000),
        expiresAt = now + math.max((station.duration or 5000) + 15000, 30000),
    }
    return token
end)

RegisterNetEvent('qbdrugs:server:useStation', function(drugName, stageName, token, completed, proof)
    local src = source
    local drug = Config.drugs[drugName]
    if not drug then return end
    local station = drug.stations[stageName]
    if not station then return end

    local action = stationActions[src]
    stationActions[src] = nil
    if not action or action.token ~= token or action.drugName ~= drugName or action.stageName ~= stageName then return end
    local now = GetGameTimer()
    if completed ~= true or now > action.expiresAt or now < action.readyAt then return end

    if not QB.distance.player(src, station.coords, station.radius or Config.proximity.stationRadius) then
        QB.notify.send(src, { title = 'Too far away', message = 'Get closer to the station.', type = 'error' })
        return
    end

    if station.minigame and not QB.minigames.consumeProof(src, proof, station.minigame) then return end

    local ok, err, result = Production.completeStage(src, drugName, stageName, station.coords)
    if not ok then
        QB.notify.send(src, { title = station.label, message = err, type = 'error' })
        return
    end

    QB.notify.send(src, {
        title = station.label,
        message = result and ('Produced %dx %s.'):format(result.amount, result.item) or 'Done.',
        type = 'success',
    })
end)

AddEventHandler('playerDropped', function()
    stationActions[source] = nil
end)
