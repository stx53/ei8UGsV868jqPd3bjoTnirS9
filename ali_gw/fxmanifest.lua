fx_version 'cerulean'
game 'gta5'

author 'Ali1337'
description 'aligw'
version '1.0.0'

ui_page 'index.html'

files {
    'index.html',
    'style.css',
    'script.js'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua',
}



client_script 'client.lua'
shared_script 'config.lua'

 