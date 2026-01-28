Queue = {}

function Queue.new()
    return {first = 0, last = -1}
end

function Queue.push(q, v)
    -- Prevent duplicates
    for _, val in ipairs(q) do
        if val == v then
            return false
        end
    end

    local last = q.last + 1
    q.last = last
    q[last] = v
end

function Queue.peek(q)
    local first = q.first
    if first > q.last then return nil end
    return q[first]
end

function Queue.pop(q)
    local first = q.first
    if first > q.last then error('list is empty') end
    local v = q[first]
    q[first] = nil
    q.first = first + 1
    return v
end

function Queue.empty(q)
    if q.first > q.last then
        return true
    end

    return false
end

return Queue
