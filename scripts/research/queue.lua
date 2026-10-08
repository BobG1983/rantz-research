local technology = require("scripts.research.technology")
local queue = {}
local capacity = 7

function queue.remove_capped(force, config)
    local remaining, changed = {}, false
    for _, tech in ipairs(force.research_queue) do
        if technology.is_target_reached(tech, config) then
            changed = true
        else
            remaining[#remaining + 1] = tech.name
        end
    end
    if changed then force.research_queue = remaining end
end

function queue.promote(force, name)
    local current = force.research_queue
    if not name or (current[1] and current[1].name == name) then return end
    local found
    for i, tech in ipairs(current) do
        if tech.name == name then found = i; break end
    end
    -- Never silently drop a manually queued technology to make room.
    if not found and #current >= capacity then return end
    local result = {name}
    for i, tech in ipairs(current) do
        if i ~= found then result[#result + 1] = tech.name end
    end
    force.research_queue = result
end

return queue
