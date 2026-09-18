--[[ ═══════════════════════════════════════════════════════════════════════════
     LXR-MARKET — Shared rules: what may be listed, what the broker keeps
     © 2026 iBoss21 / LXRCore — All Rights Reserved
     ═══════════════════════════════════════════════════════════════════════════ ]]

LXRMarket = LXRMarket or {}
local M = LXRMarket

function M.Broker(id) for _, b in ipairs(Config.Brokers) do if b.id == id then return b end end end

---May this catalog item be listed? Returns true or false, reason.
function M.Listable(name)
    local def = LXRShared.Items[name]
    if not def then return false, 'no_item' end
    if def.legal == false and not Config.Market.illegal then return false, 'illegal' end
    for _, c in ipairs(Config.Market.excludeCategories) do if def.category == c then return false, 'not_here' end end
    return true
end

---A clean asking price or nil.
function M.Price(p)
    p = tonumber(p)
    if not p then return nil end
    p = math.floor(p * 100 + 0.5) / 100
    if p < Config.Market.minPrice or p > Config.Market.maxPrice then return nil end
    return p
end

---Broker's cut and the seller's take on a sale.
function M.Split(total)
    local cut = math.floor(total * Config.Market.cut * 100 + 0.5) / 100
    return cut, math.floor((total - cut) * 100 + 0.5) / 100
end

---How the asking price compares to the ledger: 'bargain' | 'fair' | 'dear'.
function M.Verdict(name, price, quality)
    local v = LXRShared.ItemValue(name, quality)
    if v <= 0 then return 'fair' end
    if price <= v * 0.8 then return 'bargain' end
    if price >= v * 1.6 then return 'dear' end
    return 'fair'
end

---Stall scope key: shared market or per broker.
function M.Scope(brokerId) return Config.Market.shared and 'all' or brokerId end
