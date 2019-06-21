local styles = data.raw["gui-style"].default
styles["module-inserter-small-button"] = {
    type = "button_style",
    parent = "button",
    right_padding = 4,
    left_padding = 4,
}

styles["module-inserter-button"] =
    {
        type = "button_style",
        parent = "button",
        width = 36,
        height = 36,
        right_padding = 0,
        left_padding = 0,
    }

styles["mi_delete_preset"] = {
    type = "button_style",
    parent = "red_icon_button",
    padding = 0
}
