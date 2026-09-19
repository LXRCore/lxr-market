--[[
    ██╗     ██╗  ██╗██████╗       ███╗   ███╗ █████╗ ██████╗ ██╗  ██╗███████╗████████╗
    ██║     ╚██╗██╔╝██╔══██╗      ████╗ ████║██╔══██╗██╔══██╗██║ ██╔╝██╔════╝╚══██╔══╝
    ██║      ╚███╔╝ ██████╔╝█████╗██╔████╔██║███████║██████╔╝█████╔╝ █████╗     ██║
    ██║      ██╔██╗ ██╔══██╗╚════╝██║╚██╔╝██║██╔══██║██╔══██╗██╔═██╗ ██╔══╝     ██║
    ███████╗██╔╝ ██╗██║  ██║      ██║ ╚═╝ ██║██║  ██║██║  ██║██║  ██╗███████╗   ██║
    ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝      ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝   ╚═╝

    LXR Core - Market

    The second-hand market. A broker at each town takes goods on
    consignment: a citizen lists what they carry at a price, the broker
    keeps a cut, anyone browsing the stalls can buy, and the seller collects
    what was earned at any broker. Listings run out after a while and the
    goods come back to whoever listed them. Everything is a core catalog
    item; the ledger value is shown beside the asking price so buyers know
    a bargain from a robbery.

    Brand:       LXRCore — Lux Empire eXperience RedM Core
    Product:     wolves.land / The Land of Wolves
    Developer:   iBoss21 / LXRCore
    Website:     https://www.lxrcore.com
    Discord:     https://discord.gg/GAhk8cgXe9
    GitHub:      https://github.com/LXRCore

    Version: 3.0.0
    Performance Target: 0.00 ms idle (interact points; one 10-minute expiry tick on the server)

    © 2026 iBoss21 / LXRCore | lxrcore.com | All Rights Reserved
]]

Config = Config or {}

-- ████████████████████████████████████████████████████████████████████████████████
-- ████████████████████████ LANGUAGE ██████████████████████████████████████████████
-- ████████████████████████████████████████████████████████████████████████████████
Config.Lang = 'en'

-- ████████████████████████████████████████████████████████████████████████████████
-- ████████████████████████ BROKERS ═══════════════════════════════════════════════
-- ████████████████████████████████████████████████████████████████████████████████
Config.Brokers = {
    { id = 'valentine',  label = 'Valentine Market Stalls',   coords = vector3(-322.40, 782.60, 118.20), heading = 180.0, ped = 'u_m_m_valauctionboss_01', blip = true },
    { id = 'saintdenis', label = 'Saint Denis Market',         coords = vector3(2725.30, -1283.90, 49.20), heading = 90.0,  ped = 'u_m_m_sdcustomsexchanger_01', blip = true },
    { id = 'rhodes',     label = 'Rhodes Trading Post',        coords = vector3(1325.60, -1290.80, 77.30), heading = 270.0, ped = 'u_m_m_rhdgenstoreowner_01', blip = true },
}

-- ████████████████████████████████████████████████████████████████████████████████
-- ████████████████████████ THE STALLS ════════════════════════════════════════════
-- ████████████████████████████████████████████████████████████████████████████████
Config.Market = {
    account = 'cash',
    cut = 0.08,                  -- the broker's share of every sale
    listingFee = 0.05,           -- paid when listing, kept even if nothing sells
    days = 7,                    -- a listing runs this long, then the goods return to the seller's shelf here
    maxListings = 8,             -- per citizen
    minPrice = 0.01, maxPrice = 500.00,
    illegal = false,             -- brokers refuse illegal catalog items (the fence is for that)
    excludeCategories = { 'document', 'key', 'currency' },
    shared = true,               -- one market across all brokers (false: each broker has its own stalls)
}

Config.Security = { rateLimit = { windowMs = 2000, burst = 6 }, maxDistance = 4.0, promptDistance = 2.5, images = 'nui://lxr-inventory/html/images/' }
Config.Debug = { printBanner = true, log = true }
