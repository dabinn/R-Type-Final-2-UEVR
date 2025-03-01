-- File:    ds-uevr-game-rtype-final2.lua
-- Brief:   DS UEVR plugin for R-Type Final 2
-- Details: This plugin automatically adjusts the camera distance for optimal 
--          viewing in each level of R-Type Final 2. It also includes custom 
--          parameters for the DS UVER Free Camera, enhancing the overall 
--          enjoyment of the game.
-- License: MIT
-- Version: 2.0.0
-- Date:    2025/02/13
-- Author:  Dabinn Huang @DSlabs
-- Powered by TofuExpress --

-- Initialize the library and global variables
print("---------- ds-uevr-game-rtype-final2 init ----------")
local uId ="DS-RTYPE" -- Unique ID for this plugin
local lib=require("ds-uevr/libcommon")
local events=require("ds-uevr/libevents")
local eventgen=require("ds-uevr/libeventgen")
local te=TofuExpress

local function uprint(...)
    lib.uprint(uId, ...)
end


-- load  freecam
if not te.freecam then -- Check if freecam lib already loaded by another plugin
    uprint("Custom Free Camera")
end
local freecam=require("ds-uevr/libfreecam")
local cfg=freecam.extCfg -- External configuration for the freecam
local camType = freecam.camType


-- freecam customization
uprint("Customizing Free Camera")
cfg.opt = {
    enableGuiToggle = true, -- Disable game GUI when free camera is enabled
    recenterVROnCameraReset = true, -- Reset the camera and recenter VR at the same time
    freeCamKeepPosition = true,  -- Don't reset the free camera's position while switching cameras.
}


-- Enums
local sceneType={
    Default=0,
    FreeCam=1, -- not really a scene, but we use it to set the contorls
    InStage=2, -- Includes Normal Stage and Competition
    Cinematic=3,
    Hangar=4,
    HangerDecal=5,
}

local sceneCfg = {}
sceneCfg[sceneType.FreeCam] = {
    camMode = camType.free,
    buttons = {
        active = "L3_held",
        deactive = "L3",
        resetCam = "R3",
        speedIncrease = "RB",
        speedDecrease = "LB",
    },
    -- use the default axes Config
}
sceneCfg[sceneType.InStage] = { -- Used by InStage/Competition
    camMode = camType.orbit,
    buttons = {
        camDolly = "RB_held",
        camOffset= "Back",
        resetCam = "R3",
    },
    axes = {
        rot={"RX", "RY"},
    },
}
sceneCfg[sceneType.Hangar] = sceneCfg[sceneType.InStage] -- Same as InStage
sceneCfg[sceneType.HangerDecal] = {
    camMode = camType.orbit,
    buttons = {
        moveBackward = "RB",
        camOffset= "Back",
        resetCam = "R3",
    },
    axes = {
        move={"", "RT"},
        rot={"RX", "RY"},
    },
}
sceneCfg[sceneType.Cinematic] = {
    camMode = camType.scene,
    buttons = {
        camOffset= "Back",
        speedIncrease = "RB",
        speedDecrease = "LB",
        resetCam = "R3",
    },
    axes = {
        move={"LX", "LY"},
        rot={"RX", "RY"},
        elev={"LTRT"},
    },
}

cfg.spd = {}
cfg.spd[camType.free] = {
    speedTotalStep = 10,
    move_speed_max = 50000, -- cm per second
    move_speed_min = 200,
    rotate_speed_max = 180, -- degrees per second
    rotate_speed_min = 90, -- degrees per second
    currMoveStep = 5,
    currRotStep = 5
}
cfg.spd[camType.orbit] = {
    speedTotalStep = 1, -- 1: no speed adjustment, only needs to set the max speed
    move_speed_max = 5000,
    rotate_speed_max = 90,
    currMoveStep = 1,
    currRotStep = 1
}
cfg.spd[camType.scene] = {
    speedTotalStep = 3, -- 1: no speed adjustment, only needs to set the max speed
    move_speed_max = 10000,
    move_speed_min = 50,
    rotate_speed_max = 90,
    rotate_speed_min = 90, -- degrees per second
    currMoveStep = 1,
    currRotStep = 1
}




