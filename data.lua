data.raw["gui-style"].default["rantz_research_header_label"] = {
    type = "label_style",
    font_color = {r = .91764705882352941176, g = .85098039215686274509, b = .67450980392156862745},
    right_padding = 6
}

data.raw["gui-style"].default["rantz_research_list_flow"] = {
    type = "vertical_flow_style",
    vertical_spacing = 0
}

data.raw["gui-style"].default["rantz_research_tech_flow"] = {
    type = "horizontal_flow_style",
    horizontal_spacing = 0,
    resize_row_to_width = true
}

data.raw["gui-style"].default["rantz_research_sprite_button"] = {
    type = "button_style",
    width = 24,
    height = 24,
    top_padding = 0,
    right_padding = 0,
    bottom_padding = 0,
    left_padding = 0,
    left_click_sound = {
        {
            filename = "__core__/sound/gui-click.ogg",
            volume = 1
        }
    }
}

data.raw["gui-style"].default["rantz_research_tech_label"] = {
    type = "label_style",
    left_padding = 4,
    right_padding = 4
}

data.raw["gui-style"].default["rantz_research_sprite"] = {
    type = "image_style",
    width = 24,
    height = 24,
    top_padding = 0,
    right_padding = 0,
    bottom_padding = 0,
    left_padding = 0,
    stretch_image_to_widget_size = true
}

data:extend({
    -- keybindings
    {
        type = "custom-input",
        name = "rantz_research_toggle",
        key_sequence = "SHIFT + T"
    }
})
