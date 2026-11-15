local _, ES = ...

---------------------------------------------------------------------------
-- "Imprescindibles": equipo que fabrica la profesión y le sirve a tu personaje
-- (clase y especialización) mientras subes de nivel. Lo azul (raro o mejor) que
-- puedes llevar y lleva las características de tu especialización se recomienda
-- por defecto; lo verde no (casi nadie lo usa), pero se puede añadir a mano.
--
-- La ruta lo incluye como un paso más: en el primer nivel en que la receta se
-- puede aprender y aún da puntos, ese nivel se sube fabricándola (opts.pinned de
-- Planner: { [nivel] = receta }). Así la pieza sale del camino de subir y su coste
-- ya va en la ruta, la lista de compra y los materiales. Lo que ya no da puntos
-- desde tu nivel (o está por encima de tu objetivo) sale aparte, sin coste.
--
-- Qué te sirve se mira en el juego (GetItemInfo, GetItemStats): tipo de armadura de
-- tu clase a ese nivel (malla hasta 40 y placas desde 40, etc.), armas que sabes
-- usar, nivel para llevarlo (no lo que ya se te ha quedado bajo) y que sus
-- características sean las de tu especialización (agilidad para un pícaro, intelecto
-- y espíritu para un sanador...). La especialización se saca de tus talentos; se
-- puede elegir otra (ES.charData.gearSpec).
--
-- Por profesión (ES.db.prof[prof], del personaje):
--   gearOff   = true: sin imprescindibles en la ruta (icono)
--   gearPicks = { [receta] = cantidad }: lo que cambias tú (0 = quitada)
---------------------------------------------------------------------------

local Gear = { version = 0 }
ES.Gear = Gear

-- Especializaciones por clase, en el orden de sus pestañas de talentos, y su papel
Gear.SPECS = {
  WARRIOR = { { key = "arms", name = "Armas", role = "melee" }, { key = "fury", name = "Furia", role = "melee" },
    { key = "prot", name = "Protección", role = "tank" }, default = 1 },
  PALADIN = { { key = "holy", name = "Sagrado", role = "heal" }, { key = "prot", name = "Protección", role = "tank" },
    { key = "ret", name = "Reprensión", role = "melee" }, default = 3 },
  HUNTER = { { key = "bm", name = "Dominio de bestias", role = "ranged" }, { key = "mm", name = "Puntería", role = "ranged" },
    { key = "sv", name = "Supervivencia", role = "ranged" }, default = 1 },
  ROGUE = { { key = "assa", name = "Asesinato", role = "agi" }, { key = "combat", name = "Combate", role = "agi" },
    { key = "sub", name = "Sutileza", role = "agi" }, default = 2 },
  PRIEST = { { key = "disc", name = "Disciplina", role = "heal" }, { key = "holy", name = "Sagrado", role = "heal" },
    { key = "shadow", name = "Sombra", role = "caster" }, default = 3 },
  SHAMAN = { { key = "ele", name = "Elemental", role = "caster" }, { key = "enh", name = "Mejora", role = "melee" },
    { key = "resto", name = "Restauración", role = "heal" }, default = 2 },
  MAGE = { { key = "arcane", name = "Arcano", role = "caster" }, { key = "fire", name = "Fuego", role = "caster" },
    { key = "frost", name = "Escarcha", role = "caster" }, default = 3 },
  WARLOCK = { { key = "aff", name = "Aflicción", role = "caster" }, { key = "demo", name = "Demonología", role = "caster" },
    { key = "destro", name = "Destrucción", role = "caster" }, default = 1 },
  DRUID = { { key = "balance", name = "Equilibrio", role = "caster" }, { key = "feral", name = "Combate feral", role = "feral" },
    { key = "resto", name = "Restauración", role = "heal" }, default = 2 },
}
for _, list in pairs(Gear.SPECS) do ES.Localize(list, "name") end

