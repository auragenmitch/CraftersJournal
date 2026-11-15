local _, ES = ...
local L = ES.L

---------------------------------------------------------------------------
-- Ventana del equipo imprescindible (clic derecho en su icono, arriba de la ruta):
-- tu especialización (la de tus talentos u otra), las piezas recomendadas con
-- cuántas quieres de cada una (- / +; 0 la quita de la ruta), las que añadas tú y
-- el resto de piezas de la profesión que puedes llevar (+ para añadirla). Cada
-- cambio recalcula la ruta. La lógica, en GearPicks.lua.
---------------------------------------------------------------------------

local WIDTH, ROW_H, MAX_H = 400, 34, 440
local GREY, BLUE, ORANGE, GOLD = "|cff999999", "|cff4da6ff", "|cffff9933", "|cffffd100"

local panel

local STATUS = ES.Localize({
  route = "en la ruta, a %d",
  grey = "ya no da puntos desde tu nivel",
  above = "por encima de tu objetivo",
  nolearn = "receta que no puedes conseguir ahora",
  dropped = "falta el precio de un material",
})

local function Recalculate()
  local page = panel and panel.page
  if page and ES.CalculatePlan then ES:CalculatePlan(page) end
end

local function SetQty(id, qty)
  ES.Gear:SetQty(panel.profKey, id, qty)
  Recalculate()
end

local function Row(i)
  local rows = panel.rows
  if rows[i] then return rows[i] end
  local row = CreateFrame("Button", nil, panel.content)
  row:SetSize(WIDTH - 24, ROW_H)
  local hl = row:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 0.82, 0.25, 0.08)
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(24, 24)
  row.icon:SetPoint("LEFT", 2, 0)
  row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 6, -1)
  row.name:SetPoint("RIGHT", row, "RIGHT", -78, 0)
  row.name:SetJustifyH("LEFT")
  row.name:SetWordWrap(false)
  row.sub = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  row.sub:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 6, 0)
  row.sub:SetPoint("RIGHT", row, "RIGHT", -78, 0)
  row.sub:SetJustifyH("LEFT")
  row.sub:SetWordWrap(false)
  row.plus = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
  row.plus:SetSize(22, 20)
  row.plus:SetPoint("RIGHT", -2, 0)
  row.plus:SetText("+")
  row.qty = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  row.qty:SetPoint("RIGHT", row.plus, "LEFT", -4, 0)
  row.qty:SetWidth(18)
  row.qty:SetJustifyH("CENTER")
  row.minus = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
  row.minus:SetSize(22, 20)
  row.minus:SetPoint("RIGHT", row.qty, "LEFT", -4, 0)
  row.minus:SetText("-")
  row.section = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  row.section:SetPoint("LEFT", 4, 0)
  row.section:SetPoint("RIGHT", -4, 0)
  row.section:SetJustifyH("LEFT")
  row:SetScript("OnLeave", function() GameTooltip:Hide() end)
  rows[i] = row
  return row
end

