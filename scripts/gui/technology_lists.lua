local technology = require("scripts.research.technology")
local lists = {}

function lists.prepare(force, config)
    local blacklist, result = {}, {allowed = {}, blacklisted = {}}
    for _, name in ipairs(config.deprioritized_techs) do blacklist[name] = true end
    for name, tech in pairs(force.technologies) do
        if not tech.researched and tech.enabled and not tech.prototype.hidden and #tech.research_unit_ingredients > 0 then
            local list = blacklist[name] and result.blacklisted or result.allowed
            list[#list + 1] = {name, tech}
        end
    end
    technology.sort_by_effort(result.allowed, config)
    technology.sort_by_effort(result.blacklisted, config)
    return result
end

function lists.capture_drafts(flow)
    local drafts = {}
    for _, name in ipairs({"allowed", "blacklisted"}) do
        local pane = flow[name]
        if pane and pane.flow then
            for _, child in ipairs(pane.flow.children) do
                if child.type == "textfield" and child.tags.tech_name and child.text ~= child.tags.saved_text then
                    drafts[child.tags.tech_name] = child.text
                end
            end
        end
    end
    return drafts
end

local function add_row(grid, tech, blacklisted)
    local name = tech.name
    local tags = {tech_name = name}
    local action = grid.add{type = "sprite-button", style = "rantz_research_sprite_button",
        name = "rantz_research_" .. (blacklisted and "enable-" or "disable-") .. name,
        sprite = blacklisted and "utility/check_mark" or "utility/not_available_black",
        tooltip = {"rantz_research_gui." .. (blacklisted and "enable_tooltip" or "disable_tooltip")},
        mouse_button_filter = {"left"}, tags = tags}
    local field = grid.add{type = "textfield", name = "rantz_research_target-" .. name,
        text = "", numeric = true, allow_decimal = false, allow_negative = false,
        lose_focus_on_confirm = true, tags = {tech_name = name, saved_text = ""}}
    field.style.width = 35
    local label = grid.add{type = "label", name = "rantz_research_name-" .. name,
        style = "rantz_research_tech_label", tags = tags}
    label.style.width = 240
    label.style.single_line = true
    local packs = grid.add{type = "flow", name = "rantz_research_packs-" .. name,
        style = "rantz_research_tech_flow", direction = "horizontal", tags = tags}
    return {action, field, label, packs}
end

local function ensure_headers(grid)
    for column, key in ipairs({"action", "max", "research", "required_packs"}) do
        local name = "column_" .. key
        local header = grid[name]
        if not header then
            header = grid.add{type = "label", name = name,
                caption = column == 1 and "" or {"rantz_research_gui." .. name},
                tags = {column_header = true}}
            header.style.font = "default-small"
            header.style.bottom_padding = 4
        end
        local actual = header.get_index_in_parent()
        if actual ~= column then grid.swap_children(actual, column) end
    end
end

function lists.render(pane, technologies, blacklisted, config, drafts)
    local grid = pane.flow
    if not grid then
        grid = pane.add{type = "table", name = "flow", column_count = 4}
        grid.style.horizontal_spacing = 4
        grid.style.vertical_spacing = 0
    end
    if grid.empty then grid.empty.destroy() end
    ensure_headers(grid)
    local present = {}
    for _, entry in ipairs(technologies) do present[entry[1]] = true end
    -- Snapshot children before destroying; retained input fields keep focus/cursor.
    local previous_children = {table.unpack(grid.children)}
    for _, child in ipairs(previous_children) do
        if not child.tags.column_header and not present[child.tags.tech_name] then child.destroy() end
    end
    for i, entry in ipairs(technologies) do
        local name, tech = entry[1], entry[2]
        local prefix = blacklisted and "rantz_research_enable-" or "rantz_research_disable-"
        local cells
        if grid[prefix .. name] then
            cells = {grid[prefix .. name], grid["rantz_research_target-" .. name],
                grid["rantz_research_name-" .. name], grid["rantz_research_packs-" .. name]}
        else
            cells = add_row(grid, tech, blacklisted)
        end
        for column, cell in ipairs(cells) do
            local desired = 4 + (i - 1) * 4 + column
            local actual = cell.get_index_in_parent()
            if actual ~= desired then grid.swap_children(actual, desired) end
        end
        -- Refresh retained buttons too, including windows restored from a save.
        cells[1].sprite = blacklisted and "utility/check_mark" or "utility/not_available_black"
        cells[1].style.width = 28
        cells[1].style.height = 28
        local field, label, packs = cells[2], cells[3], cells[4]
        local infinite = technology.is_infinite(tech)
        local target = config.target_levels[name]
        local saved_text = infinite and target ~= nil and tostring(target) or ""
        local desired_text = drafts[name] ~= nil and drafts[name] or saved_text
        if field.text ~= desired_text then field.text = desired_text end
        field.tags = {tech_name = name, saved_text = saved_text}
        field.enabled = infinite
        field.tooltip = {"rantz_research_gui." .. (infinite and "target_level_tooltip" or "finite_target_tooltip")}
        label.caption = tech.localised_name
        label.tooltip = tech.localised_name
        local disabled = technology.is_disabled(tech, config)
        label.style.font_color = disabled and {r = 0.5, g = 0.5, b = 0.5} or {r = 1, g = 1, b = 1}
        if technology.is_target_reached(tech, config) then
            label.tooltip = {"rantz_research_gui.target_reached_tooltip", tech.localised_name, target}
        elseif disabled then
            label.tooltip = {"rantz_research_gui.disabled_packs_tooltip", tech.localised_name}
        end
        packs.clear()
        for _, ingredient in ipairs(tech.research_unit_ingredients) do
            local sprite = "item/" .. ingredient.name
            if not helpers.is_valid_sprite_path(sprite) then sprite = "utility/questionmark" end
            packs.add{type = "sprite", style = "rantz_research_sprite", sprite = sprite}
        end
    end
    if #technologies == 0 then grid.add{type = "label", name = "empty", caption = {"rantz_research_gui.none"}} end
end

function lists.update(flow, prepared, config)
    local drafts = lists.capture_drafts(flow)
    lists.render(flow.allowed, prepared.allowed, false, config, drafts)
    lists.render(flow.blacklisted, prepared.blacklisted, true, config, drafts)
end

return lists
