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
  all = (type(locale) == 'function' and locale('menu.s_a4114a83f4c6') or 'Todos'),
  open = (type(locale) == 'function' and locale('security_alerts.s_98417beca640') or 'Abertos'),
  acknowledged = (type(locale) == 'function' and locale('security_alerts.s_15f2c1da4e0a') or 'Reconhecidos'),
  critical = (type(locale) == 'function' and locale('security_alerts.s_a21ee5d668e1') or 'Criticos'),
  weapon = (type(locale) == 'function' and locale('security_alerts.s_44aaa95d24b6') or 'Armas'),
  entity = (type(locale) == 'function' and locale('security_alerts.s_e47a09f8439f') or 'Entidades'),
  movement = (type(locale) == 'function' and locale('security_alerts.s_d2b8987011ed') or 'Movimento'),
  camera = (type(locale) == 'function' and locale('security_alerts.s_4da9c9af9631') or 'Camera'),
  player_state = (type(locale) == 'function' and locale('security_alerts.s_39c5d5a3d1bf') or 'Estado do jogador'),
  event = (type(locale) == 'function' and locale('security_alerts.s_c7b33878f639') or 'Eventos'),
  aim = (type(locale) == 'function' and locale('security_alerts.s_0ba9f2880a76') or 'Mira'),
  crash = (type(locale) == 'function' and locale('security_alerts.s_e94f808d7c3f') or 'Crashes'),
  runtime = (type(locale) == 'function' and locale('security_alerts.s_36a55c366f72') or 'Runtime client'),
  canary = (type(locale) == 'function' and locale('security_alerts.s_79945f0dfe7d') or 'Canarios')
}

