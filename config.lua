Config = {}

---------------------------------------------------------------------
-- General
---------------------------------------------------------------------
Config.Locale = 'en'             -- 'en' or 'tr' (see locales/)
Config.Framework = 'auto'        -- 'auto', 'qbox', 'qbcore', 'esx' or 'standalone'
Config.Inventory = 'auto'        -- 'auto', 'ox_inventory', 'framework' (qb-inventory / ESX usable items) or 'none'
Config.Notify = 'framework'      -- 'framework', 'ox_lib' or 'native' (framework falls back to ox_lib)
Config.UsableItemDelay = 5000    -- ms to wait before hooking framework usable items, so consumable scripts register first

---------------------------------------------------------------------
-- Alcohol & stages
---------------------------------------------------------------------
Config.MaxAlcohol = 100          -- Alcohol points are always clamped between 0 and this value

Config.Stages = {
    -- Points needed to enter stage 1 (buzzed), 2 (drunk), 3 (heavily drunk) and 4 (blackout range)
    Thresholds = { 20, 40, 70, 90 },
    Hysteresis = 4,              -- A stage is kept until points drop this far below its threshold
    IntoxicatedFrom = 1,         -- Stage from which the 'intoxicated' state bag becomes true
}

Config.ResetOnDeath = true       -- Clear intoxication when the player dies (verified server-side)

---------------------------------------------------------------------
-- Metabolism (server-side)
---------------------------------------------------------------------
Config.Metabolism = {
    Interval = 15,               -- Seconds between metabolism ticks
    -- Points removed per tick for each stage (before profile / tolerance / recovery modifiers)
    Rates = { [0] = 1, [1] = 1, [2] = 2, [3] = 3, [4] = 3 },
}

---------------------------------------------------------------------
-- Tolerance (optional, per character)
---------------------------------------------------------------------
Config.Tolerance = {
    Enabled = false,
    Persist = true,              -- Save tolerance per character (independent from alcohol persistence)
    MaxReduction = 0.30,         -- Max reduction of alcohol gained from drinks at 100 tolerance (0.30 = 30%)
    MetabolismBonus = 0.15,      -- Extra metabolism speed at 100 tolerance (0.15 = 15% faster)
    Gain = 2.0,                  -- Tolerance gained per drinking session step (shrinks as tolerance grows)
    GainCooldown = 900,          -- Seconds between tolerance gains (prevents grinding)
    GainMinAlcohol = 40,         -- Tolerance only grows when the player is at least this drunk
    DecayAfter = 86400,          -- Seconds without drinking before tolerance starts to decrease
    DecayPerDay = 5.0,           -- Tolerance lost per day after DecayAfter
}

---------------------------------------------------------------------
-- BAC (gameplay abstraction, not medically accurate)
---------------------------------------------------------------------
Config.BAC = {
    Max = 0.30,                  -- BAC reported at max alcohol points (linear mapping)
    Decimals = 3,
    -- Optional custom mapping: Convert = function(points) return points / 100 * 0.3 end
    Convert = nil,
}

---------------------------------------------------------------------
-- Drink profiles
-- Stage tables are indexed 1-4; a missing stage uses the closest lower value.
---------------------------------------------------------------------
Config.DefaultProfile = 'shot'

