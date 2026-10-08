fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'Kakarot'
description 'Allows players to deliver packages and sell drugs to npcs'
version '1.3.0'
dependency 'qblib'
dependency 'qbcore'
shared_scripts {
    '@qblib/init.lua',
    '@qbcore/init.lua',
    '@qbsql/init.lua',
    'shared/config.lua',
    'shared/recipes.lua',
    'shared/steps.lua'
}

client_scripts {
    'client/_functions.lua',
    'client/**.lua'
}

server_scripts {
    'server/_functions.lua',
    'server/**.lua'
}