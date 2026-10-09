local configuration = require("scripts.research.configuration")
local research = require("scripts.research.controller")
local function unlock(name, researched)
    return {name = name, researched = researched, research_unit_ingredients = {}}
end
local advanced = unlock("advanced-pack", false)
local completed = unlock("completed-pack", true)
local force = {name = "player", players = {}, recipes = {
    starter = {enabled = true, prototype = {unlock_results = true}, products = {{type = "item", name = "starter-pack"}}},
    alternative = {enabled = false, prototype = {unlock_results = true}, products = {{type = "item", name = "custom-pack"}}},
    recycling = {enabled = true, prototype = {unlock_results = false}, products = {{type = "item", name = "custom-pack"}}}
}, technologies = {
    [advanced.name] = advanced, [completed.name] = completed,
    consumer = {research_unit_ingredients = {{name = "starter-pack"}, {name = "advanced-pack"},
        {name = "completed-pack"}, {name = "custom-pack"}, {name = "unknown-pack"}}}
}}
advanced.force = force
storage = {}
game = {tick = 1}
local config = configuration.ensure(force)
config.enabled = false
assert(config.allowed_ingredients["starter-pack"])
assert(config.allowed_ingredients["completed-pack"])
assert(config.researched_packs["completed-pack"] and config.researched_packs["starter-pack"])
assert(not config.allowed_ingredients["advanced-pack"])
assert(not config.researched_packs["advanced-pack"])
assert(not config.allowed_ingredients["custom-pack"], "Recycling must not imply the pack is unlocked")
assert(not config.allowed_ingredients["unknown-pack"])
advanced.researched = true
research.on_research_finished{research = advanced}
assert(config.allowed_ingredients["advanced-pack"], "Unset choice follows newly completed research")
research.set_pack_mode(force, "advanced-pack", "off")
research.set_pack_mode(force, "unknown-pack", "on")
configuration.initialize(force)
assert(not config.allowed_ingredients["advanced-pack"], "Explicit Off survives refresh and completed research")
assert(config.researched_packs["advanced-pack"], "Manual Off is distinct from Not researched")
assert(not config.researched_packs["unknown-pack"], "Manual On does not mark a pack researched")
assert(config.allowed_ingredients["unknown-pack"], "Explicit On survives missing unlock research")
force.recipes.alternative.enabled = true
configuration.refresh(force, config)
assert(config.allowed_ingredients["custom-pack"], "Use enabled production recipes for differently named modded packs")
local existing = {allowed_ingredients = {["advanced-pack"] = false, ["unknown-pack"] = true}}
configuration.refresh(force, existing)
assert(not existing.allowed_ingredients["advanced-pack"] and existing.allowed_ingredients["unknown-pack"])
print("Pack default regressions passed")