Config.Profiles = {
    beer = {
        label = 'Beer',
        alcoholMultiplier = 1.0,     -- Multiplies the alcohol gained from drinks with this profile
        metabolismMultiplier = 0.85, -- < 1.0 lasts longer, > 1.0 wears off faster
        nausea = 0.7,                -- Nausea tendency (scales how often nausea waves happen)
        blackout = 0.6,              -- Blackout tendency (scales blackout chance)
        burp = true,                 -- Chance to burp after drinking
        timecycle = 'spectator5',
        strength = { 0.30, 0.55, 0.75, 0.90 },
        shake = { 0.15, 0.40, 0.70, 0.90 },
        clipset = { nil, 'move_m@drunk@slightlydrunk', 'move_m@drunk@moderatedrunk' },
    },
    wine = {
        label = 'Wine',
        alcoholMultiplier = 1.0,
        metabolismMultiplier = 1.0,
        nausea = 0.8,
        blackout = 0.8,
        timecycle = 'cinema',
        strength = { 0.35, 0.60, 0.85, 1.0 },
        shake = { 0.20, 0.50, 0.90, 1.10 },
        clipset = { nil, 'move_m@drunk@slightlydrunk', 'move_m@drunk@moderatedrunk' },
    },
    cocktail = {
        label = 'Cocktail',
        alcoholMultiplier = 1.0,
        metabolismMultiplier = 1.0,
        nausea = 1.0,
        blackout = 1.0,
        timecycle = 'drug_wobbly',
        strength = { 0.30, 0.55, 0.80, 0.90 },
        shake = { 0.30, 0.70, 1.20, 1.40 },
        clipset = { nil, 'move_m@drunk@slightlydrunk', 'move_m@drunk@moderatedrunk' },
    },
    shot = {
        label = 'Shot',
        alcoholMultiplier = 1.0,
        metabolismMultiplier = 1.1,
        nausea = 1.1,
        blackout = 1.1,
        timecycle = 'Drunk',
        strength = { 0.45, 0.75, 1.0 },
        shake = { 0.35, 0.80, 1.40, 1.60 },
        postfx = { [3] = 'DrugsTrevorClownsFightIn' },
        clipset = { nil, 'move_m@drunk@slightlydrunk', 'move_m@drunk@verydrunk' },
    },
    heavy = {
        label = 'Moonshine',
        alcoholMultiplier = 1.0,
        metabolismMultiplier = 1.0,
        nausea = 1.5,
        blackout = 1.5,
        tinnitus = true,             -- Ear ringing right after drinking
        timecycle = 'Drunk',
        strength = { 0.50, 0.90, 1.0 },
        shake = { 0.45, 1.00, 1.80, 2.00 },
        postfx = { [2] = 'DrugsTrevorClownsFightIn', [3] = 'DrugsMichaelAliensFightIn' },
        clipset = { nil, 'move_m@drunk@moderatedrunk', 'move_m@drunk@verydrunk' },
    },
}

---------------------------------------------------------------------
-- Drinks: item name = { alcohol = points, profile = profile name }
---------------------------------------------------------------------
Config.Drinks = {
    beer      = { alcohol = 6,  profile = 'beer' },
    wine      = { alcohol = 10, profile = 'wine' },
    champagne = { alcohol = 9,  profile = 'wine' },
    cocktail  = { alcohol = 12, profile = 'cocktail' },
    vodka     = { alcohol = 15, profile = 'shot' },
    whiskey   = { alcohol = 15, profile = 'shot' },
    tequila   = { alcohol = 15, profile = 'shot' },
    rum       = { alcohol = 14, profile = 'shot' },
    gin       = { alcohol = 14, profile = 'shot' },
    moonshine = { alcohol = 28, profile = 'heavy' },
}

---------------------------------------------------------------------
-- Recovery items
--   reduction  = alcohol points removed immediately
--   metabolism = { multiplier, duration } temporary faster metabolism (seconds)
--   nausea     = seconds added before the next nausea wave
---------------------------------------------------------------------
Config.RecoveryItems = {
    water  = { reduction = 8 },
    coffee = { reduction = 5, metabolism = { multiplier = 1.5, duration = 300 } },
    milk   = { reduction = 6, nausea = 120 },
    ayran  = { reduction = 10, nausea = 180 },
}

