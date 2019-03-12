local prefix = "module_inserter_"
data:extend({
    {
        type = "int-setting",
        name = prefix .. "config_size",
        setting_type = "runtime-per-user",
        default_value = 11,
        minimum_value = 1,
        maximum_value = 200, --don't trust factorians..
        order = "a"
    },
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