require "defines"
require "util"

MAX_CONFIG_SIZE = 6
MAX_STORAGE_SIZE = 12
DEBUG = false

require "gui"

MOD_NAME = "ModuleInserter"

types = {["mining-drill"]=true,["assembling-machine"]=true,lab=true, ["rocket-silo"] = true, furnace=true, beacon=true}

typeToSlot = {}
typeToSlot.lab = defines.inventory.lab_modules
typeToSlot["assembling-machine"] = defines.inventory.assembling_machine_modules
typeToSlot["mining-drill"] = defines.inventory.mining_drill_modules
typeToSlot["furnace"] = defines.inventory.assembling_machine_modules
typeToSlot["rocket-silo"] = defines.inventory.assembling_machine_modules
typeToSlot["beacon"] = 1

function subPos(p1,p2)
  local p2 = p2 or {x=0,y=0}
  return {x=p1.x-p2.x, y=p1.y-p2.y}
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
  local logisticCell = player.character.logistic_cell
  local port = false
  if logisticCell and logisticCell.transmitting and logisticCell.mobile then
    port = logisticCell
  end
  return port
end

script.on_event(defines.events.on_marked_for_deconstruction, function(event)
  local status, err = pcall(function()
    local entity = event.entity
    local deconstruction = false
    local upgrade = false
    local module = false
    local player = nil
    -- Determine which player used upgrade planner.
    -- If more than one player has upgrade planner in their hand or one
    -- player has a upgrade planner and other has deconstruction planner,
    -- we can't determine it, so we have to discard deconstruction order.
    for _, p in pairs(game.players) do
      if p.connected then
        local stack = p.cursor_stack
        if stack and stack.valid_for_read then
          if stack.name == "upgrade-planner" then
            if upgrade or deconstruction or module then
              --debugDump("Upgrade planner used", true)
              return
            end
            upgrade = true
          elseif stack.name == "deconstruction-planner" then
            if upgrade or module then
              --debugDump("Deconstruction/Module planner used", true)
              return
            end
            deconstruction = true
          elseif stack.name == "module-inserter" then
            if upgrade or deconstruction then
              --debugDump("Deconstruction/Upgrade planner used", true)
              return
            end
            player = p
            module = true
          end
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

    -- Check if player has space for proxy item
    --/c game.player.print(serpent.dump(game.player.get_inventory(defines.inventory.player_main).can_insert{name="module-inserter-proxy", count=1} or game.player.get_inventory(defines.inventory.player_quickbar).can_insert{name="module-inserter-proxy", count=1}))

    local proxy = {name="module-inserter-proxy", count=1}

    --if player.get_inventory(defines.inventory.player_main).can_insert(proxy) or player.get_inventory(defines.inventory.player_quickbar).can_insert(proxy) then
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
    local freeSlots = 0
    for i=1,#player.get_inventory(defines.inventory.player_quickbar) do
      if not player.get_inventory(defines.inventory.player_quickbar)[i].valid_for_read then
        freeSlots = freeSlots + 1
      end
    end

    if player.get_inventory(defines.inventory.player_main).can_insert(proxy) or
      (freeSlots > 1 and player.cursor_stack.valid_for_read) or
      (freeSlots > 0 and not player.cursor_stack.valid_for_read) then
      if entity.type == "assembling-machine" and not entity.recipe then
        player.print("Can't insert modules in assembler without recipe")
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
        local prototype = game.item_prototypes[module]
        if module and prototype.module_effects and prototype.module_effects["productivity"] then
          if prototype.module_effects["productivity"] ~= 0 then
            if entity.type == "beacon" then
              player.print("Can't insert "..module.." in "..entity.name)
              entity.cancel_deconstruction(entity.force)
              return
            end
            if global.productivityAllowed and entity.type == "assembling-machine" then
              if entity.recipe and not global.productivityAllowed[entity.recipe.name] == true then
                player.print("Can't use "..module.." with recipe: " .. entity.recipe.name)
                entity.cancel_deconstruction(entity.force)
                return
              end
            end
          end
        end
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

        local key = entityKey(new_entity)
        if global.entitiesToInsert[key] then
          global.entitiesToInsert[key] = nil
          if player.get_item_count("module-inserter-proxy") > 0 then
            player.remove_item(proxy)
          end
          local toDelete = false
          for tick, t in pairs(global.removeTicks) do
            for k, g in pairs(t) do
              if g.key == key then
                toDelete = {t=tick, k=k}
                break
              end
            end
            if toDelete then
              break
            end
          end
          if toDelete then
            global.removeTicks[toDelete.t][toDelete.k] = nil
          end
        end
        if not global.entitiesToInsert[key] then -- or (global.entitiesToInsert[key].ghost and not global.entitiesToInsert[key].ghost.valid) then
          local ghost = entity.surface.create_entity(new_entity)
          global.entitiesToInsert[key] = {entity = entity, player = player, modules = modules, ghost = ghost}
          --ghost.time_to_live = 60*30
          local delTick = game.tick + ghost.time_to_live + 2
          global.removeTicks[delTick] = global.removeTicks[delTick] or {}
          table.insert(global.removeTicks[delTick], {p=player,g=ghost, key = key})
          player.insert{name="module-inserter-proxy", count=1}
        end
      end
    end
    entity.cancel_deconstruction(entity.force)
  end)
  if not status then
    debugDump(err, true)
  end
end)

