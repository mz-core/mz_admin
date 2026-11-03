MZAdminSecurityAlerts = MZAdminSecurityAlerts or {}

local MENU_ID = 'mz_admin:security'
local LIST_ID = 'mz_admin:security:list'
local EVENT = 'mz_admin:client:securityAlertAction'
local CurrentParent = nil
local CurrentActions = {}
local CurrentSummary = nil
local CurrentPlayerStateObservability = nil
local CurrentAvailable = false

local FILTER_LABELS = {
  all = 'Todos',
  open = 'Abertos',
  acknowledged = 'Reconhecidos',
  critical = 'Criticos',
  weapon = 'Armas',
  entity = 'Entidades',
  movement = 'Movimento',
  camera = 'Camera',
  player_state = 'Estado do jogador',
  event = 'Eventos',
  aim = 'Mira',
  crash = 'Crashes',
  runtime = 'Runtime client',
  canary = 'Canarios'
}

local CODE_LABELS = {
  weapon_damage_no_equipped_weapon = 'Dano sem arma oficial equipada',
  weapon_damage_hash_mismatch = 'Hash divergente da arma oficial',
  weapon_damage_death_state_incompatible = 'Dano em estado de morte incompativel',
  weapon_damage_unknown_hash = 'Hash de arma desconhecido',
  weapon_damage_session_not_ready = 'Sessao ainda nao pronta',
  weapon_damage_transition_window = 'Janela de transicao de arma',
  weapon_damage_payload_invalid = 'Payload de dano invalido',
  weapon_damage_rate_suspect = 'Taxa de eventos suspeita',
  projectile_weapon_unauthorized = 'Projetil sem arma autorizada',
  entity_spawn_rate_suspect = 'Spawn excessivo de entidades',
  entity_model_blocked = 'Modelo de entidade bloqueado',
  movement_teleport_suspect = 'Deslocamento/teleporte suspeito',
  movement_noclip_suspect = 'Padrao de noclip suspeito',
  movement_vehicle_reentry_distance = 'Retorno ao veiculo a distancia',
  camera_freecam_suspect = 'Freecam suspeita',
  client_resource_presence_missing = 'Runtime client ausente',
  client_resource_stop_observed = 'Parada de resource observada',
  canary_triggered = 'Canario de seguranca acionado',
  camera_spectate_unapproved = 'Spectate nao autorizado',
  player_model_change_unapproved = 'Troca de ped/modelo nao autorizada',
  player_godmode_suspect = 'Godmode suspeito',
  player_invisible_suspect = 'Invisibilidade suspeita',
  event_explosion_rate_suspect = 'Spam de explosoes',
  event_explosion_anomaly_suspect = 'Explosao com metadados anormais',
  event_clear_tasks_rate_suspect = 'Interferencia repetida em ped',
  event_remote_clear_tasks_suspect = 'Clear tasks contra outro jogador',
  event_tazer_rate_suspect = 'Spam de tazer',
  event_ptfx_rate_suspect = 'Spam de particulas',
  event_ptfx_anomaly_suspect = 'Particula anormal/remota',
  event_projectile_rate_suspect = 'Spam de projeteis',
  event_fire_rate_suspect = 'Spam de fogo',
  event_fire_remote_suspect = 'Fogo remoto suspeito',
  event_remote_weapon_action_suspect = 'Acao remota de arma',
  event_damage_modifier_suspect = 'Modificador de dano/defesa',
  aim_headshot_pattern_suspect = 'Padrao estatistico de headshots',
  crash_observed = 'Jogador sofreu crash',
  crash_cluster_suspect = 'Varios jogadores crasharam em sequencia'
}

local function trim(value)
  return tostring(value or ''):gsub('%c', ' '):gsub('^%s+', ''):gsub('%s+$', '')
end

local function notify(message, kind)
  if type(MZAdminUI) == 'table' then
    MZAdminUI.Notify(tostring(message), kind or 'inform')
  end
end

local function bind(option, action, args)
  args = type(args) == 'table' and args or {}
  args.action = action
  option.event = EVENT
  option.args = args
  return option
end

local function detailMenuId(id)
  return 'mz_admin:security:incident:' .. trim(id):gsub('[^%w_%-]', ''):sub(1, 64)
end

