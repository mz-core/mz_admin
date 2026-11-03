Config = {
  -- Locale global definido pelo servidor (mz_starter/cfg/base.cfg).
  Locale = type(GetConvar) == 'function' and GetConvar('locale', 'pt-BR') or 'pt-BR',

  -- Permissao global necessaria para usar noclip.
  NoClipPermission = 'staff.noclip',

  AdminCommand = 'admin',
  StaffOrganizationCommand = 'stafforg',

  NoClipCommand = 'noclip',
  WallCommand = 'wall',
  SpectateCommand = 'spectate',
  SpectateStopCommand = 'specoff',

  NoClipSpeed = 1.5,
  NoClipSprintSpeed = 3.0,

  Wall = {
    updateInterval = 250,
    authorizationInterval = 1500,
    drawDistance = 800.0,
    showOtherBuckets = true,
    showSelf = false,
    preferStreamedCoords = true,
    smooth = true,
    smoothFactor = 0.28,
    smoothDropAfterMs = 3000,
    showVehicleName = true,
    vehicleNameMaxLength = 18,
    citizenIdMaxLength = 24,
    showWeaponState = true,
    drawLines = true,
    lineDistance = 200.0,
    lineAlpha = 160,
    textZOffset = 1.15,
    textScale = 0.30,
    screenLineSpacing = 0.024,
    colors = {
      default = { 255, 255, 255, 255 },
      dead = { 255, 70, 70, 255 },
      staff = { 255, 220, 0, 255 }
    }
  },

  Spectate = {
    updateInterval = 250,
    authorizationInterval = 1500,
    targetOffset = 6.0
  },

  NotifyTitle = 'MZ Admin',

  -- Comandos que dao armas nativas direto no ped ficam desligados por padrao.
  Debug = false,
  AllowNativeWeaponCommands = false,
  DefaultWeaponAmmo = 250,

  Controls = {
    forward = 'W',
    backward = 'S',
    left = 'A',
    right = 'D',
    up = 'SPACE',
    down = 'LCTRL'
  },

  -- Comandos administrativos preservados e revalidados pelo servidor.
  Commands = {
    loc = 'loc',
    tp = 'tp',
    tpm = 'tpm',
    gotoPlayer = 'goto',
    bringPlayer = 'bring',
    kickPlayer = 'kick',
    deleteVehicle = 'dv',
    spawnVehicle = 'car',
    fixVehicle = 'fix',
    heal = 'heal',
    armor = 'armor',
    weapon = 'arma',
    weaponAlias = 'weapon',
    weaponKit = 'armas',
    clearWeapons = 'limpararmas',
    revive = 'revive',
    godMode = 'godmode'
  },

  -- Tablet administrativo (aberto por TAB e pelo comando /mztablet).
  -- Flag reversivel: desligar retorna ao comportamento anterior sem desfazer commits.
  Tablet = {
    Enabled = true,
    OpenCommand = 'mztablet',
    OpenKey = 'TAB', -- conflito real com a roda de armas (hold TAB) do GTA; remapeavel em Key Bindings.
    RefreshPlayersMs = 5000 -- polling moderado SOMENTE com a aba de jogadores aberta.
  }
}
