local fixtures = require("tests.fixtures")
local research = require("scripts.research.controller")
local monitor = require("scripts.research.monitor")
local technology = require("scripts.research.technology")
local gui = require("scripts.gui")
local lab_gui = require("scripts.gui.lab")
defines = {inventory = {lab_input = 1}, relative_gui_type = {lab_gui = 2}, relative_gui_position = {right = 3}}
local function tech(name, pack, cost)
    return {name = name, localised_name = name, enabled = true, researched = false, level = 1,
        prototype = {hidden = false, max_level = 4294967295}, prerequisites = {},
        research_unit_count = cost, research_unit_energy = 60,
        research_unit_ingredients = {{name = pack, amount = 1}}}
end
local rare, common = tech("rare", "agricultural-science-pack", 1), tech("common", "red", 10)
local force = fixtures.force{name = "player", technologies = {rare = rare, common = common}}
storage = {}
game = {tick = 0, forces = {player = force}, players = force.players}
helpers = {is_valid_sprite_path = function() return true end}
prototypes = {item = {red = {localised_name = "Red"}, ["agricultural-science-pack"] = {localised_name = "Agricultural"}}}
local config = research.ensure_config(force)
assert(config.pack_check_seconds == 10 and config.pack_grace_seconds == 60)
config.pack_check_seconds = 1
config.pack_grace_seconds = 5
config.enabled = false
research.set_pack_allowed(force, "red", true)
config.research_strategy = "cheap"
for i = 1, 2 do
    force.players[i] = {index = i, force = force,
        gui = {top = fixtures.element({}), relative = fixtures.element({})}}
    gui.toggle_gui(force.players[i])
end
local pack = "agricultural-science-pack"
local function row(i) return force.players[i or 1].gui.top.rantz_research_gui.flow.allowed_ingredients[pack] end
assert(row().rantz_pack_mode.selected_index == 2)
assert(row().rantz_pack_mode.tooltip[1] == "rantz_research_gui.monitor_required")
assert(not research.set_pack_mode(force, pack, "dynamic"))
local function select_mode(index)
    row().rantz_pack_mode.selected_index = index
    gui.on_pack_selection_changed{player_index = 1, element = row().rantz_pack_mode}
end
select_mode(3)
assert(row().rantz_pack_mode.selected_index == 2, "Dynamic must be rejected without a lab")
local contents, reads = {}, 0
local lab = {object_name = "LuaEntity", valid = true, type = "lab", force = force,
    surface = {name = "nauvis"}, position = {x = 1, y = 2},
    get_inventory = function(index)
        assert(index == defines.inventory.lab_input)
        reads = reads + 1
        return {get_contents = function() return contents end}
    end}
local player = force.players[1]
player.opened = lab
lab_gui.refresh(player)
local panel = player.gui.relative.rantz_research_lab
assert(panel.monitor.visible == false, "First lab opening must use false, not nil, for visibility")
gui.on_click{player_index = 1, element = panel.lab_header.rantz_lab_toggle}
assert(panel.monitor.visible)
panel.destroy()
lab_gui.refresh(player)
assert(player.gui.relative.rantz_research_lab.monitor.visible, "Remember expansion after reopening")
force.players[2].opened = lab
lab_gui.refresh(force.players[2])
assert(force.players[2].gui.relative.rantz_research_lab.monitor.visible == false, "Expansion is per player")
local button = player.gui.relative.rantz_research_lab.monitor
gui.on_click{player_index = 1, element = button}
assert(config.monitored_lab == lab and row(1).rantz_pack_mode.items[3][1] == "rantz_research_gui.pack_dynamic"
    and row(2).rantz_pack_mode.items[3][1] == "rantz_research_gui.pack_dynamic")
local other_lab = {object_name = "LuaEntity", valid = true, type = "lab", force = force,
    surface = lab.surface, position = {x = 10, y = 20}, get_inventory = lab.get_inventory}
