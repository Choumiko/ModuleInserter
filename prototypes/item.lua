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
    selection_mode = {"same-force", "deconstruct"},
    alt_selection_mode = {"same-force", "any-entity"},
    selection_cursor_box_type = "copy",
    alt_selection_cursor_box_type = "copy",
    entity_type_filters = {"mining-drill", "furnace", "assembling-machine", "lab", "beacon", "rocket-silo", "item-request-proxy"},
    entity_filter_mode = "whitelist",
    alt_entity_filters = {"item-request-proxy"},
    alt_entity_filter_mode = "whitelist",
    --show_in_library = true
}

--Error while loading item prototype "module-inserter" (selection-tool): Missing selection_mode in module-inserter item definition.
--Valid values are: blueprint, deconstruct, cancel-deconstruct, items, trees, buildable-type, tiles, items-to-place, any-entity, any-tile, matches-force.


data:extend{{
    type = "item",
    name = "module_inserter_pickup",
    icon = "__base__/graphics/icons/wooden-chest.png",
    flags = {"hidden"},
    icon_size = 32,
    order = "a[items]-a[wooden-chest]",
    place_result = "module_inserter_pickup",
    stack_size = 1
}}

local mi_proxy = copyPrototype("logistic-container","logistic-chest-active-provider","module_inserter_pickup")

mi_proxy.max_health = 100
mi_proxy.corpse = "small-remnants"
mi_proxy.selection_box = {{-0.5, -0.5}, {0.5, 0.5}}
mi_proxy.minable = {mining_time = 0.1}
mi_proxy.icon = "__ModuleInserter__/graphics/module-inserter-icon.png"
mi_proxy.icon_size = 32
mi_proxy.flags = {
    "placeable-neutral",
    "player-creation",
    "placeable-off-grid",
    "hidden",
    "not-on-map",
    "not-blueprintable",
    "not-upgradable",
    "no-automated-item-removal",
    "no-automated-item-insertion",
}
mi_proxy.next_upgrade = nil
mi_proxy.fast_replaceable_group = nil
mi_proxy.collision_box = {{-0.1,-0.1},{0.1,0.1}}
mi_proxy.collision_mask = {"doodad-layer", "not-colliding-with-itself"}

data:extend({mi_planner, mi_proxy})
