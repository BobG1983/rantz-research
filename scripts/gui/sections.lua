local sections = {}

local definitions = {
    strategy = {content = "research_strategies_outer", header = "strategy_header", label = "research_strategy"},
    ingredients = {content = "allowed_ingredients", header = "ingredients_header", label = "allowed_ingredients_label"},
    allowed = {content = "allowed", header = "allowed_header", label = "allowed_label"},
    blacklisted = {content = "blacklisted", header = "blacklisted_header", label = "blacklisted_label"},
    settings = {content = "settings", header = "settings_header", label = "settings_label"}
}

function sections.get_expanded(player)
    -- Access saved UI preferences only in event handlers, never at module load.
    storage.gui_expanded_sections = storage.gui_expanded_sections or {}
    local saved = storage.gui_expanded_sections[player.index]
    if not saved then
        saved = {}
        storage.gui_expanded_sections[player.index] = saved
    end
    return saved
end

function sections.set_expanded(flow, name, expanded)
    local section = definitions[name]
    flow[section.content].visible = expanded
    local button = flow[section.header]["rantz_research_toggle_" .. name]
    button.sprite = expanded and "utility/collapse" or "utility/expand"
    button.tooltip = {
        "rantz_research_gui." .. (expanded and "collapse_section" or "expand_section"),
        {"rantz_research_gui." .. section.label}
    }
end

function sections.add_spacing(parent)
    -- Keep the gap visible even when the section's content is collapsed.
    local spacer = parent.add{type = "empty-widget"}
    spacer.style.height = 6
end

sections.definitions = definitions

function sections.add_collapsible_section(parent, name, spec)
    local definition = definitions[name]
    local header = parent.add{type = "flow", name = definition.header, direction = "horizontal"}
    header.style.vertical_align = "center"
    header.add{
        type = "sprite-button", name = "rantz_research_toggle_" .. name,
        style = "rantz_research_sprite_button", sprite = "utility/expand",
        tooltip = {"rantz_research_gui.expand_section", {"rantz_research_gui." .. definition.label}},
        mouse_button_filter = {"left"}
    }
    header.add{type = "label", name = "summary", style = "rantz_research_header_label",
        caption = {"rantz_research_gui." .. definition.label}}
    spec.name = definition.content
    spec.visible = false
    local content = parent.add(spec)
    sections.add_spacing(parent)
    return content
end

function sections.capture(player, flow)
    local saved = sections.get_expanded(player)
    for name, definition in pairs(definitions) do
        if flow[definition.content] then saved[name] = flow[definition.content].visible end
    end
end

function sections.restore(player, flow)
    local saved = sections.get_expanded(player)
    for name in pairs(definitions) do sections.set_expanded(flow, name, saved[name] == true) end
end

return sections
