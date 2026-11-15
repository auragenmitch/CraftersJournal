local _, ES = ...
local L = ES.L

---------------------------------------------------------------------------
-- Precios de Auctionator (CurseForge: "¿puedes usar el escaneo de Auctionator si
-- lo tienes? Es muy rápido y nos ahorra hacer dos escaneos").
--
-- Solo la interfaz pública de Auctionator (Auctionator.API.v1), y cada función se
-- comprueba antes de usarla: si falta alguna, todo sigue como antes.
--   GetAuctionPriceByItemID(caller, itemID) -> precio mínimo por unidad (cobre) o nil
--   GetAuctionAgeByItemID(caller, itemID)   -> días desde que lo vio en la AH, o nil
--   RegisterForDBUpdate(caller, callback)   -> avisa cuando Auctionator guarda precios
--
-- Dos momentos:
--   1. Auctionator escanea toda la AH (C_AuctionHouse.ReplicateItems desde su código):
--      Crafter's Journal ya no la vuelve a leer y procesar entera (eran dos addons
--      procesando las mismas decenas de miles de subastas al abrir la AH). Espera a
--      que Auctionator guarde sus precios y los toma (Scanner:OnForeignScan, TakeOver).
--      Sin RegisterForDBUpdate no se sabe cuándo acaba: se lee como antes.
--   2. Sin escaneo propio (o de más de 24 h): se toman los precios que Auctionator ya
--      tenga de hoy, para no empezar sin precios (Bootstrap).
-- El escaneo resultante es como uno propio (ES.db.scans[reino]) con source =
-- "auctionator". Auctionator solo da el precio mínimo: las unidades a la venta y las
-- subastas se copian del escaneo anterior (y su escalera de precios, si el mínimo no
-- cambió). No entra en el historial de alertas de mercado: le faltan las subastas una
-- a una con las que se comparan los escaneos.
-- Opción: ES.db.noAuctionator (Options.lua).
---------------------------------------------------------------------------

local Atr = { CALLER = "CraftersJournal" }
ES.AtrPrices = Atr

local WAIT_FULL = 5 * 60      -- s esperando a que Auctionator guarde su escaneo completo
local BOOTSTRAP_AGE = 24 * 3600 -- sin escaneo propio de menos de esto, se toman los suyos
local BOOTSTRAP_MIN = 30      -- objetos con precio de hoy necesarios para que valga la pena
local BATCH = 400             -- objetos por fotograma al importar

function Atr.API()
  local a = type(Auctionator) == "table" and type(Auctionator.API) == "table" and Auctionator.API.v1
  if type(a) == "table" and type(a.GetAuctionPriceByItemID) == "function" then return a end
  return nil
end

function Atr:Enabled()
  return ES.db ~= nil and not ES.db.noAuctionator and Atr.API() ~= nil
end

-- ¿Puede avisarnos Auctionator cuando guarda sus precios?
function Atr:CanFollow()
  local a = self:Enabled() and Atr.API()
  return a and type(a.RegisterForDBUpdate) == "function" or false
end

-- ¿La petición de escaneo completo sale del código de Auctionator? (pila de llamadas)
function Atr.FromAuctionator(stack)
  if stack == nil then
    if not debugstack then return false end
    local ok, s = pcall(debugstack, 1, 40, 40)
    stack = ok and s or nil
  end
  return type(stack) == "string" and stack:find("[/\\]Auctionator[/\\]") ~= nil
end

local function Price(api, itemID)
  local ok, price = pcall(api.GetAuctionPriceByItemID, Atr.CALLER, itemID)
  if not ok or type(price) ~= "number" or price <= 0 then return nil end
  return price
end

local function Age(api, itemID)
  if type(api.GetAuctionAgeByItemID) ~= "function" then return 0 end -- (sin la función: se fía)
  local ok, age = pcall(api.GetAuctionAgeByItemID, Atr.CALLER, itemID)
  if not ok or type(age) ~= "number" then return nil end
  return age
end