UEVR_UObjectHook.activate()

local camOffests = {}
camOffests[sceneType.Default] = {
    Vector3f:new(0, 0, 0),
}
camOffests[sceneType.InStage] = {
    Vector3f:new(15000, 0, 0),
    Vector3f:new(20000, 0, 0),
    Vector3f:new(25000, 0, 0),
}
camOffests[sceneType.Cinematic] = {
    Vector3f:new(20, 0, 0),
    Vector3f:new(0, 0, 0),
    Vector3f:new(-2000, 0, 0),
}
camOffests[sceneType.HangerDecal] = {
    Vector3f:new(3000, 0, 0),
    Vector3f:new(5000, 0, 0),
    Vector3f:new(0, 0, 0),
}
local camOffsetsPresetNos = {} -- Remeber the last preset number for each scene


local scene = sceneType.Default
local lastScene = scene
local isInStage = false
local isInHanger = false
local viewTarget = nil

-- Cam offsets for each scene
local function updateCamOffsets()
    local presetNos = camOffsetsPresetNos
    if not presetNos[scene] then
        presetNos[scene] = 1
    end
    local presetNo = presetNos[scene]
    if scene == sceneType.InStage or scene == sceneType.Competition then
        -- set New cam offsets, and remember the last preset number for each scene
        presetNos[lastScene] = freecam.setCamOffsets(camOffests[sceneType.InStage], presetNo)
    elseif camOffests[scene] then -- Include sceneType.Default
        presetNos[lastScene] = freecam.setCamOffsets(camOffests[scene], presetNo)
    end
end

-- viewTarget

-- # In Hangar
-- Controller: E28PlayerController /Game/Level/Hangar/Hangar_pre.Hangar_pre.PersistentLevel.E28PlayerController_2147475868
-- Camera Manager: E28PlayerCameraManager /Game/Level/Hangar/Hangar_pre.Hangar_pre.PersistentLevel.E28PlayerCameraManager_2147475866
-- View Target: DefaultPawn /Game/Level/Hangar/Hangar_pre.Hangar_pre.PersistentLevel.DefaultPawn_2147475852

-- # In Hangar (changed)
-- Controller: E28PlayerController /Game/Level/Hangar/Hangar_pre.Hangar_pre.PersistentLevel.E28PlayerController_2147475868
-- Camera Manager: E28PlayerCameraManager /Game/Level/Hangar/Hangar_pre.Hangar_pre.PersistentLevel.E28PlayerCameraManager_2147475866
-- View Target: CameraActor /Game/Level/Hangar/Hangar_BG.Hangar_BG.PersistentLevel.CameraActor_1

-- # In HangerDecal
-- Controller/Camera Manager: Same as Hanger
-- View Target: DecalModel_C /Game/Level/Hangar/Hangar_BG.Hangar_BG.PersistentLevel.DecalModel_2

-- # Cinematic
-- Controller: ShooterPlayerController /Game/Level/st_01_01/stage_01_01_root.stage_01_01_root.PersistentLevel.erController_2147476387
-- Camera Manager: PlayerCameraManager /Game/Level/st_01_01/stage_01_01_root.stage_01_01_root.PersistentLevel.aManager_2147476385
-- View Target: ShooterPlayerController /Game/Level/st_01_01/stage_01_01_root.stage_01_01_root.PersistentLevel.ShooterPlayerController_2147476387

-- # Cinematic (Changed)
-- Controller: ShooterPlayerController /Game/Level/st_01_01/stage_01_01_root.stage_01_01_root.PersistentLevel.erController_2147476387
-- Camera Manager: PlayerCameraManager /Game/Level/st_01_01/stage_01_01_root.stage_01_01_root.PersistentLevel.aManager_2147476385
-- View Target: CineCameraActor /Game/Level/st_01_01/stage_01_01_root.stage_01_01_root.PersistentLevel.CineCameraActor_2147473764

