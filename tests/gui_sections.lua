-- Run from the mod root with Lua 5.2: lua tests/gui_sections.lua
local fixtures = require("tests.fixtures")
local element = fixtures.element

storage = nil
local gui = require("scripts.gui")
assert(storage == nil, "Loading modules must not initialize saved state")
remote = {interfaces = {}}
storage = {rantz_research_config = {player = {
    enabled = false, prioritized_techs = {}, deprioritized_techs = {},
    allowed_ingredients = {}, infinite_research = {}, research_strategy = "balanced"
}}}
local force = {name = "player", technologies = {}, players = {}}
for i = 1, 2 do
    force.players[i] = {index = i, force = force, gui = {top = element({})}}
end
game = {tick = 1, players = force.players}
local contents = {
    strategy = "research_strategies_outer", ingredients = "allowed_ingredients",
    allowed = "allowed", blacklisted = "blacklisted", settings = "settings"
}
local function flow(index)
    return game.players[index].gui.top.rantz_research_gui.flow
end
local function toggle(index, name)
    gui.on_click({player_index = index, element = flow(index)[name .. "_header"]["rantz_research_toggle_" .. name]})
end

gui.toggle_gui(game.players[1])
gui.toggle_gui(game.players[2])
for name, content in pairs(contents) do
    assert(not flow(1)[content].visible and not flow(2)[content].visible)
    toggle(1, name)
    gui.toggle_gui(game.players[1])
    gui.toggle_gui(game.players[1])
    assert(flow(1)[content].visible)
    assert(flow(1)[name .. "_header"]["rantz_research_toggle_" .. name].sprite == "utility/collapse")
    assert(not flow(2)[content].visible, "Preferences must be per player")
end
toggle(1, "settings")
gui.refresh_force(force)
assert(not flow(1).settings.visible and flow(1).allowed.visible)
gui.toggle_gui(game.players[1])

-- Reload code with persisted storage, as after loading a saved game.
package.loaded["scripts.gui"] = nil
gui = require("scripts.gui")
gui.toggle_gui(game.players[1])
for name, content in pairs(contents) do
    assert(flow(1)[content].visible == (name ~= "settings"))
end
assert(flow(1).settings_header.rantz_research_toggle_settings.sprite == "utility/expand")

-- Adopt the visible state of a pre-existing window when it is closed.
storage.gui_expanded_sections = nil
gui.toggle_gui(game.players[1])
gui.toggle_gui(game.players[1])
assert(flow(1).allowed.visible and not flow(1).settings.visible)
print("GUI section persistence regressions passed")
