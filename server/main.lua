--[[ ═══════════════════════════════════════════════════════════════════════════
     LXR-MARKET — Server: the broker's ledger
     © 2026 iBoss21 / LXRCore — All Rights Reserved
     ═══════════════════════════════════════════════════════════════════════════ ]]

local LXRCore = exports['lxr-core']:GetCoreObject()
local LXR = exports['lxr-core']:GetLXR()
local M = LXRMarket
local RES = GetCurrentResourceName()
local buckets = {}

local function limited(src)
    local b = buckets[src]
    local now = GetGameTimer()
    if not b or now - b.at > Config.Security.rateLimit.windowMs then b = { at = now, n = 0 } buckets[src] = b end
    b.n = b.n + 1
    return b.n > Config.Security.rateLimit.burst
end
local function player(src) return LXRCore.Functions.GetPlayer(src) end
local function near(src, c)
    local ped = GetPlayerPed(src)
    return ped ~= 0 and #(GetEntityCoords(ped) - vector3(c.x, c.y, c.z)) <= Config.Security.maxDistance
end
local function nameOf(P) local c = P.PlayerData.charinfo or {} return ((c.firstname or '') .. ' ' .. (c.lastname or '')):gsub('^%s+', '') end
local function decode(s) local ok, t = pcall(json.decode, s or '') return ok and type(t) == 'table' and t or {} end