-- # In stage
-- Controller: ShooterPlayerController /Game/Level/st_01_01/stage_01_01_root.stage_01_01_root.PersistentLevel.ShooterPlayerController_2147481244
-- Camera Manager: PlayerCameraManager /Game/Level/st_01_01/stage_01_01_root.stage_01_01_root.PersistentLevel.PlayerCameraManager_2147481242
-- View Target: ScreenCameraActor /Game/Level/st_01_01/stage_01_01_root.stage_01_01_root.PersistentLevel.ScreenCameraActor_2147481212

local function getViewTarget()
    -- In Stage: The correct viewTarget is "ScreenCameraActor" in stage mode
    -- In Hanger: viewTargets are not good, just use 0,0,0 instead.
    -- In HangerDecal: Temporarily set to normal CAM because it uses right stick.
    local view_target = nil
    local pawn = uevr.api:get_local_pawn(0)
    if pawn then
        local controller = pawn.Controller
        if controller ~= nil then
            -- uprint("Controller: " .. controller:get_full_name())
            local camera_manager = controller.PlayerCameraManager
            if camera_manager ~= nil then
                -- lib.lzprint("Camera Manager: " .. camera_manager:get_full_name())
                local view_target_struct = camera_manager.ViewTarget
                -- uprint("View Target Struct: " .. view_target_struct:get_full_name())
                if view_target_struct ~= nil then
                    view_target = view_target_struct.Target
                end
            end
        end
    end
    return view_target
end
local function updateViewTarget(freecamMode)
    local view_target = nil
    local pos = nil
    -- ViewTarget is only used by freecam Mode 2
    if freecamMode == 2 then
        if scene == sceneType.Hangar then
            pos = Vector3f:new(0, 0, 0)
            -- local hanger_pawn_c = uevr.api:find_uobject("Class /Script/Engine.DefaultPawn")
            -- local hanger_pawn = UEVR_UObjectHook.get_first_object_by_class(hanger_pawn_c)
            -- if hanger_pawn ~= nil then
            --     uprint("Hanger Pawn: " .. hanger_pawn:get_full_name())
            --     viewTarget = hanger_pawn
            --     local pos = viewTarget:K2_GetActorLocation()
            --     uprint("Hanger Pawn pos: " .. pos.X .. ", " .. pos.Y .. ", " .. pos.Z)
            --     freecam.setTargetPos(pos)
            -- end
        else
            view_target = getViewTarget()
            if view_target ~= nil then
                uprint("View Target: " .. view_target:get_full_name())
                pos = view_target:K2_GetActorLocation()
            end
        end
    end
    if view_target == nil then
        uprint("No View Target.")
    end
    viewTarget = view_target
    freecam.setViewTargetPos(pos)
end

local function sceneCamToggle(freecamMode)
    freecam:resetCam()
    -- UE: front=+x, right=+y, up=+z
    updateCamOffsets()
    updateViewTarget(freecamMode)
    freecam.camModeToggle(freecamMode)
    lastScene = scene
end
local function setSceneCofig(sceneConfig)
    freecam.setCamControl(sceneConfig.camMode, sceneConfig)
end
-- Just a convenience function for scene switching
-- Make sure you have correct sceneConfig, no additional checks here
local function sceneToggle(sceneConfig)
    setSceneCofig(sceneConfig)
    sceneCamToggle(sceneConfig.camMode)
end


