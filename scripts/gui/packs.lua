local packs = {}

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
        local allowed = config.allowed_ingredients[name]
        if allowed then enabled = enabled + 1 end
        local row = flow[name]
        if not row then
            local prototype = prototypes.item[name]
            local caption = prototype and prototype.localised_name or name
            row = flow.add{type = "flow", name = name, direction = "horizontal"}
            row.style.vertical_align = "center"
            row.style.horizontal_spacing = 8
            row.add{
                type = "checkbox",
                name = "rantz_research_allow_ingredient-" .. name,
                caption = "",
                tooltip = caption,
                state = allowed
            }
            row.add{
                type = "sprite",
                style = "rantz_research_sprite",
                sprite = prototype and ("item/" .. name) or "utility/questionmark",
                tooltip = caption
            }
        end
        local current_index = row.get_index_in_parent()
        if current_index ~= index then flow.swap_children(current_index, index) end
        row["rantz_research_allow_ingredient-" .. name].state = allowed
    end
    flow.parent.ingredients_header.summary.caption = {
        "", {"rantz_research_gui.allowed_ingredients_label"}, " (", enabled, "/", #names, ")"
    }
end

return packs
