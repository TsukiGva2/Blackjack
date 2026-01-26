Queue = {}

function Queue.new()
    return {first = 0, last = -1}
end

function Queue.push(q, v)
    local last = q.last + 1
    q.last = last
    q[last] = v
end

function Queue.pop(q)
    local first = q.first
    if first > q.last then error('list is empty') end
    local v = q[first]
    q[first] = nil
    q.first = first + 1
    return v
end

return Queue
