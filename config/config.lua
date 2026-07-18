--[[
    config/config.lua
    -----------------
    Everything about the spawn screen is configured here. Pure data, no logic.
]]

BitirimSpawn = {}

BitirimSpawn.Config = {
    debug = false,

    -- Heading shown above the cards. Keep it short.
    title = 'Spawn Location',
    brand = 'BITIRIM',

    ---------------------------------------------------------------------------
    -- SPAWN POINTS
    -- Listed first, in this order. The player's last location is appended
    -- automatically as the final option (see `lastLocation` below).
    ---------------------------------------------------------------------------
    spawns = {
        {
            id = 'hotel',
            label = 'Hotel',
            icon = 'hotel',                                  -- see web/js/app.js ICONS
            coords = vec4(-1279.62, 305.4, 63.98, 150.59),
        },
    },

    -- The "Last Location" entry. Set enabled = false to drop it entirely.
    lastLocation = {
        enabled = true,
        label = 'Last Location',
        icon = 'pin',
    },

    ---------------------------------------------------------------------------
    -- CINEMATIC CAMERA
    -- A slow drifting shot while the player chooses. Tune coords/lookAt to
    -- frame whatever view you want behind the cards.
    ---------------------------------------------------------------------------
    camera = {
        coords = vec3(-1295.0, 288.0, 78.0),        -- where the camera sits
        lookAt = vec3(-1279.62, 305.4, 66.0),       -- what it points at
        fov = 45.0,

        -- Gentle orbit so the shot never feels static. 0 disables the drift.
        driftSpeed = 0.35,      -- degrees per second
        driftRadius = 4.0,      -- metres of horizontal sway

        -- The engine streams the world around the PLAYER, not the camera, so
        -- we move the streaming focus to the shot and wait for it to load.
        -- Raise this if the scenery still looks flat/untextured on slow disks.
        streamWait = 1500,      -- ms
    },

    ---------------------------------------------------------------------------
    -- INTEGRATION
    ---------------------------------------------------------------------------
    -- Hide bitirim_hud while the selector is open (ID / cash / bank / clock,
    -- the health-armour-food-water bars and the street-name pin).
    hideHud = true,
    hudEvent = 'bitirim_hud:client:setVisible',

    -- Fade timings (ms).
    fadeOut = 600,
    fadeIn = 800,
}
