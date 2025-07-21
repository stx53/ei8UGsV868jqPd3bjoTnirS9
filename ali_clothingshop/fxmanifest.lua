fx_version 'cerulean'
game 'gta5'


author 'ali'
description 'ali_clothing'
version '1.0.0'

ui_page 'web/index.html'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}

files {
    'web/index.html',
    'web/style.css',
    'web/script.js'
}

exports {
    'showSavedOutfits'
}