-- Peso de cada característica para cada papel. Las de peso 0,5 o más son "las suyas":
-- una pieza le sirve si al menos la mitad de lo que da son de esas
local ROLES = {
  melee  = { str = 1, agi = 0.6, ap = 0.6, hit = 1, crit = 1, sta = 0.3 },
  agi    = { agi = 1, str = 0.5, ap = 0.6, hit = 1, crit = 1, sta = 0.3 },
  feral  = { agi = 1, str = 0.8, ap = 0.6, sta = 0.6, hit = 1, crit = 1, def = 0.5 },
  ranged = { agi = 1, ap = 0.6, hit = 1, crit = 1, int = 0.3, sta = 0.3 },
  tank   = { sta = 1, def = 1, str = 0.6, agi = 0.5, hit = 0.4 },
  caster = { int = 1, spell = 1, hit = 1, crit = 0.8, spi = 0.4, sta = 0.4 },
  heal   = { int = 1, spell = 1, spi = 0.8, mp5 = 1, sta = 0.3 },
}
Gear.ROLES = ROLES
local CORE = 0.5

-- Clave de GetItemStats -> característica (por partes del nombre: ITEM_MOD_AGILITY_SHORT...)
local STAT_KEYS = {
  { "STRENGTH", "str" }, { "AGILITY", "agi" }, { "STAMINA", "sta" }, { "INTELLECT", "int" }, { "SPIRIT", "spi" },
  { "ATTACK_POWER", "ap" }, { "DEFENSE", "def" }, { "BLOCK", "def" }, { "PARRY", "def" }, { "DODGE", "def" },
  { "HIT", "hit" }, { "CRIT", "crit" }, { "MANA_REGEN", "mp5" }, { "POWER_REGEN0", "mp5" },
  { "SPELL", "spell" }, { "HEALING", "spell" },
}
function Gear.StatOf(key)
  if type(key) ~= "string" or key:find("RESISTANCE") then return nil end
  for _, k in ipairs(STAT_KEYS) do
    if key:find(k[1], 1, true) then return k[2] end
  end
  return nil
end

-- Armadura de cada clase { hasta 39, desde 40 }: 1 tela, 2 cuero, 3 malla, 4 placas
local ARMOR = { WARRIOR = { 3, 4 }, PALADIN = { 3, 4 }, HUNTER = { 2, 3 }, SHAMAN = { 2, 3 },
  ROGUE = { 2, 2 }, DRUID = { 2, 2 }, PRIEST = { 1, 1 }, MAGE = { 1, 1 }, WARLOCK = { 1, 1 } }
local SHIELD = { WARRIOR = true, PALADIN = true, SHAMAN = true }
-- Armas (subclase de la clase 2) que sabe usar cada clase
local WEAPONS = {
  WARRIOR = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 15, 16, 18 },
  PALADIN = { 0, 1, 4, 5, 6, 7, 8 },
  HUNTER = { 0, 1, 2, 3, 6, 7, 8, 10, 13, 15, 16, 18 },
  ROGUE = { 2, 3, 4, 7, 13, 15, 16, 18 },
  PRIEST = { 4, 10, 15, 19 },
  SHAMAN = { 0, 1, 4, 5, 10, 13, 15 },
  MAGE = { 7, 10, 15, 19 },
  WARLOCK = { 7, 10, 15, 19 },
  DRUID = { 4, 5, 10, 13, 15 },
}
local weaponSet = {}
for class, list in pairs(WEAPONS) do
  weaponSet[class] = {}
  for _, sub in ipairs(list) do weaponSet[class][sub] = true end
end

-- Hueco (para quedarse con la mejor de cada hueco y tramo de nivel)
local SLOTS = { INVTYPE_ROBE = "INVTYPE_CHEST", INVTYPE_WEAPON = "1h", INVTYPE_WEAPONMAINHAND = "1h",
  INVTYPE_WEAPONOFFHAND = "1h", INVTYPE_2HWEAPON = "2h", INVTYPE_RANGED = "ranged", INVTYPE_RANGEDRIGHT = "ranged",
  INVTYPE_THROWN = "ranged" }
local NOT_GEAR = { INVTYPE_BODY = true, INVTYPE_TABARD = true, INVTYPE_BAG = true, INVTYPE_QUIVER = true,
  INVTYPE_AMMO = true, INVTYPE_NON_EQUIP_IGNORE = true, INVTYPE_NON_EQUIP = true }

local TOO_LOW = 5 -- piezas para 5 niveles menos que el tuyo o más: ya no se recomiendan
Gear.TOO_LOW = TOO_LOW

---------------------------------------------------------------------------
-- Tu personaje
---------------------------------------------------------------------------
function Gear.Class()
  if not UnitClass then return nil end
  local _, class = UnitClass("player")
  return class
end

function Gear.Level()
  return (UnitLevel and UnitLevel("player")) or 1
end

