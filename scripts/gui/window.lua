local sections = require("scripts.gui.sections")
local controls = require("scripts.gui.controls")
local window = {}
window.version = 9

function window.get(player)
    return player.gui.top.rantz_research_gui
end

function window.create(player, config)
    local frame = player.gui.top.add{type = "frame", name = "rantz_research_gui", direction = "vertical",
        caption = {"rantz_research_gui.title"}, tags = {rantz_gui_version = window.version}}
    local flow = frame.add{type = "flow", name = "flow", direction = "vertical", style = "rantz_research_list_flow"}
    controls.add_checkbox(flow, "enabled", "enabled", config.enabled)
    local strategy = sections.add_collapsible_section(flow, "strategy", {type = "table", column_count = 3})
    strategy.style.horizontal_spacing = 16
    strategy.style.vertical_spacing = 6
    for _, name in ipairs(controls.strategies) do
        strategy.add{type = "radiobutton", name = "rantz_research_research_" .. name,
            caption = {"rantz_research_gui.research_" .. name}, tooltip = {"rantz_research_gui.research_" .. name .. "_tooltip"},
            state = config.research_strategy == name}
    end
    local packs = sections.add_collapsible_section(flow, "ingredients", {type = "table", column_count = 3})
    packs.style.horizontal_spacing = 32
    packs.style.vertical_spacing = 6
    for _, name in ipairs({"allowed", "blacklisted"}) do
        local pane = sections.add_collapsible_section(flow, name, {type = "scroll-pane",
            horizontal_scroll_policy = "never", vertical_scroll_policy = "auto"})
        pane.style.top_padding = 5
        pane.style.bottom_padding = 5
        pane.style.maximal_height = 200
        pane.style.minimal_width = 440
    end
    local settings_panel = sections.add_collapsible_section(flow, "settings", {type = "flow", direction = "vertical"})
    for _, setting in ipairs(controls.settings) do
        controls.add_checkbox(settings_panel, setting.name, setting.label, config[setting.field])
    end
    local timing = settings_panel.add{type = "table", name = "monitor_timing", column_count = 2}
    timing.style.horizontal_spacing = 8
    for _, name in ipairs({"pack_check_seconds", "pack_grace_seconds"}) do
        timing.add{type = "label", caption = {"rantz_research_gui." .. name}}
        local row = timing.add{type = "flow", name = name, direction = "horizontal"}
        row.style.vertical_align = "center"
        local field = row.add{type = "textfield", name = "rantz_research_timing_input", text = tostring(config[name]),
            numeric = true, allow_decimal = false, allow_negative = false, lose_focus_on_confirm = true,
            tooltip = {"rantz_research_gui." .. name .. "_tooltip"},
            tags = {monitor_timing = name, saved_text = tostring(config[name])}}
        field.style.width = 60
    end
    sections.restore(player, flow)
    return frame
end

function window.ensure(player, config)
    local frame = window.get(player)
    if frame and frame.tags.rantz_gui_version ~= window.version then
        sections.capture(player, frame.flow)
        frame.destroy()
        frame = window.create(player, config)
    end
    return frame
end

return window
