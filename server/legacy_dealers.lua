-- Legacy dealer domain. Pricing, inventory changes, reputation and delivery deadlines are server-owned.
local core = exports['qb-core']:GetCoreObject()
local config = LegacyDealerConfig
local dealers, locks, ready = {}, {}, false
local function query(sql, args)
    local result, err = Kora.sql.query(sql, args or {})
    assert(result ~= nil, err or 'dealer database operation failed')
    return result
end
local function player(src, citizenid)
    local value = core.Functions.GetPlayer(src)
    if value and (not citizenid or value.PlayerData.citizenid == citizenid) then return value end
end
local function locked(src, fn)
    local current = player(src)
    if not ready or not current then return nil, 'not_ready' end
    local cid = current.PlayerData.citizenid
    if locks[cid] then return nil, 'busy' end
    locks[cid] = true
    local ok, result, err = pcall(fn, cid)
    locks[cid] = nil
    if not ok then
        print('[qbdrugs] dealer operation failed: ' .. tostring(result))
        return nil, 'storage_unavailable'
    end
    return result, err
end
local function shopId(dealer) return 'qbdrugs-dealer-' .. dealer.id end
local function openHours(dealer)
    local state = GlobalState.kora_weathersync
    local hour = state and tonumber(state.hour)
    if not hour then return false end
    local first, last = dealer.time.min, dealer.time.max
    if first == last then return true end
    if first > last then return hour >= first or hour <= last end
    return hour >= first and hour <= last
end
local function available(src, name)
    local dealer = type(name) == 'string' and dealers[name]
    if not dealer or not openHours(dealer) or GetPlayerRoutingBucket(src) ~= 0 or not isNear(src, dealer.coords, 5) then return nil end
    return dealer
end
local function roster()
    local result = copyTable(dealers)
    for _, dealer in pairs(result) do
        local inventory = exports['qb-inventory']:GetInventory('shop:' .. shopId(dealer))
        if inventory and inventory.items then
            for slot, product in pairs(dealer.products) do
                local item = inventory.items[slot]
                product.amount = item and item.amount or 0
            end
        end
    end
    return result
end
local function loadDealers()
    local loaded = {}
    for _, row in ipairs(query('SELECT * FROM `dealers`')) do
        local coords, hours = decodeJson(row.coords), decodeJson(row.time)
        assert(type(row.name) == 'string' and row.name ~= '' and not loaded[row.name], 'invalid or duplicate dealer name')
        coords = cleanVec(coords)
        assert(coords and hours and inRange(hours.min, 0, 23, true) and inRange(hours.max, 0, 23, true), 'invalid dealer coordinates/hours')
        local dealer = { id = row.id, name = row.name, coords = coords, time = hours, products = copyTable(config.Products) }
        loaded[row.name] = dealer
        assert(exports['qb-inventory']:CreateShop({ name = shopId(dealer), label = row.name, coords = coords,
            slots = #config.Products, items = copyTable(config.Products), policyOwner = GetCurrentResourceName(),
            access = function(src) return ready and available(src, row.name) ~= nil end }), 'dealer shop registration failed')
    end
    dealers = loaded
end
local function stockAccess(payload, src)
    local id = payload.shopId or (payload.inventoryId and payload.inventoryId:match('^shop:(.+)$'))
    if type(id) ~= 'string' or not id:match('^qbdrugs%-dealer%-') then return true end
    if not ready then return false end
    for name, dealer in pairs(dealers) do
        if shopId(dealer) == id then
            if not available(src, name) then return false end
            if not payload.itemName then return true end
            local current = player(src)
            if not current then return false end
            for _, product in ipairs(dealer.products) do
                if product.name == payload.itemName then return current.Functions.GetRep('dealer') >= product.minrep end
            end
            return false
        end
    end
    return false
end
local function registerShopPolicy()
    for _, kind in ipairs({ 'openInventory', 'buyItem' }) do
        exports.kora_inventory:RegisterHook(kind, function(payload, src)
            local ok, result = pcall(stockAccess, payload, src)
            return ok and result == true
        end)
    end
end
local function publicDelivery(row)
    local data = decodeJson(row.data)
    if not data then return nil end
    data.id = tonumber(row.id)
    data.coords, data.locationLabel = copyTable(data.location.coords), data.location.label
    data.status = row.status
    return data
