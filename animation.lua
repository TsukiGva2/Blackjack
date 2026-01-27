
local __c=0
local function iota()
    __c = __c + 1
    return __c
end

local Animation = {
    const = {
        types = {
            NONE        = iota(), -- Dummy
            SPRITESHEET = iota(), -- Single spritesheet image
            IMAGELIST   = iota(), -- List of frames
            EFFECT      = iota(), -- Shaders/special effects
            MOVEMENT    = iota(), -- Physical animation, e.g. hover.
        },
    },
}

local FRAME_TIME = 1 / 24

function Animation.new()
    return {
        kind = Animation.const.types.NONE,
        time = 0,
        frame = 0,
        frames = {},
    }
end

function Animation.update(anim, dt)
    -- 24 fps is every 1/24th s
    
    anim.time = anim.time + dt

    if anim.time >= FRAME_TIME  then
        anim.time = anim.time - FRAME_TIME
        anim.frame = anim.frame + 1
    end

    anim.frame = anim.frame % #anim.frames
end

