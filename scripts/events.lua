local research = require("scripts.research.controller")
local gui = require("scripts.gui")

local function initialize()
    -- Integration calls belong to lifecycle events, never configuration reads.
    if remote.interfaces.RQ and remote.interfaces.RQ.popup then remote.call("RQ", "popup", false) end
    for _, force in pairs(game.forces) do
        research.initialize(force)
        research.start_next_research(force, true)
        gui.refresh_force(force)
    end
end
script.on_init(initialize)
script.on_configuration_changed(initialize)
script.on_event(defines.events.on_player_joined_game, function(event)
    local player = game.players[event.player_index]
    gui.refresh_force(player.force)
end)

local function add_default_technologies(force, destination, text)
    local present = {}
    for _, name in ipairs(destination) do present[name] = true end
    for name in string.gmatch(text, "[^,]+") do
        name = string.gsub(name, "%s+", "")
        local tech = force.technologies[name]
        if tech and tech.enabled and not tech.researched and not present[name] then
            destination[#destination + 1] = name
            present[name] = true
        end
    end
end

script.on_event(defines.events.on_player_created, function(event)
    local player = game.players[event.player_index]
    local force = player.force
    local config = research.ensure_config(force)
    local defaults = settings.get_player_settings(player)
    add_default_technologies(force, config.prioritized_techs, defaults["rantz-research-queued-tech-setting"].value)
    add_default_technologies(force, config.deprioritized_techs, defaults["rantz-research-blacklisted-tech-setting"].value)
    research.start_next_research(force, true)
    gui.refresh_force(force)
end)
script.on_event(defines.events.on_force_created, function(event)
    research.initialize(event.force)
    research.start_next_research(event.force, true)
end)
script.on_event(defines.events.on_research_finished, research.on_research_finished)
script.on_event(defines.events.on_gui_checked_state_changed, gui.on_checkbox_click)
script.on_event(defines.events.on_gui_click, gui.on_click)
script.on_event(defines.events.on_gui_confirmed, gui.on_target_confirmed)
script.on_event("rantz_research_toggle", function(event)
    gui.toggle_gui(game.players[event.player_index])
end)
