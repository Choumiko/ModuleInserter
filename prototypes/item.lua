local copyPrototype = require "__ModuleInserter__/lib"

local mi_planner = {
    type = "selection-tool",
    name = "module-inserter",
    icon = "__ModuleInserter__/graphics/module-inserter-icon.png",
    icon_size = 32,
    subgroup = "tool",
    order = "c[automated-construction]-d[module-inserter]",
    stack_size = 1,
    stackable = false,
    selection_color = { r = 0, g = 1, b = 0 },
    alt_selection_color = { r = 0, g = 0, b = 1 },
    selection_mode = {"same-force", "buildable-type"},
    alt_selection_mode = {"same-force", "any-entity"},
    selection_cursor_box_type = "copy",
    alt_selection_cursor_box_type = "copy",
    entity_type_filters = {"mining-drill", "furnace", "assembling-machine", "lab", "beacon", "rocket-silo", "module-inserter-proxy"},
    entity_filter_mode = "whitelist",
    alt_entity_filters = {"item-request-proxy", "module-inserter-proxy"},
    alt_entity_filter_mode = "whitelist",
    --show_in_library = true
}

--Error while loading item prototype "module-inserter" (selection-tool): Missing selection_mode in module-inserter item definition.
--Valid values are: blueprint, deconstruct, cancel-deconstruct, items, trees, buildable-type, tiles, items-to-place, any-entity, any-tile, matches-force.


local mi_proxy = copyPrototype("container","wooden-chest","module-inserter-proxy")
mi_proxy.icon = "__ModuleInserter__/graphics/module-inserter-icon.png"
mi_proxy.flags = mi_proxy.flags or {}
table.insert(mi_proxy.flags, "placeable-off-grid")
mi_proxy.collision_box = {{-0.1,-0.1},{0.1,0.1}}
mi_proxy.collision_mask = {"doodad-layer", "not-colliding-with-itself"}

local mi_proxy_i = copyPrototype("item","wooden-chest","module-inserter-proxy")
mi_proxy_i.flags = mi_proxy_i.flags or {}
table.insert(mi_proxy_i.flags, "hidden")
mi_proxy_i.icon = "__ModuleInserter__/graphics/module-inserter-icon.png"
mi_proxy_i.stack_size = 1000
mi_proxy_i.fuel_value = nil

data:extend({mi_planner,mi_proxy, mi_proxy_i,})
