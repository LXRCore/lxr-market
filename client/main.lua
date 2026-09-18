--[[ ═══════════════════════════════════════════════════════════════════════════
     LXR-MARKET — Client: the broker, the stalls
     © 2026 iBoss21 / LXRCore — All Rights Reserved
     ═══════════════════════════════════════════════════════════════════════════ ]]

local LXRCore = exports['lxr-core']:GetCoreObject()
local LXR = exports['lxr-core']:GetLXR()
local N = Citizen.InvokeNative
local brokers, open, current = {}, false, nil

local function toast(key, kind, vars) LXRCore.Notify(Lang:t(key, vars), kind or 'info') end
local function page(action, payload) SendNUIMessage({ action = action, payload = payload, brand = LXRCore.Brand, lang = Config.Lang, locale = Lang.bundle(), images = Config.Security.images }) end
local function close() if not open then return end open = false current = nil SetNuiFocus(false, false) page('close') end
local function openStalls(b)
    if open then return end
    local ok, data = LXR.RPC.Server('lxr-market:open', b.id)
    if not ok then return toast('error.' .. tostring(data), 'error') end
    open = true current = b
    SetNuiFocus(true, true)
    page('open', data)
end
local function relay(name, ...)
    local ok, res, extra = LXR.RPC.Server(name, current.id, ...)
    if not ok then toast('error.' .. tostring(res), 'error', { amount = extra and ('%.2f'):format(extra) }) return { ok = false } end
    return { ok = true, data = res, extra = extra }
end

RegisterNUICallback('close', function(_, cb) close() cb({ ok = true }) end)
RegisterNUICallback('list', function(d, cb) if not current then return cb({ ok = false }) end local r = relay('lxr-market:list', d.slot, d.amount, d.price) if r.ok then toast('info.listed', 'success') end cb(r) end)
RegisterNUICallback('buy', function(d, cb) if not current then return cb({ ok = false }) end local r = relay('lxr-market:buy', d.id) if r.ok then toast('info.bought', 'success') end cb(r) end)
RegisterNUICallback('cancel', function(d, cb) if not current then return cb({ ok = false }) end cb(relay('lxr-market:cancel', d.id)) end)
RegisterNUICallback('collect', function(_, cb) if not current then return cb({ ok = false }) end local r = relay('lxr-market:collect') if r.ok and r.extra then toast('info.collected', 'success', { amount = ('%.2f'):format(r.extra.money or 0), items = r.extra.items or 0 }) end cb(r) end)

local function spawnBroker(b)
    local model = joaat(b.ped)
    if not IsModelValid(model) then return end
    RequestModel(model)
    local t = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < t do Wait(10) end
    if not HasModelLoaded(model) then return end
    local ped = CreatePed(model, b.coords.x, b.coords.y, b.coords.z - 1.0, b.heading or 0.0, false, false, false, false)
    N(0x283978A15512B2FE, ped, true)
    SetEntityInvincible(ped, true) SetBlockingOfNonTemporaryEvents(ped, true) FreezeEntityPosition(ped, true)
    SetModelAsNoLongerNeeded(model)
    brokers[b.id] = ped
    exports['lxr-interact']:AddEntity('lxr-market:' .. b.id, ped, { label = b.label, distance = Config.Security.promptDistance, options = { { label = Lang:t('ui.browse'), key = 'J', onSelect = function() openStalls(b) end } } })
end
local function removeBroker(b)
    local ped = brokers[b.id]
    if not ped then return end
    exports['lxr-interact']:Remove('lxr-market:' .. b.id)
    if DoesEntityExist(ped) then DeleteEntity(ped) end
    brokers[b.id] = nil
end

CreateThread(function()
    while GetResourceState('lxr-interact') ~= 'started' do Wait(1000) end
    for _, b in ipairs(Config.Brokers) do
        if b.blip then
            local bl = N(0x554D9D53F696D002, 1664425300, b.coords.x, b.coords.y, b.coords.z)
            if bl and bl ~= 0 then N(0x74F74D3207ED525C, bl, joaat('blip_shop_market'), true) N(0x9CB1A1623062F402, bl, b.label) end
        end
    end
    while true do
        if LocalPlayer.state.isLoggedIn then
            local pos = GetEntityCoords(PlayerPedId())
            for _, b in ipairs(Config.Brokers) do
                local d = #(pos - b.coords)
                if d < 60.0 and not brokers[b.id] then spawnBroker(b) elseif d > 80.0 and brokers[b.id] then removeBroker(b) end
            end
        end
        Wait(2000)
    end
end)

RegisterNetEvent('lxr:client:unloaded', function() close() for _, b in ipairs(Config.Brokers) do removeBroker(b) end end)
AddEventHandler('onResourceStop', function(res) if res == GetCurrentResourceName() then close() for _, b in ipairs(Config.Brokers) do removeBroker(b) end end end)
exports('IsOpen', function() return open end)
