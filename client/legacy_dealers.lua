local core = exports['qb-core']:GetCoreObject()
local dealerZones, deliveryZone, active, busy = {}, nil, nil, false
local function removeDelivery()
    if deliveryZone then exports.kora_target:removeZone(deliveryZone); deliveryZone = nil end
end
local function message(text, kind)
    Kora.notify.send({ title = 'Dealer', message = text, type = kind or 'info' })
end
local function finished(result)
    removeDelivery()
    active = nil
    message(('Delivery completed: $%d, reputation %+d'):format(result.marked or result.cash or 0, result.dealerRep or 0), 'success')
end
local function deliver()
    if busy or not active then return end
    busy = true
    local ok, err = pcall(function()
        if not Kora.progressbar.start({ label = 'Delivering package', duration = 3500, canCancel = true,
            disable = { move = true, car = true, combat = true } }) then return end
        local result, reason = Kora.callback.trigger('qbdrugs:server:finishDelivery', { id = active.id })
        if result then finished(result) else message(reason or 'Delivery could not be completed', 'error') end
    end)
    busy = false
    if not ok then message('Delivery interrupted; the package can be retried.', 'error'); print('[qbdrugs] delivery: ' .. tostring(err)) end
end
local function route(data)
    if type(data) ~= 'table' or not data.id or not data.location or not data.location.coords then return end
    removeDelivery()
    active = data
    local coords = data.location.coords
    deliveryZone = exports.kora_target:addBoxZone({ coords = vector3(coords.x, coords.y, coords.z), size = vector3(2, 2, 2),
        options = { { label = 'Deliver package', icon = 'fa-solid fa-box', onSelect = deliver } } })
    SetNewWaypoint(coords.x, coords.y)
    message(('Deliver %d %s to %s. Follow the marked delivery location.'):format(data.amount, data.itemData.item, data.location.label))
end
local function request(name)
    if busy then return end
    busy = true
    local ok, data, reason = pcall(Kora.callback.trigger, 'qbdrugs:server:beginDelivery', name)
    busy = false
    if ok and data then route(data) else message(reason or 'Delivery unavailable', 'error') end
end
local function clearDealers()
    for _, zone in ipairs(dealerZones) do exports.kora_target:removeZone(zone) end
    dealerZones = {}
end
local function refresh(dealers)
    clearDealers()
    for name, dealer in pairs(type(dealers) == 'table' and dealers or {}) do
        local coords = dealer.coords
        dealerZones[#dealerZones + 1] = exports.kora_target:addBoxZone({
            coords = vector3(coords.x, coords.y, coords.z), size = vector3(2, 2, 2),
            options = {
                { label = name .. ': shop', icon = 'fa-solid fa-shopping-basket', onSelect = function() TriggerServerEvent('qb-drugs:server:dealerShop', name) end },
                { label = 'Request delivery', icon = 'fa-solid fa-box', onSelect = function() request(name) end },
            },
        })
    end
end
local function loaded()
    core.Functions.TriggerCallback('qb-drugs:server:RequestConfig', refresh)
    local result = Kora.callback.trigger('qbdrugs:server:resumeDelivery')
    if result then route(result) end
end
RegisterNetEvent('qb-drugs:client:RefreshDealers', refresh)
RegisterNetEvent('qbdrugs:client:delivery', function(data) if source == 65535 then route(data) end end)
RegisterNetEvent('qbdrugs:client:deliveryFinished', function(data) if source == 65535 then finished(data) end end)
RegisterNetEvent('qb-drugs:client:setLocation', function()
    -- Mail action arguments are presentation only; recover the server's own active route.
    local result = Kora.callback.trigger('qbdrugs:server:resumeDelivery')
    if result then route(result) end
end)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', loaded)
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function() removeDelivery(); clearDealers(); active, busy = nil, false end)
AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then removeDelivery(); clearDealers() end
end)
CreateThread(function() if LocalPlayer.state.isLoggedIn then loaded() end end)
