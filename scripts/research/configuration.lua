local configuration = {}

local defaults = {
    enabled = true, prioritized_only = false, allow_switching = true,
    deprioritize_infinite_tech = false, research_strategy = "balanced"
}

function configuration.get(force)
    return storage.rantz_research_config and storage.rantz_research_config[force.name]
end

function configuration.refresh(force, config)
    local previous = config.allowed_ingredients or {}
    local ingredients = {}
    for _, tech in pairs(force.technologies) do
        for _, ingredient in pairs(tech.research_unit_ingredients) do
            ingredients[ingredient.name] = previous[ingredient.name] ~= false
        end
    end
    config.allowed_ingredients = ingredients
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
