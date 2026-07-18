--[[
    client/main.lua
    ---------------
    Drives the Bitirim spawn selector.

    Flow (kicked off by qbx_core after the character is loaded):
        qb-spawn:client:setupSpawns
            -> collect spawn options (config + last location)
            -> park the ped, hide radar/HUD, start the cinematic camera
            -> open the NUI with a cursor
            -> on click: fade, fire the framework's loaded events, teleport

    The load/teleport sequence deliberately mirrors stock qbx_spawn so nothing
    downstream (jobs, HUD, bitirim_stranger's ready handshake) notices a
    difference.
]]

local Cfg = BitirimSpawn.Config

local spawns = {}
local previewCam
local isOpen = false

local function log(...)
    if Cfg.debug then print('[bitirim_spawn]', ...) end
end

---------------------------------------------------------------------------
-- CAMERA
---------------------------------------------------------------------------

local function startCamera()
    local c = Cfg.camera
    previewCam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA',
        c.coords.x, c.coords.y, c.coords.z, 0.0, 0.0, 0.0, c.fov, false, 0)
    PointCamAtCoord(previewCam, c.lookAt.x, c.lookAt.y, c.lookAt.z)
    SetCamActive(previewCam, true)
    RenderScriptCams(true, false, 0, true, true)

    -- Slow orbit so the shot breathes instead of sitting dead still.
    if (c.driftSpeed or 0) > 0 then
        CreateThread(function()
            local angle = 0.0
            while DoesCamExist(previewCam) and isOpen do
                angle = (angle + c.driftSpeed * 0.016) % 360.0
                local rad = math.rad(angle)
                SetCamCoord(previewCam,
                    c.coords.x + math.cos(rad) * c.driftRadius,
                    c.coords.y + math.sin(rad) * c.driftRadius,
                    c.coords.z)
                PointCamAtCoord(previewCam, c.lookAt.x, c.lookAt.y, c.lookAt.z)
                Wait(16)
            end
        end)
    end
end

local function stopCamera()
    if not previewCam then return end
    SetCamActive(previewCam, false)
    DestroyCam(previewCam, true)
    RenderScriptCams(false, false, 0, true, true)
    previewCam = nil
end

---------------------------------------------------------------------------
-- HUD
---------------------------------------------------------------------------

local function setHudVisible(visible)
    if not Cfg.hideHud then return end
    TriggerEvent(Cfg.hudEvent, visible)
end

---------------------------------------------------------------------------
-- UI
---------------------------------------------------------------------------

local function openUI()
    isOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        title = Cfg.title,
        brand = Cfg.brand,
        options = spawns,
    })
end

local function closeUI()
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

---------------------------------------------------------------------------
-- SPAWNING
---------------------------------------------------------------------------

local function doSpawn(index)
    local spawnData = spawns[index]
    if not spawnData then return end

    closeUI()
    DoScreenFadeOut(Cfg.fadeOut)
    while not IsScreenFadedOut() do Wait(0) end

    -- Same order stock qbx_spawn uses — the framework expects these first.
    TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
    TriggerEvent('QBCore:Client:OnPlayerLoaded')

    -- Hand streaming back to the player before we move them.
    ClearFocus()

    FreezeEntityPosition(cache.ped, false)
    DisplayRadar(true)
    setHudVisible(true)

    if spawnData.propertyId then
        TriggerServerEvent('qbx_properties:server:enterProperty',
            { id = spawnData.propertyId, isSpawn = true })
    else
        SetEntityCoords(cache.ped, spawnData.x, spawnData.y, spawnData.z, false, false, false, false)
        SetEntityHeading(cache.ped, spawnData.w or 0.0)

        -- Wait for ground collision so the player can't fall through the map.
        local deadline = GetGameTimer() + 5000
        RequestCollisionAtCoord(spawnData.x, spawnData.y, spawnData.z)
        while not HasCollisionLoadedAroundEntity(cache.ped) and GetGameTimer() < deadline do
            RequestCollisionAtCoord(spawnData.x, spawnData.y, spawnData.z)
            Wait(0)
        end
    end

    -- The ped was hidden for the selection shot — make it visible again.
    -- Missing this leaves every player invisible to everyone, including
    -- themselves, since each client hides its own networked ped.
    SetEntityVisible(cache.ped, true, false)

    stopCamera()
    Wait(200)
    DoScreenFadeIn(Cfg.fadeIn)
    log('spawned at', spawnData.label)
end

RegisterNUICallback('bitirim_spawn:select', function(data, cb)
    cb('ok')
    if not isOpen then return end
    doSpawn(tonumber(data and data.index) or 1)
end)

---------------------------------------------------------------------------
-- ENTRY POINT
---------------------------------------------------------------------------

RegisterNetEvent('qb-spawn:client:setupSpawns', function()
    spawns = {}

    -- 1. Configured spawn points, in config order.
    for i = 1, #Cfg.spawns do
        local s = Cfg.spawns[i]
        spawns[#spawns + 1] = {
            label = s.label,
            icon = s.icon,
            x = s.coords.x, y = s.coords.y, z = s.coords.z, w = s.coords.w,
        }
    end

    -- 2. The player's last location, via qbx_spawn's existing server callback.
    if Cfg.lastLocation.enabled then
        local lastCoords, lastPropertyId = lib.callback.await('qbx_spawn:server:getLastLocation')
        if lastCoords then
            spawns[#spawns + 1] = {
                label = Cfg.lastLocation.label,
                icon = Cfg.lastLocation.icon,
                x = lastCoords.x, y = lastCoords.y, z = lastCoords.z, w = lastCoords.w,
                propertyId = lastPropertyId,
            }
        end
    end

    -- Park the player out of sight while they choose.
    FreezeEntityPosition(cache.ped, true)
    SetEntityVisible(cache.ped, false, false)
    DisplayRadar(false)
    setHudVisible(false)

    startCamera()

    -- The engine streams around the ped, not the camera. Without moving the
    -- streaming focus the scenery behind the cards never loads and renders as
    -- flat, untextured geometry.
    local cam = Cfg.camera
    SetFocusPosAndVel(cam.lookAt.x, cam.lookAt.y, cam.lookAt.z, 0.0, 0.0, 0.0)
    Wait(cam.streamWait or 1500)

    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    DoScreenFadeIn(Cfg.fadeIn)

    openUI()
    log('selector opened with', #spawns, 'options')
end)

-- qbx_core fires this alongside setupSpawns; stock qbx_spawn ignores it too.
RegisterNetEvent('qb-spawn:client:openUI', function() end)

-- Safety: never leave the player stuck with a locked cursor.
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if isOpen then
        SetNuiFocus(false, false)
        ClearFocus()
        stopCamera()
        FreezeEntityPosition(cache.ped, false)
        SetEntityVisible(cache.ped, true, false)
        DisplayRadar(true)
    end
end)
