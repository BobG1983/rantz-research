local fixtures = require("tests.fixtures")
local research = require("scripts.research.controller")
local queue = require("scripts.research.queue")
local function tech(name, count)
    return {name = name, enabled = true, researched = false, level = 1,
        prototype = {hidden = false, max_level = 4294967295}, prerequisites = {},
        research_unit_count = count, research_unit_energy = 60,
        research_unit_ingredients = {{name = "red", amount = 1}}}
end
local mining, steel = tech("mining", 10), tech("steel", 20)
local force = fixtures.force{name = "player", technologies = {mining = mining, steel = steel}}
mining.force, steel.force = force, force
storage = {}
game = {tick = 1, forces = {player = force}}
local config = research.ensure_config(force)
config.allowed_ingredients.red = true
config.research_strategy = "cheap"
research.start_next_research(force, true)
assert(force.current_research == mining and config.automatic_research == "mining")
for i = 1, 20 do
    research.set_strategy(force, i % 2 == 1 and "expensive" or "cheap")
    assert(#force.research_queue == 1, "Repeated switches must never fill the queue")
    assert(force.current_research == (i % 2 == 1 and steel or mining))
end
-- Per-force ownership survives module reloads (all persistent state is in storage).
assert(research.get_config(force).automatic_research == "mining")
local writes = force.queue_writes
research.start_next_research(force, true)
assert(force.queue_writes == writes)
local manual = {}
for i = 1, 7 do
    manual[i] = tech("manual-" .. i, 1000)
    force.technologies[manual[i].name] = manual[i]
end
force.research_queue = {mining, manual[1], manual[2]}
research.on_research_queued{force = force, research = manual[2], player_index = 1}
assert(force.research_queue[1] == manual[1] and force.research_queue[2] == manual[2])
assert(force.research_queue[3] == mining)
research.set_strategy(force, "expensive")
-- Select explicitly here to isolate queue placement from scoring the manual technologies.
queue.promote(force, "steel", config)
assert(#force.research_queue == 3 and force.research_queue[3] == steel)
assert(force.research_queue[1] == manual[1] and force.research_queue[2] == manual[2])
queue.promote(force, manual[2].name, config)
assert(#force.research_queue == 2 and force.current_research == manual[1])
assert(config.automatic_research == nil, "A player entry must never become automatic")
-- Full queues retain every manual entry; replacing our own slot is still possible.
force.research_queue = manual
queue.promote(force, "mining", config)
assert(#force.research_queue == 7 and force.research_queue[7] == manual[7])
force.research_queue = {mining, manual[1], manual[2], manual[3], manual[4], manual[5], manual[6]}
config.automatic_research = "mining"
queue.promote(force, "steel", config)
assert(#force.research_queue == 7 and force.research_queue[7] == steel)
for i = 1, 6 do assert(force.research_queue[i] == manual[i]) end
-- No eligible automatic choice removes only the mod's previous entry.
queue.promote(force, nil, config)
assert(#force.research_queue == 6 and not config.automatic_research)
-- Player reordering claims the queue; neither caps nor switching may remove it.
force.research_queue = {mining, manual[1]}
config.automatic_research = "mining"
research.on_research_moved{force = force, player_index = 1}
config.target_levels.mining = 0
queue.remove_capped(force, config)
queue.promote(force, "steel", config)
assert(#force.research_queue == 3 and force.current_research == mining)
config.target_levels.mining = nil
-- Player cancellation clears ownership and does not immediately re-add the choice.
force.research_queue = {manual[1]}
research.on_research_cancelled{force = force, player_index = 1, research = {steel = 1}}
assert(not config.automatic_research and #force.research_queue == 1)
-- Duplicate player levels are preserved, even if their name matches our choice.
force.research_queue = {mining, mining}
config.automatic_research = "mining"
research.on_research_queued{force = force, research = mining, player_index = 1}
queue.promote(force, "steel", config)
assert(force.research_queue[1] == mining and force.research_queue[2] == mining)
-- Script-generated queue events must not recursively schedule or claim ownership.
local owned = config.automatic_research
writes = force.queue_writes
research.on_research_queued{force = force, research = steel}
research.on_research_moved{force = force}
research.on_research_cancelled{force = force, research = {steel = 1}}
assert(config.automatic_research == owned and force.queue_writes == writes)
-- Switching disabled keeps our active research, but explicit player work wins.
force.research_queue = {mining}
config.automatic_research = "mining"
config.allow_switching = false
research.set_strategy(force, "expensive")
assert(force.current_research == mining)
force.research_queue = {mining, manual[1]}
research.on_research_queued{force = force, research = manual[1], player_index = 1}
assert(force.current_research == manual[1] and force.research_queue[2] == mining)
-- Existing saves with no ownership metadata are preserved conservatively.
force.research_queue = {mining, manual[1]}
manual[1].prerequisites = {mining}
config.automatic_research = "mining"
queue.promote(force, "steel", config)
assert(force.research_queue[1] == mining and force.research_queue[2] == manual[1],
    "An automatic prerequisite needed by player work becomes protected")
manual[1].prerequisites = {}
config.automatic_research = nil
force.research_queue = {mining, steel}
queue.promote(force, "steel", config)
assert(force.current_research == mining and #force.research_queue == 2)
print("Research queue regressions passed")
