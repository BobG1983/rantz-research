local pack_costs = require("scripts.research.pack_costs")
local monitor = require("scripts.research.monitor")

local technology = {}

function technology.is_infinite(tech)
    -- Factorio represents an infinite prototype maximum as uint32 max.
    return tech.prototype.max_level == 4294967295
end

function technology.is_target_reached(tech, config)
    local target = config.target_levels and config.target_levels[tech.name]
    -- For unfinished infinite research, level is the NEXT level to complete.
    return technology.is_infinite(tech) and target ~= nil and tech.level > target
end

function technology.has_disabled_packs(tech, config)
    for _, ingredient in pairs(tech.research_unit_ingredients) do
        if not monitor.is_allowed(config, ingredient.name) then return true end
    end
    return false
end

function technology.is_disabled(tech, config)
    return technology.is_target_reached(tech, config) or technology.has_disabled_packs(tech, config)
end

function technology.get_unresearched_prerequisites(tech)
    local prerequisites = {}
    prerequisites[#prerequisites + 1] = tech
    local visited = {[tech.name] = true}
    local index = 1
    while (index <= #prerequisites) do
        for _, prerequisite in pairs(prerequisites[index].prerequisites) do
            if prerequisite.enabled and not prerequisite.researched and not visited[prerequisite.name] then
                visited[prerequisite.name] = true
                prerequisites[#prerequisites + 1] = prerequisite
            end
        end
        index = index + 1
    end
    return prerequisites
end

function technology.can_research(force, tech, config)
    if not tech or tech.researched or not tech.enabled or tech.prototype.hidden then
        return false
    end
    if technology.is_disabled(tech, config) then
        return false
    end
    for _, prerequisite in pairs(tech.prerequisites) do
        if not prerequisite.researched then
            return false
        end
    end
    if #tech.research_unit_ingredients == 0 then
        return false
    end
    for _, deprioritized in pairs(config.deprioritized_techs) do
        if tech.name == deprioritized then
            return false
        end
    end
    return true
end

-- Packs in a research unit are consumed together, not sequentially.
-- Time therefore depends on unit count and duration, never ingredient count.
function technology.calculate_effort(tech, config)
    local unit_cost = 0
    for _, ingredient in pairs(tech.research_unit_ingredients) do
        -- Unknown modded packs still contribute by quantity at the base weight.
        unit_cost = unit_cost + ingredient.amount * (pack_costs[ingredient.name] or 1)
    end
    local research_time = tech.research_unit_count * tech.research_unit_energy
    local research_cost = tech.research_unit_count * unit_cost
    local effort = 0
    if config.research_strategy == "fast" then
        effort = research_time
    elseif config.research_strategy == "slow" then
        effort = -research_time
    elseif config.research_strategy == "cheap" then
        effort = research_cost
    elseif config.research_strategy == "expensive" then
        effort = -research_cost
    elseif config.research_strategy == "balanced" then
        -- Count research units once, balancing duration with weighted pack usage.
        effort = research_time * unit_cost
    else
        effort = math.random(1, 999)
    end
    return effort
end

function technology.precedes(a, a_score, b, b_score, config)
    if config.deprioritize_infinite_tech then
        local a_infinite, b_infinite = technology.is_infinite(a), technology.is_infinite(b)
        if a_infinite ~= b_infinite then return not a_infinite end
    end
    if a_score ~= b_score then return a_score < b_score end
    return a.name < b.name
end

function technology.sort_by_effort(techs, config)
    local scores, disabled, positions = {}, {}, {}
    for i, entry in ipairs(techs) do
        local name, tech = entry[1], entry[2]
        disabled[name] = technology.is_disabled(tech, config)
        positions[name] = i
        -- Random research has no cost ordering; preserve order within each group
        -- without consuming random numbers just to redraw the GUI.
        scores[name] = config.research_strategy == "random" and 0 or technology.calculate_effort(tech, config)
    end
    table.sort(techs, function(a, b)
        local an, bn = a[1], b[1]
        if disabled[an] ~= disabled[bn] then return not disabled[an] end
        if config.research_strategy == "random" then
            if config.deprioritize_infinite_tech then
                local ai, bi = technology.is_infinite(a[2]), technology.is_infinite(b[2])
                if ai ~= bi then return not ai end
            end
            return positions[an] < positions[bn]
        end
        return technology.precedes(a[2], scores[an], b[2], scores[bn], config)
    end)
end

return technology
