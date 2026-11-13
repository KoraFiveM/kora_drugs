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
    Kora.stream.loadAnimDict("mp_ped_interaction")
    ClearPedTasks(initiatorPed)
    ClearPedTasks(receiverPed)

    TaskPlayAnim(initiatorPed, "mp_ped_interaction", 'handshake_guy_a', 8.0, -8.0, 3000, 0, 0, false, false, false)
    TaskPlayAnim(receiverPed, "mp_ped_interaction", 'handshake_guy_b', 8.0, -8.0, 3000, 0, 0, false, false, false)
    SetTimeout(3000, function()
        RemoveAnimDict("mp_ped_interaction")
        if onFinished then onFinished() end
    end)
end

local OFFER_APP_ID = 'kora_drugs:cornerOffer'
local offerAccepted = false

Kora.nui.registerApp({
    id = OFFER_APP_ID,
    title = Kora.lang('CornerSelling.offer'),
    icon = 'DollarSign',
    layout = 'compact',
    width = 480,
    height = 350,
    placement = 'right',
    defaultView = 'offer',
    navigation = { { id = 'offer', label = Kora.lang('CornerSelling.offer'), icon = 'DollarSign', content = { title = Kora.lang('CornerSelling.offer'), blocks = {} } } },
    onAction = function(actionId)
        if actionId == 'offer:accept' then
            offerAccepted = true
            return { close = true }
        end
        if actionId == 'offer:deny' then
            offerAccepted = false
            return { close = true }
        end
        return {}
    end,
})

local function openOffer(deal)
    offerAccepted = false
    local title = Kora.lang('CornerSelling.title')
    Kora.nui.updateApp(OFFER_APP_ID, {
        navigation = {
            {
                id = 'offer', label = title, icon = 'DollarSign',
                content = {
                    title = title,
                    blocks = {
                        {
                            type = 'list', id = 'offer-card', layout = 'cards', columns = 1,
                            items = {
                                {
                                    id = deal.item,
                                    label = deal.itemLabel,
                                    image = deal.img,
                                    metadata = {
                                        { label = Kora.lang('CornerSelling.price'), value = ('$%d'):format(math.floor(deal.singlePrice)) },
                                        { label = Kora.lang('CornerSelling.amount'), value = tostring(deal.amount) },
                                        { label = Kora.lang('CornerSelling.total'), value = ('$%d'):format(math.floor(deal.total)) }
                                    },
                                    actions = {
                                        { id = 'offer:accept', label = Kora.lang('CornerSelling.accept'), icon = 'Check', variant = 'primary' },
                                        { id = 'offer:deny', label = Kora.lang('CornerSelling.deny'), icon = 'X', variant = 'destructive' },
                                    },
                                },
                            },
                        },
                    },
                },
            },
        },
    })
    Kora.nui.openApp(OFFER_APP_ID, { viewId = 'offer' })
    return offerAccepted
end

local function passChecks(id)
    return IsPedHuman(id) == 1 and not IsPedAPlayer(id) and not IsPedInAnyVehicle(id, false) and not previous[id]
end

local function endBuyer()
    if cornerPrompt then Kora.textui.hide(cornerPrompt); cornerPrompt = nil end
    if buyer then
        ClearPedTasks(buyer)
        SetEntityAsMissionEntity(buyer, false, true)
        SetEntityAsNoLongerNeeded(buyer)
        previous[buyer] = true
        buyer = nil
    end
end

local function findBuyer()
    if not drugDeal then
        drugDeal = Kora.callback.trigger('kora_drugs:getSellableItem')
    end
    if not drugDeal then isSelling = false drugDeal = nil return end
    cornerPrompt = Kora.textui.show(Kora.lang('CornerSelling.looking'))
    repeat
        Wait(1000)
        local ped = Kora.closest.ped(GetEntityCoords(PlayerPedId()), 10.0)
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
    Kora.textui.update(cornerPrompt, Kora.lang('CornerSelling.buyer_found'))
    if not isSelling then endBuyer() return end
    repeat
        Wait(1000)
        TaskGoToCoordAnyMeans(buyer, GetEntityCoords(PlayerPedId()), 1.0, 0, 0, 0, 0)
    until Kora.distance.entity(buyer, 2.0) or not isSelling
    if not isSelling then endBuyer() return end
    TaskTurnPedToFaceEntity(buyer, PlayerPedId(), -1)
    exports.kora_target:addEntity(buyer, {
        {
            icon = 'fas fa-handshake',
            label = Kora.lang('CornerSelling.sell_to_buyer'),
            onSelect = function()
                if isOfferOpen then return end

                isOfferOpen = true
                local offerBuyer = buyer
                local accepted = openOffer(drugDeal)

                isOfferOpen = false
                if accepted and isSelling and buyer == offerBuyer then
                    handShake(PlayerPedId(), offerBuyer, function()
                        ClearPedTasks(offerBuyer)
                        ClearPedTasks(PlayerPedId())
                    end)
                    TriggerServerEvent('kora_drugs:sellToBuyer', NetworkGetNetworkIdFromEntity(offerBuyer))
                end
                endBuyer()
                drugDeal = nil
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
    end
end)