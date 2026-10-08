local controls = {}
controls.strategies = {"fast", "cheap", "balanced", "slow", "expensive", "random"}
controls.settings = {
    {name = "queued_only", field = "prioritized_only", label = "prioritized_only"},
    {name = "allow_switching", field = "allow_switching", label = "allow_switching"},
    {name = "deprioritize_infinite_tech", field = "deprioritize_infinite_tech", label = "deprioritize_infinite_tech"}
}

function controls.add_checkbox(parent, name, label, value)
    return parent.add{type = "checkbox", name = "rantz_research_" .. name,
        caption = {"rantz_research_gui." .. label}, tooltip = {"rantz_research_gui." .. label .. "_tooltip"},
        state = value == true}
end

function controls.sync(flow, config)
    flow.rantz_research_enabled.state = config.enabled
    for _, setting in ipairs(controls.settings) do
        flow.settings["rantz_research_" .. setting.name].state = config[setting.field]
    end
    for _, name in ipairs(controls.strategies) do
        flow.research_strategies_outer["rantz_research_research_" .. name].state = config.research_strategy == name
    end
end

function controls.setting_field(name)
    if name == "rantz_research_enabled" then return "enabled" end
    for _, setting in ipairs(controls.settings) do
        if name == "rantz_research_" .. setting.name then return setting.field end
    end
end

return controls
