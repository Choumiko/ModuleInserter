require "__ModuleInserter__/prototypes/item"
require "__ModuleInserter__/prototypes/style"

data:extend({
    {
        type = "recipe",
        name = "module-inserter",
        energy_required = 0.1,
        ingredients = {},
        result = "module-inserter",
        enabled = false
    }
})

table.insert(
    data.raw["technology"]["construction-robotics"]["effects"],
    { type = "unlock-recipe", recipe = "module-inserter" }
)

-- data.raw.module["speed-module"].limitation = {"iron-gear-wheel"}
-- data.raw.module["speed-module"]["limitation_message_key"] = "production-module-usable-only-on-intermediates"