---------------------------------------------------------------------
-- Visual effects (client)
---------------------------------------------------------------------
Config.Effects = {
    Enabled = true,
    TransitionTime = 3000,       -- Milliseconds to fade between stages / profiles
    ShakeName = 'DRUNK_SHAKE',
    MaxShake = 2.0,              -- Largest shake value used in profiles (sets fade speed)
    MotionBlurStage = 2,         -- Stage from which motion blur and the ped drunk flag are enabled
    Pulses = true,               -- Short camera jolts for hiccups, nausea and vomiting
}

---------------------------------------------------------------------
-- Movement (client)
---------------------------------------------------------------------
Config.Movement = {
    Enabled = true,
    BlendTime = 1.0,             -- Clipset blend speed
    -- Return false to skip applying a drunk clipset (e.g. custom walk style systems)
    CanApply = function(ped) return true end,
    -- Called after the drunk clipset is removed; reapply custom walk styles here
    OnRestore = function(ped) end,
}

---------------------------------------------------------------------
-- Driving (client)
---------------------------------------------------------------------
Config.Driving = {
    Mode = 'sway',               -- 'off', 'sway', 'reduced_control' or 'inverted'
    MinStage = 2,                -- Stage from which driving is affected
    MinSpeed = 3.0,              -- m/s; slower vehicles are not affected
    HighSpeed = 30.0,            -- m/s; above this speed the sway is scaled down
    HighSpeedScale = 0.5,
    Sway = {
        Strength = { nil, 0.15, 0.30 },  -- Steering drift per stage
        Chance = 0.45,           -- Chance of starting a drift at each update
        IntervalMin = 1500,      -- ms between drift updates (update rate)
        IntervalMax = 3500,
        Smoothing = 0.03,        -- How quickly drift builds up and gets corrected (0-1)
    },
    ReducedControl = {           -- Used by 'reduced_control': short moments of delayed steering
        IntervalMin = 6000,
        IntervalMax = 14000,
        DurationMin = 200,
        DurationMax = 400,
    },
    Inverted = {                 -- Used by 'inverted' only
        MinStage = 3,
        Strength = 0.9,
    },
    Horn = {
        MinStage = 3,
        Chance = 0.10,           -- Chance per interval of an involuntary horn
        IntervalMin = 8000,
        IntervalMax = 20000,
    },
}

---------------------------------------------------------------------
-- Falling / stumbling (client)
---------------------------------------------------------------------
Config.Falling = {
    Enabled = true,
    MinStage = 3,
    CheckInterval = 1500,        -- ms between checks
    Cooldown = 12000,            -- ms between falls
    WalkChance = 0.04,
    RunChance = 0.15,
    WalkDuration = 1500,
    RunDuration = 2500,
}

---------------------------------------------------------------------
-- Nausea (scheduled by the server)
---------------------------------------------------------------------
Config.Nausea = {
    Enabled = true,
    MinAlcohol = 75,
    InitialDelay = { 15, 30 },   -- Seconds before the first wave once MinAlcohol is reached
    RepeatDelay = { 60, 120 },   -- Seconds between waves
    SuccessDelay = 150,          -- Seconds of relief after resisting
    PostponeDelay = 15,          -- Retry delay when the player is in a state that cannot be interrupted
    ResponseTimeout = 20,        -- Seconds the client has to answer a nausea wave
    VomitChance = 0.6,           -- Used when the skill check is disabled or unavailable
    SkillCheck = {
        Enabled = true,          -- Uses ox_lib skillCheck
        Difficulty = { { areaSize = 38, speedMultiplier = 1.6 } },
        Inputs = { 'e' },
    },
    ReactionAnim = { dict = 're@construction', name = 'out_of_breath', duration = 2500 },
}

---------------------------------------------------------------------
-- Vomiting
---------------------------------------------------------------------
Config.Vomit = {
    HealthLoss = 5,
    AlcoholReduction = 5,
    Cooldown = 45,               -- Seconds between vomits
    AnimDict = 'missheistpaletoscore1leadinout',
    AnimName = 'trv_puking_leadout',
    Duration = 5000,
    PtfxAsset = 'scr_paletoscore',
    PtfxName = 'scr_trev_puke',
    PtfxDuration = 2500,
}

