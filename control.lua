require "defines"
require "util"

MAX_CONFIG_SIZE = 6
MAX_STORAGE_SIZE = 12

require "gui"


types = {["mining-drill"]=true,["assembling-machine"]=true,lab=true, ["rocket-silo"] = true, furnace=true, beacon=true}

typeToSlot = {}
typeToSlot.lab = defines.inventory.lab_modules
typeToSlot["assembling-machine"] = defines.inventory.assembling_machine_modules
typeToSlot["mining-drill"] = defines.inventory.mining_drill_modules
typeToSlot["furnace"] = defines.inventory.assembling_machine_modules
typeToSlot["rocket-silo"] = defines.inventory.assembling_machine_modules
typeToSlot["beacon"] = 1

nameToSlots = {}
local metaitem = game.forces.player.recipes["mi-meta"].ingredients

for i, ent in pairs(metaitem) do
  nameToSlots[ent.name] = ent.amount
end

productivityRecipes = game.forces.player.technologies["mi-meta-productivityRecipes"].effects
productivityAllowed = {}
for _, recipe in pairs(productivityRecipes) do
  productivityAllowed[recipe.recipe] = true
end


function expandPos(pos, range)
  local range = range or 0.5
  if not pos or not pos.x then error("invalid pos",3) end
  return {{pos.x - range, pos.y - range}, {pos.x + range, pos.y + range}}
end

function entityKey(ent)
  if ent.position and ent.direction then
    return ent.position.x..":"..ent.position.y--..":"..ent.direction
  end
  return false
end
--/c game.player.print(serpent.dump(game.player.surface.find_logistic_network_by_position(game.player.position, game.player.force.name).find_cell_closest_to(game.player.position)))
function hasPocketBots(player)
  local armor = player.get_inventory(defines.inventory.player_armor)[1].valid_for_read and player.get_inventory(defines.inventory.player_armor)[1]
  local modularArmor = (armor and armor.has_grid) and armor.grid or false
  local port = false
  if modularArmor then
    for _, equipment in pairs(grid.equipment) do
      if equipment.type == "roboport-equipment" then
        port = true
        break
      end
    end
  end
  return port
end