end
local function currentSession(cid)
    return query('SELECT * FROM `qbdrugs_deliveries` WHERE `active_citizenid` = ? LIMIT 1', { cid })[1]
end
local function exchange(src, row, suffix, terms)
    if not player(src, row.citizenid) then return nil, 'player_changed' end
    terms.citizenid = row.citizenid
    return exports.kora_inventory:ExecutePlayerExchange(src, 'qbdrugs:delivery:' .. row.id .. ':' .. suffix, terms)
end
local function sendMail(cid, data, completion)
    if GetResourceState('kora_phone-stevie') ~= 'started' and GetResourceState('qb-phone') ~= 'started' then return end
    local mail = { sender = data.dealer, subject = completion and 'Delivery completed' or 'Delivery request',
        message = completion and ('Your delivery has been settled. Reputation change: %s.'):format(completion.dealerRep)
            or ('Deliver %d %s to %s.'):format(data.amount, data.itemData.item, data.location.label) }
    if not completion then mail.button = { enabled = true, buttonEvent = 'qb-drugs:client:setLocation', buttonData = { id = data.id } } end
    -- The pinned legacy export returns nil; delivery authority does not depend on mail transport acknowledgement.
    local ok, err = pcall(function() exports['qb-phone']:sendNewMailToOffline(cid, mail) end)
    if not ok then print('[qbdrugs] delivery mail unavailable: ' .. tostring(err)) end
end
local function issue(src, row)
    if row.status ~= 'prepared' then return publicDelivery(row) end
    local data = assert(publicDelivery(row), 'invalid delivery snapshot')
    local receipt, err = exchange(src, row, 'issue', { take = {}, give = { { name = data.itemData.item, amount = data.amount } },
        cash = 0, dealerRep = 0, reason = 'qbdrugs-delivery-issue' })
    if not receipt then return nil, err end
    query('UPDATE `qbdrugs_deliveries` SET `status` = ? WHERE `id` = ? AND `status` = ?', { 'issued', row.id, 'prepared' })
    row.status = 'issued'
    data.status = 'issued'
    sendMail(row.citizenid, data)
    return data