local function request(name, ...)
  local data, err = MZAdminClient.StaffRequest(name, ...)
  if not data then
    notify(('Central de alertas: %s'):format(tostring(err or 'indisponivel')), 'error')
    return nil
  end
  return data
end

local function incidentMetadata(item)
  local metadata = {
    { label = 'ID', value = tostring(item.id or '-') },
    { label = 'Categoria', value = tostring(item.category or '-') },
    { label = 'Confianca', value = tostring(item.confidence or '-') },
    { label = 'Status', value = tostring(item.status or '-') },
    { label = 'Risco do incidente', value = tostring(item.riskScore or 0) .. '/100' },
    { label = 'Ocorrencias', value = tostring(item.count or 1) },
    { label = 'Sinal', value = tostring(item.subject or item.code or '-') },
    { label = 'Ultima', value = tostring(item.lastSeenIso or item.lastSeenAt or '-') }
  }
  if item.category == 'weapon' then
    metadata[#metadata + 1] = { label = 'Reportada', value = tostring(item.reportedWeaponName or item.reportedWeaponHash or '-') }
    metadata[#metadata + 1] = { label = 'Oficial', value = tostring(item.authorizedWeaponName or item.authorizedWeaponHash or 'nenhuma') }
  end
  return metadata
end

local function evidenceMetadata(item)
  local metadata = {
    { label = 'Horario', value = tostring(item.at or '-') },
    { label = 'Origem', value = tostring(item.origin or '-') },
    { label = 'Confianca', value = tostring(item.confidence or '-') }
  }
  local fields = {
    { 'entityType', 'Entidade' }, { 'model', 'Modelo' }, { 'amount', 'Quantidade' },
    { 'windowMs', 'Janela ms' }, { 'distance', 'Distancia' }, { 'height', 'Altura' },
    { 'cameraDistance', 'Camera/ped' }, { 'alpha', 'Alpha' }, { 'bucket', 'Bucket' },
    { 'health', 'Vida' }, { 'armour', 'Colete' }, { 'invincible', 'Invencivel' },
    { 'damageDisabled', 'Dano desativado' }, { 'fullProofs', 'Proofs completos' },
    { 'inVehicle', 'Em veiculo' }, { 'spectator', 'Spectator' }, { 'vehicleNetId', 'Veiculo net ID' },
    { 'weaponHash', 'Arma hash' }, { 'hitComponent', 'Componente' }, { 'hits', 'Acertos' },
    { 'headshots', 'Headshots' }, { 'ratio', 'Proporcao' }, { 'eventType', 'Tipo evento' },
    { 'reportedWeaponHash', 'Hash reportado' }, { 'authorizedWeaponHash', 'Hash oficial' },
    { 'damage', 'Dano' }, { 'targetNetId', 'Target/net ID' },
    { 'burstAmount', 'Burst' }, { 'burstWindowMs', 'Janela burst ms' },
    { 'populationName', 'Populacao' }, { 'populationClass', 'Classe populacao' },
    { 'mappingVersion', 'Mapa populacao' }, { 'mappingValidated', 'Mapa validado' },
    { 'owner', 'Owner atual' }, { 'firstOwner', 'Primeiro owner' },
    { 'targetOwner', 'Owner do alvo' }, { 'damageScale', 'Escala de dano' },
    { 'distanceFromSender', 'Distancia do emissor' }, { 'effectHash', 'Efeito hash' },
    { 'scale', 'Escala' }, { 'projectileHash', 'Projetil hash' },
    { 'weaponModifier', 'Mod. arma' }, { 'meleeModifier', 'Mod. melee' },
    { 'defenseModifier', 'Mod. defesa' }, { 'action', 'Acao' },
    { 'distanceBand', 'Faixa distancia' }, { 'pingBand', 'Faixa ping' },
    { 'averageDistance', 'Distancia media' }, { 'qualifiedWindows', 'Janelas qualificadas' },
    { 'lifecycle', 'Lifecycle' }, { 'sessionId', 'Sessao lifecycle' },
    { 'transition', 'Transicao' }, { 'targetType', 'Tipo do alvo' },
    { 'targetDistance', 'Distancia do alvo' }, { 'ammoRevision', 'Revisao de municao' },
    { 'transitionRevision', 'Revisao da transicao' }, { 'rateProfile', 'Perfil de cadencia' },
    { 'rateCount', 'Eventos na janela' }, { 'rateThreshold', 'Limite da janela' },
    { 'rateWindowMs', 'Janela de cadencia (ms)' },
    { 'correlationId', 'Correlacao' }, { 'ruleVersion', 'Versao da regra' }
  }
  for _, field in ipairs(fields) do
    if item[field[1]] ~= nil and item[field[1]] ~= '' then
      local value = item[field[1]]
      if field[1] == 'ratio' and tonumber(value) then value = ('%.2f'):format(tonumber(value)) end
      metadata[#metadata + 1] = { label = field[2], value = tostring(value) }
    end
  end
  return metadata
end

local function openDetails(id, includeIdentifiers)
  local data = request('securityIncidentDetails', id, includeIdentifiers == true)
  local incident = data and data.incident
  if type(incident) ~= 'table' then return false end
  local human = type(incident.human) == 'table' and incident.human or {}

  local technical = incidentMetadata(incident)
  technical[#technical + 1] = { label = 'Source atual', value = tostring(incident.source or 'offline') }
  if incident.category == 'weapon' then
    technical[#technical + 1] = { label = 'Municao oficial', value = tostring(incident.authorizedAmmo or '-') }
    technical[#technical + 1] = { label = 'Dano reportado', value = tostring(incident.damage or '-') }
    technical[#technical + 1] = { label = 'Target/net ID', value = tostring(incident.targetNetId or '-') }
  end
  technical[#technical + 1] = { label = 'Evidencias suprimidas', value = tostring(incident.suppressedCount or 0) }

  local options = {
    {
      title = human.title or CODE_LABELS[incident.code] or tostring(incident.code or 'Incidente'),
      description = tostring(human.summary or '-'),
      icon = incident.severity == 'critical' and 'shield-halved' or 'shield',
      metadata = {
        { label = 'Categoria', value = tostring(human.category_label or incident.category or '-') },
        { label = 'Severidade', value = tostring(human.severity_label or incident.severity or '-') },
        { label = 'Confianca', value = tostring(human.confidence_label or incident.confidence or '-') },
        { label = 'Acao recomendada', value = tostring(human.recommended_action or '-') },
        { label = 'LAB', value = incident.lab and 'SIM' or 'nao' }
      },
      readOnly = true
    },
    {
      title = 'Detalhes tecnicos',
      description = ('%s | %s | online: %s'):format(
        tostring(incident.severity or 'info'), tostring(incident.status or 'open'), incident.online and 'sim' or 'nao'
      ),
      icon = 'code',
      metadata = technical,
      readOnly = true
    },
    bind({ title = 'Copiar ID do incidente', description = tostring(incident.id), icon = 'copy' }, 'copyId', { id = incident.id })
  }

  if CurrentActions.securityAlertAcknowledge and incident.status == 'open' then
    options[#options + 1] = bind({ title = 'Reconhecer incidente', description = 'Marca como em analise; nao pune o jogador.', icon = 'check' }, 'ack', { id = incident.id })
  end
  if CurrentActions.securityAlertNote then
    options[#options + 1] = bind({ title = 'Adicionar nota', description = 'Nota administrativa auditavel.', icon = 'note-sticky' }, 'note', { id = incident.id })
  end
  if CurrentActions.securityAlertClear then
    options[#options + 1] = bind({ title = 'Marcar resolvido', description = 'Preserva todas as evidencias.', icon = 'circle-check' }, 'status', { id = incident.id, status = 'resolved' })
    options[#options + 1] = bind({ title = 'Marcar falso positivo', description = 'Preserva todas as evidencias.', icon = 'shield-circle-check' }, 'status', { id = incident.id, status = 'false_positive' })
    if incident.status ~= 'open' then
      options[#options + 1] = bind({ title = 'Reabrir incidente', icon = 'rotate-left' }, 'status', { id = incident.id, status = 'open' })
    end
  end
  if CurrentActions.securityAlertIdentifiers and includeIdentifiers ~= true then
    options[#options + 1] = bind({ title = 'Exibir identificadores', description = 'Acesso sensivel e auditado.', icon = 'fingerprint' }, 'identifiers', { id = incident.id })
  end
  if type(incident.identifiers) == 'table' then
    local masked = type(incident.identifiers.masked) == 'table' and incident.identifiers.masked or {}
    options[#options + 1] = {
      title = 'Identificadores mascarados', icon = 'fingerprint', readOnly = true,
      metadata = {
        { label = 'license', value = tostring(masked.license or '-') },
        { label = 'fivem', value = tostring(masked.fivem or '-') }
      }
    }
  end
  options[#options + 1] = bind({ title = 'Exportar evidencia JSON', description = 'Copia um pacote tecnico sanitizado.', icon = 'file-code' }, 'export', { id = incident.id, format = 'json' })
  options[#options + 1] = bind({ title = 'Exportar evidencia Markdown', description = 'Copia um relatorio humano sanitizado.', icon = 'file-lines' }, 'export', { id = incident.id, format = 'markdown' })
  if incident.online and CurrentActions.securityAlertLab then
    options[#options + 1] = bind({
      title = incident.lab and 'Desativar LAB' or 'Ativar LAB por 60 minutos',
      description = 'Desativa punicao automatica e amplia a retencao desta sessao.',
      icon = 'flask'
    }, 'lab', { id = incident.id, source = incident.source, enabled = incident.lab ~= true })
  end
  for index, evidence in ipairs(incident.evidence or {}) do
    options[#options + 1] = {
      title = ('Ocorrencia agrupada #%d'):format(index),
      description = tostring(evidence.reason or 'evidencia server-side'),
      metadata = evidenceMetadata(evidence),
      icon = 'list', readOnly = true
    }
  end
  for index, entry in ipairs(incident.timeline or {}) do
    local metadata = {
      { label = 'ID', value = tostring(entry.id or '-') },
      { label = 'Horario', value = tostring(entry.at or '-') }
    }
    local keys = {}
    for key in pairs(type(entry.data) == 'table' and entry.data or {}) do keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do
      metadata[#metadata + 1] = { label = tostring(key), value = tostring(entry.data[key]) }
    end
    options[#options + 1] = {
      title = ('Timeline #%d'):format(index),
      description = tostring(entry.kind or 'correlacao'),
      metadata = metadata,
      icon = 'timeline', readOnly = true
    }
  end
  if incident.online and CurrentActions.securityAlertGoto then
    options[#options + 1] = bind({ title = 'Ir ate o jogador', description = 'Revalida alvo, identidade e hierarquia no servidor.', icon = 'person-walking-arrow-right' }, 'playerAction', { id = incident.id, playerAction = 'goto' })
  end
  if incident.online and CurrentActions.securityAlertSpectate then
    options[#options + 1] = bind({ title = 'Espectar jogador', description = 'Revalida alvo, identidade e hierarquia no servidor.', icon = 'binoculars' }, 'playerAction', { id = incident.id, playerAction = 'spectate' })
  end

  for _, note in ipairs(incident.notes or {}) do
    options[#options + 1] = {
      title = 'Nota - ' .. tostring(note.authorName or note.authorCitizenid or 'Staff'),
      description = tostring(note.text or ''),
      metadata = { { label = 'Data', value = tostring(note.at or '-') } },
      icon = 'note-sticky', readOnly = true
    }
  end

  local contextId = detailMenuId(incident.id)
  MZAdminUI.RegisterContext({
    id = contextId,
    menu = LIST_ID,
    title = tostring(incident.playerName or 'Incidente'),
    subtitle = ('%s | CID %s'):format(tostring(incident.id), tostring(incident.citizenid or 'indisponivel')),
    badge = tostring(incident.severity or 'info'):upper(),
    options = options
  })
  return MZAdminUI.ShowContext(contextId)
end

function MZAdminSecurityAlerts.OpenList(filters)
  filters = type(filters) == 'table' and filters or { filter = 'all' }
  local data = request('securityIncidentList', filters)
  if not data then return false end
  local incidents = type(data.incidents) == 'table' and data.incidents or {}
  local options = {}
  for _, item in ipairs(incidents) do
    local row = {
      title = ('[%s]%s %s'):format(tostring(item.severity or 'info'):upper(), item.lab and '[LAB]' or '', tostring(item.playerName or item.citizenid or 'Jogador')),
      description = ('%s | %d ocorrencia(s) | risco do incidente %d'):format(
        item.human and item.human.title or CODE_LABELS[item.code] or tostring(item.code or 'incidente'), tonumber(item.count) or 1, tonumber(item.riskScore) or 0
      ),
      icon = item.severity == 'critical' and 'triangle-exclamation' or 'shield',
      metadata = incidentMetadata(item),
      arrow = CurrentActions.securityAlertDetails == true,
      readOnly = CurrentActions.securityAlertDetails ~= true
    }
    if CurrentActions.securityAlertDetails then row = bind(row, 'details', { id = item.id }) end
    options[#options + 1] = row
  end
  if #options == 0 then
    options[1] = { title = 'Nenhum incidente encontrado', description = 'Nao ha registros em memoria para este filtro.', icon = 'shield-circle-check', readOnly = true }
  end
  MZAdminUI.RegisterContext({
    id = LIST_ID,
    menu = MENU_ID,
    title = 'Incidentes de segurança',
    subtitle = ('Filtro: %s | %d resultado(s)'):format(FILTER_LABELS[filters.filter] or (filters.player and 'Jogador') or 'Todos', #incidents),
    badge = tostring(#incidents),
    options = options
  })
  return MZAdminUI.ShowContext(LIST_ID)
end

function MZAdminSecurityAlerts.Register(parentId, actions, available)
  CurrentParent = trim(parentId) ~= '' and trim(parentId) or CurrentParent
  CurrentActions = type(actions) == 'table' and actions or {}
  CurrentAvailable = available == true
  CurrentSummary = CurrentAvailable and request('securityAlertSummary') or nil
  CurrentPlayerStateObservability = CurrentActions.securityAlertsView == true
    and request('playerStateObservability') or nil

  local summary = CurrentSummary and CurrentSummary.summary or {}
  local guard = CurrentSummary and CurrentSummary.guard or {}
  local topPlayer = type(summary.topPlayer) == 'table' and summary.topPlayer or nil
  local policyLabel = guard.alertOnly == true and 'somente alertas' or 'revisar configuracao'
  local modules = type(guard.modules) == 'table' and guard.modules or {}
  local infrastructure = type(guard.infrastructure) == 'table' and guard.infrastructure or {}
  local health = type(infrastructure.detectorHealth) == 'table' and infrastructure.detectorHealth or {}
  local sensors = type(health.sensors) == 'table' and health.sensors or {}
  local leases = type(infrastructure.leases) == 'table' and infrastructure.leases or {}
  local contracts = type(infrastructure.eventContracts) == 'table' and infrastructure.eventContracts or {}
  local correlation = type(infrastructure.correlation) == 'table' and infrastructure.correlation or {}
  local lifecycle = type(infrastructure.lifecycle) == 'table' and infrastructure.lifecycle or {}
  local entityClassification = type(infrastructure.entityClassification) == 'table' and infrastructure.entityClassification or {}
  local labStatus = type(infrastructure.lab) == 'table' and infrastructure.lab or {}
  local incidentPersistence = type(infrastructure.incidentPersistence) == 'table' and infrastructure.incidentPersistence or {}
  local playerStateMetrics = type(CurrentPlayerStateObservability) == 'table'
    and type(CurrentPlayerStateObservability.metrics) == 'table' and CurrentPlayerStateObservability.metrics or {}
  local playerStateAlerts = type(CurrentPlayerStateObservability) == 'table'
    and type(CurrentPlayerStateObservability.alerts) == 'table' and CurrentPlayerStateObservability.alerts or {}
  local function moduleState(name)
    local module = type(modules[name]) == 'table' and modules[name] or {}
    if module.enabled ~= true then return 'desligado' end
    return tostring(module.mode or 'observe')
  end
  local summaryMetadata = {
    { label = 'Total', value = tostring(summary.total or 0) },
    { label = 'Abertos', value = tostring(summary.open or 0) },
    { label = 'Criticos', value = tostring(summary.critical or 0) },
    { label = 'Nao reconhecidos', value = tostring(summary.unacknowledged or 0) },
    { label = 'Armas', value = moduleState('weapon') },
    { label = 'Entidades', value = moduleState('entity') },
    { label = 'Movimento', value = moduleState('movement') },
    { label = 'Estado/player', value = moduleState('playerState') },
    { label = 'PS players loaded', value = tostring(playerStateMetrics.players_loaded or 0) },
    { label = 'PS transitions/rejected', value = ('%d/%d'):format(
      tonumber(playerStateMetrics.state_transitions_total) or 0,
      tonumber(playerStateMetrics.state_transition_rejections_total) or 0
    ) },
    { label = 'PS persistence pending/failure', value = ('%d/%d'):format(
      tonumber(playerStateMetrics.persistence_pending_total) or 0,
      tonumber(playerStateMetrics.persistence_failures_total) or 0
    ) },
    { label = 'PS alertas agregados', value = tostring(#playerStateAlerts) },
    { label = 'Eventos', value = moduleState('event') },
    { label = 'Mira', value = moduleState('aim') },
    { label = 'Versao regras', value = tostring(guard.ruleVersion or '-') },
    { label = 'Sensores', value = ('%d/%d presentes'):format(tonumber(sensors.present) or 0, tonumber(sensors.online) or 0) },
    { label = 'Sensores ausentes', value = tostring(sensors.missing or 0) },
    { label = 'Leases ativas', value = tostring(leases.active or 0) },
    { label = 'Lifecycle ativo', value = tostring(lifecycle.active or 0) },
    { label = 'Lifecycle divergente', value = tostring(lifecycle.diverged or 0) },
    { label = 'Mapa de populacao', value = ('%s (%s)'):format(
      tostring(entityClassification.mappingVersion or '-'),
      entityClassification.mappingValidated == true and 'validado' or 'staging'
    ) },
    { label = 'Contratos aceitos/rejeitados', value = ('%d/%d'):format(tonumber(contracts.accepted) or 0, tonumber(contracts.rejected) or 0) },
    { label = 'Correlacoes em memoria', value = tostring(correlation.entries or 0) },
    { label = 'LAB ativos', value = tostring(labStatus.active or 0) },
    { label = 'Persistencia de incidentes', value = incidentPersistence.enabled == true and 'ativa' or 'desligada' },
    { label = 'Cancelamento de dano', value = guard.enforcementActive and 'ATIVO' or 'desligado' },
    { label = 'Autokick', value = guard.autoKick and 'ATIVO' or 'desligado' },
    { label = 'Autoban', value = guard.autoBan and 'ATIVO' or 'desligado' },
    { label = 'Maior risco de incidente', value = topPlayer and (('%s (%d)'):format(tostring(topPlayer.playerName or topPlayer.citizenid or '-'), tonumber(topPlayer.riskScore) or 0)) or 'nenhum' }
  }
  local options = {
    {
      title = CurrentAvailable and 'Resumo operacional' or 'Central indisponivel',
      description = CurrentAvailable
        and ('Modo %s | politica: %s'):format(tostring(guard.mode or 'observe'), policyLabel)
        or 'O mz_banguard nao esta iniciado ou o contrato de alertas nao respondeu.',
      icon = CurrentAvailable and 'shield' or 'plug-circle-xmark',
      metadata = summaryMetadata,
      readOnly = true
    }
  }

  if CurrentAvailable then
    options[#options + 1] = bind({ title = 'Atualizar dados', description = 'Reconsulta resumo e estado no servidor.', icon = 'rotate' }, 'refresh')
    if topPlayer then
      options[#options + 1] = bind({
        title = 'Jogador com maior risco',
        description = ('%s | risco de incidente %d | %d ocorrencia(s)'):format(
          tostring(topPlayer.playerName or topPlayer.citizenid or '-'), tonumber(topPlayer.riskScore) or 0, tonumber(topPlayer.occurrences) or 0
        ),
        icon = 'user-shield'
      }, 'filter', { player = tostring(topPlayer.citizenid or topPlayer.playerName or '') })
    end
    for _, filter in ipairs({ 'all', 'open', 'acknowledged', 'critical', 'weapon', 'entity', 'movement', 'camera', 'player_state', 'event', 'aim', 'crash', 'runtime', 'canary' }) do
      options[#options + 1] = bind({
        title = FILTER_LABELS[filter],
        description = filter == 'all' and 'Lista os incidentes mais recentes.' or ('Filtrar por ' .. FILTER_LABELS[filter]:lower()),
        icon = filter == 'critical' and 'triangle-exclamation' or 'filter'
      }, 'filter', { filter = filter })
    end
    options[#options + 1] = bind({ title = 'Buscar jogador', description = 'Nome, citizenid ou source atual.', icon = 'user-magnifying-glass' }, 'playerFilter')
  end

  MZAdminUI.RegisterContext({
    id = MENU_ID,
    menu = CurrentParent,
    title = 'Central de Alertas',
    subtitle = 'Observacao server-side, triagem e acoes auditadas',
    badge = ('ALERTAS %d'):format(tonumber(summary.unacknowledged) or 0),
    options = options
  })
  return true
end

function MZAdminSecurityAlerts.GetRootOption()
  if CurrentActions.securityAlertsView ~= true then return nil end
  local summary = CurrentSummary and CurrentSummary.summary or {}
  local count = tonumber(summary.unacknowledged) or 0
  return {
    title = CurrentAvailable and ('Segurança - Central de Alertas (%d)'):format(count) or 'Segurança - Central indisponível',
    description = CurrentAvailable and 'Resumo, incidentes, filtros e acoes de investigacao.' or 'Consulte o estado do mz_banguard.',
    icon = 'bell',
    menu = MENU_ID,
    arrow = true
  }
end

function MZAdminSecurityAlerts.GetMenuId()
  return MENU_ID
end

AddEventHandler(EVENT, function(payload)
  local action = type(payload) == 'table' and tostring(payload.action or '') or ''
  if action == 'filter' then
    if trim(payload.player) ~= '' then
      MZAdminSecurityAlerts.OpenList({ player = trim(payload.player) })
    else
      MZAdminSecurityAlerts.OpenList({ filter = tostring(payload.filter or 'all') })
    end
  elseif action == 'refresh' then
    MZAdminSecurityAlerts.Register(CurrentParent, CurrentActions, CurrentAvailable)
    MZAdminUI.ShowContext(MENU_ID)
  elseif action == 'playerFilter' then
    local values = MZAdminUI.InputDialog('Buscar incidentes por jogador', {
      { type = 'input', label = 'Nome, citizenid ou source', required = true, min = 1, max = 64 }
    }, { allowCancel = true })
    local player = values and trim(values[1]) or ''
    if player ~= '' then MZAdminSecurityAlerts.OpenList({ player = player }) end
  elseif action == 'details' and CurrentActions.securityAlertDetails then
    openDetails(payload.id, false)
  elseif action == 'identifiers' then
    openDetails(payload.id, true)
  elseif action == 'copyId' then
    local id = trim(payload.id)
    if lib and type(lib.setClipboard) == 'function' then lib.setClipboard(id) end
    notify('ID do incidente: ' .. id, 'success')
  elseif action == 'ack' then
    if request('securityIncidentAcknowledge', payload.id) then openDetails(payload.id, false) end
  elseif action == 'note' then
    local values = MZAdminUI.InputDialog('Adicionar nota ao incidente', {
      { type = 'textarea', label = 'Nota', required = true, min = 3, max = 500 }
    }, { allowCancel = true })
    local note = values and trim(values[1]) or ''
    if #note >= 3 and request('securityIncidentNote', payload.id, note) then openDetails(payload.id, false) end
  elseif action == 'status' then
    if request('securityIncidentStatus', payload.id, payload.status) then openDetails(payload.id, false) end
  elseif action == 'export' then
    local exported = request('securityIncidentExport', payload.id, payload.format)
    if exported and type(exported.content) == 'string' then
      if lib and type(lib.setClipboard) == 'function' then lib.setClipboard(exported.content) end
      notify(('Evidencia sanitizada copiada: %s'):format(tostring(exported.filename or 'evidence')), 'success')
    end
  elseif action == 'lab' and CurrentActions.securityAlertLab then
    local values = MZAdminUI.InputDialog(payload.enabled and 'Ativar LAB' or 'Desativar LAB', {
      { type = 'textarea', label = 'Motivo auditavel', required = true, min = 3, max = 256 }
    }, { allowCancel = true })
    local reason = values and trim(values[1]) or ''
    if #reason >= 3 and request('securityIncidentLab', payload.source, payload.enabled == true, 3600, reason) then
      openDetails(payload.id, false)
    end
  elseif action == 'playerAction' then
    local playerAction = tostring(payload.playerAction or '')
    local data = request('securityIncidentAction', payload.id, playerAction)
    local targetSource = data and tonumber(data.targetSource)
    if targetSource then
      if playerAction == 'goto' then
        ExecuteCommand((Config.Commands.gotoPlayer or 'goto') .. ' ' .. math.floor(targetSource))
      elseif playerAction == 'spectate' then
        ExecuteCommand((Config.SpectateCommand or 'spectate') .. ' ' .. math.floor(targetSource))
      end
    end
  end
end)
