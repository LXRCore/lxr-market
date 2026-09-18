--[[ ═══════════════════════════════════════════════════════════════════════════
     LXR-MARKET — Offline tests: what may be listed, prices, the split, verdicts, locale parity
     Usage (from the lxr-market folder):  lua tests/run.lua [--mock out.js en|ka]
     © 2026 iBoss21 / LXRCore — All Rights Reserved
     ═══════════════════════════════════════════════════════════════════════════ ]]

local CORE = os.getenv('LXR_CORE_PATH') or '../lxr-core'
package.path = CORE .. '/?.lua;' .. package.path
local ok = pcall(function() require('tests.lib.fxshim') end)
if not ok then print('lxr-core shim not found at ' .. CORE) os.exit(2) end
local Shim = require('tests.lib.fxshim')
for _, f in ipairs({ 'shared/main.lua', 'shared/locale.lua', 'locales/en.lua', 'config.lua', 'shared/catalog.lua', 'shared/items.lua', 'shared/prices.lua' }) do Shim.load(CORE .. '/' .. f) end
Config = nil Locale = nil
Shim.load('shared/locale.lua') Shim.load('locales/en.lua') Shim.load('locales/ka.lua') Shim.load('config.lua') Shim.load('shared/rules.lua')
local M = LXRMarket

local passed, failed = 0, 0
local function test(name, fn) local okT, err = xpcall(fn, debug.traceback) if okT then passed = passed + 1 print('  ^ ok   ' .. name) else failed = failed + 1 print('  x FAIL ' .. name .. '\n' .. err) end end
local function eq(a, b, msg) if a ~= b then error((msg or 'eq') .. ': expected ' .. tostring(b) .. ' got ' .. tostring(a), 2) end end

print('lxr-market offline tests')
test('listable: catalog goods yes, illegal and papers no', function()
    assert(M.Listable('bread')) assert(M.Listable('pelt_deer'))
    local okI, why = M.Listable('moonshine') assert(not okI) eq(why, 'illegal')
    local okD, why2 = M.Listable('hunting_license') assert(not okD) eq(why2, 'not_here')
    local okN, why3 = M.Listable('nothing') assert(not okN) eq(why3, 'no_item')
    for _, b in ipairs(Config.Brokers) do assert(M.Broker(b.id) == b) assert(b.ped and b.coords) end
end)
test('prices are clean and bounded; the split leaves the broker its cut', function()
    eq(M.Price('1.234'), 1.23) eq(M.Price(0), nil) eq(M.Price(99999), nil) eq(M.Price('x'), nil)
    local cut, take = M.Split(10)
    eq(cut, math.floor(10 * Config.Market.cut * 100 + 0.5) / 100) eq(cut + take, 10)
end)
test('verdicts against the ledger', function()
    local v = LXRShared.ItemValue('bread')
    eq(M.Verdict('bread', v * 0.5), 'bargain') eq(M.Verdict('bread', v), 'fair') eq(M.Verdict('bread', v * 2), 'dear')
    eq(M.Verdict('nothing', 5), 'fair')
    eq(M.Scope('valentine'), Config.Market.shared and 'all' or 'valentine')
end)
test('locale parity', function()
    local en, ka = Locale.Bundles.en, Locale.Bundles.ka
    local missing = {}
    for k in pairs(en) do if ka[k] == nil then missing[#missing + 1] = k end end
    eq(#missing, 0, 'ka missing: ' .. table.concat(missing, ', '))
end)
print(('%d passed, %d failed'):format(passed, failed))
if arg and arg[1] == '--mock' and arg[2] then
    Config.Lang = arg[3] or 'en'
    local function L(id, seller, sname, name, amount, price, q, exp)
        local def = LXRShared.Items[name]
        return { id = id, seller = seller, sellerName = sname, name = name, label = def.label, description = def.description, category = def.category, rarity = def.rarity, amount = amount, price = price, each = math.floor(price / amount * 100 + 0.5) / 100, ledger = LXRShared.ItemValue(name, q), verdict = M.Verdict(name, price / amount, q), quality = q, expiresIn = exp }
    end
    local listings = { L(1, 'B', 'Nino Kvaratskhelia', 'pelt_bear', 1, 4.50, 3, 5 * 86400 + 3600), L(2, 'C', 'Tomas Reyes', 'weapon_revolver_cattleman', 1, 9.00, 60, 2 * 86400), L(3, 'A', 'Sadie Adler', 'bread', 6, 0.20, nil, 6 * 86400), L(4, 'B', 'Nino Kvaratskhelia', 'lantern', 1, 2.50, nil, 86400 * 3), L(5, 'D', 'Grace Delacroix', 'whiskey', 3, 1.20, nil, 86400), L(6, 'C', 'Tomas Reyes', 'horse_brush', 1, 0.60, nil, 86400 * 4), L(7, 'A', 'Sadie Adler', 'gold_nugget', 2, 20.00, nil, 86400 * 6), L(8, 'D', 'Grace Delacroix', 'pickaxe', 1, 1.00, nil, 86400 * 2) }
    local satchel = { { slot = 2, name = 'bread', label = 'Bread', amount = 3, ledger = LXRShared.ItemValue('bread'), category = 'food' }, { slot = 8, name = 'lantern', label = 'Lantern', amount = 1, ledger = LXRShared.ItemValue('lantern'), category = 'tool' }, { slot = 13, name = 'gold_nugget', label = 'Gold Nugget', amount = 2, ledger = LXRShared.ItemValue('gold_nugget'), category = 'currency' } }
    local f = assert(io.open(arg[2], 'w'))
    f:write('window.__LXR_MOCK__ = ' .. json.encode({ action = 'open', images = '/lxr-inventory/html/images/', payload = { broker = { id = 'valentine', label = 'Valentine Market Stalls' }, listings = listings, satchel = satchel, shelf = { money = 3.45, items = { { id = 9, name = 'canteen', label = 'Canteen', amount = 1, note = 'expired' } } }, me = 'A', cash = 12.50, rules = { cut = Config.Market.cut, fee = Config.Market.listingFee, days = Config.Market.days, max = Config.Market.maxListings, minPrice = Config.Market.minPrice, maxPrice = Config.Market.maxPrice } }, lang = Config.Lang, locale = Lang.bundle(), brand = { name = 'The Land of Wolves', theme = 'night' } }) .. ';\n')
    f:close()
    print('mock written to ' .. arg[2])
end
os.exit(failed == 0 and 0 or 1)
