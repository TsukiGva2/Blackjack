local __c=0
function iota()
    __c = __c + 1
    return __c
end

local Animation = {
    const = {
        TRANSFORM = iota(),
        SHEET     = iota(),
    },
}

Animation.fps = 24

function Animation.new(animation_options)
    local animation = animations_options 

    animations.playing = false

    if animation.TYPE == Animations.const.types.SHEET then
        local image = animation.image

        animation.quads = {}

        for y = 0, image:getHeight() - h, h do
            for x = 0, image:getWidth() - w, w do
                table.insert(animation.quads,
                    love.graphics.newQuad(x, y, w, h,
                        image:getDimensions()))
            end
        end

        animation.frames = animation.frames or #animation.quads
    end

    animation.timer = 0
    animation.speed = animation.speed or 1
    animation.loop  = animation.loop or false

    return animation
end

function Animation.update_sprite_sheet_anim()
    local frame_time = 1 / Animation.fps

    while animation.timer >= frame_time do
        animation.timer = animation.timer - frame_time
        animation.frame = animation.frame + 1

        if animation.frame > animation.frames then
            if animation.loop then
                animation.frame = 1
            else
                animation.playing = false
                animation.frame = 1
            end
        end
    end
end

function Animation.update(animation, dt)
    if not animation.playing then return end

    animation.timer = animation.timer + dt * animation.speed

    if animation.TYPE == Animations.const.types.SHEET then
        Animation.update_sprite_sheet_anim(animation)
    end

    if animation.TYPE == Animations.const.types.TRANSFORM then
        animation:STEP(dt)
    end
end

function Animation.check(animation, data)
    animation:check(data)
end

function Animation.draw(animation, x, y)
    love.graphics.draw(animation.image,
        animation.quads[animation.frame], x, y, 0, 0.5, 0.5)
end

return Animation

