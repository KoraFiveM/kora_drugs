fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'Kakarot'
description 'Allows players to deliver packages and sell drugs to npcs'
version '0.2.0'
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
    'shared/config.lua',
    'shared/constants.lua',
    'shared/legacy_dealers.lua',
    'shared/recipes.lua',
    'shared/steps.lua'
}

client_scripts {
    'client/_functions.lua',
    'client/**.lua',
    -- Optional FFT hooks: returns immediately unless fft_kora_hooks is true.
    'fft_hooks.lua'
}

server_scripts {
    '@kora_sql/init.lua',
    'server/schema.lua',
    'server/_functions.lua',
    'server/**.lua',
    -- Optional FFT hooks: returns immediately unless fft_kora_hooks is true.
    'fft_hooks_server.lua'
}


-- kora_qa: Gherkin test scenarios (converted legacy tests), see [kora]/kora_qa/README.md
qa_feature 'tests/*.feature'
