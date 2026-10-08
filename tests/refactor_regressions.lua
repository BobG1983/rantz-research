local fixtures = require("tests.fixtures")
local configuration = require("scripts.research.configuration")
local research = require("scripts.research.controller")
local technology = require("scripts.research.technology")
local queue = require("scripts.research.queue")
local selection = require("scripts.research.selection")

local function tech(name, cost, infinite)
    return {name = name, localised_name = name, enabled = true, researched = false,
        prototype = {hidden = false, max_level = infinite and 4294967295 or 1}, level = 14,
        research_unit_count = cost, research_unit_energy = 60, prerequisites = {},
        research_unit_ingredients = {{name = "red", amount = 1}}}
end
local a, b, c = tech("a", 10, true), tech("b", 100, true), tech("c", 1000000)
local force = fixtures.force{name = "player", technologies = {a = a, b = b, c = c}}
for _, t in pairs(force.technologies) do t.force = force end
game = {tick = 1, forces = {player = force}, players = force.players}
remote = {interfaces = {RQ = {popup = true}}, call = function() error("Configuration must not call remote interfaces") end}
storage = {}
assert(configuration.get(force) == nil and storage.rantz_research_config == nil)
local config = configuration.initialize(force)
assert(config.enabled and config.allow_switching and not config.prioritized_only)
assert(force.queue_writes == 0, "Initializing defaults must not schedule research")
local original_config = config
config.allowed_ingredients.red = false
config.target_levels.a = 13
config.enabled = false
config.tech_counts = {a = 999}
configuration.initialize(force)
assert(config == original_config and not config.enabled and not config.allowed_ingredients.red)
assert(config.target_levels.a == 13 and config.tech_counts == nil)
assert(configuration.get(force) == config and force.queue_writes == 0)
config.allowed_ingredients.red = true
config.target_levels.a = nil
config.enabled = true

