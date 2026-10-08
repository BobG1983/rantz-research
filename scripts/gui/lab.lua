local research = require("scripts.research.controller")
local monitor = require("scripts.research.monitor")
local lab_gui = {}
local panel_name = "rantz_research_lab"

local function set_expanded(panel, expanded)
    panel.monitor.visible = expanded
    panel.lab_header.rantz_lab_toggle.sprite = expanded and "utility/collapse" or "utility/expand"
    panel.lab_header.rantz_lab_toggle.tooltip = {"rantz_research_gui." ..
        (expanded and "collapse_monitor" or "expand_monitor")}
end

function lab_gui.refresh(player)
    local root = player.gui.relative
    if not root then return end
    local panel = root[panel_name]
    local entity = player.opened
    -- opened can also be a GUI element or another LuaObject.
    if not entity or entity.object_name ~= "LuaEntity" or not monitor.valid_lab(entity, player.force) then
        if panel then panel.destroy() end
        return
    end
    if panel and panel.tags.rantz_lab_version ~= 2 then
        panel.destroy()
        panel = nil
    end
    if not panel then
        panel = root.add{type = "frame", name = panel_name, direction = "vertical",
            tags = {rantz_lab_version = 2},
            anchor = {gui = defines.relative_gui_type.lab_gui, position = defines.relative_gui_position.right}}
        panel.style.padding = 6
        local header = panel.add{type = "flow", name = "lab_header", direction = "horizontal"}
        header.style.vertical_align = "center"
        header.add{type = "sprite-button", name = "rantz_lab_toggle", sprite = "utility/expand",
            style = "rantz_research_sprite_button", mouse_button_filter = {"left"}}
        header.add{type = "label", name = "lab_title", caption = {"rantz_research_gui.title"},
            style = "rantz_research_header_label"}
        panel.add{type = "button", name = "monitor", caption = {"rantz_research_gui.monitor_lab"}}
        panel.monitor.style.font = "default-small"
        panel.monitor.style.height = 28
    end
    local expanded = storage.rantz_lab_panel_expanded
    set_expanded(panel, expanded ~= nil and expanded[player.index] == true)
    local config = research.ensure_config(player.force)
    local selected = config.monitored_lab == entity
    panel.monitor.caption = {"rantz_research_gui." .. (selected and "stop_monitoring" or "monitor_lab")}
    panel.monitor.tooltip = {"rantz_research_gui.monitor_lab_tooltip"}
    local lab = config.monitored_lab
    if monitor.valid_lab(lab, player.force) then
        panel.lab_header.lab_title.tooltip = {"rantz_research_gui.monitor_location", lab.surface.name,
            math.floor(lab.position.x), math.floor(lab.position.y)}
    else
        panel.lab_header.lab_title.tooltip = {"rantz_research_gui.monitor_required"}
    end
end

function lab_gui.on_click(event)
    local player = game.players[event.player_index]
    local panel = player and player.gui.relative and player.gui.relative[panel_name]
    if not panel or not event.element or not event.element.valid then return false end
    if panel.lab_header and event.element == panel.lab_header.rantz_lab_toggle then
        storage.rantz_lab_panel_expanded = storage.rantz_lab_panel_expanded or {}
        local expanded = not panel.monitor.visible
        storage.rantz_lab_panel_expanded[player.index] = expanded
        set_expanded(panel, expanded)
        return true
    end
    if event.element ~= panel.monitor then return false end
    local entity = player.opened
    if entity and entity.object_name == "LuaEntity" and monitor.valid_lab(entity, player.force) then
        local config = research.ensure_config(player.force)
        if config.monitored_lab == entity then research.set_monitored_lab(player.force, nil)
        else research.set_monitored_lab(player.force, entity) end
    end
    return true
end

return lab_gui
