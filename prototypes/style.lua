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
    parent = "tool_button_red",
    padding = 0
}

styles["mi_shortcut_bar_button_green"] = {
    type = "button_style",
    parent = "shortcut_bar_button_green",
    padding = 4
}

data:extend{
    {
        type = "sprite",
        name = "mi_import_string",
        filename = "__base__/graphics/icons/shortcut-toolbar/mip/import-string-x24.png",
        priority = "extra-high-no-scale",
        size = 24,
        scale = 0.5,
        mipmap_count = 2,
        flags = {"gui-icon"}
    }
}

styles.mi_naked_scroll_pane = {
  type = "scroll_pane_style",
  extra_padding_when_activated = 0,
  padding = 0,
  vertically_stretchable = "on",
  graphical_set = {
    shadow = default_inner_shadow--luacheck: ignore
  },
  vertical_flow_style = {
    type = "vertical_flow_style",
    padding = 12,
    top_padding = 8
  }
}