-- Prerequisite diamonds and even malformed cycles must terminate without duplicates.
local root, left, right, shared = tech("root", 1), tech("left", 1), tech("right", 1), tech("shared", 1)
root.prerequisites = {left, right}; left.prerequisites = {shared}; right.prerequisites = {shared}
shared.prerequisites = {root}
assert(#technology.get_unresearched_prerequisites(root) == 4)

config.deprioritize_infinite_tech = true
for _, strategy in ipairs({"fast", "slow", "cheap", "expensive", "balanced"}) do
    config.research_strategy = strategy
    local rows = {{"a", a}, {"b", b}, {"c", c}}
    technology.sort_by_effort(rows, config)
    assert(rows[1][1] == "c", "Finite research must precede any infinite cost")
    assert(rows[2][1] == ((strategy == "slow" or strategy == "expensive") and "b" or "a"))
    assert(selection.choose(force, config) == "c")
end
config.deprioritize_infinite_tech = false
config.research_strategy = "cheap"
force.research_queue = {b, c}
research.start_next_research(force, true)
assert(force.current_research == a and force.research_queue[2] == b and force.research_queue[3] == c)
local writes = force.queue_writes
research.start_next_research(force, true)
assert(force.queue_writes == writes, "Already selected work must not be requeued")
config.allow_switching = false
force.research_queue = {b, c}
research.start_next_research(force, true)
assert(force.current_research == b and #force.research_queue == 2)
config.target_levels.b = 13
research.start_next_research(force, true)
assert(force.current_research == c and #force.research_queue == 1)
config.target_levels.b = nil

local full = {}
for i = 1, 7 do
    local t = tech("queued-" .. i, 1000)
    force.technologies[t.name] = t
    full[i] = t
end
force.research_queue = full
queue.promote(force, "a")
assert(#force.research_queue == 7 and force.research_queue[7] == full[7], "Full queues must not lose entries")
queue.promote(force, full[7].name)
assert(force.current_research == full[7] and force.research_queue[7] == full[6])

-- All mutation paths, including public remote methods, synchronize both windows.
config.enabled = false
config.allow_switching = true
force.research_queue = {}
helpers = {is_valid_sprite_path = function() return true end}
prototypes = {item = {red = {localised_name = "Red"}}}
for i = 1, 2 do force.players[i] = {index = i, force = force, gui = {top = fixtures.element({})}} end
local gui = require("scripts.gui")
for _, player in ipairs(force.players) do gui.toggle_gui(player) end
local function flow(i) return force.players[i].gui.top.rantz_research_gui.flow end
local field = flow(1).allowed.flow["rantz_research_target-a"]
field.text = "123"
field.test_has_focus = true
research.set_strategy(force, "expensive")
assert(flow(1).allowed.flow["rantz_research_target-a"] == field and field.text == "123" and field.test_has_focus)
assert(flow(2).research_strategies_outer.rantz_research_research_expensive.state)
research.set_pack_allowed(force, "red", false)
assert(not flow(2).allowed_ingredients.red["rantz_research_allow_ingredient-red"].state)
assert(field.valid and field.text == "123")
research.set_target_level(force, "a", 15)
assert(field.text == "123", "Another player changing a target must not erase a local draft")
assert(flow(2).allowed.flow["rantz_research_target-a"].text == "15")
gui.on_target_confirmed({player_index = 1, element = field})
assert(config.target_levels.a == 123 and flow(2).allowed.flow["rantz_research_target-a"].text == "123")
field.text = "124"
research.set_blacklisted(force, "a", true)
assert(flow(1).blacklisted.flow["rantz_research_target-a"].text == "124")
assert(config.target_levels.a == 123)
remote.add_interface = function(name, api) remote.interfaces[name] = api end
require("scripts.remote")
remote.interfaces.rantz_research.queued_only("player", true)
assert(flow(1).settings.rantz_research_queued_only.state and flow(2).settings.rantz_research_queued_only.state)
assert(not research.set_target_level(force, "a", -1))
assert(not research.set_strategy(force, "invalid"))
assert(not research.set_setting(force, "enabled", "true"))

-- Upgrade persisted GUI instances once, retaining section preferences.
local old = force.players[1].gui.top.rantz_research_gui
old.flow.settings.visible = true
old.tags = {}
gui.refresh_force(force)
assert(not old.valid and flow(1).settings.visible)

local lists = require("scripts.gui.technology_lists")
local original_prepare, prepare_calls = lists.prepare, 0
lists.prepare = function(...)
    prepare_calls = prepare_calls + 1
    return original_prepare(...)
end
gui.refresh_force(force)
assert(prepare_calls == 1, "Two players should share one list preparation")

local callbacks, remote_calls = {}, 0
remote.call = function() remote_calls = remote_calls + 1 end
defines = {events = {on_player_joined_game = 1, on_player_created = 2, on_force_created = 3,
    on_research_finished = 4, on_gui_checked_state_changed = 5, on_gui_click = 6, on_gui_confirmed = 7}}
script = {
    on_init = function(fn) callbacks.init = fn end,
    on_configuration_changed = function(fn) callbacks.configuration = fn end,
    on_event = function(id, fn) callbacks[id] = fn end
}
settings = {get_player_settings = function() return {
    ["rantz-research-queued-tech-setting"] = {value = "b, b, missing"},
    ["rantz-research-blacklisted-tech-setting"] = {value = "c, c"}
} end}
require("scripts.events")
callbacks.init()
assert(remote_calls == 1)
callbacks.configuration()
assert(remote_calls == 2 and config.target_levels.a == 123)
callbacks[2]({player_index = 1})
callbacks[2]({player_index = 2})
local occurrences = 0
for _, name in ipairs(config.prioritized_techs) do if name == "b" then occurrences = occurrences + 1 end end
assert(occurrences == 1, "Defaults from multiple players must not duplicate queue entries")
assert(configuration.get(force) == config and remote_calls == 2)
assert(remote.interfaces.rantz_research)
print("Refactor regressions passed")