end
local function begin(src, supplied)
    return locked(src, function(cid)
        local row = currentSession(cid)
        if row then return issue(src, row) end
        local name = type(supplied) == 'table' and supplied.dealer or supplied
        local dealer = available(src, name)
        if not dealer then return nil, 'dealer_unavailable' end
        local rep, options = player(src, cid).Functions.GetRep('dealer'), {}
        for index, item in ipairs(config.DeliveryItems) do if rep >= item.minrep then options[#options + 1] = index end end
        if #options == 0 then return nil, 'reputation_required' end
        local itemIndex, amount = options[math.random(#options)], math.random(1, 3)
        local location = config.DeliveryLocations[math.random(#config.DeliveryLocations)]
        -- Existing clients choose an allowed route/item/quantity. Preserve that valid intent while deriving all reward terms here.
        if type(supplied) == 'table' and supplied.item ~= nil then
            local requested = type(supplied.item) == 'number' and config.DeliveryItems[supplied.item]
            if not requested or rep < requested.minrep or type(supplied.amount) ~= 'number'
                or supplied.amount % 1 ~= 0 or supplied.amount < 1 or supplied.amount > 3 then return nil, 'invalid_delivery' end
            local coords, found = supplied.coords
            if type(coords) ~= 'table' and type(coords) ~= 'vector3' then return nil, 'invalid_delivery' end
            for _, candidate in ipairs(config.DeliveryLocations) do
                local c = candidate.coords
                if type(coords.x) == 'number' and type(coords.y) == 'number' and type(coords.z) == 'number'
                    and math.abs(coords.x - c.x) <= 0.01 and math.abs(coords.y - c.y) <= 0.01 and math.abs(coords.z - c.z) <= 0.01 then
                    found = candidate; break
                end
            end
            if not found then return nil, 'invalid_delivery' end
            itemIndex, amount, location = supplied.item, supplied.amount, found
        end
        local data = { dealer = name, amount = amount, item = itemIndex, itemData = copyTable(config.DeliveryItems[itemIndex]),
            location = copyTable(location),
            deadline = os.time() + config.deliverySeconds, bucket = 0 }
        -- Persist pricing and penalty settings with the delivery; a config edit cannot alter an outstanding promise.
        data.rules = { marked = config.UseMarkedBills, gain = config.DeliveryRepGain, loss = config.DeliveryRepLoss,
            police = config.PoliceDeliveryModifier, wrong = config.WrongAmountFee, overdue = config.OverdueDeliveryFee }
        query('INSERT INTO `qbdrugs_deliveries` (`citizenid`,`active_citizenid`,`status`,`data`,`created_at`) VALUES (?, ?, ?, ?, ?)',
            { cid, cid, 'prepared', json.encode(data), os.time() })
        return issue(src, assert(currentSession(cid), 'delivery insert could not be read'))
    end)
end
local function settlementResult(row, terms)
    return { id = tonumber(row.id), cash = terms.cash, marked = terms.give[1] and terms.give[1].info.worth,
        dealerRep = terms.dealerRep, completed = true }
end
local function settle(src, supplied)
    return locked(src, function(cid)
        local row = currentSession(cid)
        local id = type(supplied) == 'table' and tonumber(supplied.id)
        if not row or (id and id ~= tonumber(row.id)) then
            if id and id >= 1 and id % 1 == 0 then
                local completed = query('SELECT * FROM `qbdrugs_deliveries` WHERE `id` = ? AND `citizenid` = ? AND `status` = ? LIMIT 1', { id, cid, 'complete' })[1]
                if completed then return settlementResult(completed, assert(decodeJson(completed.settlement))) end
            end
            return nil, 'no_delivery'
        end
        local data = assert(publicDelivery(row), 'invalid delivery snapshot')
        if type(supplied) ~= 'table' or (supplied.id and tonumber(supplied.id) ~= tonumber(row.id)) then return nil, 'wrong_delivery' end
        if row.status == 'prepared' then return nil, 'not_issued' end
        if not player(src, cid) or GetPlayerRoutingBucket(src) ~= data.bucket or not isNear(src, data.location.coords, 5) then return nil, 'wrong_location' end
        local terms = decodeJson(row.settlement)
        if not terms then
            local count = math.min(data.amount, exports['qb-inventory']:GetItemCount(src, data.itemData.item) or 0)
            local late, full = os.time() > data.deadline, count == data.amount
            local payout = data.itemData.payout * count
            local perfect = not late and full
            if late then payout = math.floor(payout / data.rules.overdue)
            elseif not full then payout = math.floor(payout / data.rules.wrong)
            else
                local police = core.Functions.GetDutyCount('police')
                if police > 0 then payout = payout * police * data.rules.police end
            end
            terms = { citizenid = cid, take = count > 0 and { { name = data.itemData.item, amount = count } } or {}, give = {},
                cash = math.floor(payout), dealerRep = perfect and data.rules.gain or -data.rules.loss, reason = 'qbdrugs-delivery-settle' }
            if perfect and data.rules.marked and payout > 0 then
                terms.give = { { name = 'markedbills', amount = 1, info = { worth = math.floor(payout) } } }
                terms.cash = 0
            end
            query('UPDATE `qbdrugs_deliveries` SET `status` = ?, `settlement` = ? WHERE `id` = ?', { 'settling', json.encode(terms), row.id })
        end
        local receipt, err = exchange(src, row, 'settle', terms)
        if not receipt then return nil, err end
        query('UPDATE `qbdrugs_deliveries` SET `status` = ?, `active_citizenid` = NULL, `completed_at` = ? WHERE `id` = ?',
            { 'complete', os.time(), row.id })
        local result = settlementResult(row, terms)
        sendMail(cid, data, result)
        return result
    end)
end
local function notify(src, message)
    Kora.notify.send(src, { title = 'Dealer', message = message, type = 'error' })
end
Kora.callback.register('qbdrugs:server:beginDelivery', begin, { rateLimit = { max = 4, window = 10000 } })
Kora.callback.register('qbdrugs:server:finishDelivery', settle, { rateLimit = { max = 4, window = 10000 } })
Kora.callback.register('qbdrugs:server:resumeDelivery', function(src)
    return locked(src, function(cid) local row = currentSession(cid); return row and issue(src, row) end)
end, { rateLimit = { max = 4, window = 10000 } })
core.Functions.CreateCallback('qb-drugs:server:RequestConfig', function(_, cb) cb(roster()) end)
exports('GetDealers', roster)
Kora.compat.provideExport('qb-drugs', 'GetDealers', roster)
RegisterNetEvent('qb-drugs:server:dealerShop', function(name)
    local src = source
    if not ready or not player(src) or not available(src, name) then return end
    exports['qb-inventory']:OpenShop(src, shopId(dealers[name]))
end)
local eventTimes = {}
local function eventAllowed(src)
    local now = GetGameTimer()
    local elapsed = eventTimes[src] and now - eventTimes[src]
    if elapsed and elapsed >= 0 and elapsed < 500 then return false end
    eventTimes[src] = now
    return true
end
AddEventHandler('playerDropped', function() eventTimes[source] = nil end)
RegisterNetEvent('qb-drugs:server:giveDeliveryItems', function(data)
    local src = source
    if not eventAllowed(src) then return end
    local result, err = begin(src, data)
    if result then TriggerClientEvent('qbdrugs:client:delivery', src, result) else notify(src, err or 'Delivery unavailable') end
end)
RegisterNetEvent('qb-drugs:server:successDelivery', function(data)
    local src = source
    if not eventAllowed(src) then return end
    local result, err = settle(src, data)
    if result then TriggerClientEvent('qbdrugs:client:deliveryFinished', src, result) else notify(src, err or 'Delivery unavailable') end
end)
RegisterNetEvent('qb-drugs:server:updateDealerItems', function(_, _, name)
    -- Stock is already decremented by the inventory purchase transaction. Never trust a second client debit or refund.
    local src = source
    if available(src, name) then TriggerClientEvent('qb-drugs:client:RefreshDealers', src, roster()) end
end)
local function refresh()
    loadDealers()
    TriggerClientEvent('qb-drugs:client:RefreshDealers', -1, roster())
end
local adminBusy = false
local function changeDealer(src, fn)
    if not isAdmin(src) or adminBusy then return end
    adminBusy = true
    local ok, err = pcall(fn)
    adminBusy = false
    if not ok then print('[qbdrugs] dealer roster change failed: ' .. tostring(err)); notify(src, 'Dealer storage unavailable') end
end
core.Commands.Add('newdealer', 'Create a drug dealer', { { name = 'name' }, { name = 'min' }, { name = 'max' } }, true, function(src, args)
    changeDealer(src, function()
    local name, first, last = cleanName(args[1], 50, '^[%w _%-]+$'), inRange(args[2], 0, 23, true), inRange(args[3], 0, 23, true)
    local current = player(src)
    if not name or not first or not last or dealers[name] or not current or GetPlayerRoutingBucket(src) ~= 0 then return end
    local coords = GetEntityCoords(GetPlayerPed(src))
    query('INSERT INTO `dealers` (`name`,`coords`,`time`,`createdby`) VALUES (?, ?, ?, ?)',
        { name, json.encode({ x = coords.x, y = coords.y, z = coords.z }), json.encode({ min = first, max = last }), current.PlayerData.citizenid })
    refresh()
    end)
end, 'admin')
core.Commands.Add('deletedealer', 'Delete a drug dealer', { { name = 'name' } }, true, function(src, args)
    changeDealer(src, function()
    if not dealers[args[1]] then return end
    query('DELETE FROM `dealers` WHERE `id` = ?', { dealers[args[1]].id })
    refresh()
    end)
end, 'admin')
core.Commands.Add('dealers', 'List drug dealers', {}, false, function(src)
    if not isAdmin(src) then return end
    local names = {}; for name in pairs(dealers) do names[#names + 1] = name end; table.sort(names)
    TriggerClientEvent('chat:addMessage', src, { args = { 'Dealers', table.concat(names, ', ') } })
end, 'admin')
core.Commands.Add('dealergoto', 'Teleport to a drug dealer', { { name = 'name' } }, true, function(src, args)
    if not isAdmin(src) or not dealers[args[1]] then return end
    local coords = dealers[args[1]].coords
    SetEntityCoords(GetPlayerPed(src), coords.x, coords.y, coords.z, false, false, false, false)
end, 'admin')
registerShopPolicy()
loadDealers()
ready = true
AddEventHandler('onResourceStop', function(name)
    if name == 'kora_inventory' then ready = false end
end)
AddEventHandler('qbinventory:server:ready', function()
    registerShopPolicy(); loadDealers(); ready = true
end)
