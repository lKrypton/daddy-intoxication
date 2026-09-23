fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'daddy-intoxication'
author 'Daddy Studios'
description 'Server-authoritative intoxication system with drink profiles, tolerance, BAC and pma-voice support'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'locales/en.lua',
    'locales/tr.lua',
    'shared/utils.lua',
    'bridge/shared.lua',
}

client_scripts {
    'bridge/client.lua',
    'client/main.lua',
    'client/effects.lua',
    'client/audio.lua',
    'client/animations.lua',
    'client/driving.lua',
}

server_scripts {
    'bridge/server.lua',
    'bridge/inventory.lua',
    'server/persistence.lua',
    'server/main.lua',
}

dependencies {
    '/onesync',
    'ox_lib',
}
