local styles = data.raw["gui-style"].default
styles["module-inserter-small-button"] = {
    type = "button_style",
    parent = "button",
    width = 60
}

styles["module-inserter-button"] =
    {
        type = "button_style",
        parent = "mod_gui_button",
    }

styles["mi_delete_preset"] = {
    type = "button_style",
    parent = "red_icon_button",
    padding = 0
}

styles["mi_shortcut_bar_button_green"] = {
    type = "button_style",
    parent = "shortcut_bar_button_green",
    padding = 4
}