game.on_event(defines.events.on_marked_for_deconstruction, function(event)
  local entity = event.entity
  local deconstruction = false
  local upgrade = false
  local module = false
  local player = nil
  -- Determine which player used upgrade planner.
  -- If more than one player has upgrade planner in their hand or one
  -- player has a upgrade planner and other has deconstruction planner,
  -- we can't determine it, so we have to discard deconstruction order.
  for i = 1, #game.players do
    if game.players[i].cursor_stack.valid_for_read then
      if game.players[i].cursor_stack.name == "upgrade-planner" then
        if upgrade or deconstruction or module then
          --debugDump("Upgrade planner used", true)
          return
        end
        upgrade = true
      elseif game.players[i].cursor_stack.name == "deconstruction-planner" then
        if upgrade or module then
          --debugDump("Deconstruction/Module planner used", true)
          return
        end
        deconstruction = true
      elseif game.players[i].cursor_stack.name == "module-inserter" then
        if upgrade or deconstruction then
          --debugDump("Deconstruction/Upgrade planner used", true)
          return
        end
        player = game.players[i]
        module = true
      end
    end
  end

  if not player then return end

  if not global["config"][player.name] then

    -- Config for this player does not exist yet, so we have nothing to do.
    -- We can create it now for later usage.
    global["config"][player.name] = {}
    entity.cancel_deconstruction(entity.force)
    return
  end

  local config = global["config"][player.name]

  if entity.type ~= "rocket-silo" then

    -- Check if player has space for proxy item
    --/c game.player.print(serpent.dump(game.player.get_inventory(defines.inventory.player_main).can_insert{name="module-inserter-proxy", count=1} or game.player.get_inventory(defines.inventory.player_quickbar).can_insert{name="module-inserter-proxy", count=1}))

    local proxy = {name="module-inserter-proxy", count=1}


    if player.get_inventory(defines.inventory.player_main).can_insert(proxy) or player.get_inventory(defines.inventory.player_quickbar).can_insert(proxy) then
      -- Check if entity is valid and stored in config as a source.
      local index = 0
      for i = 1, #config do
        if config[i].from == entity.name then
          index = i
          break
        end
      end
      if index == 0 then
        entity.cancel_deconstruction(entity.force)
        return
      end
      local modules = util.table.deepcopy(config[index].to)
      local cTable = {}
      for i, module in pairs(modules) do
        if module then
          if not cTable[module] then
            cTable[module] = 1
          else
            cTable[module] = cTable[module] + 1
          end
        end
        if module and module:find("productivity") then
          if entity.type == "beacon" then
            player.print("Can't insert "..module.." in "..entity.name)
            entity.cancel_deconstruction(entity.force)
            return
          end
          if entity.type == "assembling-machine" then
            if entity.recipe and not productivityAllowed[entity.recipe.name] then
              player.print("Can't use "..module.." with recipe: " .. entity.recipe.name)
              entity.cancel_deconstruction(entity.force)
              return
            end
          end
        end
      end
      if entity.type == "assembling-machine" and not entity.recipe then
        player.print("Can't insert modules in assembler without recipe")
        entity.cancel_deconstruction(entity.force)
        return
      end
      local inventory = entity.get_inventory(typeToSlot[entity.type])
      local contents = inventory.get_contents()
      if not util.table.compare(cTable,contents) then
        -- proxy entity that the robots fly to
        local new_entity = {
          name = "entity-ghost",
          inner_name = "module-inserter-proxy",
          position = entity.position,
          direction = entity.direction,
          force = entity.force
        }
        if not global.entitiesToInsert[entityKey(new_entity)] then
          entity.surface.create_entity(new_entity)
          global.entitiesToInsert[entityKey(new_entity)] = {entity = entity, player = player, modules = modules}
          player.insert{name="module-inserter-proxy", count=1}
        end
      end
    end
  end
  entity.cancel_deconstruction(entity.force)
end)

local function initGlob()

  if not global.version or global.version < "0.0.2" then
    global.config = {}
    global["config-tmp"] = {}
    global["storage"] = {}
    global.entitiesToInsert = {}
    global.version = "0.0.2"
  end

  global.entitiesToInsert = global.entitiesToInsert or {}
  global["config"] = global["config"] or {}
  global["config-tmp"] = global["config-tmp"] or {}
  global["storage"] = global["storage"] or {}
  global.guiVersion = global.guiVersion or {}
  
  if global.version < "0.0.7" then
    global["storage"] = {}
    global.version = "0.0.7"
  end

  global.version = "0.0.6"
end

local function oninit() initGlob() end

local function onload()
  initGlob()
end

function update_gui(player)
  if global.guiVersion[player.name] < "0.0.7" and player.gui.top["module-inserter-config-button"] then
    player.gui.top["module-inserter-config-button"].destroy()
    global.guiVersion[player.name] = "0.0.7"
  end
  gui_init(player)
end

function count_keys(hashmap)
  local result = 0
  for _, __ in pairs(hashmap) do
    result = result + 1
  end
  return result
end

function get_config_item(player, index, type1)
  if not global["config-tmp"][player.name]
    or index > #global["config-tmp"][player.name]
    or global["config-tmp"][player.name][index][type1] == "" or type(global["config-tmp"][player.name][index][type1]) == "table" then

    return {"upgrade-planner-item-not-set"}

  end
  return game.get_localised_item_name(global["config-tmp"][player.name][index][type1])
end

game.on_init(oninit)
game.on_load(onload)

