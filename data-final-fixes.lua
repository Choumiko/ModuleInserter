require "lib"

local types = {["mining-drill"]=true,["assembling-machine"]=true,lab=true,["rocket-silo"]=true, furnace=true, beacon=true}

local metaitem = copyPrototype("deconstruction-item", "deconstruction-planner", "mi-meta")
local metarecipe = copyPrototype("recipe", "deconstruction-planner", "mi-meta")
metarecipe.ingredients = {}
metarecipe.enabled = false
metarecipe.hidden = true

local metaProductivityRecipesR = copyPrototype("technology", "automated-construction", "mi-meta-productivityRecipes")
metaProductivityRecipesR.ingredients = {}
metaProductivityRecipesR.enabled = false
metaProductivityRecipesR.hidden = true
metaProductivityRecipesR.effects = {}


for t, _ in pairs(types) do
  for _, ent in pairs(data.raw[t]) do
    if type(ent.module_specification) == "table" and type(ent.module_specification.module_slots) == "number" then
      if data.raw["item"][ent.name] then
        table.insert(metarecipe.ingredients, {ent.name, ent.module_specification.module_slots})
        local prototype = data.raw["item"][ent.name]
        local style =
          {
            type = "checkbox_style",
            parent = "mi-icon-style",
            default_background =
            {
              filename = prototype.icon,
              width = 32,
              height = 32
            },
            hovered_background =
            {
              filename = prototype.icon,
              width = 32,
              height = 32
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
data:extend({metaitem, metarecipe})

local tmpTable = {}

for k,prototype in pairs(data.raw["module"]) do
  local style =
    {
      type = "checkbox_style",
      parent = "mi-icon-style",
      default_background =
      {
        filename = prototype.icon,
        width = 32,
        height = 32
      },
      hovered_background =
      {
        filename = prototype.icon,
        width = 32,
        height = 32
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
  -- get allowed recipes for module
  if prototype.limitation and type(prototype.limitation) == "table" then
    for _, recipe in pairs(prototype.limitation) do
      tmpTable[recipe] = true
    end
  end
  data.raw["gui-style"].default["mi-icon-"..prototype.name] = style
end

for r,_ in pairs(tmpTable) do
  table.insert(metaProductivityRecipesR.effects, {type="unlock-recipe", recipe=r})
end

data:extend({metaProductivityRecipesR})

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
      x = 111
    },
    hovered_background =
    {
      filename = "__core__/graphics/gui.png",
      priority = "extra-high-no-scale",
      width = 32,
      height = 32,
      x = 111
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
