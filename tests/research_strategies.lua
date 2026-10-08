-- Run from the mod root with Lua 5.2: lua tests/research_strategies.lua
local technology = require("scripts.research.technology")
local research = require("scripts.research.controller")

local packs = {
    "automation-science-pack", "logistic-science-pack", "military-science-pack",
    "chemical-science-pack", "production-science-pack", "utility-science-pack",
    "space-science-pack", "metallurgic-science-pack", "electromagnetic-science-pack",
    "agricultural-science-pack", "cryogenic-science-pack", "promethium-science-pack"
}
local function tech(name, ingredients, count, time)
    return {
        name = name, research_unit_ingredients = ingredients,
        research_unit_count = count or 100, research_unit_energy = time or 3600,
        enabled = true, researched = false, prototype = {hidden = false}, prerequisites = {}
    }
end
local function score(t, strategy)
    return technology.calculate_effort(t, {research_strategy = strategy})
end
local red = tech("red", {{name = packs[1], amount = 1}})
local ingredients = {}
for _, name in ipairs(packs) do ingredients[#ingredients + 1] = {name = name, amount = 1} end
local all = tech("all", ingredients)
local extra = tech("extra", {{name = packs[1], amount = 2}})
local many = tech("many", red.research_unit_ingredients, 200)
local longer = tech("longer", red.research_unit_ingredients, 100, 7200)
local late = tech("late", {{name = "promethium-science-pack", amount = 1}})

-- 100 units at 60 seconds have the same duration with one or all 12 packs.
for _, strategy in ipairs({"fast", "slow"}) do
    assert(score(red, strategy) == score(all, strategy))
    assert(score(red, strategy) == score(extra, strategy))
    assert(score(many, strategy) == score(longer, strategy))
end
assert(score(red, "fast") < score(longer, "fast"))
assert(score(red, "slow") > score(longer, "slow"))
assert(score(extra, "cheap") == 2 * score(red, "cheap"))
assert(score(many, "cheap") == 2 * score(red, "cheap"))
assert(score(longer, "cheap") == score(red, "cheap"))
assert(score(all, "cheap") > score(red, "cheap"))
assert(score(late, "cheap") > score(red, "cheap"))
assert(score(late, "expensive") < score(red, "expensive"))
assert(score(all, "expensive") == -score(all, "cheap"))
local previous = 0
for _, name in ipairs(packs) do
    local cost = score(tech(name, {{name = name, amount = 1}}), "cheap")
    assert(cost >= previous)
    previous = cost
end
assert(score(extra, "balanced") == 2 * score(red, "balanced"))
assert(score(many, "balanced") == 2 * score(red, "balanced"))
assert(score(longer, "balanced") == 2 * score(red, "balanced"))
assert(score(late, "balanced") > score(red, "balanced"))
assert(score(tech("modded", {{name = "custom-pack", amount = 3}}), "cheap") == 300)

-- Verify the scheduler and the GUI's sorting agree on the strategy winner.
remote = {interfaces = {}}
game = {tick = 1}
local force = require("tests.fixtures").force{name = "player", technologies = {red = red, late = late, longer = longer}}
local config = {
    enabled = true, allow_switching = true, prioritized_techs = {}, deprioritized_techs = {},
    allowed_ingredients = {[packs[1]] = true, ["promethium-science-pack"] = true},
    infinite_research = {}
}
storage = {rantz_research_config = {player = config}}
for strategy, expected in pairs({cheap = "red", expensive = "late", fast = "red", slow = "longer"}) do
    -- Remove duration/cost ties to test the winner rather than iteration order.
    local candidates = (strategy == "cheap" or strategy == "expensive")
        and {red = red, late = late} or {red = red, longer = longer}
    force.technologies = candidates
    force.research_queue = {}
    config.research_strategy = strategy
    research.start_next_research(force, true)
    assert(force.research_queue[1].name == expected)
    local rows = {}
    for name, t in pairs(candidates) do rows[#rows + 1] = {name, t} end
    technology.sort_by_effort(rows, config)
    assert(rows[1][1] == expected)
end
print("Research strategy regressions passed")
