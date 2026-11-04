fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mz_admin'
author 'Mazus'
description 'Admin tools - Noclip, etc'
version '0.3.1'

ui_page 'web/index.html'

files {
  'web/index.html',
  'web/style.css',
  'web/app.js',
  'locales/*.json',
  'web/logo_s.svg'
}

shared_scripts {
  '@ox_lib/init.lua',
  'shared/config.lua',
  'shared/locale.lua',
  'shared/permissions.lua'
}

client_scripts {
  'client/ui.lua',
  'client/auth.lua',
  'client/staff_management.lua',
  'client/admin_logs.lua',
  'client/security_alerts.lua',
  'client/bans.lua',
  'client/whitelist.lua',
  'client/warnings.lua',
  'client/garage_wizard.lua',
  'client/player_selector.lua',
  'client/world_furniture_catalog.lua',
  'client/world_outlets_wizard.lua',
  'client/world_props_wizard.lua',
  'client/world_wizard.lua',
  'client/noclip.lua',
  'client/wall.lua',
  'client/spectate.lua',
  'client/commands.lua',
  'client/menu.lua',
  'client/router.lua',
  'client/tablet.lua',
  'client/main.lua'
}

server_scripts {
  'server/security.lua',
  'server/bans.lua',
  'server/whitelist.lua',
  'server/warnings.lua',
  'server/staff.lua',
  'server/logs.lua',
  'server/security_alerts.lua',
  'server/garages.lua',
  'server/world.lua',
  'server/wall.lua',
  'server/spectate.lua',
  'server/tablet.lua',
  'server/main.lua'
}

dependencies {
  'ox_lib',
  'mz_core',
  'mz_status',
  'mz_org',
  'mz_garagem'
}