player.opened = other_lab
lab_gui.refresh(player)
gui.on_click{player_index = 1, element = player.gui.relative.rantz_research_lab.monitor}
assert(config.monitored_lab == other_lab, "Monitoring a new lab replaces the previous lab")
player.opened = lab
lab_gui.refresh(player)
gui.on_click{player_index = 1, element = player.gui.relative.rantz_research_lab.monitor}
assert(config.monitored_lab == lab)
select_mode(3)
assert(config.dynamic_packs[pack] and not monitor.is_allowed(config, pack))
assert(row().rantz_pack_availability.sprite == "utility/status_not_working")
assert(row().rantz_pack_mode.selected_index == 3)
assert(not technology.can_research(force, rare, config))
contents = {{name = pack, count = 1, quality = "legendary"}}
game.tick = 60
research.poll_monitors()
assert(monitor.is_allowed(config, pack) and row(2).rantz_pack_mode.selected_index == 3)
assert(row(1).rantz_pack_availability.sprite == "utility/status_working")
assert(row(2).rantz_pack_availability.sprite == "utility/status_working")
assert(technology.can_research(force, rare, config))
-- A gap shorter than five seconds preserves eligibility, including across reload-like requires.
contents = {}
game.tick = 120; research.poll_monitors()
game.tick = 360; research.poll_monitors()
assert(monitor.is_allowed(config, pack))
assert(require("scripts.research.monitor").is_allowed(config, pack))
config.enabled = true
force.research_queue = {}
research.start_next_research(force, true)
assert(config.automatic_research == rare.name)
game.tick = 420; research.poll_monitors()
assert(not monitor.is_allowed(config, pack) and force.current_research == common)
assert(#force.research_queue == 1, "Interrupted automatic research is removed from the queue")
local writes = force.queue_writes
game.tick = 480; research.poll_monitors()
assert(force.queue_writes == writes, "Unchanged inventories must not reschedule research")
contents = {{name = pack, count = 2, quality = "normal"}}
game.tick = 540; research.poll_monitors()
assert(force.current_research == rare)
config.allow_switching = false
contents = {}; game.tick = 600; research.poll_monitors()
game.tick = 900; research.poll_monitors()
assert(force.current_research == rare, "Respect switching disabled")
config.enabled = false
-- Manual Off wins over stock and clears Dynamic, while On remains available without a lab.
select_mode(2)
contents = {{name = pack, count = 1}}
research.poll_monitors()
assert(not monitor.is_allowed(config, pack) and not config.dynamic_packs[pack])
research.set_pack_mode(force, pack, "dynamic")
assert(monitor.is_allowed(config, pack))
lab.valid = false
game.tick = 960; research.poll_monitors()
assert(not config.monitored_lab and config.dynamic_packs[pack])
assert(row().rantz_pack_mode.selected_index == 3 and row().rantz_pack_mode.tooltip[1] == "rantz_research_gui.monitor_required")
assert(not monitor.is_allowed(config, pack))
select_mode(1)
assert(monitor.is_allowed(config, pack) and not config.dynamic_packs[pack])
-- A replacement source gets a fresh sample; no stale grace period or inventory.
lab.valid = true
assert(research.set_monitored_lab(force, lab))
assert(research.set_pack_mode(force, pack, "dynamic"))
local replacement = {valid = true, type = "lab", force = force,
    surface = {name = "gleba"}, position = {x = 0, y = 0},
    get_inventory = function() return {get_contents = function() return {} end} end}
assert(research.set_monitored_lab(force, replacement))
assert(not monitor.is_allowed(config, pack))
replacement.force = {}
game.tick = game.tick + 60
research.poll_monitors()
assert(not config.monitored_lab)
-- No candidate: retain the player's queue. Queued-only, blacklist, and targets still apply.
config.enabled = true; config.allow_switching = true; config.prioritized_only = true
force.research_queue = {rare}
config.automatic_research = nil
research.start_next_research(force, true)
assert(force.current_research == rare)
config.enabled = false; config.prioritized_only = false
research.set_monitored_lab(force, lab)
config.deprioritized_techs = {"rare"}
assert(not technology.can_research(force, rare, config))
config.deprioritized_techs = {}; config.target_levels.rare = 0
assert(not technology.can_research(force, rare, config))
research.set_monitored_lab(force, nil)
local before = reads
research.poll_monitors()
assert(reads == before, "A missing source must not read inventories")
-- Settings validate whole seconds, synchronize players, and control read frequency.
local function timing(name, text)
    local field = player.gui.top.rantz_research_gui.flow.settings.monitor_timing[name].rantz_research_timing_input
    field.text = text
    gui.on_target_confirmed{player_index = 1, element = field}
    return field
end
assert(timing("pack_check_seconds", "0").text == "1")
assert(timing("pack_grace_seconds", "bad").text == "5")
assert(timing("pack_check_seconds", "3601").text == "1")
timing("pack_check_seconds", "10")
timing("pack_grace_seconds", "60")
assert(config.pack_check_seconds == 10 and config.pack_grace_seconds == 60)
assert(force.players[2].gui.top.rantz_research_gui.flow.settings.monitor_timing.pack_check_seconds.rantz_research_timing_input.text == "10")
research.set_monitored_lab(force, lab)
local at_selection = reads
for i = 1, 9 do game.tick = game.tick + 60; research.poll_monitors() end
assert(reads == at_selection, "Do not read the inventory between configured checks")
game.tick = game.tick + 60; research.poll_monitors()
assert(reads == at_selection + 1)
contents = {}; game.tick = game.tick + 600; research.poll_monitors()
local empty_start = game.tick
for i = 1, 5 do game.tick = empty_start + i * 600; research.poll_monitors() end
assert(monitor.is_allowed(config, pack))
game.tick = empty_start + 3600; research.poll_monitors()
assert(not monitor.is_allowed(config, pack))
-- Destruction events clear the reference immediately instead of waiting for polling.
lab.valid = true
assert(research.set_monitored_lab(force, lab))
assert(research.set_pack_mode(force, pack, "dynamic"))
research.on_monitored_lab_removed({entity = lab})
assert(not config.monitored_lab and not monitor.is_allowed(config, pack))
print("Dynamic pack regressions passed")
