-- Run from kora_drugs: lua test/creator_suggestion.lua
local sent = {}
local admins = { [1] = true }
local players = { "1", "2" }
local handlers = {}
Config = { creator = { chatSuggestion = true } }
source = nil
isAdmin = function(src) return admins[src] == true end
GetPlayers = function() return players end
GetCurrentResourceName = function() return 'kora_drugs' end
TriggerClientEvent = function(ev, src, ...) sent[#sent + 1] = { ev = ev, src = src, args = { ... } } end
AddEventHandler = function(name, fn) handlers[name] = fn end
CreateThread = function() end

dofile('server/creator_suggestion.lua')

local function take() local s = sent; sent = {}; return s end

SyncAllCreatorSuggestions()
local s = take()
assert(#s == 1 and s[1].src == 1 and s[1].ev == 'chat:addSuggestion' and s[1].args[1] == '/drugCreator', 'only the admin gets it')
SyncAllCreatorSuggestions()
assert(#take() == 0, 'no repeat while unchanged')

admins[1] = false
SyncAllCreatorSuggestions()
s = take()
assert(#s == 1 and s[1].ev == 'chat:removeSuggestion' and s[1].src == 1, 'removed when permission is lost')

admins[2] = true
handlers['kora_core:server:playerLoaded'](2)
s = take()
assert(#s == 1 and s[1].src == 2 and s[1].ev == 'chat:addSuggestion', 'sent on player loaded')

source = 2; handlers['chat:init']()
assert(#take() == 1, 'chat restart resends it')

Config.creator.chatSuggestion = false
SyncAllCreatorSuggestions()
s = take()
assert(#s == 1 and s[1].ev == 'chat:removeSuggestion' and s[1].src == 2, 'config off removes it')
Config.creator.chatSuggestion = true

source = 2; handlers['playerDropped']()
SyncAllCreatorSuggestions()
s = take()
assert(#s == 1 and s[1].src == 2 and s[1].ev == 'chat:addSuggestion', 'dropped player state is forgotten')

handlers['onResourceStop']('other')
assert(#take() == 0)
handlers['onResourceStop']('kora_drugs')
s = take()
assert(#s == 1 and s[1].ev == 'chat:removeSuggestion', 'removed on resource stop')
print('creator_suggestion ok')
