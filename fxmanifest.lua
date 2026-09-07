fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'Kakarot'
description 'Allows players to deliver packages and sell drugs to npcs'
version '1.3.0'
ui_page 'web/build/index.html'
shared_scripts {
    '@qblib/init.lua',
    'shared/config.lua',
}

client_scripts {
    'client/_functions.lua',
    'client/**.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/_functions.lua',
    'server/**.lua'
}

files {
	'locales/**.lua',
	'web/build/index.html',
  'web/build/**/*'

}