-- Objetos que interesan: los de las profesiones (los mismos que guarda el historial)
local itemList
local function Items()
  if not itemList then
    itemList = {}
    for _, data in pairs(ES.Data) do
      if type(data) == "table" and data.recipes then
        for _, r in pairs(data.recipes) do
          for _, rq in ipairs(r.r) do itemList[rq[1]] = true end
          if r.out then itemList[r.out[1]] = true end
          if r.scroll then itemList[r.scroll] = true end
        end
      end
    end
    local list = {}
    for id in pairs(itemList) do list[#list + 1] = id end
    table.sort(list)
    itemList = list
  end
  return itemList
end
Atr.Items = Items

-- Escaneo a partir de los precios de Auctionator: { [itemID] = entrada } con los
-- objetos vistos hace como mucho `maxAge` días. `prev`: el escaneo anterior (de él
-- salen unidades, subastas y escalera). Por tandas (`done(items, n)` al acabar);
-- sin C_Timer, de golpe. `merge`: lo que Auctionator no vio hoy se queda como estaba
-- en el escaneo anterior (para empezar con precios sin perder los que ya había)
function Atr:Collect(maxAge, prev, done, merge)
  local api = Atr.API()
  if not api then return done(nil, 0) end
  local list, items, n, i = Items(), {}, 0, 1
  local old = prev and prev.items or {}
  if merge then
    for id, e in pairs(old) do items[id] = e end
  end
  local function Step()
    local last = math.min(#list, i + BATCH - 1)
    for k = i, last do
      local id = list[k]
      local price = Price(api, id)
      local age = price and Age(api, id)
      if price and age and age <= maxAge then
        local p = old[id]
        local e = { minUnit = math.floor(price + 0.5), atr = true }
        if p then
          e.quantity, e.listings, e.sellers, e.topShare = p.quantity, p.listings, p.sellers, p.topShare
          if p.minUnit == e.minUnit then e.ladder, e.median, e.avgUnit = p.ladder, p.median, p.avgUnit end
        end
        items[id] = e
        n = n + 1
      end
    end
    i = last + 1
    if i <= #list and C_Timer and C_Timer.After then
      C_Timer.After(0, Step)
    else
      done(items, n)
    end
  end
  Step()
end

-- Guarda como escaneo los precios recogidos y avisa a todo el addon (como un escaneo)
function Atr:Save(items, n, why)
  local key = ES:RealmKey()
  local prev = ES.db.scans[key]
  local scan = { time = time(), total = n, unique = n, items = items, source = "auctionator",
    ownerPct = prev and prev.ownerPct or 0 }
  ES.db.scans[key] = scan
  ES:ScanLog(string.format("precios de Auctionator (%s): %d objetos", why, n))
  ES.Scanner.statusText = string.format(L["Precios de Auctionator: %d objetos de profesiones."], n)
  ES:RefreshScanButtons()
  ES:OnScanComplete(scan, true)
  return scan
end

-- 1. Auctionator acaba de pedir el escaneo completo: lo toma él. Devuelve true si
-- Crafter's Journal no tiene que leerlo (lo hará al guardar Auctionator sus precios)
function Atr:TakeOver(stack)
  if not self:CanFollow() or not Atr.FromAuctionator(stack) then return false end
  self:Register()
  self.awaiting = time()
  ES:ScanLog("escaneo completo de Auctionator: se esperan sus precios")
  return true
end

-- Auctionator guardó precios (su escaneo completo, o una búsqueda): si esperábamos su
-- escaneo completo, se toman los de hoy. Si no, solo para empezar con precios
function Atr:OnDBUpdate()
  if not self:Enabled() or self.collecting then return end
  local now = time()
  if self.awaiting and now - self.awaiting <= WAIT_FULL then
    -- (un momento: Auctionator puede guardar por partes; se agrupa)
    if self.queued then return end
    self.queued = true
    C_Timer.After(2, function()
      self.queued = nil
      if not self.awaiting then return end
      self.awaiting = nil
      self:Import(0, "escaneo completo")
    end)
    return
  end
  self.awaiting = nil
  self:Bootstrap()
end

function Atr:Import(maxAge, why, minItems, merge)
  if self.collecting then return end
  self.collecting = true
  local prev = ES.db.scans[ES:RealmKey()]
  self:Collect(maxAge, prev, function(items, n)
    self.collecting = nil
    if not items or n < (minItems or 1) then
      ES:ScanLog(string.format("precios de Auctionator (%s): solo %d objetos, no se usan", why, n))
      return
    end
    self:Save(items, n, why)
  end, merge)
end

-- 2. Sin escaneo propio reciente: los precios de hoy que Auctionator ya tenga
function Atr:Bootstrap()
  if not self:Enabled() or self.collecting or (ES.Scanner and ES.Scanner:IsBusy()) then return end
  local scan = ES.db.scans[ES:RealmKey()]
  if scan and time() - (scan.time or 0) < BOOTSTRAP_AGE then return end
  if self.bootstrapTried and time() - self.bootstrapTried < 600 then return end -- (como mucho cada 10 min)
  self.bootstrapTried = time()
  self:Import(0, "sin escaneo propio", BOOTSTRAP_MIN, true)
end

function Atr:Register()
  if self.registered then return end
  local api = self:Enabled() and Atr.API()
  if not (api and type(api.RegisterForDBUpdate) == "function") then return end
  local ok = pcall(api.RegisterForDBUpdate, Atr.CALLER, function() Atr:OnDBUpdate() end)
  self.registered = ok or nil
end

-- Al entrar y al abrir la AH (Auctionator puede cargarse después que nosotros)
do
  local f = CreateFrame("Frame")
  ES.SafeRegister(f, "PLAYER_LOGIN")
  ES.SafeRegister(f, "AUCTION_HOUSE_SHOW")
  f:SetScript("OnEvent", function(_, event)
    if not ES.db then return end
    C_Timer.After(event == "PLAYER_LOGIN" and 5 or 1, function()
      if not Atr:Enabled() then return end
      Atr:Register()
      Atr:Bootstrap()
    end)
  end)
end