---------------------------------------------------------------------
-- Blackout (scheduled by the server at stage 4)
---------------------------------------------------------------------
Config.Blackout = {
    Enabled = true,
    Chance = 0.5,                -- Chance per metabolism tick while in stage 4 (scaled by profile)
    Duration = 8,                -- Seconds spent unconscious
    Cooldown = 180,              -- Seconds between blackouts
    RetryDelay = 20,             -- Seconds before retrying when the player cannot black out (e.g. driving)
    AlcoholReduction = 10,
    HealthLoss = 10,
    FadeOut = 1500,              -- ms
    FadeIn = 2000,               -- ms
}

---------------------------------------------------------------------
-- Voice (pma-voice, optional)
-- Other players hear an intoxicated player's voice muffled. Radio and phone effects are not touched.
---------------------------------------------------------------------
Config.Voice = {
    Enabled = true,
    Resource = 'pma-voice',
    Stages = { [2] = 'daddy_drunk_moderate', [3] = 'daddy_drunk_heavy', [4] = 'daddy_drunk_heavy' },
    Submixes = {
        daddy_drunk_moderate = { freqLow = 120.0, freqHigh = 950.0, fudge = 0.3, rmMix = 0.08 },
        daddy_drunk_heavy    = { freqLow = 80.0,  freqHigh = 480.0, fudge = 0.6, rmMix = 0.15 },
    },
}

---------------------------------------------------------------------
-- Audio (client)
---------------------------------------------------------------------
Config.Audio = {
    Hiccups = { Enabled = true, MinStage = 1, MaxStage = 2, IntervalMin = 35000, IntervalMax = 65000, Speech = 'GENERIC_SHOCK' },
    Groans = { Enabled = true, MinStage = 3, IntervalMin = 45000, IntervalMax = 90000, Speech = 'GENERIC_GROAN' },
    Burp = { Enabled = true, Chance = 0.5, Speech = 'GENERIC_GROAN' },
    Vomit = { Speech = 'CHOKE' },
    Heartbeat = { Enabled = true, MinAlcohol = 80, SoundSet = 'Special_Abilities_Sounds', SoundName = 'Heartbeat_Loop' },
    Tinnitus = { Enabled = true, MinAlcohol = 75, Cooldown = 45000, Duration = 4000, SoundSet = 'WastedSounds', SoundName = 'Bed' },
    BlackoutScene = 'FBI_HEIST_H5_MUTE_AMBIENCE_SCENE',  -- Audio scene used to muffle the world during blackout (nil to disable)
}

---------------------------------------------------------------------
-- Persistence (resource KVP, keyed by character)
---------------------------------------------------------------------
Config.Persistence = {
    Enabled = true,
    OfflineMetabolism = true,    -- Apply metabolism for the time the player was offline
    SaveInterval = 300,          -- Seconds between autosaves of loaded players
}

---------------------------------------------------------------------
-- Forced animation safety
-- Vomiting, blackouts, nausea and falls are skipped or postponed while any of these is true.
---------------------------------------------------------------------
Config.BlockingStates = { 'isDead', 'inLastStand', 'isCuffed', 'isHandcuffed', 'handcuffed', 'isEscorted', 'isEscorting', 'isCarried', 'isCarrying' }

-- Extra check for your own systems. Return true to block forced animations.
Config.IsActionBlocked = function(ped) return false end

---------------------------------------------------------------------
-- Debug
---------------------------------------------------------------------
Config.AdminCommand = true       -- /setalcohol [id] [points] [profile] for admins
Config.Debug = false             -- Enables debug output and the test commands /testnausea, /testvomit, /testblackout
Config.DebugPermission = 'group.admin'  -- ACE principal allowed to use /setalcohol and the test commands
