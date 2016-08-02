require "util"

MAX_CONFIG_SIZE = 6
MAX_STORAGE_SIZE = 12
DEBUG = false

require "gui"

MOD_NAME = "ModuleInserter"

typeToSlot = {}
typeToSlot.lab = defines.inventory.lab_modules
typeToSlot["assembling-machine"] = defines.inventory.assembling_machine_modules
typeToSlot["mining-drill"] = defines.inventory.mining_drill_modules
typeToSlot["furnace"] = defines.inventory.furnace_modules --TODO 0.13 change to furnace_modules
typeToSlot["rocket-silo"] = defines.inventory.assembling_machine_modules
typeToSlot["beacon"] = 1

function entityKey(ent)
  if ent.position and ent.direction then
    return ent.position.x..":"..ent.position.y--..":"..ent.direction
  end
  return false
end

function count_keys(hashmap)
  local result = 0
  for _, _ in pairs(hashmap) do
    result = result + 1
  end
  return result
end

function on_tick(event)
  if global.removeTicks[event.tick] then
    local status, err = pcall(function()
      for key, g in pairs(global.removeTicks[event.tick]) do
        if not g.g.valid then
          if g.p.get_item_count("module-inserter-proxy") > 0 then
            g.p.remove_item{name="module-inserter-proxy", count = 1}
          end
          global.entitiesToInsert[key] = nil
          global.removeTicks[event.tick][key] = nil
        end
      end
      if count_keys(global.removeTicks[event.tick]) == 0 then
        global.removeTicks[event.tick] = nil
      end
      if count_keys(global.removeTicks) == 0 then
        script.on_event(defines.events.on_tick, nil)
      end
    end)
    if not status then
      debugDump(err, true)
    end
  end
end

function add_ghost(key, data, tick)
  global.removeTicks[tick] = global.removeTicks[tick] or {}
  global.removeTicks[tick][key] = data
  script.on_event(defines.events.on_tick, on_tick)
end

function remove_ghost(key)
  local toDelete = false
  for tick, t in pairs(global.removeTicks) do
    if t[key] then
      toDelete = {t=tick, k=key}
      break
    end
  end
  if toDelete then
    global.removeTicks[toDelete.t][toDelete.k] = nil
    if count_keys(global.removeTicks[toDelete.t]) == 0 then
      global.removeTicks[toDelete.t] = nil
    end
    if count_keys(global.removeTicks) == 0 then
      script.on_event(defines.events.on_tick, nil)
    end
  end
end

function on_player_selected_area(event)
  local status, err = pcall(function()
    if not event.player_index or event.item ~= "module-inserter" then return end
    local player = game.players[event.player_index]
    if not global["config"][player.index] then

      -- Config for this player does not exist yet, so we have nothing to do.
      -- We can create it now for later usage.
      global["config"][player.index] = {}
      return
    end

    local config = global["config"][player.index]

    for _, entity in pairs(event.entities) do

      -- Check if entity is valid and stored in config as a source.
      local index
      for i = 1, #config do
        if config[i].from == entity.name then
          index = i
          break
        end
      end

      local proxy = {name="module-inserter-proxy", count=1}

      local can_insert_main = player.get_inventory(defines.inventory.player_main).can_insert(proxy)
      local can_insert_quick = player.get_inventory(defines.inventory.player_quickbar).can_insert(proxy)

      if index and (can_insert_main or can_insert_quick) then
        if entity.type == "assembling-machine" and not entity.recipe then
          player.print("Can't insert modules in assembler without recipe")
        else
          local modules = util.table.deepcopy(config[index].to)
          local cTable = {}
          local valid_modules = true
          for _, module in pairs(modules) do
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
                  valid_modules = false
                end
                if entity.type == "assembling-machine" and entity.recipe and next(prototype.limitations) and not prototype.limitations[entity.recipe.name] then
                  player.print({"", "Can't use ", prototype.localised_name, " with recipe: ", entity.recipe.localised_name})
                  valid_modules = false
                end
              end
            end
          end

          local contents = entity.get_inventory(typeToSlot[entity.type]).get_contents()
          if valid_modules and not util.table.compare(cTable,contents) then
            -- proxy entity that the robots fly to
            local new_entity = {
              name = "entity-ghost",
              inner_name = "module-inserter-proxy",
              position = entity.position,
              direction = entity.direction,
              force = entity.force
            }
            --game.player.surface.create_entity{name = "item-request-proxy", position = game.player.selected.position, force = game.player.force, target = game.player.selected, modules={{item="speed-module-3", count=2}}}
            --                        local module_proxy = {
            --                          name = "item-request-proxy",
            --                          position = game.player.selected.position,
            --                          force = game.player.force,
            --                          target = game.player.selected,
            --                          request_filters = {count=2, item="speed-module-3"}
            --                        }

            local key = entityKey(new_entity)
            if global.entitiesToInsert[key] then
              global.entitiesToInsert[key] = nil
              if player.get_item_count("module-inserter-proxy") > 0 then
                player.remove_item(proxy)
              end
              remove_ghost(key)
            end
            if not global.entitiesToInsert[key] then -- or (global.entitiesToInsert[key].ghost and not global.entitiesToInsert[key].ghost.valid) then
              local ghost = entity.surface.create_entity(new_entity)
              global.entitiesToInsert[key] = {entity = entity, player = player, modules = modules, ghost = ghost}
              ghost.time_to_live = 60*30
              add_ghost(key, {p=player,g=ghost}, game.tick + ghost.time_to_live + 1)
              if can_insert_main then
                player.get_inventory(defines.inventory.player_main).insert(proxy)
              elseif can_insert_quick then
                player.get_inventory(defines.inventory.player_quickbar).insert(proxy)
              end
            end
          end
        end
      end
    end
  end)
  if not status then
    debugDump(err, true)
  end
