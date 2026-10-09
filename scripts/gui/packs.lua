local monitor = require("scripts.research.monitor")
local packs = {}
local status_sprites = {
    pack_in_stock = "utility/status_working",
    pack_out_of_stock = "utility/status_not_working",
    pack_not_researched = "utility/status_yellow",
    pack_stock_not_monitored = "utility/status_yellow"
}

local pack_order = {
    ["automation-science-pack"] = 1,
    ["logistic-science-pack"] = 2,
    ["chemical-science-pack"] = 3,
    ["military-science-pack"] = 4,
    ["utility-science-pack"] = 5,
    ["production-science-pack"] = 6,
    ["metallurgic-science-pack"] = 7,
    ["electromagnetic-science-pack"] = 8,
    ["agricultural-science-pack"] = 9,
    ["cryogenic-science-pack"] = 10,
    ["promethium-science-pack"] = 11,
    ["space-science-pack"] = 12
}

function packs.update(flow, config)
    -- Old saved GUI instances are replaced when the window is reopened.
    if flow.type ~= "table" then
        return
    end
    local previous_rows = {table.unpack(flow.children)}
    for _, row in ipairs(previous_rows) do
        if config.allowed_ingredients[row.name] == nil then row.destroy() end
    end
    local names = {}
    for name in pairs(config.allowed_ingredients) do
        names[#names + 1] = name
    end
    table.sort(names, function(a, b)
        local a_order = pack_order[a] or math.huge
        local b_order = pack_order[b] or math.huge
        if a_order ~= b_order then
            return a_order < b_order
        end
        return a < b
    end)
    local enabled = 0
    for index, name in ipairs(names) do
        local allowed = monitor.is_allowed(config, name)
        local dynamic = config.dynamic_packs and config.dynamic_packs[name] == true
        if allowed then enabled = enabled + 1 end
        local row = flow[name]
        if not row then
            local prototype = prototypes.item[name]
            local caption = prototype and prototype.localised_name or name
            row = flow.add{type = "flow", name = name, direction = "horizontal"}
            row.style.vertical_align = "center"
            row.style.horizontal_spacing = 8
            row.add{
                type = "sprite", name = "icon",
                style = "rantz_research_sprite",
                sprite = prototype and ("item/" .. name) or "utility/questionmark",
                tooltip = caption
            }
            local dropdown = row.add{type = "drop-down", name = "rantz_pack_mode",
                items = {}, tags = {pack = name}}
            dropdown.style.width = 120
        end
        local current_index = row.get_index_in_parent()
        if current_index ~= index then flow.swap_children(current_index, index) end
        local dropdown = row.rantz_pack_mode
        local has_lab = monitor.has_lab(config)
        -- Factorio cannot disable individual dropdown entries. Show Dynamic in
        -- grey without a lab and reject that selection in the event handler.
        dropdown.items = {{"rantz_research_gui.pack_on"}, {"rantz_research_gui.pack_off"},
            has_lab and {"rantz_research_gui.pack_dynamic"} or
                {"", "[color=128,128,128]", {"rantz_research_gui.pack_dynamic"}, "[/color]"}}
        dropdown.selected_index = dynamic and 3 or (config.allowed_ingredients[name] and 1 or 2)
        dropdown.tooltip = {"rantz_research_gui." .. (has_lab and "dynamic_tooltip" or "monitor_required")}
        local status = monitor.pack_status(config, name)
        row.icon.tooltip = {"", prototypes.item[name] and prototypes.item[name].localised_name or name,
            "\n", {"rantz_research_gui." .. status}}
        local indicator = row.rantz_pack_availability
        if not indicator then
            indicator = row.add{type = "sprite", name = "rantz_pack_availability"}
            indicator.style.width = 12
            indicator.style.height = 12
        end
        indicator.sprite = status_sprites[status]
        indicator.tooltip = {"rantz_research_gui." .. status}
    end
    flow.parent.ingredients_header.summary.caption = {
        "", {"rantz_research_gui.allowed_ingredients_label"}, " (", enabled, "/", #names, ")"
    }
end

return packs