-- on level changed
events:on('level_changed', function (new_level)
    -- All actors can be assumed to be deleted when the level changes
    local level_name = new_level:get_full_name()
    uprint("New level: " .. level_name)

    --[[ 
    Level name examples:
    Level /Game/Level/st_01_02/stage_01_02_root.stage_01_02_root.PersistentLevel <-- Stage mode
    Level /ST_0115/Level/st_01_15/stage_01_15_root.stage_01_15_root.PersistentLevel <-- Stage mode (Stage 4)
    Level /ST_0119/Level/st_01_19/Stage_01_19_root.Stage_01_19_root.PersistentLevel <-- Competition mode
    Level /Game/Level/title/title.title.PersistentLevel
    Level /Game/Level/Hangar/Hangar_pre.Hangar_pre.PersistentLevel <--- Hangar
    Level /Game/Level/Hangar/PilotCustom/PilotCustom_BG01.PilotCustom_BG01.PersistentLevel <-- Hanger/PilotCustom
    Level /Game/Level/Museum/Museum.Museum.PersistentLevel
    ]]
    scene = 0
    isInStage = false
    isInHanger = false
    if string.match(level_name, "^Level /Game/Level/st_%d+_%d+/stage_.+") then -- In Stage and Cinematic
        uprint("##### In Stage #####")
        isInStage = true -- Will check pawn to set camera later
    elseif string.match(level_name, "^Level /ST_%d+/Level/st_%d+_%d+/.+") then -- In Stage / Competition
        uprint("##### In Stage/Competition #####")
        isInStage = true -- Will check pawn to set camera later
    elseif string.match(level_name, "^Level /Game/Level/Hangar/.+") then -- In Hangar
        uprint("##### In Hangar #####")
        isInHanger = true -- Will check view_target to set Hanger/HangerDecal later
    else
        uprint("##### Out of Stage #####") -- Title, Museum, PilotCustom, Deca, etc
        scene = sceneType.Default
        sceneCamToggle(camType.default) -- Reset camera when exist stage
    end

end)

events:on('pawn_changed', function(pawn)
    if isInStage then
        local pawn_name = pawn:get_full_name()
        uprint("## Pawn Chaged: ".. pawn_name) 
        -- cutscene
        -- Pawn /Game/Level/st_01_01/stage_01_01_root.stage_01_01_root.PersistentLevel.Pawn_2147383444
        if string.match(pawn_name, "^Pawn /.+") then
            uprint("# In Cinematic.")
            scene = sceneType.Cinematic
            sceneCamToggle(sceneCfg[scene].camMode) -- No need to set sceneConfig again.
        else 
        -- if string.match(pawn_name, "^P%d+ /.+") then -- P001/P027/P042 ...etc
            uprint("# In Stage.")
            scene = sceneType.InStage
            sceneToggle(sceneCfg[scene])
        end
    end
end)

events:on('freecam_update_target_position', function ()
    if viewTarget ~= nil then  -- Only update pos when scene has been assigned a view target
        local pos = viewTarget:K2_GetActorLocation()
        freecam.setViewTargetPos(pos)
    end
end)

uevr.sdk.callbacks.on_post_engine_tick(function(engine, delta)
    -- Check if camera moved from hanger to decal room
    if isInHanger then
        local view_target = getViewTarget()
        if view_target ~= nil then
            -- DecalModel_C /Game/Level/Hangar/Hangar_BG.Hangar_BG.PersistentLevel.DecalModel_2
            if string.match(view_target:get_full_name(), "DecalModel_C /Game/Level/Hangar/.+") then -- In HangerDecal
                if scene ~= sceneType.HangerDecal then
                    uprint("# In HangerDecal")
                    scene = sceneType.HangerDecal
                    sceneToggle(sceneCfg[scene])
                end
            else
                if scene ~= sceneType.Hangar then
                    uprint("# In Hangar")
                    scene = sceneType.Hangar
                    sceneToggle(sceneCfg[scene])
                end
            end
        end
    end
end)

-- Initialize the plugin
lib.enableGUI(true) -- Prevent the GUI from being hidden by the last game session
-- Setup custom scene configurations first that will not be affected by scene changes
setSceneCofig(sceneCfg[sceneType.FreeCam])
setSceneCofig(sceneCfg[sceneType.Cinematic])

-- Initialize the freecam
freecam.init()

-- uevr.sdk.callbacks.on_script_reset(function()
-- end)

