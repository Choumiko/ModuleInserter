require "lib"

local types = {["mining-drill"]=true,["assembling-machine"]=true,lab=true,["rocket-silo"]=true, furnace=true, beacon=true}


local metaitem = copyPrototype("deconstruction-item", "deconstruction-planner", "mi-meta")
local metarecipe = copyPrototype("recipe", "deconstruction-planner", "mi-meta")
metarecipe.ingredients = {}
metarecipe.enabled = false
metarecipe.hidden = true


for t, _ in pairs(types) do
  for _, ent in pairs(data.raw[t]) do
    if type(ent.module_specification) == "table" and type(ent.module_specification.module_slots) == "number" then
      table.insert(metarecipe.ingredients, {ent.name, ent.module_specification.module_slots})
    end
  end
end
data:extend({metaitem, metarecipe})
