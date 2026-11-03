-- mz_admin/client/tablet.lua
-- Shim de compatibilidade do tablet administrativo.
--
-- O tablet foi UNIFICADO no MZAdminRouter (client/router.lua). TAB, /admin e
-- /mztablet conduzem a MESMA interface Flight-style com navegacao lateral.
-- Este arquivo preserva apenas o namespace legado e o registro de comando/tecla
-- para nao quebrar consumidores; nao existe mais uma segunda UI em paralelo.

MZAdminTablet = MZAdminTablet or {}

local function cfg()
  return type(Config.Tablet) == 'table' and Config.Tablet or {}
end

function MZAdminTablet.IsOpen()
  if MZAdminRouter and type(MZAdminRouter.IsOpen) == 'function' then
    return MZAdminRouter.IsOpen()
  end
  return false
end

function MZAdminTablet.Open()
  if MZAdminRouter and type(MZAdminRouter.Open) == 'function' then
    return MZAdminRouter.Open('blocked')
  end
  return false
end

function MZAdminTablet.Close()
  if MZAdminRouter and type(MZAdminRouter.Close) == 'function' then
    return MZAdminRouter.Close()
  end
  return false
end

function MZAdminTablet.Toggle()
  if MZAdminRouter and type(MZAdminRouter.Toggle) == 'function' then
    return MZAdminRouter.Toggle('blocked')
  end
  return false
end

RegisterCommand((cfg()).OpenCommand or 'mztablet', function()
  MZAdminTablet.Toggle()
end, false)

-- Keymapping dedicado: com o tablet aberto, TAB pertence ao keydown da NUI
-- (tabletBlockedToggle). O atalho so abre quando o painel esta fechado, para
-- nao existirem dois handlers disparando o mesmo toggle.
RegisterCommand('mz_admin_tablet_toggle', function()
  if MZAdminUI and type(MZAdminUI.IsTabletOpen) == 'function' and MZAdminUI.IsTabletOpen() then
    return
  end
  MZAdminTablet.Toggle()
end, false)

if (cfg()).Enabled and type((cfg()).OpenKey) == 'string' and (cfg()).OpenKey ~= '' then
  RegisterKeyMapping(
    'mz_admin_tablet_toggle',
    'Abrir/fechar o painel administrativo MZ',
    'keyboard',
    (cfg()).OpenKey
  )
end
