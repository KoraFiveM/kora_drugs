local isSelling = false
local previous = {}
local buyer = nil
local p
local Items = exports['qb-core']:GetShared('Items')
local drugDeal = nil
local function handShake(initiatorPed, receiverPed, onFinished)
    if not DoesEntityExist(initiatorPed) or not DoesEntityExist(receiverPed) then
        return
    end
    QB.stream.loadAnimDict("mp_ped_interaction")
    ClearPedTasks(initiatorPed)
    ClearPedTasks(receiverPed)

    TaskPlayAnim(initiatorPed, "mp_ped_interaction", 'handshake_guy_a', 8.0, -8.0, 3000, 0, 0, false, false, false)
    TaskPlayAnim(receiverPed, "mp_ped_interaction", 'handshake_guy_b', 8.0, -8.0, 3000, 0, 0, false, false, false)
    if onFinished then
        SetTimeout(3000, onFinished)
    end
end

local function resolve(bool) 
    if p then
        p:resolve(bool)
    end
end

RegisterNUICallback('accept', function(data, cb)
    SetNuiFocus(false, false)
    resolve(true)
    cb('ok')
end)
RegisterNUICallback('decline', function(data, cb)
    SetNuiFocus(false, false)
    resolve(false)
    cb('ok')
end)
RegisterNUICallback('hideUI', function(data, cb)
    SetNuiFocus(false, false)
    resolve(false)
    cb('ok')
end)

local function passChecks(id)
    local isPedHuman = IsPedHuman(id)
    local isPedPlayer = IsPedAPlayer(id)
    local isPedInVehicle = IsPedInAnyVehicle(id, false)
    local new = not previous[id]
    return isPedHuman == 1 and not isPedPlayer and not isPedInVehicle and new
end

local function endBuyer()
    if buyer then
        ClearPedTasks(buyer)
        SetEntityAsMissionEntity(buyer, false, true)
        SetEntityAsNoLongerNeeded(buyer)
        previous[buyer] = true
        buyer = nil
        p = nil
        exports['qb-core']:HideText()
    end
end

local function canSell()
    drugDeal = QB.callback.trigger('qbdrugs:getSellableItem')
    QB.print.debug(drugDeal)
    return drugDeal
end
local function findBuyer()
    if not drugDeal then
        canSell()
    end
    if not drugDeal then return end
    repeat
        exports['qb-core']:DrawText("Looking for a buyer...")
        Wait(1000)
        local ped = QB.closest.ped(GetEntityCoords(PlayerPedId()), 10.0)
        if ped.id then
            if passChecks(ped.id) then
                buyer = ped.id
                SetEntityAsMissionEntity(buyer, true, true)
                ClearPedTasksImmediately(buyer)
                SetBlockingOfNonTemporaryEvents(buyer, true)
                SetPedFleeAttributes(buyer, 0, false)
            end
        end
    until buyer ~= nil or not isSelling
    exports['qb-core']:DrawText("Buyer found! <br> On his way To you")
    if not isSelling then endBuyer() return end
    repeat
        Wait(1000)
        TaskGoToCoordAnyMeans(buyer, GetEntityCoords(PlayerPedId()), 1.0, 0, 0, 0, 0)
    until #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(buyer)) < 2.0 or not isSelling
    if not isSelling then endBuyer() return end
    exports['qb-core']:HideText()
    TaskTurnPedToFaceEntity(buyer, PlayerPedId(), -1)
    exports.qbtarget:addEntity(buyer, {
        {
            icon = "fas fa-hand-holding",
            label = "Sell to Buyer",
            onSelect = function()
                p = promise.new()
                SendNUIMessage({
                    action = 'setVisible',
                    data = {
                        img = drugDeal.img,
                        itemLabel = drugDeal.itemLabel,
                        total = drugDeal.total,
                        singlePrice = drugDeal.singlePrice,
                        amount = drugDeal.amount,

                    }
                })
                SetNuiFocus(true, true)
                local result = Citizen.Await(p)
                if result then
                    handShake(PlayerPedId(), buyer, function() ClearPedTasks(buyer) ClearPedTasks(PlayerPedId()) end)
                    TriggerServerEvent('qbdrugs:sellToBuyer', NetworkGetNetworkIdFromEntity(buyer))
                end
                endBuyer()
                findBuyer()
            end,
        }
    })
end

RegisterCommand('cornerSell', function(source)
    isSelling = not isSelling
    if isSelling then
        findBuyer()
    else
        resolve(false)
        endBuyer()
        exports['qb-core']:HideText()
    end
end)