game.on_event(defines.events.on_robot_built_entity, function(event)
  local status, err = pcall(function()
    local entity = event.created_entity
    if entity.name == "module-inserter-proxy" then
      local origEntity = global.entitiesToInsert[entityKey(entity)]
      if origEntity and origEntity.entity.valid then
        local player = origEntity.player
        local modules = origEntity.modules
        origEntity = origEntity.entity
        --debugDump(modules,true)
        local inventory = origEntity.get_inventory(typeToSlot[origEntity.type])
        local contents = inventory.get_contents()
        -- remove all modules first
        for k, v in pairs(contents) do
          for i=1,v do
            if player.can_insert{name=k,count=1} then
              inventory.remove{name=k, count=1}
              player.insert{name=k, count=1}
            end
          end
        end
        if type(modules) == "table" then
          local logisticsNetwork = origEntity.surface.find_logistic_network_by_position(origEntity.position, origEntity.force.name)
--          if not logisticsNetwork then
--            for _, network in pairs(player.force.logistic_networks[origEntity.surface.name]) do
--              local cell = network.find_cell_closest_to(origEntity.position)
--              if cell and not cell.mobile and cell.is_in_construction_range(origEntity.position) and cell.logistic_network then
--                logisticsNetwork = cell.logistic_network
--              end
--            end
--          end
          for i,module in pairs(modules) do
            if module then
              if inventory.can_insert{name = module, count = 1} then
                if player.get_item_count(module) > 0 then
                  inventory.insert{name = module, count = 1}
                  player.remove_item{name = module, count = 1}
                else
                  --check logisticsnetwork
                  if logisticsNetwork and logisticsNetwork.get_item_count(module) > 0 then
                    inventory.insert{name = module, count = 1}
                    logisticsNetwork.remove_item{name = module, count = 1}
                  end
                end
              end
            end
          end
        end
        global.entitiesToInsert[entityKey(entity)] = nil
      end
      entity.destroy()
    end
  end)
  if not status then
    debugDump(err, true)
  end
end)

game.on_event(defines.events.on_gui_click, function(event)
  local element = event.element
  --debugDump(element.name, true)
  local player = game.get_player(event.player_index)
  if not global.guiVersion[player.name] then global.guiVersion[player.name] = "0.0.0" end
  if global.guiVersion[player.name] < "0.0.7" then
    update_gui(player)
    return
  end

  if element.name == "module-inserter-config-button" then
    gui_open_frame(player)
  elseif element.name == "module-inserter-apply" then
    gui_save_changes(player)
  elseif element.name == "module-inserter-clear-all" then
    gui_clear_all(player)
  elseif element.name  == "module-inserter-storage-store" then
    gui_store(player)
  else
    event.element.name:match("(%w+)__([%w%s%-%#%!%$]*)_*([%w%s%-%#%!%$]*)_*(%w*)")
    local type, index, slot = string.match(element.name, "module%-inserter%-(%a+)%-(%d+)%-*(%d*)")
    --debugDump({t=type,i=index,s=slot},true)
    if type and index then
      if type == "from" then
        gui_set_rule(player, type, tonumber(index))
      elseif type == "to" then
        gui_set_modules(player, tonumber(index), tonumber(slot))
      elseif type == "restore" then
        gui_restore(player, tonumber(index))
      elseif type == "remove" then
        gui_remove(player, tonumber(index))
      end
    end
  end
end)

game.on_event(defines.events.on_research_finished, function(event)
  if event.research.name == 'automated-construction' then
    for _, player in pairs(game.players) do
      gui_init(player, true)
    end
  end
end)

function debugDump(var, force)
  if false or force then
    for i,player in ipairs(game.players) do
      local msg
      if type(var) == "string" then
        msg = var
      else
        msg = serpent.dump(var, {name="var", comment=false, sparse=false, sortkeys=true})
      end
      player.print(msg)
    end
  end
end

function saveVar(var, name)
  local var = var or global
  local n = name or ""
  game.makefile("module"..n..".lua", serpent.block(var, {name="glob"}))
end

remote.add_interface("mi",
  {
    saveVar = function(name)
      saveVar(global, name)
    end
  })
