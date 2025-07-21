fx_version 'cerulean'
game 'gta5'

author 'ali1337'
description 'IMPULSE V STREAMER MENU'
version '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

client_script 'client/main.lua'

server_scripts {
    'config.lua',
    'server/main.lua'
}
