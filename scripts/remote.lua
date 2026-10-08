local research = require("scripts.research.controller")

-- Preserve the public remote interface name for other mods.
remote.add_interface("rantz_research", {
    enabled = function(force_name, value) research.set_rantz_research(game.forces[force_name], value) end,
    queued_only = function(force_name, value) research.set_queued_only(game.forces[force_name], value) end,
    allow_switching = function(force_name, value) research.set_allow_switching(game.forces[force_name], value) end,
    deprioritize_infinite_tech = function(force_name, value) research.set_deprioritize_infinite_tech(game.forces[force_name], value) end
})