LXRCore.DB.RegisterMigration(RES, '0001_market', [[
CREATE TABLE IF NOT EXISTS `lxr_market_listings` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `scope` VARCHAR(32) NOT NULL DEFAULT 'all',
  `seller` VARCHAR(50) NOT NULL,
  `seller_name` VARCHAR(80) NOT NULL,
  `item` VARCHAR(64) NOT NULL,
  `amount` INT NOT NULL,
  `info` TEXT NULL,
  `price` DECIMAL(10,2) NOT NULL,
  `listed_at` INT NOT NULL,
  `expires_at` INT NOT NULL,
  PRIMARY KEY (`id`), KEY `scope` (`scope`), KEY `seller` (`seller`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
CREATE TABLE IF NOT EXISTS `lxr_market_shelf` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,
  `kind` VARCHAR(8) NOT NULL,
  `item` VARCHAR(64) NULL,
  `amount` INT NOT NULL DEFAULT 0,
  `info` TEXT NULL,
  `money` DECIMAL(10,2) NOT NULL DEFAULT 0,
  `note` VARCHAR(120) NULL,
  `at` INT NOT NULL,
  PRIMARY KEY (`id`), KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
]])

local function listings(scope)
    local rows = LXRCore.DB.Query('SELECT id, seller, seller_name, item, amount, info, price, listed_at, expires_at FROM lxr_market_listings WHERE scope = ? ORDER BY listed_at DESC LIMIT 400', { scope }) or {}
    local out = {}
    for _, r in ipairs(rows) do
        local def = LXRShared.Items[r.item]
        if def then
            local info = decode(r.info)
            out[#out + 1] = { id = r.id, seller = r.seller, sellerName = r.seller_name, name = r.item, label = def.label, description = def.description, category = def.category, rarity = def.rarity, amount = r.amount, price = tonumber(r.price), each = math.floor(tonumber(r.price) / math.max(1, r.amount) * 100 + 0.5) / 100, ledger = LXRShared.ItemValue(r.item, info.quality), verdict = M.Verdict(r.item, tonumber(r.price) / math.max(1, r.amount), info.quality), quality = info.quality, expiresIn = math.max(0, r.expires_at - os.time()) }
        end
    end
    return out
end
local function shelf(cid)
    local rows = LXRCore.DB.Query('SELECT id, kind, item, amount, info, money, note, at FROM lxr_market_shelf WHERE citizenid = ? ORDER BY at DESC', { cid }) or {}
    local money, items = 0, {}
    for _, r in ipairs(rows) do
        if r.kind == 'money' then money = money + tonumber(r.money)
        else local def = LXRShared.Items[r.item] if def then items[#items + 1] = { id = r.id, name = r.item, label = def.label, amount = r.amount, note = r.note } end end
    end
    return { money = math.floor(money * 100 + 0.5) / 100, items = items }
end
local function satchel(P, src)
    local out = {}
    for slot, it in pairs(P.PlayerData.items or {}) do
        local def = it and LXRShared.Items[it.name]
        if def and M.Listable(it.name) then out[#out + 1] = { slot = tonumber(slot), name = it.name, label = def.label, amount = it.amount, ledger = LXRShared.ItemValue(it.name, it.info and it.info.quality), quality = it.info and it.info.quality, category = def.category } end
    end
    table.sort(out, function(a, b) return a.slot < b.slot end)
    return out
end
local function book(src, broker)
    local P = player(src)
    local cid = P.PlayerData.citizenid
    return { broker = { id = broker.id, label = broker.label }, listings = listings(M.Scope(broker.id)), satchel = satchel(P, src), shelf = shelf(cid), me = cid, cash = P.PlayerData.money[Config.Market.account] or 0,
        rules = { cut = Config.Market.cut, fee = Config.Market.listingFee, days = Config.Market.days, max = Config.Market.maxListings, minPrice = Config.Market.minPrice, maxPrice = Config.Market.maxPrice } }
end

LXR.RPC.Register('lxr-market:open', function(src, brokerId)
    if limited(src) then return false, 'rate' end
    local P, broker = player(src), M.Broker(brokerId)
    if not P or not broker then return false, 'invalid' end
    if not near(src, broker.coords) then return false, 'too_far' end
    return true, book(src, broker)
end)

LXR.RPC.Register('lxr-market:list', function(src, brokerId, slot, amount, price)
    if limited(src) then return false, 'rate' end
    local P, broker = player(src), M.Broker(brokerId)
    if not P or not broker then return false, 'invalid' end
    if not near(src, broker.coords) then return false, 'too_far' end
    local it = P.PlayerData.items[tonumber(slot) or -1]
    if not it then return false, 'invalid' end
    local okL, why = M.Listable(it.name)
    if not okL then return false, why end
    local n = math.floor(tonumber(amount) or 0)
    if n < 1 or n > it.amount then return false, 'invalid_amount' end
    local p = M.Price(price)
    if not p then return false, 'bad_price' end
    local cid = P.PlayerData.citizenid
    local count = LXRCore.DB.Scalar('SELECT COUNT(*) FROM lxr_market_listings WHERE seller = ?', { cid }) or 0
    if tonumber(count) >= Config.Market.maxListings then return false, 'too_many' end
    if Config.Market.listingFee > 0 and not P.Functions.RemoveMoney(Config.Market.account, Config.Market.listingFee, 'market:fee') then return false, 'no_money', Config.Market.listingFee end
    if not P.Functions.RemoveItem(it.name, n, it.slot, 'market:listed') then return false, 'invalid' end
    local now = os.time()
    LXRCore.DB.Insert('INSERT INTO lxr_market_listings (scope, seller, seller_name, item, amount, info, price, listed_at, expires_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', { M.Scope(broker.id), cid, nameOf(P), it.name, n, json.encode(it.info or {}), p, now, now + Config.Market.days * 86400 })
    LXRCore.Emit('lxr:market:listed', nil, src, it.name, n, p)
    if Config.Debug.log then LXRCore.Log.info('market', ('listed %dx %s at $%.2f'):format(n, it.name, p), { source = src }) end
    return true, book(src, broker)
end)

LXR.RPC.Register('lxr-market:buy', function(src, brokerId, id)
    if limited(src) then return false, 'rate' end
    local P, broker = player(src), M.Broker(brokerId)
    if not P or not broker then return false, 'invalid' end
    if not near(src, broker.coords) then return false, 'too_far' end
    local row = LXRCore.DB.Single('SELECT id, scope, seller, seller_name, item, amount, info, price FROM lxr_market_listings WHERE id = ?', { tonumber(id) or -1 })
    if not row or row.scope ~= M.Scope(broker.id) then return false, 'gone' end
    if row.seller == P.PlayerData.citizenid then return false, 'own' end
    local total = tonumber(row.price)
    if (P.PlayerData.money[Config.Market.account] or 0) < total then return false, 'no_money', total end
    if not LXRCore.Inventory.CanCarry(src, row.item, row.amount) then return false, 'too_heavy' end
    -- take the listing first so two buyers cannot both have it
    local gone = LXRCore.DB.Update('DELETE FROM lxr_market_listings WHERE id = ?', { row.id })
    if not gone or gone == 0 then return false, 'gone' end
    if not P.Functions.RemoveMoney(Config.Market.account, total, 'market:buy') then
        LXRCore.DB.Insert('INSERT INTO lxr_market_listings (id, scope, seller, seller_name, item, amount, info, price, listed_at, expires_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', { row.id, row.scope, row.seller, row.seller_name, row.item, row.amount, row.info, row.price, os.time(), os.time() + Config.Market.days * 86400 })
        return false, 'no_money', total
    end
    P.Functions.AddItem(row.item, row.amount, nil, decode(row.info), 'market:bought')
    local cut, take = M.Split(total)
    LXRCore.DB.Insert('INSERT INTO lxr_market_shelf (citizenid, kind, money, note, at) VALUES (?, ?, ?, ?, ?)', { row.seller, 'money', take, ('%dx %s → %s'):format(row.amount, row.item, nameOf(P)), os.time() })
    local S = LXRCore.Functions.GetPlayerByCitizenId(row.seller)
    if S then LXRCore.Notify(S.PlayerData.source, Lang:t('info.sold', { label = LXRShared.Items[row.item].label, amount = ('%.2f'):format(take) }), 'success', 8000) end
    LXRCore.Emit('lxr:market:sold', nil, src, row.seller, row.item, row.amount, total, cut)
    if Config.Debug.log then LXRCore.Log.info('market', ('bought %dx %s for $%.2f (cut $%.2f)'):format(row.amount, row.item, total, cut), { source = src, seller = row.seller }) end
    return true, book(src, broker)
end)

LXR.RPC.Register('lxr-market:cancel', function(src, brokerId, id)
    if limited(src) then return false, 'rate' end
    local P, broker = player(src), M.Broker(brokerId)
    if not P or not broker then return false, 'invalid' end
    if not near(src, broker.coords) then return false, 'too_far' end
    local row = LXRCore.DB.Single('SELECT id, seller, item, amount, info FROM lxr_market_listings WHERE id = ? AND seller = ?', { tonumber(id) or -1, P.PlayerData.citizenid })
    if not row then return false, 'gone' end
    LXRCore.DB.Update('DELETE FROM lxr_market_listings WHERE id = ?', { row.id })
    if not LXRCore.Inventory.CanCarry(src, row.item, row.amount) or not P.Functions.AddItem(row.item, row.amount, nil, decode(row.info), 'market:cancelled') then
        LXRCore.DB.Insert('INSERT INTO lxr_market_shelf (citizenid, kind, item, amount, info, note, at) VALUES (?, ?, ?, ?, ?, ?, ?)', { P.PlayerData.citizenid, 'item', row.item, row.amount, row.info, 'cancelled', os.time() })
    end
    return true, book(src, broker)
end)

LXR.RPC.Register('lxr-market:collect', function(src, brokerId)
    if limited(src) then return false, 'rate' end
    local P, broker = player(src), M.Broker(brokerId)
    if not P or not broker then return false, 'invalid' end
    if not near(src, broker.coords) then return false, 'too_far' end
    local cid = P.PlayerData.citizenid
    local rows = LXRCore.DB.Query('SELECT id, kind, item, amount, info, money FROM lxr_market_shelf WHERE citizenid = ?', { cid }) or {}
    local money, taken = 0, 0
    for _, r in ipairs(rows) do
        if r.kind == 'money' then money = money + tonumber(r.money) LXRCore.DB.Update('DELETE FROM lxr_market_shelf WHERE id = ?', { r.id })
        elseif LXRCore.Inventory.CanCarry(src, r.item, r.amount) and P.Functions.AddItem(r.item, r.amount, nil, decode(r.info), 'market:shelf') then taken = taken + 1 LXRCore.DB.Update('DELETE FROM lxr_market_shelf WHERE id = ?', { r.id }) end
    end
    if money > 0 then P.Functions.AddMoney(Config.Market.account, math.floor(money * 100 + 0.5) / 100, 'market:earnings') end
    return true, book(src, broker), { money = money, items = taken }
end)

-- listings run out: the goods go to the seller's shelf
CreateThread(function()
    while true do
        Wait(600000)
        local now = os.time()
        local rows = LXRCore.DB.Query('SELECT id, seller, item, amount, info FROM lxr_market_listings WHERE expires_at < ?', { now }) or {}
        for _, r in ipairs(rows) do
            LXRCore.DB.Update('DELETE FROM lxr_market_listings WHERE id = ?', { r.id })
            LXRCore.DB.Insert('INSERT INTO lxr_market_shelf (citizenid, kind, item, amount, info, note, at) VALUES (?, ?, ?, ?, ?, ?, ?)', { r.seller, 'item', r.item, r.amount, r.info, 'expired', now })
        end
    end
end)

AddEventHandler('playerDropped', function() buckets[source] = nil end)
CreateThread(function() if Config.Debug.printBanner then print(('^1[lxr-market]^7 v%s — %d brokers, cut %d%%, listings run %d days'):format(GetResourceMetadata(RES, 'version', 0), #Config.Brokers, Config.Market.cut * 100, Config.Market.days)) end end)
exports('Listings', function(scope) return listings(scope or 'all') end)