local function getMetaItemData()
  local metaitem = game.forces.player.recipes["mi-meta"].ingredients

  for i, ent in pairs(metaitem) do
    global.nameToSlots[ent.name] = ent.amount
  end

  game.forces.player.technologies["mi-meta-productivityRecipes"].reload()
  productivityRecipes = game.forces.player.technologies["mi-meta-productivityRecipes"].effects
  global.productivityAllowed = #productivityRecipes > 0 and global.productivityAllowed or false
  for _, recipe in pairs(productivityRecipes) do
    global.productivityAllowed[recipe.recipe] = true
  end
end

local function remove_invalid_items()
  local items = game.item_prototypes
  for name, p in pairs(global.config) do
    for i=#p,1,-1 do
      if p[i].from ~= "" and not items[p[i].from] then
        global.config[name][i].from = ""
        global.config[name][i].to = ""
        debugDump(p[i].from,true)
      end
      if type(p[i].to) == "table" then
        for k, m in pairs(p[i].to) do
          if m and not items[m] then
            global.config[name][i].to[k] = false
          end
        end
      end
    end
  end

  for player, store in pairs(global.storage) do
    for name, p in pairs(store) do
      for i=#p,1,-1 do
        if p[i].from ~= "" and not items[p[i].from] then
          global.storage[player][name][i].from = ""
          global.storage[player][name][i].to = ""
        end
        if type(p[i].to) == "table" then
          for k, m in pairs(p[i].to) do
            if m and not items[m] then
              global.storage[player][name][i].to[k] = false
            end
          end
        end
      end
    end
  end
end

function update_gui()
  local status, err = pcall(function()
    for i,player in pairs(game.players) do
      if player.valid and player.gui.top["module-inserter-config-button"] then
        player.gui.top["module-inserter-config-button"].destroy()
      end
      gui_init(player)
    end
  end)
  if not status then
    debugDump(err, true)
  end
end

local function init_global()
  global.entitiesToInsert = global.entitiesToInsert or {}
  global.removeTicks = global.removeTicks or {}
  global["config"] = global["config"] or {}
  global["config-tmp"] = global["config-tmp"] or {}
  global["storage"] = global["storage"] or {}
  global.nameToSlots = global.nameToSlots or {}
  global.productivityAllowed = global.productivityAllowed or {}
  global.settings = global.settings or {}
end

local function init_player(player)
  global.settings[player.name] = global.settings[player.name] or {}
end

local function init_players()
  for i,player in pairs(game.players) do
    init_player(player)
  end
end

local function init_force(force)
--force specific
end

local function init_forces()
  for i, force in pairs(game.forces) do
    init_force(force)
  end
end

local function on_init()
  init_global()
  getMetaItemData()
  init_forces()