-- La pestaña de talentos con más puntos (nil sin talentos). Clásica: nombre, icono,
-- puntos; las posteriores: id, nombre, descripción, icono, puntos
function Gear.TalentSpec()
  if not (GetNumTalentTabs and GetTalentTabInfo) then return nil end
  local best, bestPoints = nil, 0
  for i = 1, GetNumTalentTabs() or 0 do
    local r = { GetTalentTabInfo(i) }
    local points = type(r[1]) == "string" and r[3] or r[5]
    if type(points) == "number" and points > bestPoints then best, bestPoints = i, points end
  end
  return best
end

-- Tu especialización: { key, name, role, auto = true si sale de tus talentos o por defecto }
function Gear:Spec()
  local specs = Gear.SPECS[Gear.Class() or ""]
  if not specs then return nil end
  local chosen = ES.charData and ES.charData.gearSpec
  for _, s in ipairs(specs) do
    if s.key == chosen then return s end
  end
  local i = Gear.TalentSpec() or specs.default or 1
  local s = specs[i] or specs[1]
  return { key = s.key, name = s.name, role = s.role, auto = true }
end

-- Elegir especialización (nil: la de tus talentos)
function Gear:SetSpec(key)
  if ES.charData then ES.charData.gearSpec = key end
  self:Changed()
end

---------------------------------------------------------------------------
-- Lo que es cada pieza
---------------------------------------------------------------------------
local infoCache = {}
local pending = {}
local NONE = {} -- (en la caché: no es equipo)

-- { equipLoc, classID, subclassID, reqLevel, quality, stats = { [car.] = valor } } o
-- nil (no es equipo); false si el juego aún no lo tiene cargado
function Gear.ItemInfo(itemID)
  local cached = infoCache[itemID]
  if cached == NONE then return nil end
  if cached ~= nil then return cached end
  local instant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
  local _, _, _, equipLoc, _, classID, subclassID
  if instant then _, _, _, equipLoc, _, classID, subclassID = instant(itemID) end
  if equipLoc == "" or NOT_GEAR[equipLoc or ""] then infoCache[itemID] = NONE return nil end
  local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  local name, link, quality, _, reqLevel, _, _, _, loc2, _, _, cls2, sub2 = getInfo(itemID)
  if not name then
    pending[itemID] = true
    if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, itemID) end
    return false
  end
  equipLoc, classID, subclassID = equipLoc or loc2, classID or cls2, subclassID or sub2
  if not equipLoc or equipLoc == "" or NOT_GEAR[equipLoc] then infoCache[itemID] = NONE return nil end
  local stats = {}
  local getStats = (C_Item and C_Item.GetItemStats) or GetItemStats
  local raw = getStats and link and getStats(link)
  for k, v in pairs(type(raw) == "table" and raw or {}) do
    local s = Gear.StatOf(k)
    if s and type(v) == "number" then stats[s] = (stats[s] or 0) + v end
  end
  local info = { equipLoc = equipLoc, classID = classID, subclassID = subclassID, reqLevel = reqLevel or 0,
    quality = quality, stats = stats }
  infoCache[itemID] = info
  return info
end

-- ¿La puede llevar tu clase? (tipo de armadura a ese nivel, armas, escudos)
function Gear.Wearable(info, class, level)
  if not (info and class) then return false end
  if info.equipLoc == "INVTYPE_CLOAK" then return true end
  if info.classID == 2 then return weaponSet[class] and weaponSet[class][info.subclassID] or false end
  if info.classID == 4 then
    local sub = info.subclassID
    if sub == 0 then return true end -- anillos, cuellos, abalorios, sostenido en la mano izquierda
    if sub == 6 then return SHIELD[class] or false end
    local armor = ARMOR[class]
    if not armor then return false end
    local at = math.max(info.reqLevel or 0, level or 1)
    return sub == (at >= 40 and armor[2] or armor[1])
  end
  return false
end

-- Puntuación para el papel y si lleva lo suyo: score, fits
function Gear.Score(info, role)
  local w = ROLES[role]
  if not (info and w) then return 0, false end
  local score, core, total = 0, 0, 0
  for stat, v in pairs(info.stats or {}) do
    total = total + v
    score = score + (w[stat] or 0) * v
    if (w[stat] or 0) >= CORE then core = core + v end
  end
  return score, core > 0 and core >= total * 0.5
end

