local _, ES = ...
local L = ES.L

---------------------------------------------------------------------------
-- Opciones del addon, en las opciones del juego (Opciones > AddOns > Crafter's
-- Journal) y con /cj opciones: si salen solas las ventanas junto al vendedor y junto
-- a la Casa de Subastas, y si se propone vender tu equipo (ligado o en un conjunto).
--   ES.db.protectGear      = true: tu equipo (ligado o en un conjunto) no se propone
--                            vender (InventoryUI.lua). Por defecto no: se propone todo
--   ES.db.noChatAlerts     = true: sin los avisos del chat tras un escaneo (recetas
--                            de botín en la AH, ruta que cuesta más con precios nuevos)
--   ES.db.minimap.hide     = true: sin botón del minimapa (LibDBIcon)
--   ES.db.noVendorWindow   = true: no sale la ventana junto al vendedor
--   ES.db.noCraftWindow    = true: no sale la ventana de Ganar dinero junto a la
--                            ventana de una profesión (CraftWindowUI.lua)
--   ES.db.noAuctionWindows = true: no salen solas las de junto a la AH (lista de
--                            compra y vender en la AH); el botón de la AH sigue
--                            abriendo la lista de compra a mano
--   ES.db.auctionSellWindow = true: sale la ventana de vender junto a la AH
--                            (AuctionSellUI.lua). Por defecto no: un clic sin
--                            querer anunciaba lo que llevabas (CurseForge)
--   ES.db.sellAnyKind      = true: se propone vender también consumibles, objetos de
--                            misión, varios y lo recién comprado (InventoryUI.lua)
--   ES.db.scrollAlerts     = true: tras un escaneo, aviso en el chat de recetas de
--                            botín que te faltan y están en la AH (Collection.lua).
--                            Por defecto no
--   ES.db.noFollowScans    = true: no se lee el escaneo completo que pide otro addon
--                            (Scanner:OnForeignScan)
--   ES.db.noAuctionator    = true: no se usan los precios de Auctionator
--                            (AuctionatorPrices.lua)
---------------------------------------------------------------------------

function ES:VendorWindowOn() return not (self.db and self.db.noVendorWindow) end
function ES:AuctionWindowsOn() return not (self.db and self.db.noAuctionWindows) end
function ES:AuctionSellWindowOn() return self:AuctionWindowsOn() and self.db and self.db.auctionSellWindow == true end
function ES:CraftWindowOn() return not (self.db and self.db.noCraftWindow) end

-- Cambia una opción (on: la casilla marcada) y lo aplica al momento: la pestaña
-- Inventario y las ventanas del vendedor y la AH, si están abiertos
function ES:SetOption(key, on)
  self.db[key] = (not on) or nil
  self:ApplyOptions(key, on)
end

function ES:ApplyOptions(key, on)
  if self.RenderInventory then self:RenderInventory() end
  if self.VendorShop and self.VendorShop.Refresh then self.VendorShop:Refresh() end
  if self.AuctionSell and self.AuctionSell.Refresh then self.AuctionSell:Refresh() end
  if self.CraftWindow and self.CraftWindow.Refresh then self.CraftWindow:Refresh() end
  -- (la lista de compra: desactivada se quita; activada sale la próxima vez que
  -- abras la AH, o ya con el botón de encima de la AH)
  local mini = self.ShoppingMini and self.ShoppingMini()
  if key == "noAuctionWindows" and not on and mini then mini:Hide() end
end

local OPTIONS = {
  { key = "noVendorWindow", label = "Ventana junto al vendedor",
    desc = "Al abrir un vendedor: lo que te falta de la lista de compra y lo que puedes venderle, con los botones Comprar todo y Vender todo." },
  { key = "noAuctionWindows", label = "Ventanas junto a la Casa de Subastas",
    desc = "Al abrir la AH: tu lista de compra (y, si la activas abajo, lo que puedes vender en la AH). Desactivadas, la lista de compra se sigue pudiendo abrir con el botón de encima de la AH." },
  -- (por defecto desactivada: anunciar desde ahí lo pides tú, no sale sola)
  { key = "auctionSellWindow", label = "Ventana de vender junto a la AH",
    desc = "Al abrir la AH, una ventana con lo que la pestaña Inventario dice que vendas allí. Para anunciar hay que pulsar dos veces la misma fila: un clic sin querer no anuncia nada.",
    get = function() return ES.db.auctionSellWindow == true end,
    set = function(on) ES.db.auctionSellWindow = on or nil ES:ApplyOptions("auctionSellWindow", on) end },
  { key = "sellAnyKind", label = "No proponer vender consumibles ni lo recién comprado",
    desc = "Activado, no se proponen vender (ni en la AH ni al vendedor) los consumibles, objetos de misión, componentes, munición y objetos varios (órdenes, fichas), salvo lo gris y lo que fabricas tú, ni lo que compraste en los últimos 3 días. Desactivado, se propone todo." },
  { key = "noCraftWindow", label = "Ventana junto a la profesión",
    desc = "Al abrir una profesión: lo que la pestaña Ganar dinero propone fabricar de esa profesión. Clic en una fila para fabricarlo." },
  -- (por defecto desactivada: se propone todo y lo tuyo lo apartas con clic derecho)
  { key = "protectGear", label = "No vender tu equipo",
    desc = "Activado, el equipo ligado a ti (tu otro equipo, lo de las misiones) y el de los conjuntos del gestor de equipo no se propone vender (ni Vender todo lo vende); los verdes sin ligar de botín, lo que fabricas y lo gris, sí. Desactivado, se propone todo: lo que quieras guardar, clic derecho y no se vende nunca.",
    get = function() return ES.db.protectGear == true end,
    set = function(on) ES.db.protectGear = on or nil ES:ApplyOptions("protectGear", on) end },
  { key = "noChatAlerts", label = "Avisos en el chat",
    desc = "Tras un escaneo: si tu ruta empezada cuesta bastante más con los precios nuevos. Desactivados, la ruta lo sigue diciendo en su línea de estado." },
  -- (por defecto desactivado: salía en cada visita a la AH con recetas que no buscabas)
  { key = "scrollAlerts", label = "Avisar de recetas de botín en la AH",
    desc = "Tras un escaneo, el chat dice qué recetas de botín que te faltan (y que ya puedes aprender) están en la AH. Las de tus rutas ya salen en la ruta y en la lista de compra.",
    get = function() return ES.db.scrollAlerts == true end,
    set = function(on) ES.db.scrollAlerts = on or nil end },
  { key = "noFollowScans", label = "Leer los escaneos de otros addons",
    desc = "Cuando otro addon escanea toda la AH, Crafter's Journal lee esos mismos datos (el servidor solo deja uno cada 15 min). Leerlos puede congelar el juego unos segundos al abrir la AH: desactivado, solo escaneas con el botón Escanear. Con precios de hace menos de 30 min no se leen." },
  { key = "noAuctionator", label = "Usar los precios de Auctionator",
    desc = "Con Auctionator instalado, Crafter's Journal toma sus precios cuando son más nuevos que tu último escaneo (sin escanear otra vez la AH), y cuando Auctionator escanea toda la AH no la vuelve a leer: usa lo que Auctionator ya guardó." },
  -- (se guarda en ES.db.minimap.hide, el sitio de LibDBIcon: también /cj minimap)
  { key = "minimap", label = "Botón del minimapa", desc = "El botón de Crafter's Journal junto al minimapa. También con /cj minimap.",
    get = function() return not (ES.db.minimap and ES.db.minimap.hide) end,
    set = function(on) ES:SetMinimapShown(on) end },
}

