local ADDON_NAME, ES = ...
local L = ES.L

---------------------------------------------------------------------------
-- Novedades: al entrar con una versión nueva del addon sale una ventana con lo nuevo
-- de las versiones que no has visto. Una vez por versión: se guarda la última vista
-- en ES.db.whatsNewSeen (de la cuenta, no del personaje).
--   * Instalación nueva (sin nada guardado): no sale; se apunta la versión actual.
--   * Versión sin notas en ES.WHATS_NEW: no sale; se apunta igual.
-- Para escribir las notas: /cj whatsnew [versión] la abre cuando quieras, sin tocar lo
-- visto. Solo en tu copia: el comando está en DevTools.lua, que no se publica.
--
-- Cómo añadir una versión: una entrada nueva ARRIBA en ES.WHATS_NEW, con la misma
-- versión que ## Version del .toc. Los textos van en español y su traducción en
-- Locales/enUS.lua (como el resto del addon).
---------------------------------------------------------------------------

-- Lo nuevo de cada versión, de la más nueva a la más antigua. `items`: { icon, title, text }
ES.WHATS_NEW = {
  {
    version = "0.55.1",
    items = {
      { icon = "Interface\\Icons\\INV_Chest_Chain_05", title = "El equipo imprescindible entra en la ruta",
        text = "Las piezas que eliges se fabrican en la ruta aunque aún no sepas la receta (también un pergamino de botín) y aunque la ruta ya esté empezada. La fila de conseguir la receta marca el camino." },
      { icon = "Interface\\Icons\\INV_Misc_Book_09", title = "Ahora en alemán y francés",
        text = "Textos, recetas y objetos en alemán y francés, con los nombres del juego. Se cambia con el selector de idioma de arriba. Si ves una traducción mejorable, dínoslo en Discord." },
      { icon = "Interface\\Icons\\INV_Misc_Gear_01", title = "Cada ventana, con su propia opción",
        text = "Las ventanas que salen solas junto al vendedor, la Casa de Subastas y la profesión tienen un engranaje que abre las opciones. La lista de compra y la de vender en la AH ya se quitan por separado." },
      { icon = "Interface\\Icons\\INV_Misc_Coin_01", title = "Confirmar antes de anunciar",
        text = "Al anunciar más de una unidad de golpe se pregunta antes cuántas y a qué precio. Así un clic sin querer no anuncia un montón. Se puede desactivar." },
      { icon = "Interface\\Icons\\INV_Misc_PocketWatch_01", title = "La AH sin tirones",
        text = "Al acabar un escaneo (el tuyo o el de otro addon, como Auctionator) los precios se guardan poco a poco y el juego ya no se congela. Nueva opción para no leer los escaneos de otros addons." },
      { icon = "Interface\\Icons\\Trade_Alchemy", title = "Rutas sin enfriamientos",
        text = "Las transmutaciones y el Mooncloth tienen enfriamiento: la ruta ya no pide 186 transmutaciones seguidas. Como mucho las usa para un punto." },
      { icon = "Interface\\Icons\\INV_Misc_Bag_10", title = "Lista de compra en su sitio",
        text = "Al cerrar la ventana de vender en la AH, la lista de compra se pega a la AH y no deja un hueco." },
    },
  },
}

local function AddonVersion()
  local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  return get and get(ADDON_NAME, "Version") or nil
end
ES.AddonVersion = AddonVersion