---------------------------------------------------------------------------
-- Piezas de una profesión
---------------------------------------------------------------------------
local candCache = {}

-- { recommended = { e }, other = { e }, pending = n } con e = { id (receta), r, item,
-- info, score, quality }, ordenadas por nivel de la receta
function Gear:Candidates(profKey)
  local spec, class, level = self:Spec(), Gear.Class(), Gear.Level()
  local key = table.concat({ profKey, self.version, tostring(class), spec and spec.key or "", level }, ":")
  local c = candCache[profKey]
  if c and c.key == key then return c end
  c = { key = key, recommended = {}, other = {}, pending = 0 }
  candCache[profKey] = c
  local data = ES.Data[profKey]
  if not (data and spec and class) then return c end
  local best = {} -- [hueco:tramo] = mejor recomendada
  for id, r in pairs(data.recipes) do
    local out = r.out and r.out[1]
    if out and not r.intermediate and not r.conversion and (r.oq or 0) >= 2 then
      local info = Gear.ItemInfo(out)
      if info == false then
        c.pending = c.pending + 1
      elseif info and Gear.Wearable(info, class, level) then
        local score, fits = Gear.Score(info, spec.role)
        local e = { id = id, r = r, item = out, info = info, score = score, quality = r.oq or info.quality or 0 }
        local relevant = (info.reqLevel or 0) >= level - TOO_LOW
        if fits and relevant and e.quality >= 3 then
          local slot = (SLOTS[info.equipLoc] or info.equipLoc) .. ":" .. math.floor((info.reqLevel or 0) / 10)
          local b = best[slot]
          if not b or score > b.score or (score == b.score and id < b.id) then
            if b then c.other[#c.other + 1] = b end
            best[slot] = e
          else
            c.other[#c.other + 1] = e
          end
        else
          c.other[#c.other + 1] = e
        end
      end
    end
  end
  for _, e in pairs(best) do c.recommended[#c.recommended + 1] = e end
  local function ByLevel(a, b)
    local la, lb = a.r.t[1] or 0, b.r.t[1] or 0
    if la ~= lb then return la < lb end
    return a.id < b.id
  end
  table.sort(c.recommended, ByLevel)
  table.sort(c.other, ByLevel)
  return c
end

function Gear:On(profKey)
  local settings = ES.db and ES.db.prof and ES.db.prof[profKey]
  return not (settings and settings.gearOff)
end

-- Lo elegido: lista de { id, qty, e, recommended } con qty > 0 (las recomendadas que
-- no quitaste y las que añadiste tú), en orden de nivel
function Gear:Picks(profKey)
  local settings = ES.db and ES.db.prof and ES.db.prof[profKey] or {}
  local over = settings.gearPicks or {}
  local c = self:Candidates(profKey)
  local list = {}
  for _, e in ipairs(c.recommended) do
    local qty = over[e.id] or 1
    if qty > 0 then list[#list + 1] = { id = e.id, qty = qty, e = e, recommended = true } end
  end
  for _, e in ipairs(c.other) do
    local qty = over[e.id] or 0
    if qty > 0 then list[#list + 1] = { id = e.id, qty = qty, e = e } end
  end
  table.sort(list, function(a, b)
    local la, lb = a.e.r.t[1] or 0, b.e.r.t[1] or 0
    if la ~= lb then return la < lb end
    return a.id < b.id
  end)
  return list
end

-- Cuántas de esta receta quieres para ti (0 si no es imprescindible)
function Gear:PickQty(profKey, recipeID)
  if not self:On(profKey) then return 0 end
  for _, p in ipairs(self:Picks(profKey)) do
    if p.id == recipeID then return p.qty end
  end
  return 0
end

-- Cuántas de este objeto guardas para ti (por la receta que lo fabrica)
function Gear:KeepItem(profKey, itemID)
  if not self:On(profKey) then return 0 end
  local n = 0
  for _, p in ipairs(self:Picks(profKey)) do
    if p.e.item == itemID then n = n + p.qty end
  end
  return n
end

function Gear:SetQty(profKey, recipeID, qty)
  ES.db.prof[profKey] = ES.db.prof[profKey] or {}
  local settings = ES.db.prof[profKey]
  settings.gearPicks = settings.gearPicks or {}
  local recommended = false
  for _, e in ipairs(self:Candidates(profKey).recommended) do
    if e.id == recipeID then recommended = true end
  end
  qty = math.max(0, math.min(9, qty))
  -- (lo de por defecto no se guarda: si cambian las recomendaciones, te sigue)
  if (recommended and qty == 1) or (not recommended and qty == 0) then qty = nil end
  settings.gearPicks[recipeID] = qty
  if not next(settings.gearPicks) then settings.gearPicks = nil end
  self:Changed()
end

function Gear:Reset(profKey)
  if ES.db.prof[profKey] then ES.db.prof[profKey].gearPicks = nil end
  self:Changed()
end

-- Para la clave de la caché de rutas: cambia si cambia lo que entra en la ruta
function Gear:Key(profKey)
  if not self:On(profKey) then return "off" end
  local parts = {}
  for _, p in ipairs(self:Picks(profKey)) do parts[#parts + 1] = p.id .. "x" .. p.qty end
  return table.concat(parts, ",")
end

---------------------------------------------------------------------------
-- En la ruta
---------------------------------------------------------------------------
-- Niveles de la ruta que se suben fabricando cada pieza: { [nivel] = receta }, o nil.
-- `opts`: las opciones del plan (from, to, excluded y lo que pide LearnSkill)
function Gear:Pins(profKey, opts)
  if not self:On(profKey) or not (opts and opts.from and opts.to) then return nil end
  local data = ES.Data[profKey]
  local P = ES.Planner
  local pins = {}
  for _, p in ipairs(self:Picks(profKey)) do
    local r = data.recipes[p.id]
    local learn = r and not (opts.excluded and opts.excluded[p.id]) and P.LearnSkill(r, opts)
    if learn then
      local s, left = math.max(opts.from, learn), p.qty
      local last = math.min(opts.to, r.t[4]) - 1
      while left > 0 and s <= last do
        local chance = P.Chance(r.t, s)
        if not pins[s] and chance > 0 then
          pins[s] = p.id
          left = left - (r.out and r.out[2] or 1) / chance -- (1/chance fabricaciones en ese nivel)
        end
        s = s + 1
      end
    end
  end
  return next(pins) and pins or nil
end

-- Cómo queda cada pieza elegida con la ruta calculada:
-- { { pick, status = "route" | "nolearn" | "grey" | "above" | "dropped", step } }
function Gear:Status(profKey, plan)
  local res = {}
  if not self:On(profKey) then return res end
  local data = ES.Data[profKey]
  local opts = plan and plan.ctx and plan.ctx.opts or {}
  for _, p in ipairs(self:Picks(profKey)) do
    local r = data.recipes[p.id]
    local entry = { pick = p }
    for _, st in ipairs(plan and plan.steps or {}) do
      if st.id == p.id then entry.status, entry.step = "route", st break end
    end
    if not entry.status then
      local learn = ES.Planner.LearnSkill(r, opts)
      if not learn then entry.status = "nolearn"
      elseif (opts.from or 1) >= r.t[4] then entry.status = "grey"
      elseif learn >= (opts.to or 300) then entry.status = "above"
      else entry.status = "dropped" end -- (le falta el precio de algún material)
    end
    res[#res + 1] = entry
  end
  return res
end

---------------------------------------------------------------------------
-- Cambios: las rutas se recalculan (la clave de su caché lleva Gear:Key)
---------------------------------------------------------------------------
function Gear:Changed()
  self.version = self.version + 1
  candCache = {}
  if ES.ClearHomeCache then ES:ClearHomeCache() end
  if ES.RefreshGearPanel then ES:RefreshGearPanel() end
end

-- Llegan del servidor los datos de piezas que faltaban: se recalcula (agrupado)
do
  local f = CreateFrame("Frame")
  ES.SafeRegister(f, "GET_ITEM_INFO_RECEIVED")
  ES.SafeRegister(f, "PLAYER_LEVEL_UP")
  ES.SafeRegister(f, "CHARACTER_POINTS_CHANGED")
  local queued = false
  f:SetScript("OnEvent", function(_, event, itemID)
    if not ES.db then return end
    if event == "GET_ITEM_INFO_RECEIVED" and not pending[itemID] then return end
    if itemID then pending[itemID] = nil end
    if queued then return end
    queued = true
    C_Timer.After(1, function()
      queued = false
      Gear:Changed()
      if ES.RefreshProfessionPages then ES:RefreshProfessionPages() end
    end)
  end)
end

function Gear.ClearCache() infoCache, candCache, pending = {}, {}, {} end -- (para pruebas)
