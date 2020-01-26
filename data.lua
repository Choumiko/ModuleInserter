require "__ModuleInserter__/prototypes/item"
require "__ModuleInserter__/prototypes/style"

data:extend({
    {
        type = 'custom-input',
        name = 'get-module-inserter',
        key_sequence = "",
        action = 'create-blueprint-item',
        item_to_create = 'module-inserter',
        consuming = 'none'
    },
    {
        type = 'shortcut',
        name = 'module-inserter',
        --order = "a[yarm]",
        action = 'create-blueprint-item',
        item_to_create = 'module-inserter',
        style = 'green',
        icon = {
            filename = "__ModuleInserter__/graphics/new-module-inserter-x32-white.png",
            priority = 'extra-high-no-scale',
            size = 32,
            scale = 1,
            flags = {'icon'},
        },
        small_icon = {
            filename = "__ModuleInserter__/graphics/new-module-inserter-x24-white.png",
            priority = 'extra-high-no-scale',
            size = 24,
            scale = 1,
            flags = {'icon'},
        },
        disabled_small_icon = {
            filename = "__ModuleInserter__/graphics/new-module-inserter-x24-white.png",
            priority = 'extra-high-no-scale',
            size = 24,
            scale = 1,
            flags = {'icon'},
        },
    },
    {
        type = "selection-tool",
        name = "module-inserter",
        icon = "__ModuleInserter__/graphics/module-inserter-icon.png",
        icon_size = 32,
        flags = {"hidden", "only-in-cursor"},
        stack_size = 1,
        selection_color = { r = 0, g = 1, b = 0 },
        alt_selection_color = { r = 0, g = 0, b = 1 },
        selection_mode = {"same-force", "deconstruct"},
        alt_selection_mode = {"same-force", "any-entity"},
        selection_cursor_box_type = "copy",
        alt_selection_cursor_box_type = "copy",
        entity_type_filters = {"mining-drill", "furnace", "assembling-machine", "lab", "beacon", "rocket-silo", "item-request-proxy"},
        entity_filter_mode = "whitelist",
        alt_entity_filters = {"item-request-proxy"},
        alt_entity_filter_mode = "whitelist"
    }
})
