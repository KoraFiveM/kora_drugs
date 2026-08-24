fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'qbdrugs'
author 'Jamie'
version '1.0.0'
description 'Config-driven, multi-drug-type production/economy job built on qbcore + qblib'

dependency 'qblib'
dependency 'qbcore'
dependency 'qbinventory'
dependency 'qbtarget'

-- Required to reach QB.<module> directly (zones/interact/minigames/anim/
-- progressbar/status/util/notify/distance) -- see qblib's own AGENTS.md for
-- why every consumer resource pulls this in the same way qbtarget/qbcore do.
shared_script '@qblib/init.lua'

-- config.lua before shared/items.lua: the item defs' `effect` tables and the
-- station/pipeline schema are pure data, but shared/items.lua also calls
-- QB.status.registerEffect at load time and doesn't itself depend on
-- Config -- ordered this way anyway so every file in this resource can
-- assume Config.* already exists, matching qbcore/qbtarget's own convention.
shared_scripts {
    'config.lua',
    'shared/items.lua'
}

server_scripts {
    'server/items.lua',
    'server/production.lua',
    'server/stations.lua',
    'server/selling.lua'
}

client_scripts {
    'client/growing.lua',
    'client/processing.lua',
    'client/packaging.lua',
    'client/selling.lua',
    'client/use.lua'
}
