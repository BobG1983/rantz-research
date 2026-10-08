local technology = require("scripts.research.technology")
local selection = {}

local function best_candidate(force, candidates, config)
    local best, best_score
    for _, tech in pairs(candidates) do
        if technology.can_research(force, tech, config) then
            local score = technology.calculate_effort(tech, config)
            if not best or technology.precedes(tech, score, best, best_score, config) then
                best, best_score = tech, score
            end
        end
    end
    return best and best.name
end

function selection.choose(force, config)
    for _, name in ipairs(config.prioritized_techs) do
        local tech = force.technologies[name]
        if tech and not technology.is_target_reached(tech, config) then
            local choice = best_candidate(force, technology.get_unresearched_prerequisites(tech), config)
            if choice then return choice end
        end
    end
    if not config.prioritized_only then
        return best_candidate(force, force.technologies, config)
    end
end

return selection