end

function on_player_alt_selected_area(event)
  local status, err = pcall(function()
    if not event.player_index or event.item ~= "module-inserter" then return end
    local player = game.players[event.player_index]

    for _, entity in pairs(event.entities) do
      if entity.name == "item-request-proxy" then
        entity.destroy()
      end
      if entity.valid and entity.type == "entity-ghost" and entity.ghost_name == "module-inserter-proxy" then
        log(entity.ghost_name)

        local key = entityKey(entity)
        if global.entitiesToInsert[key] then
          global.entitiesToInsert[key] = nil
          if player.get_item_count("module-inserter-proxy") > 0 then
            player.remove_item{name="module-inserter-proxy", count=1}
          end
          remove_ghost(key)
          entity.destroy()
        end
      end
    end
  end)
  if not status then
    debugDump(err, true)
  end
end

script.on_event(defines.events.on_player_selected_area, on_player_selected_area)
script.on_event(defines.events.on_player_alt_selected_area, on_player_alt_selected_area)

local function getMetaItemData()
  local metaitem = game.forces.player.recipes["mi-meta"].ingredients

  for _, ent in pairs(metaitem) do
    global.nameToSlots[ent.name] = ent.amount
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
    for _, player in pairs(game.players) do
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
  global.settings = global.settings or {}
end

local function init_player(player)
  global.settings[player.index] = global.settings[player.index] or {}
end

local function init_players()
  for _, player in pairs(game.players) do
    init_player(player)
  end
end

local function init_force(_)
--force specific
end

local function init_forces()
  for _, force in pairs(game.forces) do
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
  if count_keys(global.removeTicks) == 0 then
    script.on_event(defines.events.on_tick, nil)
  else
    script.on_event(defines.events.on_tick, on_tick)
  end
end

local function cleanup(show)
  local count = 0
  for tick, data in pairs(global.removeTicks) do
    if data then
      for i=#data,1,-1 do
        local proxyData = data[i]
        if proxyData and proxyData.g and not proxyData.g.valid then
          table.remove(data, i)
          count = count + 1
        end
      end
      if count_keys(global.removeTicks[tick]) == 0 then
        global.removeTicks[tick] = nil
      end
    end
  end
  if count_keys(global.removeTicks) == 0 then
    script.on_event(defines.events.on_tick, nil)
  else
    script.on_event(defines.events.on_tick, on_tick)
  end

  if show then
    debugDump("Removed "..count.." entries", true)
    log("ModuleInserter: Removed "..count.." entries")
  end
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
      if oldVersion < "0.1.34" then
        local tmp = {}
        tmp.config = util.table.deepcopy(global["config"])
        tmp["config-tmp"] = util.table.deepcopy(global["config-tmp"])
        tmp.storage  = util.table.deepcopy(global["storage"])
        tmp.settings = util.table.deepcopy(global.settings)
        for k, v in pairs(tmp) do
          global[k] = {}
          for _, player in pairs(game.players) do
            if player.name and v[player.name] then
              global[k][player.index] = v[player.name]
            end
          end
        end
        cleanup(true)
      end
      if oldVersion < "0.1.4" then
        for _, ent in pairs(global.entitiesToInsert) do
          if ent.ghost and ent.ghost.valid then
            ent.ghost.destroy()
          end
        end
        global.entitiesToInsert = {}
        global.removeTicks = {}
        for _, p in pairs(game.players) do
          local c = p.get_item_count("module-inserter-proxy")
          if c > 0 then
            p.remove_item{name = "module-inserter-proxy", count = c}
          end
        end
        on_load()
      end
      
      if oldVersion < "0.2.2" then
        global.productivityAllowed = nil
      end
      global.version = newVersion
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

script.on_init(on_init)
script.on_load(on_load)
script.on_configuration_changed(on_configuration_changed)
script.on_event(defines.events.on_player_created, on_player_created)
script.on_event(defines.events.on_force_created, on_force_created)

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
          for _ = 1, v do
            if player.can_insert{name=k,count=1} then
              inventory.remove{name=k, count=1}
              player.insert{name=k, count=1}
            end
          end
        end
        if type(modules) == "table" then
          local logisticsNetwork = origEntity.surface.find_logistic_network_by_position(origEntity.position, origEntity.force.name)
          for _, module in pairs(modules) do
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
        remove_ghost(key)
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
    local player = game.players[event.player_index]

    if element.name == "module-inserter-config-button" then
      gui_open_frame(player)
    elseif element.name == "module-inserter-apply" then
      gui_save_changes(player)
    elseif element.name == "module-inserter-clear-all" then
      gui_clear_all(player)
    elseif element.name == "module-inserter-debug" then
      saveVar(global,"debugButton")
      local c = 0
      for _, _ in pairs(global.entitiesToInsert) do
        c = c+1
      end
      debugDump("#Entities "..c,true)
      c = 0
      for _,k in pairs(global.removeTicks) do
        c = c+#k
      end
      debugDump("#config "..#global.config[player.index],true)
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
    for _, player in pairs(game.players) do
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
  var = var or global
  local n = name or ""
  game.write_file("module"..n..".lua", serpent.block(var, {name="glob"}))
end

remote.add_interface("mi",
  {
    saveVar = function(name)
      saveVar(global, name)
    end,
   
    init = function()
      init_global()
      init_players()
      update_gui()
    end,
    cleanup = function()
      cleanup(true)
    end,
  })
