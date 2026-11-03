local callbacks = {}
local allowedActions = {}
local resourceStarted = true
local calls = {}

local function expect(condition, message)
  if not condition then error(message, 2) end
end

lib = {
  callback = {
    register = function(name, handler)
      callbacks[name] = handler
    end
  }
}

MZAdminSecurity = {
  Authorize = function(sourceId, action)
    if sourceId ~= 1 or allowedActions[action] ~= true then
      return false, 'permission_denied'
    end
    return true, action
  end,
  ValidateTargetIdentity = function(_, expectedCitizenid)
    if expectedCitizenid == 'OUTRO_CHARACTER' then return false, 'stale_target' end
    return true
  end
}

exports = {
  mz_warns = {
    Issue = function(_, actorSource, targetSource, reason)
      calls[#calls + 1] = {
        operation = 'issue',
        actorSource = actorSource,
        targetSource = targetSource,
        reason = reason
      }
      return {
        ok = true,
        data = {
          warning = {
            publicId = 'MWR-ABC23456',
            targetName = 'Player Test',
            status = 'active'
          }
        }
      }
    end,
    List = function(_, actorSource, filters)
      calls[#calls + 1] = {
        operation = 'list',
        actorSource = actorSource,
        filters = filters
      }
      return {
        ok = true,
        data = {
          items = {},
          total = 0,
          page = filters.page,
          pageSize = filters.pageSize
        }
      }
    end,
    Revoke = function(_, actorSource, publicId, reason)
      calls[#calls + 1] = {
        operation = 'revoke',
        actorSource = actorSource,
        publicId = publicId,
        reason = reason
      }
      return {
        ok = true,
        data = {
          warning = {
            publicId = publicId,
            status = 'revoked'
          }
        }
      }
    end
  }
}

function GetResourceState(resourceName)
  return resourceName == 'mz_warns' and resourceStarted and 'started' or 'missing'
end

dofile('mz_admin/server/warnings.lua')

expect(type(callbacks['mz_admin:server:issueWarning']) == 'function', 'callback issue ausente')
expect(type(callbacks['mz_admin:server:listWarnings']) == 'function', 'callback list ausente')
expect(type(callbacks['mz_admin:server:revokeWarning']) == 'function', 'callback revoke ausente')

local denied = callbacks['mz_admin:server:issueWarning'](1, 2, 'teste')
expect(denied.ok == false and denied.error == 'permission_denied', 'bridge ignorou preautorizacao de issue')
expect(#calls == 0, 'bridge negado chamou dominio')

allowedActions.warningsIssue = true
local issued = callbacks['mz_admin:server:issueWarning'](1, 2, 'teste valido')
expect(issued.ok == true and issued.data.warning.publicId == 'MWR-ABC23456', 'bridge nao delegou issue')
expect(calls[1].actorSource == 1 and calls[1].targetSource == 2, 'bridge alterou sources de issue')

local stale = callbacks['mz_admin:server:issueWarning'](1, 2, 'teste valido', 'OUTRO_CHARACTER')
expect(stale.ok == false and stale.error == 'stale_target', 'bridge aceitou source reutilizado')
expect(#calls == 1, 'source stale chegou ao dominio de warnings')

allowedActions.warningsView = true
local listed = callbacks['mz_admin:server:listWarnings'](1, {
  status = 'active',
  targetSource = 2,
  search = 'Player',
  page = 3,
  pageSize = 999,
  invented = 'ignored'
})
expect(listed.ok == true, 'bridge nao delegou list')
expect(calls[2].filters.pageSize == 25, 'bridge aceitou pageSize do client')
expect(calls[2].filters.invented == nil, 'bridge encaminhou campo desconhecido')

allowedActions.warningsRevoke = true
local revoked = callbacks['mz_admin:server:revokeWarning'](1, 'MWR-ABC23456', 'revisao')
expect(revoked.ok == true and revoked.data.warning.status == 'revoked', 'bridge nao delegou revoke')
expect(calls[3].publicId == 'MWR-ABC23456', 'bridge alterou Public ID')

resourceStarted = false
local unavailable = callbacks['mz_admin:server:listWarnings'](1, {})
expect(unavailable.ok == false and unavailable.error == 'warnings_unavailable', 'recurso parado falhou aberto')

print('mz_admin warnings bridge harness: PASS')
