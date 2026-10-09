-- Run from the mod root with Lua 5.2: lua tests/gui_sorting.lua
local fixtures = require("tests.fixtures")
local element = fixtures.element

local handlers = {}
defines = {events = {on_player_created = 1, on_force_created = 2, on_research_finished = 3,
    on_gui_checked_state_changed = 4, on_gui_click = 5, on_gui_confirmed = 6, on_player_joined_game = 7, on_gui_opened = 8, on_gui_closed = 9,
    on_pre_player_mined_item = 10, on_robot_pre_mined = 11, on_entity_died = 12, script_raised_destroy = 13, on_gui_selection_state_changed = 14,
    on_research_queued = 15, on_research_moved = 16, on_research_cancelled = 17}}
script = {on_nth_tick = function() end, on_init = function() end, on_configuration_changed = function() end, on_event = function(id, fn) handlers[id] = fn end}
remote = {interfaces = {}, add_interface = function(name, api) remote.interfaces[name] = api end}
require("control")
assert(remote.interfaces.rantz_research.announce_completed == nil)
helpers = {is_valid_sprite_path = function() return true end}
prototypes = {item = {red = {localised_name = "Red"}, blue = {localised_name = "Blue"}}}
local force = {name = "player", technologies = {}, print = function() error("No duplicate announcements") end}
local config = {enabled = false, research_strategy = "cheap", prioritized_techs = {},
    deprioritized_techs = {}, allowed_ingredients = {red = true, blue = false},
    infinite_research = {}, target_levels = {}}
for _, prefix in ipairs({"w", "b"}) do
    for i, spec in ipairs({{"cheap", 10, "red"}, {"expensive", 100, "red"}, {"pack", 2, "blue"}, {"cap", 1, "red"}}) do
        local name = prefix .. spec[1]
        force.technologies[name] = {name = name, localised_name = name, force = force,
            researched = false, enabled = true, prerequisites = {}, level = 14,
            prototype = {hidden = false, max_level = 4294967295},
            research_unit_count = spec[2], research_unit_energy = 60,
            research_unit_ingredients = {{name = spec[3], amount = 1}}}
        if i == 4 then config.target_levels[name] = 13 end
        if prefix == "b" then config.deprioritized_techs[#config.deprioritized_techs + 1] = name end
    end
end
storage = {rantz_research_config = {player = config}}
local player = {index = 1, force = force, gui = {top = element({})}}
force.players = {player}; game = {tick = 1, players = {player}}
handlers.rantz_research_toggle({player_index = 1})
local flow = player.gui.top.rantz_research_gui.flow
assert(flow.settings.rantz_research_announce_completed == nil)
-- Simulate a saved window created before the announcement option was removed.
flow.settings.add{type = "checkbox", name = "rantz_research_announce_completed", state = true}
flow.add{type = "checkbox", name = "rantz_research_announce_completed", state = true}
handlers[7]({player_index = 1})
assert(flow.settings.rantz_research_announce_completed == nil)
assert(flow.rantz_research_announce_completed == nil)
assert(flow.settings.rantz_research_allow_switching ~= nil)
assert(flow.allowed_ingredients.style.horizontal_spacing == 32)
local function check(list, expected, disabled)
    local grid = flow[list].flow
    for i, name in ipairs(expected) do
        local field, label = grid.children[4 + (i - 1) * 4 + 2], grid.children[4 + (i - 1) * 4 + 3]
        assert(label.caption == name, "Incorrect list order")
        assert(field.style.width == 35)
        assert((label.style.font_color.r == 0.5) == (disabled[name] == true))
    end
end
check("allowed", {"wcheap", "wexpensive", "wcap", "wpack"}, {wcap = true, wpack = true})
check("blacklisted", {"bcheap", "bexpensive", "bcap", "bpack"}, {bcap = true, bpack = true})
handlers[5]({player_index = 1, element = flow.research_strategies_outer.rantz_research_research_expensive})
check("allowed", {"wexpensive", "wcheap", "wpack", "wcap"}, {wcap = true, wpack = true})
check("blacklisted", {"bexpensive", "bcheap", "bpack", "bcap"}, {bcap = true, bpack = true})
local dropdown = flow.allowed_ingredients.blue.rantz_pack_mode
dropdown.selected_index = 1
handlers[14]({player_index = 1, element = dropdown})
check("allowed", {"wexpensive", "wcheap", "wpack", "wcap"}, {wcap = true})
check("blacklisted", {"bexpensive", "bcheap", "bpack", "bcap"}, {bcap = true})
handlers[5]({player_index = 1, element = flow.research_strategies_outer.rantz_research_research_cheap})
check("allowed", {"wpack", "wcheap", "wexpensive", "wcap"}, {wcap = true})
force.technologies.wpack.researched = true
handlers[3]({research = force.technologies.wpack})
check("allowed", {"wcheap", "wexpensive", "wcap"}, {wcap = true})
assert(#flow.allowed.flow.children == 16)
handlers[5]({player_index = 1, element = flow.research_strategies_outer.rantz_research_research_random})
assert(flow.allowed.flow.children[15].caption == "wcap", "Random must still group disabled rows last")
print("GUI sorting regressions passed")
