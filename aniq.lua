local Animation = require("animation")
local Queue = require("queue")

local AniQ = {}

function AniQ.new()
    return Queue.new()
end

function AniQ.enqueue(aq, animation)
    Queue.push(aq, animation)
    animation.playing = true
end

function AniQ.update(aq, dt)
    local animation = Queue.peek(aq)
    if not animation then return end

    Animation.update(animation, dt)

    if not animation.playing then
        Queue.pop(aq)
    end
end

function AniQ.check(aq)
    local animation = Queue.peek(aq)
    if not animation then return end

    Animation.check(animation)
end

function AniQ.draw(aq)
    local animation = Queue.peek(aq)

    if not animation then return end

    Animation.draw(animation)
end

