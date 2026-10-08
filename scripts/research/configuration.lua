local configuration = {}

local defaults = {
    enabled = true, prioritized_only = false, allow_switching = true,
    deprioritize_infinite_tech = false, research_strategy = "balanced",
    pack_check_seconds = 10, pack_grace_seconds = 60
}

function configuration.get(force)
    return storage.rantz_research_config and storage.rantz_research_config[force.name]
end

function configuration.refresh(force, config)
    local previous = config.allowed_ingredients or {}
    config.pack_defaults = config.pack_defaults or {}
    local unlocked = {}
    for _, recipe in pairs(force.recipes or {}) do
        if recipe.enabled and recipe.prototype.unlock_results ~= false then
            for _, product in pairs(recipe.products) do
                if product.type == "item" then unlocked[product.name] = true end
            end
        end
    end
    local ingredients = {}
    for _, tech in pairs(force.technologies) do
        for _, ingredient in pairs(tech.research_unit_ingredients or {}) do
            local name = ingredient.name
            if previous[name] == nil then config.pack_defaults[name] = true end
            if config.pack_defaults[name] then
                local unlock = force.technologies[name]
                ingredients[name] = unlock and unlock.researched == true or (not unlock and unlocked[name] == true)
            else
                ingredients[name] = previous[name]
            end
        end
    end
    config.allowed_ingredients = ingredients
    for name in pairs(config.pack_defaults) do
        if ingredients[name] == nil then config.pack_defaults[name] = nil end
    end
end

function configuration.ensure(force)
    storage.rantz_research_config = storage.rantz_research_config or {}
    local config = configuration.get(force)
    if not config then
        config = {}
        storage.rantz_research_config[force.name] = config
    end
    for name, value in pairs(defaults) do
        if config[name] == nil then config[name] = value end
    end
    -- Historical keys remain stable for save compatibility.
    config.prioritized_techs = config.prioritized_techs or {}
    config.deprioritized_techs = config.deprioritized_techs or {}
    config.target_levels = config.target_levels or {}
    config.dynamic_packs = config.dynamic_packs or {}
    config.dynamic_available = config.dynamic_available or {}
    config.pack_empty_since = config.pack_empty_since or {}
    if not config.allowed_ingredients then configuration.refresh(force, config) end
    -- Obsolete counters/caches are no longer used or recreated.
    config.tech_counts = nil
    config.infinite_research = nil
    config.announce_completed = nil
    config.no_announce_this_tick = nil
    return config
end

function configuration.initialize(force)
    local config = configuration.ensure(force)
    configuration.refresh(force, config)
    return config
end

return configuration
