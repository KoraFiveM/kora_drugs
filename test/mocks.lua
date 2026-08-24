-- Mocks for smoke-testing qbdrugs under plain lua5.4 (no FiveM, no DB, no
-- qbcore/qblib resource actually running). Installs the FiveM natives
-- qbdrugs' server files touch, a fake `QB` (qblib) proxy, and a fake
-- `exports.qbcore` gateway backed by a tiny in-memory inventory/money/
-- metadata model -- real enough that addItem/removeItem/hasItem/getItemCount
-- round-trip like the genuine gateway does, without needing qbcore itself.

local M = {}

function M.install()
    local eventHandlers = {}
    local clientEvents = {}
    local serverEvents = {}
    local alerts = {}          -- recorded exports.qbcore:alert(...) calls
    local useableHandlers = {} -- name -> handler, from exports.qbcore:createUseable
    local metadata = {}        -- src -> key -> value
    local money = {}           -- src -> account -> amount
    local inventory = {}       -- src -> itemName -> count
    local sharedItems = {}     -- name -> record, from exports.qbcore:registerShared('items', ...)

    _G.source = nil

    function _G.AddEventHandler(name, cb) eventHandlers[name] = eventHandlers[name] or {}; table.insert(eventHandlers[name], cb) end
    function _G.RegisterNetEvent(name, cb) if cb then eventHandlers[name] = eventHandlers[name] or {}; table.insert(eventHandlers[name], cb) end end
    function _G.TriggerEvent(name, ...) for _, fn in ipairs(eventHandlers[name] or {}) do fn(...) end end
    function _G.TriggerClientEvent(name, target, ...) table.insert(clientEvents, { name = name, target = target, args = { ... } }) end
    function _G.TriggerServerEvent(name, ...) table.insert(serverEvents, { name = name, args = { ... } }) end

    local threads = {}
    function _G.CreateThread(fn) table.insert(threads, coroutine.create(fn)) end
    _G.Citizen = { CreateThread = _G.CreateThread, Await = function(p) return p and p.__value end, Wait = function() end }
    function _G.Wait(_) end

    function _G.GetGameTimer() return 0 end
    function _G.GetInvokingResource() return nil end
    function _G.GetCurrentResourceName() return 'qbdrugs' end
    function _G.GetResourceState(_) return 'started' end
    function _G.GetPlayerPed(src) return src end
    function _G.GetEntityHealth(_) return 200 end
    function _G.SetEntityHealth(_, _) end
    function _G.vector3(x, y, z) return { x = x, y = y, z = z } end

    _G.os = os
    _G.math = math

    local QB = {}
    QB.notify = { send = function() end }
    QB.status = { registerEffect = function() end }
    QB.distance = { player = function() return true end }
    -- Real qblib algorithm (modules/util/shared.lua), copied rather than
    -- dofiled across resource directories -- it's pure/deterministic given
    -- math.random and already covered by qblib's own test/smoke/util.lua;
    -- this mock exists so production.lua's rollYield has something real to
    -- call, not to re-prove weightedChoice's own correctness.
    QB.util = {
        weightedChoice = function(list)
            local total = 0
            for _, entry in ipairs(list) do total = total + entry[2] end
            local roll = math.random() * total
            local cumulative = 0
            for _, entry in ipairs(list) do
                cumulative = cumulative + entry[2]
                if roll <= cumulative then return entry[1] end
            end
            return list[#list][1]
        end,
    }

    _G.QB = QB

    local qbcoreExports = {
        registerShared = function(_, name, key, record)
            if name ~= 'items' then return false, 'unsupported registry in mock' end
            sharedItems[key] = record
            return true
        end,
        getShared = function(_, name, key)
            if name ~= 'items' then return nil end
            return sharedItems[key]
        end,
        allShared = function(_, name)
            if name ~= 'items' then return {} end
            local out = {}
            for _, record in pairs(sharedItems) do out[#out + 1] = record end
            return out
        end,
        createUseable = function(_, name, handler) useableHandlers[name] = handler end,
        hasItem = function(_, src, name, amount)
            amount = amount or 1
            return ((inventory[src] and inventory[src][name]) or 0) >= amount
        end,
        getItemCount = function(_, src, name)
            return (inventory[src] and inventory[src][name]) or 0
        end,
        addItem = function(_, src, name, amount)
            amount = amount or 1
            inventory[src] = inventory[src] or {}
            inventory[src][name] = (inventory[src][name] or 0) + amount
            return true
        end,
        removeItem = function(_, src, name, amount)
            amount = amount or 1
            local have = (inventory[src] and inventory[src][name]) or 0
            if have < amount then return false, 'not enough of item' end
            inventory[src][name] = have - amount
            return true
        end,
        addMoney = function(_, src, account, amount)
            money[src] = money[src] or {}
            money[src][account] = (money[src][account] or 0) + amount
            return true
        end,
        removeMoney = function(_, src, account, amount)
            money[src] = money[src] or {}
            local have = money[src][account] or 0
            if have < amount then return false, 'insufficient funds' end
            money[src][account] = have - amount
            return true
        end,
        incrementMetaData = function(_, src, key, delta, min, max)
            metadata[src] = metadata[src] or {}
            local newValue = (metadata[src][key] or 0) + delta
            if min and newValue < min then newValue = min end
            if max and newValue > max then newValue = max end
            metadata[src][key] = newValue
            return newValue
        end,
        alert = function(_, payload)
            table.insert(alerts, payload)
            return 1
        end,
    }

    _G.exports = setmetatable({ qbcore = qbcoreExports }, {
        __index = function() return setmetatable({}, { __index = function() return function() end end }) end,
    })

    return {
        eventHandlers = eventHandlers,
        clientEvents = clientEvents,
        serverEvents = serverEvents,
        alerts = alerts,
        useableHandlers = useableHandlers,
        metadata = metadata,
        money = money,
        inventory = inventory,
        sharedItems = sharedItems,
        QB = QB,
        fireEvent = function(name, src, ...)
            local prev = _G.source
            _G.source = src
            _G.TriggerEvent(name, ...)
            _G.source = prev
        end,
        step = function()
            for _, co in ipairs(threads) do coroutine.resume(co) end
        end,
    }
end

return M
