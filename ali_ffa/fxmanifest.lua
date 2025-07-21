fx_version 'cerulean'
game 'gta5'

author 'ali1337'
description 'ffa.'
version '1.1.0'

ui_page 'index.html'

files {
    'index.html',
    'script.js',
    'style.css',
}

shared_script 'config.lua'

client_script 'client.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config.lua',
    'server.lua'
}

server_export 'isPlayerInFFA'
