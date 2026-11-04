MZAdminPlayerSelector = MZAdminPlayerSelector or {}

function MZAdminPlayerSelector.Select(options)
  options = type(options) == 'table' and options or {}
  if type(MZAdminUI) ~= 'table' then return nil, 'admin_ui_unavailable' end
  local filters = options.allowOffline == false and { 'online' } or { 'all', 'online', 'offline' }
  local selected, err = MZAdminUI.PlayerSelector({
    title = options.title or (type(locale) == 'function' and locale('selector.title') or 'Selecionar jogador'),
    subtitle = options.subtitle or (type(locale) == 'function' and locale('selector.subtitle') or 'Online agora; pesquise para localizar Characters offline.'),
    brand = 'MZ Admin',
    filters = filters,
    defaultFilter = options.allowOffline == false and 'online' or 'all',
    pageSize = 25,
    minimumOfflineSearch = 2,
    searchPlaceholder = (type(locale) == 'function' and locale('selector.search') or 'Nome, Character, citizenid ou source...'),
    provider = 'SearchPlayersForSelector'
  })
  if err then
    MZAdminUI.Notify((type(locale) == 'function' and locale('selector.unavailable') or 'Nao foi possivel abrir a selecao de jogadores.'), 'error')
  end
  return selected, err
end

exports('SearchPlayersForSelector', function(query, filter, page, pageSize)
  return MZAdminClient.SearchPlayers(query, filter, page, pageSize)
end)
