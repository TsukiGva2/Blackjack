local Animation = {}

Animation.fps = 24

function Animation.new(image, w, h, frames, speed)
    local animation = {}

    animation.image = image
    animation.quads = {}

    animation.playing = false

    for y = 0, image:getHeight() - h, h do
        for x = 0, image:getWidth() - w, w do
            table.insert(animation.quads,
                love.graphics.newQuad(x, y, w, h,
                    image:getDimensions()))
        end
    end

    animation.timer = 0
    animation.frame = 1

    animation.frames = frames or #animation.quads
    animation.speed = speed or 1

    return animation
end

function Animation.update(animation, dt)
    if not animation.playing then return end

    animation.timer = animation.timer + dt * animation.speed
    local frame_time = 1 / Animation.fps

    while animation.timer >= frame_time do
        animation.timer = animation.timer - frame_time
        animation.frame = animation.frame + 1

        if animation.frame > animation.frames then
            animation.frame = 1
        end
    end
end

function Animation.draw(animation, x, y)
    love.graphics.draw(animation.image,
        animation.quads[animation.frame], x, y, 0, 0.5, 0.5)
end

return Animation