end

local function on_load()
-- set metatables, register conditional event handlers, local references to global
end

-- run once
local function on_configuration_changed(data)
  if not data or not data.mod_changes then
    return
  end
  if data.mod_changes[MOD_NAME] then
    local newVersion = data.mod_changes[MOD_NAME].new_version
    local oldVersion = data.mod_changes[MOD_NAME].old_version
    -- mod was added to existing save
    if not oldVersion then
      init_global()
      init_forces()
      init_players()
      update_gui()
    else
      if oldVersion < "0.1.3" then
        init_global()
        init_players()
        update_gui()
      end
    --mod was updated
    -- update/change gui for all players via game.players.gui ?
    end
  end
  getMetaItemData()
  remove_invalid_items()
  --check for other mods
end

local function on_player_created(event)
  init_player(game.players[event.player_index])
end

local function on_force_created(event)
  init_force(event.force)
end
local function on_forces_merging(event)

end

script.on_init(on_init)
script.on_load(on_load)
script.on_configuration_changed(on_configuration_changed)
script.on_event(defines.events.on_player_created, on_player_created)
script.on_event(defines.events.on_force_created, on_force_created)
script.on_event(defines.events.on_forces_merging, on_forces_merging)

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
  return game.item_prototypes[global["config-tmp"][player.name][index][type1]].localised_name
end

function on_tick(event)
  if global.removeTicks[event.tick] then
    local status, err = pcall(function()
      for _, g in pairs(global.removeTicks[event.tick]) do
        if not g.g.valid and g.p.get_item_count("module-inserter-proxy") > 0 then
          g.p.remove_item{name="module-inserter-proxy", count = 1}
          global.entitiesToInsert[g.key] = nil
        end
      end
      global.removeTicks[event.tick] = nil
    end)
    if not status then
      debugDump(err, true)
    end
  end
end

script.on_event(defines.events.on_robot_built_entity, function(event)
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
          for i,module in pairs(modules) do
            if module then
              if inventory.can_insert{name = module, count = 1} then
                if player.get_item_count(module) > 0 then
                  inventory.insert{name = module, count = 1}
                  player.remove_item{name = module, count = 1}
                  --inventory.insert{name = module, count = player.remove_item{name= module, count = 1}}
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
        local key = entityKey(entity)
        global.entitiesToInsert[key] = nil
      end
      entity.destroy()
    end
  end)
  if not status then
    debugDump(err, true)
  end
end)

script.on_event(defines.events.on_gui_click, function(event)
  local status, err = pcall(function()
    local element = event.element
    --debugDump(element.name, true)
    local player = game.get_player(event.player_index)

    if element.name == "module-inserter-config-button" then
      gui_open_frame(player)
    elseif element.name == "module-inserter-apply" then
      gui_save_changes(player)
    elseif element.name == "module-inserter-clear-all" then
      gui_clear_all(player)
    elseif element.name == "module-inserter-debug" then
      saveVar(global,"debugButton")
      local c = 0
      for _,k in pairs(global.entitiesToInsert) do
        c = c+1
      end
      debugDump("#Entities "..c,true)
      c = 0
      for _,k in pairs(global.removeTicks) do
        c = c+#k
      end
      debugDump("#config "..#global.config[player.name],true)
      debugDump("#Remove "..c,true)
    elseif element.name  == "module-inserter-storage-store" then
      gui_store(player)
    elseif element.name == "module-inserter-save-as" then
      gui_save_as(player)
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
  if not status then
    debugDump(err, true)
  end
end)

script.on_event(defines.events.on_research_finished, function(event)
  if event.research.name == 'automated-construction' then
    for _, player in pairs(event.research.force.players) do
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
  game.write_file("module"..n..".lua", serpent.block(var, {name="glob"}))
end

remote.add_interface("mi",
  {
    saveVar = function(name)
      saveVar(global, name)
    end,
    limits = function()
      debugDump(productivityAllowed,true)
      debugDump(productivityRecipes,true)
    end,
    init = function()
      init_global()
      init_players()
      update_gui()
    end
  })