local CODE_LABELS = {
  weapon_damage_no_equipped_weapon = (type(locale) == 'function' and locale('security_alerts.s_a192f2bbb77a') or 'Dano sem arma oficial equipada'),
  weapon_damage_hash_mismatch = (type(locale) == 'function' and locale('security_alerts.s_396f237eb56e') or 'Hash divergente da arma oficial'),
  weapon_damage_death_state_incompatible = (type(locale) == 'function' and locale('security_alerts.s_29030d1f30c7') or 'Dano em estado de morte incompativel'),
  weapon_damage_unknown_hash = (type(locale) == 'function' and locale('security_alerts.s_33461f5aa352') or 'Hash de arma desconhecido'),
  weapon_damage_session_not_ready = (type(locale) == 'function' and locale('security_alerts.s_53fcfa3c52d2') or 'Sessao ainda nao pronta'),
  weapon_damage_transition_window = (type(locale) == 'function' and locale('security_alerts.s_e72bb55530d2') or 'Janela de transicao de arma'),
  weapon_damage_payload_invalid = (type(locale) == 'function' and locale('security_alerts.s_351a65f0ee70') or 'Payload de dano invalido'),
  weapon_damage_rate_suspect = (type(locale) == 'function' and locale('security_alerts.s_105897cea3b9') or 'Taxa de eventos suspeita'),
  projectile_weapon_unauthorized = (type(locale) == 'function' and locale('security_alerts.s_e4ad4fe77757') or 'Projetil sem arma autorizada'),
  entity_spawn_rate_suspect = (type(locale) == 'function' and locale('security_alerts.s_8fb30cc4a8c6') or 'Spawn excessivo de entidades'),
  entity_model_blocked = (type(locale) == 'function' and locale('security_alerts.s_891cc6c6b0de') or 'Modelo de entidade bloqueado'),
  movement_teleport_suspect = (type(locale) == 'function' and locale('security_alerts.s_5e397a7b8532') or 'Deslocamento/teleporte suspeito'),
  movement_noclip_suspect = (type(locale) == 'function' and locale('security_alerts.s_cbfa6224612c') or 'Padrao de noclip suspeito'),
  movement_vehicle_reentry_distance = (type(locale) == 'function' and locale('security_alerts.s_a58d4540625a') or 'Retorno ao veiculo a distancia'),
  camera_freecam_suspect = (type(locale) == 'function' and locale('security_alerts.s_542efe0ca43e') or 'Freecam suspeita'),
  client_resource_presence_missing = (type(locale) == 'function' and locale('security_alerts.s_a93a01f21507') or 'Runtime client ausente'),
  client_resource_stop_observed = (type(locale) == 'function' and locale('security_alerts.s_04dec97d64e4') or 'Parada de resource observada'),
  canary_triggered = (type(locale) == 'function' and locale('security_alerts.s_52d121223717') or 'Canario de seguranca acionado'),
  camera_spectate_unapproved = (type(locale) == 'function' and locale('security_alerts.s_66bd65d120fd') or 'Spectate nao autorizado'),
  player_model_change_unapproved = (type(locale) == 'function' and locale('security_alerts.s_215ea568f793') or 'Troca de ped/modelo nao autorizada'),
  player_godmode_suspect = (type(locale) == 'function' and locale('security_alerts.s_c020c847f220') or 'Godmode suspeito'),
  player_invisible_suspect = (type(locale) == 'function' and locale('security_alerts.s_7cc1f4a31912') or 'Invisibilidade suspeita'),
  event_explosion_rate_suspect = (type(locale) == 'function' and locale('security_alerts.s_13f0d1ebc072') or 'Spam de explosoes'),
  event_explosion_anomaly_suspect = (type(locale) == 'function' and locale('security_alerts.s_693922aaf8db') or 'Explosao com metadados anormais'),
  event_clear_tasks_rate_suspect = (type(locale) == 'function' and locale('security_alerts.s_66f234c115de') or 'Interferencia repetida em ped'),
  event_remote_clear_tasks_suspect = (type(locale) == 'function' and locale('security_alerts.s_e375c930bdcd') or 'Clear tasks contra outro jogador'),
  event_tazer_rate_suspect = (type(locale) == 'function' and locale('security_alerts.s_5d1ec10e32ad') or 'Spam de tazer'),
  event_ptfx_rate_suspect = (type(locale) == 'function' and locale('security_alerts.s_c9127d4e8255') or 'Spam de particulas'),
  event_ptfx_anomaly_suspect = (type(locale) == 'function' and locale('security_alerts.s_5e7ab51e7f54') or 'Particula anormal/remota'),
  event_projectile_rate_suspect = (type(locale) == 'function' and locale('security_alerts.s_1f2205ce4319') or 'Spam de projeteis'),
  event_fire_rate_suspect = (type(locale) == 'function' and locale('security_alerts.s_d8dbc512fda7') or 'Spam de fogo'),
  event_fire_remote_suspect = (type(locale) == 'function' and locale('security_alerts.s_6ac17a7de817') or 'Fogo remoto suspeito'),
  event_remote_weapon_action_suspect = (type(locale) == 'function' and locale('security_alerts.s_d465adc94ea0') or 'Acao remota de arma'),
  event_damage_modifier_suspect = (type(locale) == 'function' and locale('security_alerts.s_e4dff4994c9c') or 'Modificador de dano/defesa'),
  aim_headshot_pattern_suspect = (type(locale) == 'function' and locale('security_alerts.s_122e1dec4ef1') or 'Padrao estatistico de headshots'),
  crash_observed = (type(locale) == 'function' and locale('security_alerts.s_abfa30e08d5d') or 'Jogador sofreu crash'),
  crash_cluster_suspect = (type(locale) == 'function' and locale('security_alerts.s_2402c38be22d') or 'Varios jogadores crasharam em sequencia')
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
    notify(((type(locale) == 'function' and locale('security_alerts.s_60639e1d4f7c') or 'Central de alertas: %s')):format(tostring(err or (type(locale) == 'function' and locale('router.s_735388ef2f3c') or 'indisponivel'))), 'error')
    return nil
  end
  return data
end

local function incidentMetadata(item)
  local metadata = {
    { label = 'ID', value = tostring(item.id or '-') },
    { label = (type(locale) == 'function' and locale('logs.s_5966b0ce8b7e') or 'Categoria'), value = tostring(item.category or '-') },
    { label = (type(locale) == 'function' and locale('security_alerts.s_4b9b7efcac5c') or 'Confianca'), value = tostring(item.confidence or '-') },
    { label = 'Status', value = tostring(item.status or '-') },
    { label = (type(locale) == 'function' and locale('security_alerts.s_5ca84b6a9910') or 'Risco do incidente'), value = tostring(item.riskScore or 0) .. '/100' },
    { label = (type(locale) == 'function' and locale('security_alerts.s_6ca60df35518') or 'Ocorrencias'), value = tostring(item.count or 1) },
    { label = (type(locale) == 'function' and locale('security_alerts.s_b76cf4bf00f0') or 'Sinal'), value = tostring(item.subject or item.code or '-') },
    { label = (type(locale) == 'function' and locale('security_alerts.s_11cd66d96097') or 'Ultima'), value = tostring(item.lastSeenIso or item.lastSeenAt or '-') }
  }
  if item.category == 'weapon' then
    metadata[#metadata + 1] = { label = (type(locale) == 'function' and locale('security_alerts.s_3d9c80243316') or 'Reportada'), value = tostring(item.reportedWeaponName or item.reportedWeaponHash or '-') }
    metadata[#metadata + 1] = { label = (type(locale) == 'function' and locale('security_alerts.s_45ce87990a42') or 'Oficial'), value = tostring(item.authorizedWeaponName or item.authorizedWeaponHash or (type(locale) == 'function' and locale('security_alerts.s_815c88438a33') or 'nenhuma')) }
  end
  return metadata
end

local function evidenceMetadata(item)
  local metadata = {
    { label = (type(locale) == 'function' and locale('security_alerts.s_eba5ffca729f') or 'Horario'), value = tostring(item.at or '-') },
    { label = (type(locale) == 'function' and locale('security_alerts.s_8adfd7cf105f') or 'Origem'), value = tostring(item.origin or '-') },
    { label = (type(locale) == 'function' and locale('security_alerts.s_4b9b7efcac5c') or 'Confianca'), value = tostring(item.confidence or '-') }
  }
  local fields = {
    { 'entityType', (type(locale) == 'function' and locale('security_alerts.s_c759d136337f') or 'Entidade') }, { 'model', (type(locale) == 'function' and locale('menu.s_b3a01bef14b4') or 'Modelo') }, { 'amount', (type(locale) == 'function' and locale('security_alerts.s_faf6b797a14e') or 'Quantidade') },
    { 'windowMs', (type(locale) == 'function' and locale('security_alerts.s_9b7307a7f3fb') or 'Janela ms') }, { 'distance', (type(locale) == 'function' and locale('security_alerts.s_3975ce41a954') or 'Distancia') }, { 'height', (type(locale) == 'function' and locale('security_alerts.s_34d9e3886723') or 'Altura') },
    { 'cameraDistance', 'Camera/ped' }, { 'alpha', 'Alpha' }, { 'bucket', 'Bucket' },
    { 'health', (type(locale) == 'function' and locale('security_alerts.s_518130c35cc2') or 'Vida') }, { 'armour', (type(locale) == 'function' and locale('security_alerts.s_85cd8aeada23') or 'Colete') }, { 'invincible', (type(locale) == 'function' and locale('security_alerts.s_6d2c6a7ed7c0') or 'Invencivel') },
    { 'damageDisabled', (type(locale) == 'function' and locale('security_alerts.s_6e1a8db027c4') or 'Dano desativado') }, { 'fullProofs', (type(locale) == 'function' and locale('security_alerts.s_c245c65e764c') or 'Proofs completos') },
    { 'inVehicle', (type(locale) == 'function' and locale('security_alerts.s_5abce19153bf') or 'Em veiculo') }, { 'spectator', (type(locale) == 'function' and locale('security_alerts.s_4e920fa89711') or 'Spectator') }, { 'vehicleNetId', (type(locale) == 'function' and locale('security_alerts.s_93c62fe94985') or 'Veiculo net ID') },
    { 'weaponHash', (type(locale) == 'function' and locale('security_alerts.s_80dc031b6318') or 'Arma hash') }, { 'hitComponent', (type(locale) == 'function' and locale('security_alerts.s_1414bb26b2d6') or 'Componente') }, { 'hits', (type(locale) == 'function' and locale('security_alerts.s_a6b667dadbb8') or 'Acertos') },
    { 'headshots', (type(locale) == 'function' and locale('security_alerts.s_cdef5398ee24') or 'Headshots') }, { 'ratio', (type(locale) == 'function' and locale('security_alerts.s_ad07efdd1fa0') or 'Proporcao') }, { 'eventType', (type(locale) == 'function' and locale('security_alerts.s_8118a9e61fa6') or 'Tipo evento') },
    { 'reportedWeaponHash', (type(locale) == 'function' and locale('security_alerts.s_1db5f85bbc10') or 'Hash reportado') }, { 'authorizedWeaponHash', (type(locale) == 'function' and locale('security_alerts.s_2ac62c91ec39') or 'Hash oficial') },
    { 'damage', (type(locale) == 'function' and locale('security_alerts.s_f316b1afad30') or 'Dano') }, { 'targetNetId', (type(locale) == 'function' and locale('security_alerts.s_ccc78360bd12') or 'Target/net ID') },
    { 'burstAmount', 'Burst' }, { 'burstWindowMs', (type(locale) == 'function' and locale('security_alerts.s_ea748400c9ec') or 'Janela burst ms') },
    { 'populationName', (type(locale) == 'function' and locale('security_alerts.s_45be22105f86') or 'Populacao') }, { 'populationClass', (type(locale) == 'function' and locale('security_alerts.s_401951053c0a') or 'Classe populacao') },
    { 'mappingVersion', (type(locale) == 'function' and locale('security_alerts.s_3fd90e3504c0') or 'Mapa populacao') }, { 'mappingValidated', (type(locale) == 'function' and locale('security_alerts.s_0d1cd84f4243') or 'Mapa validado') },
    { 'owner', (type(locale) == 'function' and locale('security_alerts.s_f28b371ebff9') or 'Owner atual') }, { 'firstOwner', (type(locale) == 'function' and locale('security_alerts.s_830ded9e05ba') or 'Primeiro owner') },
    { 'targetOwner', (type(locale) == 'function' and locale('security_alerts.s_70de6987c95b') or 'Owner do alvo') }, { 'damageScale', (type(locale) == 'function' and locale('security_alerts.s_3da5a0527778') or 'Escala de dano') },
    { 'distanceFromSender', (type(locale) == 'function' and locale('security_alerts.s_ac54bd153867') or 'Distancia do emissor') }, { 'effectHash', (type(locale) == 'function' and locale('security_alerts.s_2b44bc847195') or 'Efeito hash') },
    { 'scale', (type(locale) == 'function' and locale('security_alerts.s_0a1628f544be') or 'Escala') }, { 'projectileHash', (type(locale) == 'function' and locale('security_alerts.s_c079fa84c5e7') or 'Projetil hash') },
    { 'weaponModifier', (type(locale) == 'function' and locale('security_alerts.s_85ed737bf5f0') or 'Mod. arma') }, { 'meleeModifier', (type(locale) == 'function' and locale('security_alerts.s_f2ec127571f4') or 'Mod. melee') },
    { 'defenseModifier', (type(locale) == 'function' and locale('security_alerts.s_76a62397b145') or 'Mod. defesa') }, { 'action', (type(locale) == 'function' and locale('security_alerts.s_b2014622801b') or 'Acao') },
    { 'distanceBand', (type(locale) == 'function' and locale('security_alerts.s_f3894eb23b9d') or 'Faixa distancia') }, { 'pingBand', (type(locale) == 'function' and locale('security_alerts.s_6befafc057e5') or 'Faixa ping') },
    { 'averageDistance', (type(locale) == 'function' and locale('security_alerts.s_0d272062b8a1') or 'Distancia media') }, { 'qualifiedWindows', (type(locale) == 'function' and locale('security_alerts.s_d516b1e04359') or 'Janelas qualificadas') },
    { 'lifecycle', 'Lifecycle' }, { 'sessionId', (type(locale) == 'function' and locale('security_alerts.s_1750cfd895a1') or 'Sessao lifecycle') },
    { 'transition', (type(locale) == 'function' and locale('security_alerts.s_ede1c245c1d9') or 'Transicao') }, { 'targetType', (type(locale) == 'function' and locale('security_alerts.s_c4fba87f6683') or 'Tipo do alvo') },
    { 'targetDistance', (type(locale) == 'function' and locale('security_alerts.s_d42f2ccdb940') or 'Distancia do alvo') }, { 'ammoRevision', (type(locale) == 'function' and locale('security_alerts.s_8c60ed8180e3') or 'Revisao de municao') },
    { 'transitionRevision', (type(locale) == 'function' and locale('security_alerts.s_05c3106ce723') or 'Revisao da transicao') }, { 'rateProfile', (type(locale) == 'function' and locale('security_alerts.s_712892c29487') or 'Perfil de cadencia') },
    { 'rateCount', (type(locale) == 'function' and locale('security_alerts.s_ee5835607ef5') or 'Eventos na janela') }, { 'rateThreshold', (type(locale) == 'function' and locale('security_alerts.s_06ff090ba2d0') or 'Limite da janela') },
    { 'rateWindowMs', (type(locale) == 'function' and locale('security_alerts.s_5b49c9a937e3') or 'Janela de cadencia (ms)') },
    { 'correlationId', (type(locale) == 'function' and locale('security_alerts.s_782453fa6336') or 'Correlacao') }, { 'ruleVersion', (type(locale) == 'function' and locale('security_alerts.s_e2f7cbedc353') or 'Versao da regra') }
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
  technical[#technical + 1] = { label = (type(locale) == 'function' and locale('security_alerts.s_bd49709f3318') or 'Source atual'), value = tostring(incident.source or 'offline') }
  if incident.category == 'weapon' then
    technical[#technical + 1] = { label = (type(locale) == 'function' and locale('security_alerts.s_64adc19a9ecf') or 'Municao oficial'), value = tostring(incident.authorizedAmmo or '-') }
    technical[#technical + 1] = { label = (type(locale) == 'function' and locale('security_alerts.s_6a53910a4d97') or 'Dano reportado'), value = tostring(incident.damage or '-') }
    technical[#technical + 1] = { label = (type(locale) == 'function' and locale('security_alerts.s_ccc78360bd12') or 'Target/net ID'), value = tostring(incident.targetNetId or '-') }
  end
  technical[#technical + 1] = { label = (type(locale) == 'function' and locale('security_alerts.s_4b21755277ca') or 'Evidencias suprimidas'), value = tostring(incident.suppressedCount or 0) }

  local options = {
    {
      title = human.title or CODE_LABELS[incident.code] or tostring(incident.code or (type(locale) == 'function' and locale('security_alerts.s_3c3cccca7146') or 'Incidente')),
      description = tostring(human.summary or '-'),
      icon = incident.severity == 'critical' and 'shield-halved' or 'shield',
      metadata = {
        { label = (type(locale) == 'function' and locale('logs.s_5966b0ce8b7e') or 'Categoria'), value = tostring(human.category_label or incident.category or '-') },
        { label = (type(locale) == 'function' and locale('logs.s_62737be6bfeb') or 'Severidade'), value = tostring(human.severity_label or incident.severity or '-') },
        { label = (type(locale) == 'function' and locale('security_alerts.s_4b9b7efcac5c') or 'Confianca'), value = tostring(human.confidence_label or incident.confidence or '-') },
        { label = (type(locale) == 'function' and locale('security_alerts.s_da3db30145a5') or 'Acao recomendada'), value = tostring(human.recommended_action or '-') },
        { label = 'LAB', value = incident.lab and (type(locale) == 'function' and locale('security_alerts.s_9563e7496df3') or 'SIM') or (type(locale) == 'function' and locale('security_alerts.s_21592d443e0a') or 'nao') }
      },
      readOnly = true
    },
    {
      title = (type(locale) == 'function' and locale('security_alerts.s_6fa6fc15d546') or 'Detalhes tecnicos'),
      description = ('%s | %s | online: %s'):format(
        tostring(incident.severity or 'info'), tostring(incident.status or 'open'), incident.online and (type(locale) == 'function' and locale('security_alerts.s_813221ca5f14') or 'sim') or (type(locale) == 'function' and locale('security_alerts.s_21592d443e0a') or 'nao')
      ),
      icon = 'code',
      metadata = technical,
      readOnly = true
    },
    bind({ title = (type(locale) == 'function' and locale('security_alerts.s_6a3016ba9ed7') or 'Copiar ID do incidente'), description = tostring(incident.id), icon = 'copy' }, 'copyId', { id = incident.id })
  }

  if CurrentActions.securityAlertAcknowledge and incident.status == 'open' then
    options[#options + 1] = bind({ title = (type(locale) == 'function' and locale('security_alerts.s_026446335e9d') or 'Reconhecer incidente'), description = (type(locale) == 'function' and locale('security_alerts.s_9d249f955628') or 'Marca como em analise; nao pune o jogador.'), icon = 'check' }, 'ack', { id = incident.id })
  end
  if CurrentActions.securityAlertNote then
    options[#options + 1] = bind({ title = (type(locale) == 'function' and locale('security_alerts.s_344d88932f23') or 'Adicionar nota'), description = (type(locale) == 'function' and locale('security_alerts.s_acef8b5c0459') or 'Nota administrativa auditavel.'), icon = 'note-sticky' }, 'note', { id = incident.id })
  end
  if CurrentActions.securityAlertClear then
    options[#options + 1] = bind({ title = (type(locale) == 'function' and locale('security_alerts.s_2323bbf543a6') or 'Marcar resolvido'), description = (type(locale) == 'function' and locale('security_alerts.s_ee28cafc6128') or 'Preserva todas as evidencias.'), icon = 'circle-check' }, 'status', { id = incident.id, status = 'resolved' })
    options[#options + 1] = bind({ title = (type(locale) == 'function' and locale('security_alerts.s_3a497fd2be3d') or 'Marcar falso positivo'), description = (type(locale) == 'function' and locale('security_alerts.s_ee28cafc6128') or 'Preserva todas as evidencias.'), icon = 'shield-circle-check' }, 'status', { id = incident.id, status = 'false_positive' })
    if incident.status ~= 'open' then
      options[#options + 1] = bind({ title = (type(locale) == 'function' and locale('security_alerts.s_3e866566b4ec') or 'Reabrir incidente'), icon = 'rotate-left' }, 'status', { id = incident.id, status = 'open' })
    end
  end
  if CurrentActions.securityAlertIdentifiers and includeIdentifiers ~= true then
    options[#options + 1] = bind({ title = (type(locale) == 'function' and locale('security_alerts.s_4f5ff9c31e92') or 'Exibir identificadores'), description = (type(locale) == 'function' and locale('security_alerts.s_e0a3756a9b34') or 'Acesso sensivel e auditado.'), icon = 'fingerprint' }, 'identifiers', { id = incident.id })
  end
  if type(incident.identifiers) == 'table' then
    local masked = type(incident.identifiers.masked) == 'table' and incident.identifiers.masked or {}
    options[#options + 1] = {
      title = (type(locale) == 'function' and locale('security_alerts.s_5f3f8c5890b7') or 'Identificadores mascarados'), icon = 'fingerprint', readOnly = true,
      metadata = {
        { label = 'license', value = tostring(masked.license or '-') },
        { label = 'fivem', value = tostring(masked.fivem or '-') }
      }
    }
  end
  options[#options + 1] = bind({ title = (type(locale) == 'function' and locale('security_alerts.s_5c62168b48f1') or 'Exportar evidencia JSON'), description = (type(locale) == 'function' and locale('security_alerts.s_ec3274f1a054') or 'Copia um pacote tecnico sanitizado.'), icon = 'file-code' }, 'export', { id = incident.id, format = 'json' })
  options[#options + 1] = bind({ title = (type(locale) == 'function' and locale('security_alerts.s_2890616439aa') or 'Exportar evidencia Markdown'), description = (type(locale) == 'function' and locale('security_alerts.s_f2881e6acd8f') or 'Copia um relatorio humano sanitizado.'), icon = 'file-lines' }, 'export', { id = incident.id, format = 'markdown' })
  if incident.online and CurrentActions.securityAlertLab then
    options[#options + 1] = bind({
      title = incident.lab and (type(locale) == 'function' and locale('security_alerts.s_f7bf7ca93c0e') or 'Desativar LAB') or (type(locale) == 'function' and locale('security_alerts.s_52e9e551cd02') or 'Ativar LAB por 60 minutos'),
      description = (type(locale) == 'function' and locale('security_alerts.s_adab2a4671c0') or 'Desativa punicao automatica e amplia a retencao desta sessao.'),
      icon = 'flask'
    }, 'lab', { id = incident.id, source = incident.source, enabled = incident.lab ~= true })
  end
  for index, evidence in ipairs(incident.evidence or {}) do
    options[#options + 1] = {
      title = ((type(locale) == 'function' and locale('security_alerts.s_4f410c9afc0a') or 'Ocorrencia agrupada #%d')):format(index),
      description = tostring(evidence.reason or (type(locale) == 'function' and locale('security_alerts.s_3698ce1055ce') or 'evidencia server-side')),
      metadata = evidenceMetadata(evidence),
      icon = 'list', readOnly = true
    }
  end
  for index, entry in ipairs(incident.timeline or {}) do
    local metadata = {
      { label = 'ID', value = tostring(entry.id or '-') },
      { label = (type(locale) == 'function' and locale('security_alerts.s_eba5ffca729f') or 'Horario'), value = tostring(entry.at or '-') }
    }
    local keys = {}
    for key in pairs(type(entry.data) == 'table' and entry.data or {}) do keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do
      metadata[#metadata + 1] = { label = tostring(key), value = tostring(entry.data[key]) }
    end
    options[#options + 1] = {
      title = ((type(locale) == 'function' and locale('security_alerts.s_efabc7a6bc17') or 'Timeline #%d')):format(index),
      description = tostring(entry.kind or (type(locale) == 'function' and locale('security_alerts.s_73907459c8aa') or 'correlacao')),
      metadata = metadata,
      icon = 'timeline', readOnly = true
    }
  end
  if incident.online and CurrentActions.securityAlertGoto then
    options[#options + 1] = bind({ title = (type(locale) == 'function' and locale('security_alerts.s_7e0bf2421c51') or 'Ir ate o jogador'), description = (type(locale) == 'function' and locale('security_alerts.s_d9c0acc7b28a') or 'Revalida alvo, identidade e hierarquia no servidor.'), icon = 'person-walking-arrow-right' }, 'playerAction', { id = incident.id, playerAction = 'goto' })
  end
  if incident.online and CurrentActions.securityAlertSpectate then
    options[#options + 1] = bind({ title = (type(locale) == 'function' and locale('security_alerts.s_cacff92f0a39') or 'Espectar jogador'), description = (type(locale) == 'function' and locale('security_alerts.s_d9c0acc7b28a') or 'Revalida alvo, identidade e hierarquia no servidor.'), icon = 'binoculars' }, 'playerAction', { id = incident.id, playerAction = 'spectate' })
  end

  for _, note in ipairs(incident.notes or {}) do
    options[#options + 1] = {
      title = (type(locale) == 'function' and locale('security_alerts.s_45355d70d5d2') or 'Nota - ') .. tostring(note.authorName or note.authorCitizenid or 'Staff'),
      description = tostring(note.text or ''),
      metadata = { { label = (type(locale) == 'function' and locale('security_alerts.s_e5e429bcc9c2') or 'Data'), value = tostring(note.at or '-') } },
      icon = 'note-sticky', readOnly = true
    }
  end

  local contextId = detailMenuId(incident.id)
  MZAdminUI.RegisterContext({
    id = contextId,
    menu = LIST_ID,
    title = tostring(incident.playerName or (type(locale) == 'function' and locale('security_alerts.s_3c3cccca7146') or 'Incidente')),
    subtitle = ('%s | CID %s'):format(tostring(incident.id), tostring(incident.citizenid or (type(locale) == 'function' and locale('router.s_735388ef2f3c') or 'indisponivel'))),
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
      title = ('[%s]%s %s'):format(tostring(item.severity or 'info'):upper(), item.lab and '[LAB]' or '', tostring(item.playerName or item.citizenid or (type(locale) == 'function' and locale('router.s_a87c0c205c1d') or 'Jogador'))),
      description = ((type(locale) == 'function' and locale('security_alerts.s_cb38b1d4da1f') or '%s | %d ocorrencia(s) | risco do incidente %d')):format(
        item.human and item.human.title or CODE_LABELS[item.code] or tostring(item.code or (type(locale) == 'function' and locale('router.s_f430038bf4ad') or 'incidente')), tonumber(item.count) or 1, tonumber(item.riskScore) or 0
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
    options[1] = { title = (type(locale) == 'function' and locale('security_alerts.s_e72ac5122f0c') or 'Nenhum incidente encontrado'), description = (type(locale) == 'function' and locale('security_alerts.s_5374c43a8e72') or 'Nao ha registros em memoria para este filtro.'), icon = 'shield-circle-check', readOnly = true }
  end
  MZAdminUI.RegisterContext({
    id = LIST_ID,
    menu = MENU_ID,
    title = (type(locale) == 'function' and locale('security_alerts.s_f42e0a0ac91d') or 'Incidentes de segurança'),
    subtitle = ((type(locale) == 'function' and locale('security_alerts.s_f5f5526deb33') or 'Filtro: %s | %d resultado(s)')):format(FILTER_LABELS[filters.filter] or (filters.player and (type(locale) == 'function' and locale('router.s_a87c0c205c1d') or 'Jogador')) or (type(locale) == 'function' and locale('menu.s_a4114a83f4c6') or 'Todos'), #incidents),
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
  local policyLabel = guard.alertOnly == true and (type(locale) == 'function' and locale('security_alerts.s_a91fb1c101ec') or 'somente alertas') or (type(locale) == 'function' and locale('security_alerts.s_73ffc9a825b5') or 'revisar configuracao')
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
    if module.enabled ~= true then return (type(locale) == 'function' and locale('security_alerts.s_ee06676faab4') or 'desligado') end
    return tostring(module.mode or 'observe')
  end
  local summaryMetadata = {
    { label = 'Total', value = tostring(summary.total or 0) },
    { label = (type(locale) == 'function' and locale('security_alerts.s_98417beca640') or 'Abertos'), value = tostring(summary.open or 0) },
    { label = (type(locale) == 'function' and locale('security_alerts.s_a21ee5d668e1') or 'Criticos'), value = tostring(summary.critical or 0) },
    { label = (type(locale) == 'function' and locale('security_alerts.s_46eb4ee65eae') or 'Nao reconhecidos'), value = tostring(summary.unacknowledged or 0) },
    { label = (type(locale) == 'function' and locale('security_alerts.s_44aaa95d24b6') or 'Armas'), value = moduleState('weapon') },
    { label = (type(locale) == 'function' and locale('security_alerts.s_e47a09f8439f') or 'Entidades'), value = moduleState('entity') },
    { label = (type(locale) == 'function' and locale('security_alerts.s_d2b8987011ed') or 'Movimento'), value = moduleState('movement') },
    { label = (type(locale) == 'function' and locale('security_alerts.s_49d6543fe07d') or 'Estado/player'), value = moduleState('playerState') },
    { label = (type(locale) == 'function' and locale('security_alerts.s_4a66cb3e74c5') or 'PS jogadores carregados'), value = tostring(playerStateMetrics.players_loaded or 0) },
    { label = (type(locale) == 'function' and locale('security_alerts.s_b3cf611de56c') or 'PS transicoes/rejeitadas'), value = ('%d/%d'):format(
      tonumber(playerStateMetrics.state_transitions_total) or 0,
      tonumber(playerStateMetrics.state_transition_rejections_total) or 0
    ) },
    { label = (type(locale) == 'function' and locale('security_alerts.s_49248e6aad10') or 'PS persistencia pendente/falha'), value = ('%d/%d'):format(
      tonumber(playerStateMetrics.persistence_pending_total) or 0,
      tonumber(playerStateMetrics.persistence_failures_total) or 0
    ) },
    { label = (type(locale) == 'function' and locale('security_alerts.s_38f7ce98aa9a') or 'PS alertas agregados'), value = tostring(#playerStateAlerts) },
    { label = (type(locale) == 'function' and locale('security_alerts.s_c7b33878f639') or 'Eventos'), value = moduleState('event') },
    { label = (type(locale) == 'function' and locale('security_alerts.s_0ba9f2880a76') or 'Mira'), value = moduleState('aim') },
    { label = (type(locale) == 'function' and locale('security_alerts.s_7f9bd7156fec') or 'Versao regras'), value = tostring(guard.ruleVersion or '-') },
    { label = (type(locale) == 'function' and locale('security_alerts.s_6b1842c29d6b') or 'Sensores'), value = ((type(locale) == 'function' and locale('security_alerts.s_1b41c9a39463') or '%d/%d presentes')):format(tonumber(sensors.present) or 0, tonumber(sensors.online) or 0) },
    { label = (type(locale) == 'function' and locale('security_alerts.s_2b39821a51d8') or 'Sensores ausentes'), value = tostring(sensors.missing or 0) },
    { label = (type(locale) == 'function' and locale('security_alerts.s_ea7826e08436') or 'Leases ativas'), value = tostring(leases.active or 0) },
    { label = (type(locale) == 'function' and locale('security_alerts.s_62fd198a8109') or 'Lifecycle ativo'), value = tostring(lifecycle.active or 0) },
    { label = (type(locale) == 'function' and locale('security_alerts.s_7a7ba2f21609') or 'Lifecycle divergente'), value = tostring(lifecycle.diverged or 0) },
    { label = (type(locale) == 'function' and locale('security_alerts.s_b925e18a5332') or 'Mapa de populacao'), value = ('%s (%s)'):format(
      tostring(entityClassification.mappingVersion or '-'),
      entityClassification.mappingValidated == true and (type(locale) == 'function' and locale('security_alerts.s_b154a73c2ad4') or 'validado') or 'staging'
    ) },
    { label = (type(locale) == 'function' and locale('security_alerts.s_e54e620409a7') or 'Contratos aceitos/rejeitados'), value = ('%d/%d'):format(tonumber(contracts.accepted) or 0, tonumber(contracts.rejected) or 0) },
    { label = (type(locale) == 'function' and locale('security_alerts.s_be5183dedcc3') or 'Correlacoes em memoria'), value = tostring(correlation.entries or 0) },
    { label = (type(locale) == 'function' and locale('security_alerts.s_cf9ebefea537') or 'LAB ativos'), value = tostring(labStatus.active or 0) },
    { label = (type(locale) == 'function' and locale('security_alerts.s_bc762fbda50b') or 'Persistencia de incidentes'), value = incidentPersistence.enabled == true and (type(locale) == 'function' and locale('garage.s_1b9e540e4a17') or 'ativa') or (type(locale) == 'function' and locale('security_alerts.s_b9b94cbb17d9') or 'desligada') },
    { label = (type(locale) == 'function' and locale('security_alerts.s_30fb8d861c75') or 'Cancelamento de dano'), value = guard.enforcementActive and (type(locale) == 'function' and locale('security_alerts.s_9048449ecefc') or 'ATIVO') or (type(locale) == 'function' and locale('security_alerts.s_ee06676faab4') or 'desligado') },
    { label = 'Autokick', value = guard.autoKick and (type(locale) == 'function' and locale('security_alerts.s_9048449ecefc') or 'ATIVO') or (type(locale) == 'function' and locale('security_alerts.s_ee06676faab4') or 'desligado') },
    { label = 'Autoban', value = guard.autoBan and (type(locale) == 'function' and locale('security_alerts.s_9048449ecefc') or 'ATIVO') or (type(locale) == 'function' and locale('security_alerts.s_ee06676faab4') or 'desligado') },
    { label = (type(locale) == 'function' and locale('security_alerts.s_3a4424a55acd') or 'Maior risco de incidente'), value = topPlayer and (('%s (%d)'):format(tostring(topPlayer.playerName or topPlayer.citizenid or '-'), tonumber(topPlayer.riskScore) or 0)) or (type(locale) == 'function' and locale('security_alerts.s_006e5be5b19e') or 'nenhum') }
  }
  local options = {
    {
      title = CurrentAvailable and (type(locale) == 'function' and locale('security_alerts.s_c42733df0bc0') or 'Resumo operacional') or (type(locale) == 'function' and locale('security_alerts.s_93d468b39c76') or 'Central indisponivel'),
      description = CurrentAvailable
        and ((type(locale) == 'function' and locale('security_alerts.s_01d6ee7e7e6b') or 'Modo %s | politica: %s')):format(tostring(guard.mode or 'observe'), policyLabel)
        or (type(locale) == 'function' and locale('security_alerts.s_5b68e018ed8f') or 'O mz_banguard nao esta iniciado ou o contrato de alertas nao respondeu.'),
      icon = CurrentAvailable and 'shield' or 'plug-circle-xmark',
      metadata = summaryMetadata,
      readOnly = true
    }
  }

  if CurrentAvailable then
    options[#options + 1] = bind({ title = (type(locale) == 'function' and locale('security_alerts.s_d72022d91fed') or 'Atualizar dados'), description = (type(locale) == 'function' and locale('security_alerts.s_4d8d9ea3ddf2') or 'Reconsulta resumo e estado no servidor.'), icon = 'rotate' }, 'refresh')
    if topPlayer then
      options[#options + 1] = bind({
        title = (type(locale) == 'function' and locale('security_alerts.s_a30abd4e4917') or 'Jogador com maior risco'),
        description = ((type(locale) == 'function' and locale('security_alerts.s_ddd7e2a7d4ee') or '%s | risco de incidente %d | %d ocorrencia(s)')):format(
          tostring(topPlayer.playerName or topPlayer.citizenid or '-'), tonumber(topPlayer.riskScore) or 0, tonumber(topPlayer.occurrences) or 0
        ),
        icon = 'user-shield'
      }, 'filter', { player = tostring(topPlayer.citizenid or topPlayer.playerName or '') })
    end
    for _, filter in ipairs({ 'all', 'open', 'acknowledged', 'critical', 'weapon', 'entity', 'movement', 'camera', 'player_state', 'event', 'aim', 'crash', 'runtime', 'canary' }) do
      options[#options + 1] = bind({
        title = FILTER_LABELS[filter],
        description = filter == 'all' and (type(locale) == 'function' and locale('security_alerts.s_34bf27aced0d') or 'Lista os incidentes mais recentes.') or ((type(locale) == 'function' and locale('security_alerts.s_d67861a09f87') or 'Filtrar por ') .. FILTER_LABELS[filter]:lower()),
        icon = filter == 'critical' and 'triangle-exclamation' or 'filter'
      }, 'filter', { filter = filter })
    end
    options[#options + 1] = bind({ title = (type(locale) == 'function' and locale('security_alerts.s_66b0fe42f266') or 'Buscar jogador'), description = (type(locale) == 'function' and locale('security_alerts.s_5d57e61fb3ee') or 'Nome, citizenid ou source atual.'), icon = 'user-magnifying-glass' }, 'playerFilter')
  end

  MZAdminUI.RegisterContext({
    id = MENU_ID,
    menu = CurrentParent,
    title = (type(locale) == 'function' and locale('security_alerts.s_a67d9f4d1a5d') or 'Central de Alertas'),
    subtitle = (type(locale) == 'function' and locale('security_alerts.s_5f025d32c911') or 'Observacao server-side, triagem e acoes auditadas'),
    badge = ((type(locale) == 'function' and locale('security_alerts.s_0ea70b762e9e') or 'ALERTAS %d')):format(tonumber(summary.unacknowledged) or 0),
    options = options
  })
  return true
end

function MZAdminSecurityAlerts.GetRootOption()
  if CurrentActions.securityAlertsView ~= true then return nil end
  local summary = CurrentSummary and CurrentSummary.summary or {}
  local count = tonumber(summary.unacknowledged) or 0
  return {
    title = CurrentAvailable and ((type(locale) == 'function' and locale('security_alerts.s_2fcfca534865') or 'Segurança - Central de Alertas (%d)')):format(count) or (type(locale) == 'function' and locale('security_alerts.s_9b3f44f2490c') or 'Segurança - Central indisponível'),
    description = CurrentAvailable and (type(locale) == 'function' and locale('security_alerts.s_41c4a2a9c707') or 'Resumo, incidentes, filtros e acoes de investigacao.') or (type(locale) == 'function' and locale('security_alerts.s_85171022c302') or 'Consulte o estado do mz_banguard.'),
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
    local values = MZAdminUI.InputDialog((type(locale) == 'function' and locale('security_alerts.s_10fd6fc07a49') or 'Buscar incidentes por jogador'), {
      { type = 'input', label = (type(locale) == 'function' and locale('security_alerts.s_8f33b060fef4') or 'Nome, citizenid ou source'), required = true, min = 1, max = 64 }
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
    notify((type(locale) == 'function' and locale('security_alerts.s_1a1f731dca55') or 'ID do incidente: ') .. id, 'success')
  elseif action == 'ack' then
    if request('securityIncidentAcknowledge', payload.id) then openDetails(payload.id, false) end
  elseif action == 'note' then
    local values = MZAdminUI.InputDialog((type(locale) == 'function' and locale('security_alerts.s_b2a3cc3a8135') or 'Adicionar nota ao incidente'), {
      { type = 'textarea', label = (type(locale) == 'function' and locale('security_alerts.s_1a6b7be7e5a3') or 'Nota'), required = true, min = 3, max = 500 }
    }, { allowCancel = true })
    local note = values and trim(values[1]) or ''
    if #note >= 3 and request('securityIncidentNote', payload.id, note) then openDetails(payload.id, false) end
  elseif action == 'status' then
    if request('securityIncidentStatus', payload.id, payload.status) then openDetails(payload.id, false) end
  elseif action == 'export' then
    local exported = request('securityIncidentExport', payload.id, payload.format)
    if exported and type(exported.content) == 'string' then
      if lib and type(lib.setClipboard) == 'function' then lib.setClipboard(exported.content) end
      notify(((type(locale) == 'function' and locale('security_alerts.s_14aba3103da6') or 'Evidencia sanitizada copiada: %s')):format(tostring(exported.filename or 'evidence')), 'success')
    end
  elseif action == 'lab' and CurrentActions.securityAlertLab then
    local values = MZAdminUI.InputDialog(payload.enabled and (type(locale) == 'function' and locale('security_alerts.s_f0f67342564c') or 'Ativar LAB') or (type(locale) == 'function' and locale('security_alerts.s_f7bf7ca93c0e') or 'Desativar LAB'), {
      { type = 'textarea', label = (type(locale) == 'function' and locale('security_alerts.s_a9f39c41d841') or 'Motivo auditavel'), required = true, min = 3, max = 256 }
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
