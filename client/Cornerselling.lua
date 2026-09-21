local isSelling = false
local previous = {}
local buyer = nil
local Items = exports['qb-core']:GetShared('Items')
local drugDeal = nil
local isOfferOpen = false
local function handShake(initiatorPed, receiverPed, onFinished)
    if not DoesEntityExist(initiatorPed) or not DoesEntityExist(receiverPed) then
        return
    end
    QB.stream.loadAnimDict("mp_ped_interaction")
    ClearPedTasks(initiatorPed)
    ClearPedTasks(receiverPed)

    TaskPlayAnim(initiatorPed, "mp_ped_interaction", 'handshake_guy_a', 8.0, -8.0, 3000, 0, 0, false, false, false)
    TaskPlayAnim(receiverPed, "mp_ped_interaction", 'handshake_guy_b', 8.0, -8.0, 3000, 0, 0, false, false, false)
    SetTimeout(3000, function()
        RemoveAnimDict("mp_ped_interaction")
        if onFinished then onFinished() end
    end)
end

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
                if isOfferOpen then return end

                isOfferOpen = true
                local offerBuyer = buyer
                local result = QB.nui.openAlert({
                    title = 'Confirm sale',
                    message = ('Sell %dx %s for $%.2f? ($%.2f each)'):format(
                        drugDeal.amount,
                        drugDeal.itemLabel,
                        drugDeal.total,
                        drugDeal.singlePrice
                    ),
                    image = drugDeal.img,
                    confirmLabel = 'Sell',
                    cancelLabel = 'Decline',
                })

                isOfferOpen = false
                if result and result.confirmed and isSelling and buyer == offerBuyer then
                    handShake(PlayerPedId(), offerBuyer, function()
                        ClearPedTasks(offerBuyer)
                        ClearPedTasks(PlayerPedId())
                    end)
                    TriggerServerEvent('qbdrugs:sellToBuyer', NetworkGetNetworkIdFromEntity(offerBuyer))
                end
                endBuyer()
                if isSelling then findBuyer() end
            end,
        }
    })
end

RegisterCommand('cornerSell', function(source)
    isSelling = not isSelling
    if isSelling then
        findBuyer()
    else
        endBuyer()
        exports['qb-core']:HideText()
    end
end)
