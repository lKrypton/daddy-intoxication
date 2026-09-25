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

-- Free and open source: every file stays readable when uploaded to the Cfx portal.
escrow_ignore {
    'bridge/client.lua',
    'bridge/inventory.lua',
    'bridge/server.lua',
    'bridge/shared.lua',
    'CHANGELOG.md',
    'client/animations.lua',
    'client/audio.lua',
    'client/driving.lua',
    'client/effects.lua',
    'client/main.lua',
    'config.lua',
    'examples/breathalyzer.lua',
    'LICENSE',
    'locales/en.lua',
    'locales/tr.lua',
    'README.md',
    'server/main.lua',
    'server/persistence.lua',
    'shared/utils.lua',
}
