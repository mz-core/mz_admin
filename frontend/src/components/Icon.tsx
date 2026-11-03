import type { SVGProps } from "react"

// The icon set is the existing MZ Admin catalogue. Keeping the exact paths
// preserves the visual contract while the React layer replaces the renderer.
const icons: Record<string, string> = {
  home: '<path d="m3 10.5 9-7 9 7"/><path d="M5 10v10h14V10"/><path d="M9 20v-6h6v6"/>',
  house: '<path d="m3 10.5 9-7 9 7"/><path d="M5 10v10h14V10"/><path d="M9 20v-6h6v6"/>',
  plus: '<path d="M12 5v14"/><path d="M5 12h14"/>',
  edit: '<path d="M12 20h9"/><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4Z"/>',
  search: '<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>',
  settings: '<path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.38a2 2 0 0 0-.73-2.73l-.15-.09a2 2 0 0 1-1-1.74v-.51a2 2 0 0 1 1-1.72l.15-.1a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2Z"/><circle cx="12" cy="12" r="3"/>',
  garage: '<path d="M3 21V9l9-5 9 5v12"/><path d="M7 21v-8h10v8"/><path d="M9 17h6"/>',
  car: '<path d="M7 17h10"/><path d="M5 17l1.5-6h11L19 17"/><circle cx="7" cy="17" r="2"/><circle cx="17" cy="17" r="2"/>',
  key: '<circle cx="7.5" cy="14.5" r="3.5"/><path d="M10 12 21 1"/><path d="m16 6 2 2"/><path d="m18 4 2 2"/>',
  eye: '<path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12Z"/><circle cx="12" cy="12" r="3"/>',
  info: '<circle cx="12" cy="12" r="10"/><path d="M12 16v-4"/><path d="M12 8h.01"/>',
  x: '<path d="M18 6 6 18"/><path d="m6 6 12 12"/>',
  check: '<path d="m20 6-11 11-5-5"/>',
  "circle-check": '<circle cx="12" cy="12" r="10"/><path d="m9 12 2 2 4-5"/>',
  warning: '<path d="m12 3 10 18H2L12 3Z"/><path d="M12 9v5"/><path d="M12 17h.01"/>',
  archive: '<path d="M21 8v13H3V8"/><path d="M1 3h22v5H1z"/><path d="M10 12h4"/>',
  refresh: '<path d="M21 12a9 9 0 0 1-15.5 6.3L3 16"/><path d="M3 21v-5h5"/><path d="M3 12a9 9 0 0 1 15.5-6.3L21 8"/><path d="M21 3v5h-5"/>',
  box: '<path d="m21 8-9-5-9 5 9 5 9-5Z"/><path d="M3 8v8l9 5 9-5V8"/><path d="M12 13v8"/>',
  shirt: '<path d="M20.4 7.2 16 4H8L3.6 7.2 6 11l2-1v10h8V10l2 1 2.4-3.8Z"/>',
  door: '<path d="M4 21h16"/><path d="M6 21V4h10v17"/><path d="M13 12h.01"/>',
  building: '<path d="M3 21h18"/><path d="M5 21V7l8-4v18"/><path d="M19 21V11l-6-4"/><path d="M9 9h.01"/><path d="M9 13h.01"/><path d="M9 17h.01"/>',
  users: '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>',
  power: '<path d="M12 2v10"/><path d="M18.4 6.6a9 9 0 1 1-12.77.04"/>',
  lock: '<rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>',
  unlock: '<rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 9.9-1"/>',
  "map-pin": '<path d="M20 10c0 6-8 12-8 12S4 16 4 10a8 8 0 1 1 16 0Z"/><circle cx="12" cy="10" r="3"/>',
  server: '<rect x="3" y="4" width="18" height="8" rx="2"/><rect x="3" y="12" width="18" height="8" rx="2"/><path d="M7 8h.01"/><path d="M7 16h.01"/>',
  bell: '<path d="M18 8a6 6 0 1 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9"/><path d="M10 21h4"/>',
  keyboard: '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M7 9h.01M11 9h.01M15 9h.01M19 9h.01M7 13h.01M11 13h.01M15 13h.01M19 13h.01M8 17h8"/>',
  layers: '<path d="m12 2 10 6-10 6L2 8l10-6Z"/><path d="m2 12 10 6 10-6"/><path d="m2 16 10 6 10-6"/>',
  "arrow-left": '<path d="m12 19-7-7 7-7"/><path d="M19 12H5"/>',
  "arrow-right": '<path d="m12 5 7 7-7 7"/><path d="M5 12h14"/>',
  "arrow-up": '<path d="m18 15-6-6-6 6"/>',
  "arrow-down": '<path d="m6 9 6 6 6-6"/>',
  wallet: '<path d="M20 7V5a2 2 0 0 0-2-2H5a3 3 0 0 0 0 6h16v10a2 2 0 0 1-2 2H5a3 3 0 0 1-3-3V6"/><path d="M16 13h2"/>',
  target: '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1"/>',
  "user-search": '<circle cx="10" cy="8" r="4"/><path d="M3 21v-2a6 6 0 0 1 6-6h2"/><circle cx="17" cy="17" r="3"/><path d="m19.5 19.5 2 2"/>',
  history: '<path d="M3 12a9 9 0 1 0 3-6.7L3 8"/><path d="M3 3v5h5"/><path d="M12 7v5l3 2"/>',
  chevron: '<path d="m9 18 6-6-6-6"/>',
  menu: '<path d="M4 6h16"/><path d="M4 12h16"/><path d="M4 18h16"/>',
  shield: '<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10Z"/>',
  skull: '<circle cx="12" cy="10" r="7"/><path d="M8 16v4h8v-4"/><path d="M9 10h.01M15 10h.01"/><path d="m10 14 2-1 2 1"/>',
  briefcase: '<rect x="3" y="7" width="18" height="13" rx="2"/><path d="M8 7V5a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/><path d="M3 12h18"/><path d="M10 12v2h4v-2"/>',
  landmark: '<path d="m3 10 9-6 9 6"/><path d="M5 10h14"/><path d="M7 10v8M12 10v8M17 10v8"/><path d="M4 18h16M2 22h20"/>',
  crown: '<path d="m3 7 4 5 5-8 5 8 4-5-2 12H5L3 7Z"/><path d="M5 19h14"/>',
  calendar: '<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M16 3v4M8 3v4M3 11h18"/>',
  user: '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
  trash: '<path d="M3 6h18"/><path d="M8 6V4h8v2"/><path d="m19 6-1 15H6L5 6"/><path d="M10 11v6M14 11v6"/>',
  list: '<path d="M8 6h13M8 12h13M8 18h13"/><path d="M3 6h.01M3 12h.01M3 18h.01"/>',
  clipboard: '<rect x="5" y="4" width="14" height="17" rx="2"/><path d="M9 4V2h6v2"/><path d="M9 10h6M9 14h6"/>',
  chart: '<path d="M4 20V10M10 20V4M16 20v-7M22 20H2"/>',
  globe: '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18"/>',
  bolt: '<path d="M13 2 3 14h7l-1 8 10-12h-7l1-8Z"/>',
  ban: '<circle cx="12" cy="12" r="10"/><path d="m5 5 14 14"/>',
}