-- Compara "0.47.0" con "0.48.0" número a número: -1, 0 o 1 (lo que no es número, 0)
local function CompareVersions(a, b)
  local pa, pb = {}, {}
  for n in tostring(a or ""):gmatch("%d+") do pa[#pa + 1] = tonumber(n) end
  for n in tostring(b or ""):gmatch("%d+") do pb[#pb + 1] = tonumber(n) end
  for i = 1, math.max(#pa, #pb) do
    local x, y = pa[i] or 0, pb[i] or 0
    if x ~= y then return x < y and -1 or 1 end
  end
  return 0
end
ES.CompareVersions = CompareVersions

-- Notas de las versiones posteriores a `seen` hasta `current` (como mucho MAX_SHOWN, de
-- la más nueva a la más antigua). Sin `seen`: solo la de `current`
local MAX_SHOWN = 3
function ES:WhatsNewSince(seen, current)
  local out = {}
  for _, v in ipairs(ES.WHATS_NEW) do
    local released = CompareVersions(v.version, current) <= 0 -- (no las de una versión aún sin publicar)
    local unseen
    if seen then unseen = CompareVersions(v.version, seen) > 0
    else unseen = CompareVersions(v.version, current) == 0 end
    if released and unseen then
      out[#out + 1] = v
      if #out >= MAX_SHOWN then break end
    end
  end
  return out
end

---------------------------------------------------------------------------
-- Ventana
---------------------------------------------------------------------------
local WIDTH, HEIGHT = 540, 500
local GOLD = { 0.96, 0.79, 0.25 }
local frame

local function CreateWindow()
  local UI = ES.UI
  local BROWN = UI.BROWN
  local f = CreateFrame("Frame", "CraftersJournalWhatsNew", UIParent, "BackdropTemplate")
  f:SetSize(WIDTH, HEIGHT)
  f:SetPoint("CENTER", 0, 40)
  -- El marco de la ventana principal: roca oscura con borde de diálogo
  f:SetBackdrop({
    bgFile = "Interface\\FrameGeneral\\UI-Background-Rock",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 16, edgeSize = 24,
    insets = { left = 6, right = 6, top = 6, bottom = 6 },
  })
  f:SetBackdropColor(0.045, 0.042, 0.037, 0.99)
  f:SetFrameStrata("DIALOG")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  tinsert(UISpecialFrames, "CraftersJournalWhatsNew") -- Escape la cierra
  f:Hide()

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -2, -2)
  close:SetScript("OnClick", function() f:Hide() end)

  -- Cabecera: icono del addon, "Novedades" y la versión (la tarjeta de las pestañas)
  local head = UI.Panel(f, BROWN.card[1], BROWN.card[2], BROWN.card[3], BROWN.card[4])
  head:SetPoint("TOPLEFT", 14, -30)
  head:SetPoint("TOPRIGHT", -14, -30)
  head:SetHeight(70)
  f.icon = head:CreateTexture(nil, "ARTWORK")
  f.icon:SetSize(46, 46)
  f.icon:SetPoint("LEFT", 12, 0)
  f.icon:SetTexture("Interface\\Icons\\Trade_BlackSmithing")
  f.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  f.title = UI.Label(head, "", "GameFontNormalHuge")
  f.title:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 12, 0)
  f.title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
  f.sub = UI.Label(head, "", "GameFontHighlightSmall")
  f.sub:SetPoint("BOTTOMLEFT", f.icon, "BOTTOMRIGHT", 12, 2)
  f.sub:SetPoint("RIGHT", -12, 0)
  f.sub:SetJustifyH("LEFT")

  -- Lista con scroll (rueda e indicador, como las pestañas)
  local list = UI.Panel(f, BROWN.list[1], BROWN.list[2], BROWN.list[3], BROWN.list[4])
  list:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -8)
  list:SetPoint("BOTTOMRIGHT", -14, 52)
  local scroll = UI.WheelScroll(list)
  scroll:SetPoint("TOPLEFT", 10, -10)
  scroll:SetPoint("BOTTOMRIGHT", -14, 10)
  f.content = CreateFrame("Frame", nil, scroll)
  f.content:SetSize(WIDTH - 28 - 24, 1)
  scroll:SetScrollChild(f.content)
  f.scroll = scroll
  f.indicator = UI.ScrollIndicator and UI.ScrollIndicator(scroll, f.content)
  f.lines = {}

  f.ok = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.ok:SetSize(160, 26)
  f.ok:SetPoint("BOTTOM", 0, 16)
  f.ok:SetScript("OnClick", function() f:Hide() end)
  f.devTag = UI.Label(f, "", "GameFontDisableSmall")
  f.devTag:SetPoint("BOTTOMLEFT", 18, 22)
  return f
end

-- Una línea de la lista (se reutilizan): cabecera de versión o novedad con icono
local function Line(f, i)
  local l = f.lines[i]
  if l then return l end
  l = CreateFrame("Frame", nil, f.content)
  l.bg = l:CreateTexture(nil, "BACKGROUND")
  l.bg:SetAllPoints()
  local R = ES.UI.BROWN.row
  l.bg:SetColorTexture(R[1], R[2], R[3], R[4])
  l.icon = l:CreateTexture(nil, "ARTWORK")
  l.icon:SetSize(32, 32)
  l.icon:SetPoint("TOPLEFT", 8, -8)
  l.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  l.title = ES.UI.Label(l, "", "GameFontNormal")
  l.title:SetJustifyH("LEFT")
  l.text = ES.UI.Label(l, "", "GameFontHighlightSmall")
  l.text:SetJustifyH("LEFT")
  if l.text.SetSpacing then l.text:SetSpacing(2) end
  f.lines[i] = l
  return l
end

local function Height(fs, cap)
  return math.min(tonumber(fs:GetStringHeight()) or 12, cap or 200)
end

-- Rellena la ventana con `notes` (de ES:WhatsNewSince) y la enseña. `dev`: vista de
-- desarrollo (lo dice abajo y no cuenta como vista)
function ES:ShowWhatsNew(notes, dev)
  if not notes or #notes == 0 then return end
  frame = frame or CreateWindow()
  local f = frame
  local width = f.content:GetWidth()
  f.title:SetText(L["Novedades"])
  f.sub:SetText(string.format(L["Crafter's Journal %s: esto es lo nuevo desde la última vez."], notes[1].version))
  f.ok:SetText(L["¡Entendido!"])
  f.devTag:SetText(dev and L["Vista de desarrollo: no cuenta como vista."] or "")
  local y, n = 0, 0
  for vi, v in ipairs(notes) do
    -- Cabecera de la versión (solo si hay más de una)
    if #notes > 1 then
      n = n + 1
      local l = Line(f, n)
      l:ClearAllPoints()
      l:SetPoint("TOPLEFT", 0, -y)
      l:SetWidth(width)
      l.bg:Hide()
      l.icon:Hide()
      l.text:SetText("")
      l.title:ClearAllPoints()
      l.title:SetPoint("BOTTOMLEFT", 2, 4)
      l.title:SetText(string.format(L["Versión %s"], v.version))
      l.title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
      l:SetHeight(vi == 1 and 20 or 28)
      l:Show()
      y = y + (vi == 1 and 20 or 28)
    end
    for _, it in ipairs(v.items) do
      n = n + 1
      local l = Line(f, n)
      l:ClearAllPoints()
      l:SetPoint("TOPLEFT", 0, -y)
      l:SetWidth(width)
      l.bg:Show()
      l.icon:Show()
      l.icon:SetTexture(it.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
      l.title:ClearAllPoints()
      l.title:SetPoint("TOPLEFT", l.icon, "TOPRIGHT", 10, -1)
      l.title:SetWidth(width - 60)
      l.title:SetText(L[it.title])
      l.title:SetTextColor(1, 0.82, 0)
      l.text:ClearAllPoints()
      l.text:SetPoint("TOPLEFT", l.title, "BOTTOMLEFT", 0, -4)
      l.text:SetWidth(width - 60)
      l.text:SetText(L[it.text])
      local h = math.max(48, 8 + Height(l.title, 30) + 4 + Height(l.text) + 10)
      l:SetHeight(h)
      l:Show()
      y = y + h + 6
    end
  end
  for k = n + 1, #f.lines do f.lines[k]:Hide() end
  f.content:SetHeight(math.max(1, y))
  f.scroll:SetVerticalScroll(0)
  if f.indicator and f.indicator.Update then f.indicator:Update() end
  f:Show()
end

-- Al entrar: si hay versión nueva con notas, la ventana (una vez por versión)
function ES:CheckWhatsNew()
  local db, current = self.db, AddonVersion()
  if not db or not current then return end
  local seen = db.whatsNewSeen
  if seen and CompareVersions(current, seen) <= 0 then return end
  -- Instalación nueva (ni un escaneo ni la ventana abierta nunca): no hay "novedades"
  -- para quien empieza. (Los datos del personaje no sirven: se crean al cargar)
  local fresh = not seen and not (db.scans and next(db.scans)) and not db.lastPage
  db.whatsNewSeen = current
  if fresh then return end
  self:ShowWhatsNew(self:WhatsNewSince(seen, current))
end

do
  local f = CreateFrame("Frame")
  ES.SafeRegister(f, "PLAYER_LOGIN")
  -- (un momento después de entrar: que no salga encima de la pantalla de carga)
  f:SetScript("OnEvent", function() C_Timer.After(3, function() ES:CheckWhatsNew() end) end)
end

ES.WhatsNewFrame = function() return frame end -- para pruebas
