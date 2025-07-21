fx_version "cerulean"
game "gta5"
lua54 "yes"

author "Ali1337"
description "Killfeed"
version "1.0.0"

shared_scripts {
  "configs/sharedConfig.lua",
}

client_scripts {
  "client/*"
}

server_scripts {
  "server/*"
}

ui_page "frontend/index.html"
-- ui_page "http://localhost:5173/"

files {
  "frontend/*",
}

escrow_ignore {
  "frontend/*",
  "configs/*",
}
