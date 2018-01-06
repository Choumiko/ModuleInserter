data:extend({
    {
        type = "font",
        name = "module-inserter-small-font",
        from = "default",
        size = 14
    }
})

data.raw["gui-style"].default["module-inserter-small-button"] = {
    type = "button_style",
    parent = "button",
    font = "module-inserter-small-font"
}

data.raw["gui-style"].default["module-inserter-button"] =
    {
        type = "button_style",
        parent = "button",
        width = 33,
        height = 33,
        top_padding = 6,
        right_padding = 0,
        bottom_padding = 0,
        left_padding = 0,
        font = "module-inserter-small-font",
        default_graphical_set =
        {
            type = "monolith",
            monolith_image =
            {
                filename = "__ModuleInserter__/graphics/gui.png",
                priority = "extra-high-no-scale",
                width = 32,
                height = 32,
                x = 64
            }
        },
        hovered_graphical_set =
        {
            type = "monolith",
            monolith_image =
            {
                filename = "__ModuleInserter__/graphics/gui.png",
                priority = "extra-high-no-scale",
                width = 32,
                height = 32,
                x = 96
            }
        },
        clicked_graphical_set =
        {
            type = "monolith",
            monolith_image =
            {
                filename = "__ModuleInserter__/graphics/gui.png",
                width = 32,
                height = 32,
                x = 96
            }
        }
    }