const iconAliases: Record<string, string> = {
  binoculars: "eye",
  "box-open": "box",
  "building-shield": "building",
  "car-side": "car",
  "chart-column": "chart",
  "circle-info": "info",
  "clipboard-list": "clipboard",
  clock: "history",
  "clock-rotate-left": "history",
  copy: "layers",
  couch: "house",
  crosshairs: "target",
  cube: "box",
  cubes: "layers",
  database: "server",
  "door-closed": "door",
  "door-open": "door",
  "earth-americas": "globe",
  "eye-slash": "eye",
  filter: "search",
  "filter-circle-xmark": "search",
  fingerprint: "target",
  "floppy-disk": "archive",
  "heart-pulse": "circle-check",
  "id-card": "user",
  inbox: "archive",
  "kit-medical": "plus",
  "layer-group": "layers",
  link: "key",
  "link-slash": "key",
  "list-check": "circle-check",
  "location-dot": "map-pin",
  "magnifying-glass": "search",
  "map-location-dot": "map-pin",
  message: "bell",
  "money-bill": "wallet",
  "money-check-dollar": "wallet",
  "note-sticky": "edit",
  pen: "edit",
  "pen-ruler": "edit",
  "pen-to-square": "edit",
  "people-arrows-left-right": "users",
  "person-flying": "target",
  "person-walking-arrow-right": "arrow-right",
  "power-off": "power",
  "ranking-star": "crown",
  rotate: "refresh",
  "rotate-left": "refresh",
  route: "map-pin",
  "ruler-combined": "edit",
  "screwdriver-wrench": "settings",
  "shield-circle-check": "shield",
  "shield-halved": "shield",
  "shield-virus": "shield",
  sliders: "settings",
  "square-parking": "garage",
  timeline: "history",
  "triangle-exclamation": "warning",
  unlock: "unlock",
  "user-check": "circle-check",
  "user-lock": "lock",
  "user-magnifying-glass": "user-search",
  "user-plus": "plus",
  "user-shield": "shield",
  "user-xmark": "x",
  "users-gear": "users",
  "users-slash": "users",
  warehouse: "garage",
  xmark: "x",
}

type IconProps = Omit<SVGProps<SVGSVGElement>, "name"> & {
  name?: string
}

export function Icon({ name, ...props }: IconProps) {
  const requested = String(name || "menu").toLowerCase()
  const key = iconAliases[requested] || requested
  const body = icons[key] || icons.menu

  return (
    <svg
      aria-hidden="true"
      focusable="false"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={2}
      strokeLinecap="round"
      strokeLinejoin="round"
      {...props}
      dangerouslySetInnerHTML={{ __html: body }}
    />
  )
}
