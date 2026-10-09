local technology = require("scripts.research.technology")
local queue = {}
local capacity = 7

local function automatic_index(current, config)
    local found
    for i, tech in ipairs(current) do
        if tech.name == config.automatic_research then
            -- Duplicate levels cannot be distinguished by technology name.
            -- Preserve them all if a player or another mod has added duplicates.
            if found then config.automatic_research = nil; return end
            found = i
        end
    end
    if not found then config.automatic_research = nil; return end
    for i, tech in ipairs(current) do
        if i ~= found then
            for _, prerequisite in ipairs(technology.get_unresearched_prerequisites(tech)) do
                if prerequisite.name == config.automatic_research then
                    -- Player work depends on this entry, so it is now part of
                    -- their queue and must not be removed or moved behind them.
                    config.automatic_research = nil
                    return
                end
            end
        end
    end
    return found
end

local function write(force, current, names)
    if #current == #names then
        local same = true
        for i, tech in ipairs(current) do
            if tech.name ~= names[i] then same = false; break end
        end
        if same then return end
    end
    force.research_queue = names
end

function queue.remove_capped(force, config)
    local current = force.research_queue
    local automatic = automatic_index(current, config)
    if not automatic or not technology.is_target_reached(current[automatic], config) then return end
    local remaining = {}
    for i, tech in ipairs(current) do
        if i ~= automatic then remaining[#remaining + 1] = tech.name end
    end
    config.automatic_research = nil
    write(force, current, remaining)
end

function queue.promote(force, name, config)
    local current = force.research_queue
    local automatic = automatic_index(current, config)
    local remaining, already_queued = {}, false
    for i, tech in ipairs(current) do
        if i ~= automatic then
            remaining[#remaining + 1] = tech.name
            if tech.name == name then already_queued = true end
        end
    end
    config.automatic_research = nil
    -- Unowned entries belong to players (or other mods). Keep their order and
    -- duplicates, placing at most one automatic choice behind them.
    if name and not already_queued and #remaining < capacity then
        remaining[#remaining + 1] = name
        config.automatic_research = name
    end
    write(force, current, remaining)
end

function queue.yield_to_player(force, config)
    local current = force.research_queue
    local automatic = automatic_index(current, config)
    if automatic then queue.promote(force, config.automatic_research, config) end
end

return queue
