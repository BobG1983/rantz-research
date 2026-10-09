local research = require("scripts.research.controller")
local gui = require("scripts.gui")
local monitor = require("scripts.research.monitor")
local lab_gui = require("scripts.gui.lab")

local function initialize()
    -- Integration calls belong to lifecycle events, never configuration reads.
    if remote.interfaces.RQ and remote.interfaces.RQ.popup then remote.call("RQ", "popup", false) end
    for _, force in pairs(game.forces) do
        research.initialize(force)
        monitor.sample(force, research.get_config(force), game.tick)
        research.start_next_research(force, true)
        gui.refresh_force(force)
    end
end
script.on_init(initialize)
script.on_configuration_changed(initialize)
script.on_nth_tick(monitor.interval, research.poll_monitors)
script.on_event(defines.events.on_gui_opened, function(event)
    lab_gui.refresh(game.players[event.player_index])
end)
script.on_event(defines.events.on_gui_closed, function(event)
    local player = game.players[event.player_index]
    local panel = player.gui.relative.rantz_research_lab
    if panel then panel.destroy() end
end)
script.on_event(defines.events.on_pre_player_mined_item, research.on_monitored_lab_removed)
script.on_event(defines.events.on_robot_pre_mined, research.on_monitored_lab_removed)
script.on_event(defines.events.on_entity_died, research.on_monitored_lab_removed)
script.on_event(defines.events.script_raised_destroy, research.on_monitored_lab_removed)
script.on_event(defines.events.on_player_joined_game, function(event)
    local player = game.players[event.player_index]
    gui.refresh_force(player.force)
end)

script.on_event(defines.events.on_force_created, function(event)
    research.initialize(event.force)
    research.start_next_research(event.force, true)
end)
script.on_event(defines.events.on_research_finished, research.on_research_finished)
script.on_event(defines.events.on_research_queued, research.on_research_queued)
script.on_event(defines.events.on_research_moved, research.on_research_moved)
script.on_event(defines.events.on_research_cancelled, research.on_research_cancelled)
script.on_event(defines.events.on_gui_checked_state_changed, gui.on_checkbox_click)
script.on_event(defines.events.on_gui_click, gui.on_click)
script.on_event(defines.events.on_gui_confirmed, gui.on_target_confirmed)
script.on_event(defines.events.on_gui_selection_state_changed, gui.on_pack_selection_changed)
script.on_event("rantz_research_toggle", function(event)
    gui.toggle_gui(game.players[event.player_index])
end)
