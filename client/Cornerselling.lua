local isSelling = false
local previous = {}
local buyer = nil
local drugDeal = nil
local isOfferOpen = false
local cornerPrompt
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
    if cornerPrompt then QB.textui.hide(cornerPrompt); cornerPrompt = nil end
    if buyer then
        ClearPedTasks(buyer)
        SetEntityAsMissionEntity(buyer, false, true)
        SetEntityAsNoLongerNeeded(buyer)
        previous[buyer] = true
        buyer = nil
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
    cornerPrompt = QB.textui.show(QB.lang('cornerselling.looking'))
    repeat
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
    QB.textui.update(cornerPrompt, QB.lang('cornerselling.buyerFound'))
    if not isSelling then endBuyer() return end
    repeat
        Wait(1000)
        TaskGoToCoordAnyMeans(buyer, GetEntityCoords(PlayerPedId()), 1.0, 0, 0, 0, 0)
    until QB.distance.entity(buyer, 2.0) or not isSelling
    if not isSelling then endBuyer() return end
    TaskTurnPedToFaceEntity(buyer, PlayerPedId(), -1)
    QB.interact.addEntity(buyer, {
        {
            icon = QB.lang('cornerselling.sell.icon'),
            label = QB.lang('cornerselling.sell.target'),
            onSelect = function()
                if isOfferOpen then return end

                isOfferOpen = true
                local offerBuyer = buyer
                local result = QB.nui.openAlert({
                    title = QB.lang('cornerselling.sellAlert.title'),
                    message = QB.lang('cornerselling.sellAlert.message',
                        drugDeal.amount,
                        drugDeal.itemLabel,
                        drugDeal.total,
                        drugDeal.singlePrice
                    ),
                    image = drugDeal.img,
                    confirmLabel = QB.lang('cornerselling.sellAlert.confirmLabel'),
                    cancelLabel = QB.lang('cornerselling.sellAlert.cancelLabel'),
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
        if cornerPrompt then QB.textui.hide(cornerPrompt); cornerPrompt = nil end
    end
end)
