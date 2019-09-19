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

if not mods["IndustrialRevolution"] then
    table.insert(
        data.raw.technology["construction-robotics"].effects,
        { type = "unlock-recipe", recipe = "module-inserter" }
    )
else
    table.insert(
        data.raw.technology["deadlock-bronze-construction"].effects,
        { type = "unlock-recipe", recipe = "module-inserter" }
    )
    table.insert(
        data.raw.technology["personal-roboport-equipment"].effects,
        { type = "unlock-recipe", recipe = "module-inserter" }
    )
end
