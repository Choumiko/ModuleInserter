local prefix = "module_inserter_"
data:extend({
    {
        type = "int-setting",
        name = prefix .. "proxies_per_tick",
        setting_type = "runtime-global",
        default_value = 30,
        minimum_value = 1,
        order = "a"
    },
    {
        type = "bool-setting",
        name = prefix .. "overwrite",
        setting_type = "runtime-per-user",
        default_value = true,
        order = "b"
    },
    {
        type = "bool-setting",
        name = prefix .. "fill_all",
        setting_type = "runtime-per-user",
        default_value = true,
        order = "c"
    },
    {
        type = "bool-setting",
        name = prefix .. "hide_button",
        setting_type = "runtime-per-user",
        default_value = false,
        order = "d"
    }
    -- {
    --     type = "bool-setting",
    --     name = prefix .. "enable_module",
    --     setting_type = "startup",
    --     default_value = true,
    --     order = "a"
    -- },
    -- {
    --     type = "bool-setting",
    --     name = prefix .. "free_wires",
    --     setting_type = "runtime-global",
    --     default_value = false,
    --     order = "a"
    -- }
})