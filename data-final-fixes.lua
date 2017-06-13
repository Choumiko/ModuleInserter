local copyPrototype = require "lib"

local types = {["mining-drill"] = true, ["assembling-machine"] = true, lab = true, ["rocket-silo"] = true, furnace = true, beacon = true}

local function checkProductivity()
    for _, beacon in pairs(data.raw.beacon) do
        for _, effect in pairs(beacon.allowed_effects) do
            if effect == "productivity" then
                return true
            end
        end
    end
end

if checkProductivity() then
    local metaBeacon = copyPrototype("selection-tool","module-inserter","module-inserter-beacon")
    table.insert(metaBeacon.flags, "hidden")
    data:extend({metaBeacon})
end

for t, _ in pairs(types) do
    for _, ent in pairs(data.raw[t]) do
        if type(ent.module_specification) == "table" and type(ent.module_specification.module_slots) == "number" then
            if data.raw["item"][ent.name] then
                local prototype = data.raw["item"][ent.name]
                local style =
                    {
                        type = "checkbox_style",
                        parent = "mi-icon-style",
                        default_background =
                        {
                            filename = prototype.icon,
                            width = 32,
                            height = 32,
                            scale=2
                        },
                        hovered_background =
                        {
                            filename = prototype.icon,
                            width = 32,
                            height = 32,
                            scale=2
                        },
                        checked_background =
                        {
                            filename = prototype.icon,
                            width = 32,
                            height = 32
                        },
                        clicked_background =
                        {
                            filename = prototype.icon,
                            width = 32,
                            height = 32
                        }
                    }
                data.raw["gui-style"].default["mi-icon-"..prototype.name] = style
            end
        end
    end
end

for _, prototype in pairs(data.raw["module"]) do
    local style =
        {
            type = "checkbox_style",
            parent = "mi-icon-style",
            default_background =
            {
                filename = prototype.icon,
                width = 32,
                height = 32,
                scale=2
            },
            hovered_background =
            {
                filename = prototype.icon,
                width = 32,
                height = 32,
                scale=2
            },
            checked_background =
            {
                filename = prototype.icon,
                width = 32,
                height = 32
            },
            clicked_background =
            {
                filename = prototype.icon,
                width = 32,
                height = 32
            }
        }
    data.raw["gui-style"].default["mi-icon-"..prototype.name] = style
end

data.raw["gui-style"].default["mi-icon-style"] =
    {
        type = "checkbox_style",
        parent = "checkbox_style",
        width = 32,
        height = 32,
        bottom_padding = 8,
        default_background =
        {
            filename = "__core__/graphics/gui.png",
            priority = "extra-high-no-scale",
            width = 32,
            height = 32,
            x = 111,
            scale=2
        },
        hovered_background =
        {
            filename = "__core__/graphics/gui.png",
            priority = "extra-high-no-scale",
            width = 32,
            height = 32,
            x = 111,
            scale=2
        },
        clicked_background =
        {
            filename = "__core__/graphics/gui.png",
            priority = "extra-high-no-scale",
            width = 32,
            height = 32,
            x = 111
        },
        checked =
        {
            filename = "__core__/graphics/gui.png",
            priority = "extra-high-no-scale",
            width = 32,
            height = 32,
            x = 111
        }
    }