local function ItemRow(row, e, qty, status, recommended)
  row.recipeID = e.id
  row.section:SetText("")
  row.icon:Show()
  local name, texture = ES.UI.ItemLabel(e.item, e.r.name)
  row.icon:SetTexture(texture or 134400)
  row.name:SetText((qty > 0 and "" or GREY) .. tostring(name) .. (qty > 0 and "" or "|r"))
  local info = e.info or {}
  local parts = { string.format(L["nivel %d"], info.reqLevel or 0), string.format(L["habilidad %d"], e.r.train or e.r.t[1]) }
  if status then
    local text = STATUS[status.status] or ""
    if status.status == "route" then text = string.format(text, status.step.from) end
    parts[#parts + 1] = (status.status == "route" and BLUE or ORANGE) .. text .. "|r"
  elseif qty == 0 and recommended then
    parts[#parts + 1] = GREY .. L["quitada"] .. "|r"
  end
  row.sub:SetText(table.concat(parts, " · "))
  row.qty:SetText(qty > 0 and tostring(qty) or "")
  row.minus:SetShown(qty > 0)
  row.qty:Show()
  row.plus:Show()
  row.minus:SetScript("OnClick", function() SetQty(e.id, qty - 1) end)
  row.plus:SetScript("OnClick", function() SetQty(e.id, qty + 1) end)
  row:SetScript("OnClick", function() ES:OpenRecipe(e.id) end)
  row:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    if GameTooltip.SetItemByID then GameTooltip:SetItemByID(e.item) else GameTooltip:AddLine(tostring(name)) end
    GameTooltip:AddLine(" ")
    if recommended then
      GameTooltip:AddLine(L["Recomendada: azul, la puedes llevar y lleva las características de tu especialización."], 0.4, 0.7, 1, true)
    end
    GameTooltip:AddLine(L["- / +: cuántas fabricar para ti (0 la quita de la ruta). Clic: abrir la receta."], 0.5, 0.8, 1, true)
    GameTooltip:Show()
  end)
end

local function SectionRow(row, text, onClick)
  row.recipeID = nil
  row.section:SetText(GOLD .. text .. "|r")
  row.icon:Hide()
  row.name:SetText("")
  row.sub:SetText("")
  row.qty:Hide()
  row.minus:Hide()
  row.plus:Hide()
  row:SetScript("OnClick", onClick)
  row:SetScript("OnEnter", nil)
end

local function Render()
  if not (panel and panel:IsShown()) then return end
  local Gear, profKey = ES.Gear, panel.profKey
  local spec = Gear:Spec()
  local className = UnitClass and UnitClass("player") or "?"
  panel.specButton:SetText(spec and (spec.name .. (spec.auto and L[" (según tus talentos)"] or "")) or "?")
  panel.forText:SetText(string.format(L["Para tu %s, nivel %d:"], className, Gear.Level()))
  local c = Gear:Candidates(profKey)
  local over = ES.db.prof[profKey] and ES.db.prof[profKey].gearPicks or {}
  local byID = {}
  for _, g in ipairs(Gear:Status(profKey, panel.page and panel.page.plan)) do byID[g.pick.id] = g end
  local n, y = 0, 0
  local function Next()
    n = n + 1
    local row = Row(n)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 4, -y)
    row:Show()
    y = y + ROW_H
    return row
  end
  if not Gear:On(profKey) then
    SectionRow(Next(), ORANGE .. L["Desactivado: la ruta no incluye equipo. Actívalo con clic en su icono."] .. "|r")
  end
  SectionRow(Next(), L["Recomendadas para ti"])
  for _, e in ipairs(c.recommended) do
    local qty = over[e.id] or 1
    ItemRow(Next(), e, qty, qty > 0 and byID[e.id] or nil, true)
  end
  if #c.recommended == 0 then
    SectionRow(Next(), GREY .. L["Ninguna pieza azul de esta profesión le sirve ahora a tu personaje."] .. "|r")
  end
  local added = {}
  for _, e in ipairs(c.other) do if (over[e.id] or 0) > 0 then added[#added + 1] = e end end
  if #added > 0 then
    SectionRow(Next(), L["Añadidas por ti"])
    for _, e in ipairs(added) do ItemRow(Next(), e, over[e.id], byID[e.id], false) end
  end
  local rest = #c.other - #added
  SectionRow(Next(), string.format(panel.showOther and L["- Otras piezas que puedes llevar (%d)"] or L["+ Otras piezas que puedes llevar (%d)"], rest),
    function() panel.showOther = not panel.showOther Render() end)
  if panel.showOther then
    for _, e in ipairs(c.other) do
      if (over[e.id] or 0) == 0 then ItemRow(Next(), e, 0, nil, false) end
    end
  end
  if c.pending > 0 then
    SectionRow(Next(), GREY .. string.format(L["Cargando %d piezas del juego..."], c.pending) .. "|r")
  end
  for k = n + 1, #panel.rows do panel.rows[k]:Hide() end
  panel.content:SetHeight(math.max(1, y))
  local lock = ES:RouteLock(profKey)
  panel.note:SetText(lock and (ORANGE .. L["Tu ruta empezada incluye estas piezas; el resto de sus pasos se queda."] .. "|r")
    or (GREY .. L["Cada cambio recalcula la ruta."] .. "|r"))
  local h = 86 + math.min(y, MAX_H - 120) + 34
  panel:SetHeight(h)
end

local function CreatePanel()
  local f = CreateFrame("Frame", "CraftersJournalGearPanel", UIParent, "BackdropTemplate")
  f:SetWidth(WIDTH)
  f:SetFrameStrata("DIALOG")
  f:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  local G = ES.UI.BROWN.group
  f:SetBackdropColor(G[1], G[2], G[3], 0.99)
  f:SetBackdropBorderColor(0.52, 0.38, 0.17, 1)
  if f.SetClampedToScreen then f:SetClampedToScreen(true) end
  f:EnableMouse(true)
  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.title:SetPoint("TOPLEFT", 12, -10)
  f.title:SetText(L["Equipo imprescindible"])
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", 2, 2)
  close:SetScript("OnClick", function() f:Hide() end)
  f.forText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.forText:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -8)
  -- Especialización: cada clic pasa a la siguiente (y vuelve a "según tus talentos")
  f.specButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.specButton:SetSize(220, 22)
  f.specButton:SetPoint("TOPLEFT", f.forText, "BOTTOMLEFT", -2, -4)
  f.specButton:SetScript("OnClick", function()
    local specs = ES.Gear.SPECS[ES.Gear.Class() or ""] or {}
    local cur = ES.charData and ES.charData.gearSpec
    local nextKey
    if not cur then
      nextKey = specs[1] and specs[1].key
    else
      for i, s in ipairs(specs) do
        if s.key == cur then nextKey = specs[i + 1] and specs[i + 1].key end
      end
    end
    ES.Gear:SetSpec(nextKey)
    Recalculate()
  end)
  f.specButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L["Especialización"])
    GameTooltip:AddLine(L["Qué características buscan las piezas recomendadas. Pulsa para pasar a la siguiente; la última vuelve a la de tus talentos."], 1, 1, 1, true)
    GameTooltip:Show()
  end)
  f.specButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
  local scroll = ES.UI.WheelScroll(f, ROW_H * 2)
  scroll:SetPoint("TOPLEFT", 8, -86)
  scroll:SetPoint("BOTTOMRIGHT", -8, 36)
  f.content = CreateFrame("Frame", nil, scroll)
  f.content:SetSize(WIDTH - 16, 1)
  scroll:SetScrollChild(f.content)
  f.rows = {}
  f.reset = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.reset:SetSize(110, 22)
  f.reset:SetPoint("BOTTOMLEFT", 10, 8)
  f.reset:SetText(L["Restablecer"])
  f.reset:SetScript("OnClick", function()
    ES.Gear:Reset(f.profKey)
    Recalculate()
  end)
  f.note = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.note:SetPoint("LEFT", f.reset, "RIGHT", 8, 0)
  f.note:SetPoint("RIGHT", -10, 0)
  f.note:SetJustifyH("LEFT")
  f:Hide()
  return f
end

function ES:ToggleGearPanel(page, anchor)
  if panel and panel:IsShown() and panel.page == page then panel:Hide() return end
  panel = panel or CreatePanel()
  panel.page, panel.profKey = page, page.profKey
  -- (se va con la página: otra profesión, otra pestaña o la ventana cerrada)
  if not page.cjGearHook then
    page.cjGearHook = true
    page:HookScript("OnHide", function() if panel and panel.page == page then panel:Hide() end end)
  end
  panel:ClearAllPoints()
  panel:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -4)
  panel:Show()
  Render()
end

function ES:RefreshGearPanel()
  Render()
end

function ES:GearPanel() return panel end -- (para pruebas)
