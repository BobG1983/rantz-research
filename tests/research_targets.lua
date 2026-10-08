-- Run from the mod root with Lua 5.2: lua tests/research_targets.lua
local technology = require("scripts.research.technology")
local research = require("scripts.research.controller")
local gui = require("scripts.gui")
local fixtures = require("tests.fixtures")
local element = fixtures.element

remote = {interfaces = {}}
helpers = {is_valid_sprite_path = function() return true end}
local infinite = {
    name = "blue-chip-productivity", localised_name = "Blue chip productivity", level = 13,
    prototype = {max_level = 4294967295, hidden = false}, enabled = true, researched = false,
    research_unit_count = 100, research_unit_energy = 60, prerequisites = {},
    research_unit_ingredients = {{name = "automation-science-pack", amount = 1}}
}
local finite = {
    name = "finite", localised_name = "Finite", level = 1,
    prototype = {max_level = 5, hidden = false}, enabled = true, researched = false,
    research_unit_count_formula = "100*L", research_unit_count = 100,
    research_unit_energy = 60, prerequisites = {}, research_unit_ingredients = infinite.research_unit_ingredients
}
local done = {
    name = "done", researched = true, enabled = true,
    prototype = {max_level = 1, hidden = false}
}
local force = fixtures.force{name = "player", technologies = {[infinite.name] = infinite, finite = finite, done = done}, research_queue = {}, print = function() end}
infinite.force = force
local config = {
    enabled = false, allow_switching = true, prioritized_techs = {}, deprioritized_techs = {},
    research_strategy = "balanced", allowed_ingredients = {["automation-science-pack"] = true},
    infinite_research = {[infinite.name] = infinite}, target_levels = {[infinite.name] = 13}
}
storage = {rantz_research_config = {player = config}}
local player = {index = 1, force = force, gui = {top = element({})}}
force.players = {player}
game = {players = {player}, tick = 10}
prototypes = {item = {["automation-science-pack"] = {localised_name = "Red"}}}
assert(technology.is_infinite(infinite) and not technology.is_infinite(finite))
assert(technology.can_research(force, infinite, config), "Level 13 itself is permitted")
infinite.level = 14
assert(not technology.can_research(force, infinite, config), "After 13 completes, level 14 must stop")
gui.toggle_gui(player)
local function list(blacklisted)
    return player.gui.top.rantz_research_gui.flow[blacklisted and "blacklisted" or "allowed"].flow
end
local function field(blacklisted) return list(blacklisted)["rantz_research_target-" .. infinite.name] end
local function confirm(text, blacklisted)
    local input = field(blacklisted)
    input.text = text
    gui.on_target_confirmed({player_index = 1, element = input})
end
local function move(blacklisted)
    local action = blacklisted and "enable-" or "disable-"
    gui.on_click({player_index = 1, element = list(blacklisted)["rantz_research_" .. action .. infinite.name]})
end
for _, blacklisted in ipairs({false, true}) do
    local grid = list(blacklisted)
    for column, key in ipairs({"action", "max", "research", "required_packs"}) do
        assert(grid.children[column] == grid["column_" .. key])
        if column > 1 then
            assert(grid.children[column].caption[1] == "rantz_research_gui.column_" .. key)
        end
    end
end
assert(field().enabled and field().text == "13" and field().numeric)
assert(not field().allow_decimal and not field().allow_negative)
assert(not list()["rantz_research_target-finite"].enabled)
assert(not list()["rantz_research_target-done"])
local grey = false
for _, child in ipairs(list().children) do
    if child.type == "label" and child.caption == infinite.localised_name then
        grey = child.style.font_color.r == 0.5
    end
end
assert(grey, "Capped technology must remain visible but grey")
for _, text in ipairs({"letters", "1.5", "-1", "1e2", "4294967296"}) do
    confirm(text)
    assert(config.target_levels[infinite.name] == 13)
end
confirm("14")
assert(technology.can_research(force, infinite, config))
gui.on_click({player_index = 1, element = list()["rantz_research_disable-" .. infinite.name]})
assert(field(true).text == "14" and not field(false))
confirm("15", true)
assert(config.target_levels[infinite.name] == 15 and not technology.can_research(force, infinite, config))
gui.on_click({player_index = 1, element = list(true)["rantz_research_enable-" .. infinite.name]})
assert(field().text == "15" and technology.can_research(force, infinite, config))
-- Clicking a move button commits unconfirmed input in either direction.
field().text = "16"
move(false)
assert(field(true).text == "16" and config.target_levels[infinite.name] == 16)
field(true).text = "13"
config.enabled = true
move(true)
assert(field().text == "13" and config.target_levels[infinite.name] == 13)
assert(not technology.can_research(force, infinite, config))
for _, queued in ipairs(force.research_queue) do
    assert(queued.name ~= infinite.name, "Apply the cap before scheduling the newly whitelisted technology")
end
config.enabled = false
gui.toggle_gui(player)
gui.toggle_gui(player)
assert(field().text == "13", "Moving saves the draft across close/reopen")
field().text = ""
move(false)
assert(field(true).text == "" and config.target_levels[infinite.name] == nil)
field(true).text = "4294967296"
move(true)
assert(field().text == "" and config.target_levels[infinite.name] == nil, "Invalid draft must not replace the saved target")
confirm("0")
assert(not technology.can_research(force, infinite, config))
confirm("")
assert(config.target_levels[infinite.name] == nil and technology.can_research(force, infinite, config))
confirm("13")
gui.toggle_gui(player)
gui.toggle_gui(player)
assert(field().text == "13")
-- Even a queued/current capped technology must be removed; finite work survives.
config.enabled = true
config.allow_switching = false
force.research_queue = {infinite, finite, infinite}
research.start_next_research(force, true)
assert(#force.research_queue == 1 and force.research_queue[1].name == "finite")
-- Research completion refreshes both lists, retaining targets and hiding completed finite work.
config.enabled = false
finite.researched = true
config.deprioritized_techs = {"finite", "done"}
research.on_research_finished({research = infinite})
gui.refresh_force(force)
assert(field() and not list()["rantz_research_target-finite"])
assert(not list(true)["rantz_research_target-done"] and not list(true)["rantz_research_target-finite"])
assert(config.target_levels[infinite.name] == 13 and #config.deprioritized_techs == 0)
print("Research target regressions passed")