local panel
local function CreatePanel()
  local p = CreateFrame("Frame", "CraftersJournalOptionsPanel", UIParent)
  p.name = "Crafter's Journal"
  p:Hide()
  p.title = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  p.title:SetPoint("TOPLEFT", 16, -16)
  p.title:SetText("Crafter's Journal")
  p.checks = {}
  -- (con la rueda del ratón: ya no caben todas en el alto de las opciones del juego)
  local scroll = ES.UI and ES.UI.WheelScroll and ES.UI.WheelScroll(p) or CreateFrame("ScrollFrame", nil, p)
  scroll:SetPoint("TOPLEFT", 0, -50)
  scroll:SetPoint("BOTTOMRIGHT", -8, 8)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(600, 1)
  scroll:SetScrollChild(content)
  p.content = content
  local y = -6
  for i, o in ipairs(OPTIONS) do
    local cb = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    cb:SetSize(26, 26)
    cb:SetPoint("TOPLEFT", 16, y)
    cb.label = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    cb.label:SetPoint("LEFT", cb, "RIGHT", 4, 1)
    cb.desc = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    cb.desc:SetPoint("TOPLEFT", cb.label, "BOTTOMLEFT", 0, -4)
    cb.desc:SetWidth(520)
    cb.desc:SetJustifyH("LEFT")
    cb.option = o
    cb:SetScript("OnClick", function(self)
      local on = self:GetChecked() and true or false
      if o.set then o.set(on) else ES:SetOption(o.key, on) end
    end)
    p.checks[i] = cb
    y = y - 70
  end
  -- Textos y casillas al mostrarse: el idioma o las opciones pueden haber cambiado
  p:SetScript("OnShow", function(self)
    self.sub = self.sub or self:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.sub:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -6)
    self.sub:SetText(L["Ventanas, qué se propone vender, avisos, precios y botón del minimapa."])
    -- Cada casilla, debajo del texto de la anterior (cada texto ocupa lo suyo)
    local y = -6
    for _, cb in ipairs(self.checks) do
      cb.label:SetText(L[cb.option.label])
      cb.desc:SetText(L[cb.option.desc])
      cb:ClearAllPoints()
      cb:SetPoint("TOPLEFT", 16, y)
      local h = tonumber(cb.desc:GetStringHeight()) or 24
      y = y - 26 - math.max(12, math.min(h, 80)) - 14
      local o = cb.option
      if o.get then cb:SetChecked(o.get()) else cb:SetChecked(not ES.db[o.key]) end
    end
    self.content:SetHeight(-y + 10)
  end)
  -- Opciones del juego: la API nueva (Settings) o la de antes
  if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    local category = Settings.RegisterCanvasLayoutCategory(p, p.name)
    Settings.RegisterAddOnCategory(category)
    ES.optionsCategory = category
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(p)
  end
  return p
end

function ES:OptionsPanel()
  panel = panel or CreatePanel()
  return panel
end

function ES:OpenOptions()
  local p = self:OptionsPanel()
  if Settings and Settings.OpenToCategory and self.optionsCategory then
    local id = self.optionsCategory.GetID and self.optionsCategory:GetID() or self.optionsCategory.ID
    Settings.OpenToCategory(id)
  elseif InterfaceOptionsFrame_OpenToCategory then
    -- (la primera vez a veces abre la página general: se repite)
    InterfaceOptionsFrame_OpenToCategory(p)
    InterfaceOptionsFrame_OpenToCategory(p)
  else
    p:Show()
  end
end

-- Se registra al entrar (con ES.db ya cargada), para que salga en las opciones del juego
do
  local f = CreateFrame("Frame")
  ES.SafeRegister(f, "PLAYER_LOGIN")
  f:SetScript("OnEvent", function() if ES.db then ES:OptionsPanel() end end)
end
