local copyPrototype = require "__ModuleInserter__/lib"

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
mi_proxy.icon_mipmaps = 0
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

data:extend{mi_proxy}