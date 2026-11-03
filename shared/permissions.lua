MZAdminPermissions = {
  menu = 'staff.panel.open',
  loc = 'staff.coords.copy',
  noclip = Config.NoClipPermission or 'staff.noclip',
  wall = 'staff.wall',
  spectate = 'staff.spectate',

  tp = 'staff.teleport',
  tpm = 'staff.teleport',
  playersList = 'staff.players.list',
  gotoPlayer = 'staff.players.goto',
  bringPlayer = 'staff.players.bring',
  kick = 'staff.players.kick',
  ban = 'staff.players.ban',
  banView = 'staff.bans.view',
  banRevoke = 'staff.bans.revoke',
  whitelistView = 'staff.whitelist.view',
  whitelistManage = 'staff.whitelist.manage',
  warningsView = 'staff.warns.view',
  warningsIssue = 'staff.warns.issue',
  warningsRevoke = 'staff.warns.revoke',
  heal = 'staff.players.heal',
  armor = 'staff.players.armor',
  revive = 'staff.players.revive',
  godMode = 'staff.players.godmode',

  deleteVehicle = 'staff.vehicles.delete',
  spawnVehicle = 'staff.vehicles.spawn',
  fixVehicle = 'staff.vehicles.repair',
  tuneVehicle = 'staff.vehicles.tune',
  garageView = 'staff.garages.view',
  garageCreate = 'staff.garages.create',
  garageManage = 'staff.garages.manage',
  worldView = 'staff.world.view',
  worldDoorCreate = 'staff.world.doors.create',
  worldDoorManage = 'staff.world.doors.manage',
  worldDoorArchive = 'staff.world.doors.archive',
  worldPropCreate = 'staff.world.props.create',
  worldPropManage = 'staff.world.props.manage',
  worldPropArchive = 'staff.world.props.archive',
  furnitureView = 'staff.furniture.view',
  furnitureCreate = 'staff.furniture.create',
  furnitureManage = 'staff.furniture.manage',
  furnitureArchive = 'staff.furniture.archive',
  furnitureRecovery = 'staff.furniture.recovery',
  staffManage = 'staff.roles.manage',
  logsView = 'staff.logs.view',

  securityAlertsView = 'mz_banguard.alerts.view',
  securityAlertDetails = 'mz_banguard.alerts.details',
  securityAlertAcknowledge = 'mz_banguard.alerts.acknowledge',
  securityAlertNote = 'mz_banguard.alerts.note',
  securityAlertClear = 'mz_banguard.alerts.clear',
  securityAlertIdentifiers = 'mz_banguard.alerts.identifiers',
  securityAlertLab = 'mz_banguard.alerts.lab',
  securityAlertSpectate = 'mz_banguard.actions.spectate',
  securityAlertGoto = 'mz_banguard.actions.goto',

  weapon = 'staff.weapons.give',
  weaponKit = 'staff.weapons.kit',
  clearWeapons = 'staff.weapons.clear'
}

MZAdminActionGroups = {
  players = {
    'tp', 'tpm', 'playersList', 'gotoPlayer', 'bringPlayer', 'kick', 'ban', 'heal', 'armor', 'revive', 'godMode',
    'spectate'
  },
  bans = {
    'banView', 'banRevoke'
  },
  whitelist = {
    'whitelistView', 'whitelistManage'
  },
  warnings = {
    'warningsView', 'warningsIssue', 'warningsRevoke'
  },
  vehicles = {
    'deleteVehicle', 'spawnVehicle', 'fixVehicle', 'tuneVehicle'
  },
  garages = {
    'garageView', 'garageCreate', 'garageManage'
  },
  world = {
    'worldView', 'worldDoorCreate', 'worldDoorManage', 'worldDoorArchive',
    'worldPropCreate', 'worldPropManage', 'worldPropArchive',
    'furnitureView', 'furnitureCreate', 'furnitureManage', 'furnitureArchive', 'furnitureRecovery'
  },
  staff = {
    'staffManage'
  },
  visual = {
    'wall', 'spectate'
  },
  logs = {
    'logsView'
  },
  security = {
    'securityAlertsView', 'securityAlertDetails', 'securityAlertAcknowledge', 'securityAlertNote',
    'securityAlertClear', 'securityAlertIdentifiers', 'securityAlertLab', 'securityAlertSpectate', 'securityAlertGoto'
  },
  weapons = {
    'weapon', 'weaponKit', 'clearWeapons'
  }
}
