fx_version 'cerulean'
game 'gta5'
lua54 'yes'
-- Keep the legacy resource name resolvable for exports['qbdrugs'] callers.
provide 'qbdrugs'
author 'Kakarot'
description 'Allows players to deliver packages and sell drugs to npcs'
version '1.3.0'
dependency 'kora_lib'
dependency 'kora_core'
dependency 'kora_sql'
dependency 'kora_inventory'
dependency 'kora_target'
-- dependency 'kora_weathersync'
provide 'qb-drugs'
shared_scripts {
    '@kora_lib/init.lua',
    '@kora_core/init.lua',
    '@kora_sql/init.lua',
    'shared/config.lua',
    'shared/constants.lua',
    'shared/legacy_dealers.lua',
    'shared/recipes.lua',
    'shared/steps.lua'
}

client_scripts {
    'client/_functions.lua',
    'client/**.lua'
}

server_scripts {
    'server/schema.lua',
    'server/_functions.lua',
    'server/**.lua'
}

