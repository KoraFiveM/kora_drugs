-- Chat suggestion for /drugCreator, shown only to players isAdmin() allows.
-- It is sent per player (never to -1), so non-admins never learn the command exists.
local command = 'drugCreator'
local suggestion = '/' .. command
local help = 'Open the drug creator'
local recheckMs = 30000

local shown = {} -- [src] = true while this player has the suggestion

local function wanted(src)
    return Config.creator.chatSuggestion == true and isAdmin(src)
end

function SyncCreatorSuggestion(src, force)
    local want = wanted(src)
    if want and (force or not shown[src]) then
        shown[src] = true
        TriggerClientEvent('chat:addSuggestion', src, suggestion, help, {})
    elseif not want and (force or shown[src]) then
        shown[src] = nil
        TriggerClientEvent('chat:removeSuggestion', src, suggestion)
    end
end

function SyncAllCreatorSuggestions()
    for _, id in ipairs(GetPlayers()) do SyncCreatorSuggestion(tonumber(id)) end
end

-- the chat resource forgets suggestions when it restarts, so its init resends them
AddEventHandler('chat:init', function() SyncCreatorSuggestion(source, true) end)
AddEventHandler('kora_core:server:playerLoaded', function(src) SyncCreatorSuggestion(src, true) end)
AddEventHandler('playerDropped', function() shown[source] = nil end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for src in pairs(shown) do TriggerClientEvent('chat:removeSuggestion', src, suggestion) end
end)

-- covers resource start for players already online, and permission granted or lost later
CreateThread(function()
    while true do
        SyncAllCreatorSuggestions()
        Wait(recheckMs)
    end
end)
