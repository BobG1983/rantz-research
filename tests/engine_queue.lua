-- Disposable-map smoke test. Require only from a COPY of control.lua, then
-- benchmark that map for two ticks. Never enable this in a player's save.
local research = require("scripts.research.controller")
local queue = require("scripts.research.queue")

script.on_nth_tick(1, function(event)
    if event.tick ~= 1 then return end
    local force = game.forces.player
    local config = research.ensure_config(force)
    config.enabled = false
    force.research_queue = {}
    local first, second = "automation", "logistics"
    for _, name in ipairs({first, second}) do
        for _, prerequisite in pairs(force.technologies[name].prerequisites) do
            prerequisite.researched = true
        end
        force.technologies[name].researched = false
        force.technologies[name].enabled = true
    end
    queue.promote(force, first, config)
    assert(force.current_research.name == first)
    force.research_progress = 0.25
    queue.promote(force, second, config)
    assert(#force.research_queue == 1 and force.current_research.name == second)
    assert(math.abs(force.technologies[first].saved_progress - 0.25) < 0.001)
    for i = 1, 20 do
        queue.promote(force, i % 2 == 1 and first or second, config)
        assert(#force.research_queue == 1)
    end
    queue.promote(force, first, config)
    assert(math.abs(force.research_progress - 0.25) < 0.001)
    force.research_queue = {first, second}
    queue.yield_to_player(force, config)
    assert(force.current_research.name == second and force.research_queue[2].name == first)
    queue.promote(force, nil, config)
    assert(#force.research_queue == 1 and force.current_research.name == second)
    -- A player-owned candidate is kept in place and never adopted by the mod.
    queue.promote(force, second, config)
    assert(not config.automatic_research and #force.research_queue == 1)
    log("RANTZ_QUEUE_ENGINE_PASS")
end)
