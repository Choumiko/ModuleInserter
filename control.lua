require "__core__/lualib/util"
local v = require "__ModuleInserter__/semver"

local debugDump = require "__ModuleInserter__/lib_control".debugDump
local saveVar = require "__ModuleInserter__/lib_control".saveVar
local GUI = require "__ModuleInserter__/gui"

local MOD_NAME = "ModuleInserter"

local UPDATE_RATE = 117
local _productivity = {}

local function productivity_allowed(module, recipe)
    if _productivity[recipe] == nil then
        _productivity[recipe] = false
        local limits = module and game.item_prototypes[module].limitations or {}
        for _, r in pairs(limits) do
            if r == recipe then
                _productivity[recipe] = true
                break
            end
        end
    end
    return _productivity[recipe]
end

local function compare_contents(tbl1, tbl2)
    if tbl1 == tbl2 then return true end
    for k, value in pairs(tbl1) do
        if (value ~= tbl2[k]) then return false end
    end
    for k, _ in pairs(tbl2) do
        if tbl1[k] == nil then return false end
    end
    return true
end

local function sort_modules(entity, modules, cTable)
    log("Sorting modules for " .. entity.name)
    local inventory = entity.get_module_inventory()
    local contents = inventory and inventory.get_contents()
    log({"", "cTable", serpent.block(cTable)})
    log({"", "contents", serpent.block(contents)})
    if compare_contents(cTable, contents) then
        local status, err = pcall(function()
            inventory.clear()
            local insert = inventory.insert
            for _, module in pairs(modules) do
                if module then
                    insert{name = module, count = 1}
                end
            end
        end)
        if not status then
            debugDump(err, true)
            inventory.clear()
            for name, count in pairs(contents) do
                inventory.insert{name = name, count = count}
            end
        end
    end
end

local function on_tick(event)
    local tick = event.tick
    if not global.proxies then global.proxies = {} end
    local current = global.proxies[tick]
    if current then
        local check_tick = tick + UPDATE_RATE
        local check = global.proxies[check_tick] or {}
        local entity
        for k, data in pairs(current) do
            if data.proxy then
                entity = (data.target and data.target.valid) and data.target
                if not data.proxy.valid then
                    log("Proxy invalid")
                    if entity then
                        sort_modules(entity, data.modules, data.cTable)
                    end
                else
                    if entity then
                        check[k] = data
                    end
                    current[k] = nil
                end
            end
        end
        if next(check) then
            global.proxies[check_tick] = check
            --TODO: register on_nth_tick
        end
        global.proxies[tick] = nil
    end
end

local function drop_module(entity, name, count, module_inventory, chest, player)--luacheck: ignore
    if not (chest and chest.valid) then
        chest = entity.surface.create_entity{
            name = "module_inserter_pickup",
            --name = "wooden-chest",
            position = entity.position,
            force = entity.force,
            create_build_effect_smoke = false
        }
        if not (chest and chest.valid) then
            error("Invalid chest")
        else
            if player then
                chest.order_deconstruction(chest.force, player)
            else
                chest.order_deconstruction(chest.force)
            end
        end
    end

    local stack = {name = name, count = count}
    --log({"", entity.name, " dropped: ", serpent.line(stack)})
    stack.count = chest.insert(stack)
    if module_inventory.remove(stack) ~= count then
        log("Not all modules removed")
    end
    return chest
end

local function create_request_proxy(entity, modules, desired, proxies, player)
    local module_inventory = entity.get_module_inventory()
    if not module_inventory then
        return proxies
    end

    local contents = module_inventory.get_contents()
    local missing = {}
    local surplus = {}
    --log({"", entity.name, " contents: ", serpent.line(contents)})
    --log({"", entity.name, " desired: ", serpent.line(desired)})
    local diff, chest
    for name, count in pairs(desired) do
        diff = (contents[name] or 0) - count -- >0: drop, < 0 missing
        contents[name] = nil
        if diff < 0 then
            missing[name] = -1 * diff
        elseif diff > 0 then
            chest = drop_module(entity, name, diff, module_inventory, chest, player)
            surplus[name] = diff
        end
    end
    for name, count in pairs(contents) do
        diff = count - (desired[name] or 0) -- >0: drop, < 0 missing
        assert(not missing[name] and not surplus[name])
        if diff < 0 then
            missing[name] = -1 * diff
        elseif diff > 0 then
            chest = drop_module(entity, name, diff, module_inventory, chest, player)
            surplus[name] = diff
        end
    end
    --log({"", entity.name, " missing: ", serpent.line(missing)})
    contents = module_inventory.get_contents()
    local same = compare_contents(desired, contents)
    if not same then
        if next(missing)  then
            local module_proxy = {
                name = "item-request-proxy",
                position = entity.position,
                force = entity.force,
                target = entity,
                modules = missing
            }
            local ghost = entity.surface.create_entity(module_proxy)--luacheck: ignore
            proxies[entity.unit_number] = {name = entity.name, proxy = ghost, modules = modules, cTable = desired, target = entity}
        end
    else
        sort_modules(entity, modules, desired)
    end
    return proxies
end

local function on_player_selected_area(event)
    local status, err = pcall(function()
        if event.item ~= "module-inserter" or not event.player_index then return end
        local player_index = event.player_index
        local player = game.get_player(player_index)
        if not global["config"][player_index] then
            global["config"][player_index] = {}
            return
        end

        local config = global["config"][player_index]
        --player.print("Entities: " .. #event.entities)
        local check_tick = event.tick + UPDATE_RATE
        local proxies = global.proxies[check_tick] or {}
        for _, entity in pairs(event.entities) do
            if not global.nameToSlots[entity.name] then
                goto continue
            end
            --log(serpent.block({t=entity.type, n=entity.name, g= entity.type == "entity-ghost" and entity.ghost_name}))
            -- Check if entity is valid and stored in config as a source.
            local index
            for i = 1, #config do
                if config[i].from == entity.name then
                    index = i
                    break
                end
            end

            if not index then
                goto continue
            end
            if entity.type == "assembling-machine" and not entity.get_recipe() then
                player.print("Can't insert modules in assembler without recipe")
                goto continue
            end
            local modules = util.table.deepcopy(config[index].to)
            local cTable = {}
            local valid_modules = true
            local recipe = entity.type == "assembling-machine" and entity.get_recipe()
            local entity_proto = game.entity_prototypes[entity.name]
            for _, module in pairs(modules) do
                if module then
                    cTable[module] = (cTable[module] or 0) + 1
                end
                local prototype = module and game.item_prototypes[module] or false
                if prototype and prototype.module_effects and prototype.module_effects["productivity"] then
                    if prototype.module_effects["productivity"] ~= 0 then
                        if entity.type == "beacon" and not entity_proto.allowed_effects['productivity'] then
                            player.print({"inventory-restriction.cant-insert-module", prototype.localised_name, entity.localised_name})
                            valid_modules = false
                        end
                        if entity.type == "assembling-machine" and recipe and next(prototype.limitations) and not productivity_allowed(module, recipe.name) then
                            player.print({"item-limitation." .. prototype.limitation_message_key})
                            valid_modules = false
                        end
                    end
                end
            end

            if valid_modules then
                proxies = create_request_proxy(entity, modules, cTable, proxies, player)
            end
            ::continue::
        end
        if next(proxies) then
            global.proxies[check_tick] = proxies
        else
            global.proxies[check_tick] = nil
        end
    end)
    if not status then
        debugDump(err, true)
    end
end

local function on_player_alt_selected_area(event)
    local status, err = pcall(function()
        if not event.item == "module-inserter" then return end
        --player.print("Alt entities: " .. #event.entities)
        for _, entity in pairs(event.entities) do
            --log(serpent.block({t=entity.type, n=entity.name, g=entity.ghost_name}))
            if entity.name == "item-request-proxy" then
                for _, proxies in pairs(global.proxies) do
                    if proxies[entity.unit_number] then
                        proxies[entity.unit_number] = nil
                    end
                end
                entity.destroy()
            end
        end
        for tick, proxies in pairs(global.proxies) do
            if not next(proxies) then
                global.proxies[tick] = nil
                --TODO: unregister on_nth_tick
            end
        end
    end)
    if not status then
        debugDump(err, true)
    end
end

script.on_event(defines.events.on_player_selected_area, on_player_selected_area)
script.on_event(defines.events.on_player_alt_selected_area, on_player_alt_selected_area)

--TODO get # of slots only when necessary
local function getMetaItemData()
    global.nameToSlots = {}
    for name, prototype in pairs(game.entity_prototypes) do
        if prototype.module_inventory_size and prototype.module_inventory_size > 0 then
            global.nameToSlots[name] = prototype.module_inventory_size
        end
    end
end

local function remove_invalid_items()
    local items = game.item_prototypes
    for name, p in pairs(global.config) do
        for i=#p,1,-1 do
            if p[i].from and not items[p[i].from] then
                global.config[name][i].from = false
                global.config[name][i].to = {}
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
                if p[i].from and not items[p[i].from] then
                    global.storage[player][name][i].from = false
                    global.storage[player][name][i].to = {}
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

local function init_global()
    global.proxies = global.proxies or {}
    global.config = global.config or {}
    global["config-tmp"] = global["config-tmp"] or {}
    global.storage = global.storage or {}
    global.nameToSlots = global.nameToSlots or {}
    global.settings = global.settings or {}

    global.gui_elements = global.gui_elements or {}
end

local function init_player(player)
    local i = player.index
    global.settings[i] = global.settings[i] or {}
    global.config[i] = global.config[i] or {}
    global.storage[i] = global.storage[i] or {}
    global.gui_elements[i] = global.gui_elements[i] or {}
    -- not setting config-tmp intentionally
    --global["config-tmp"][i] = global["config-tmp"][i] or {}
    GUI.init(player)
end

local function init_players()
    for _, player in pairs(game.players) do
        init_player(player)
    end
end

local function on_init()
    init_global()
    getMetaItemData()
end

local function on_load()
    -- set metatables, register conditional event handlers, local references to global
    if table_size(global.proxies) == 0 then
        script.on_event(defines.events.on_tick, nil)
    else
        script.on_event(defines.events.on_tick, on_tick)
    end
end

local function on_configuration_changed(data)
    if not data then
        return
    end
    if data.mod_changes and data.mod_changes[MOD_NAME] then
        local newVersion = data.mod_changes[MOD_NAME].new_version
        newVersion = v(newVersion)
        local oldVersion = data.mod_changes[MOD_NAME].old_version
        -- mod was added to existing save
        if not oldVersion then
            init_global()
            init_players()
        else
            oldVersion = v(oldVersion)
            if oldVersion < v"0.2.3" then
                global = {}
                init_global()
                init_players()
            end

            if oldVersion < v"4.0.1" then
                --saveVar(global, "preUpdate")
                for name, p in pairs(global.config) do
                    for i=#p,1,-1 do
                        if p[i].from == "" then
                            global.config[name][i].from = false
                            global.config[name][i].to = {}
                        end
                        if type(p[i].to) ~= "table" then
                            global.config[name][i].to = {}
                        end
                    end
                end

                for name, p in pairs(global["config-tmp"]) do
                    for i=#p,1,-1 do
                        if p[i].from == "" then
                            global["config-tmp"][name][i].from = false
                            global["config-tmp"][name][i].to = {}
                        end
                        if type(p[i].to) ~= "table" then
                            global["config-tmp"][name][i].to = {}
                        end
                    end
                end

                for player, store in pairs(global.storage) do
                    for name, p in pairs(store) do
                        for i=#p,1,-1 do
                            if p[i].from == "" then
                                global.storage[player][name][i].from = false
                                global.storage[player][name][i].to = {}
                            end
                            if type(p[i].to) ~= "table" then
                                global.storage[player][name][i].to = {}
                            end
                        end
                    end
                end
            end

            if oldVersion < v"4.0.4" then
                --just to make extra sure all is set
                init_global()
                for i, player in pairs(game.players) do
                    if player and player.valid then
                        init_player(player)
                        GUI.refresh(player)
                    else
                        global.config[i] = nil
                        global.settings[i] = nil
                        global.storage[i] = nil
                        global["config-tmp"][i] = nil
                    end
                end
            end

            if oldVersion < v'4.1.0' then
                init_global()
                global.removeTicks = nil
                local check_tick = game.tick + UPDATE_RATE
                local proxies = global.proxies[check_tick] or {}
                local cTable, player
                if global.entitiesToInsert then
                    for key, origEntity in pairs(global.entitiesToInsert) do
                        if origEntity.entity and origEntity.entity.valid and type(origEntity.modules) == "table" then
                            player = origEntity.player and origEntity.player.valid and origEntity.player
                            cTable = {}
                            for _, module in pairs(origEntity.modules) do
                                if module then
                                    cTable[module] = (cTable[module] or 0) + 1
                                end
                            end
                            proxies = create_request_proxy(origEntity.entity, origEntity.modules, cTable, proxies, player)
                        end
                        global.entitiesToInsert[key] = nil
                    end
                    global.proxies[check_tick] = proxies
                end
                global.entitiesToInsert = nil
                init_players()
                saveVar(global, "post")
            end
            global.version = tostring(newVersion) --do i really need that?
        end
    end
    getMetaItemData()
    remove_invalid_items()
    on_load()
    --check for other mods
end

local function on_player_created(event)
    init_player(game.players[event.player_index])
end

script.on_init(on_init)
script.on_load(on_load)
script.on_configuration_changed(on_configuration_changed)
script.on_event(defines.events.on_player_created, on_player_created)

local function on_gui_click(event)
    local status, err = pcall(function()
        local element = event.element
        --log("click " .. element.name)
        local player = game.get_player(event.player_index)

        if element.name == "module_inserter_config_button" then
            GUI.open_frame(player)
        elseif element.name == "module-inserter-apply" then
            GUI.save_changes(player)
        elseif element.name == "module-inserter-clear-all" then
            GUI.clear_all(player)
        elseif element.name  == "module-inserter-storage-store" then
            GUI.store(player)
        elseif element.name == "module-inserter-save-as" then
            GUI.save_as(player)
        else
            event.element.name:match("(%w+)__([%w%s%-%#%!%$]*)_*([%w%s%-%#%!%$]*)_*(%w*)")
            local type, index, _ = string.match(element.name, "module%-inserter%-(%a+)%-(%d+)%-*(%d*)")
            --log(serpent.block({t=type,i=index,s=slot}))
            if type and index then
                if type == "restore" then
                    GUI.restore(player, tonumber(index))
                elseif type == "remove" then
                    GUI.remove(player, tonumber(index))
                end
            end
        end
    end)
    if not status then
        debugDump(err, true)
    end
end

-- get a entity prototype from an item name
local function item_to_entity(name)
    local proto = game.entity_prototypes[name]
    if not proto then
        local item_proto = game.item_prototypes[name]
        proto = item_proto and item_proto.place_result
    end
    return proto
end

local function on_gui_elem_changed(event)
    local status, err = pcall(function()
        --log("elem_changed: " .. event.element.name)
        --event.element.name:match("(%w+)__([%w%s%-%#%!%$]*)_*([%w%s%-%#%!%$]*)_*(%w*)")
        local type, index, slot = string.match(event.element.name, "module%-inserter%-(%a+)%-(%d+)%-*(%d*)")
        if not type then
            return
        end
        local elem_value = event.element.elem_value
        --log(serpent.block({t=type,i=index,s=slot, elem_value = elem_value}))
        local item = false
        local recipe, result
        if elem_value then
            item = game.item_prototypes[elem_value]
            if not item then
                --try recipes then entities
                recipe = game.recipe_prototypes[elem_value]
                item = recipe and recipe.main_product or next(recipe.products)
                item = item or game.entity_prototypes[elem_value]
            end
            -- if item then
            --     log(serpent.block(item.type))
            -- else
            --     log("nothing found")
            -- end
            -- log(serpent.block(recipe.products, {name="products"}))
        end
        local player = game.get_player(event.player_index)
        if type == "from" then
            result = item and item_to_entity(item.name)
            GUI.set_rule(player, tonumber(index), result, event.element)
            -- if result then
            --     log(serpent.block(result.type))
            --     log(serpent.block(result.name))
            --     log(result.module_inventory_size)
            -- end
            if elem_value and not result then
                player.print("No entity found for item: " .. elem_value)
            end
        elseif type == "to" then
            result = item and game.item_prototypes[item.name]
            GUI.set_modules(player, tonumber(index), tonumber(slot), result)
            -- if result then
            --     log(serpent.block(result.type))
            --     log(serpent.block(result.name))
            --     log(serpent.block(result.module_effects))
            -- end
        end
    end)
    if not status then
        debugDump(err, true)
    end
end

local function on_runtime_mod_setting_changed(event)
    local _, err = pcall(function()
        --log(serpent.block(event))
        if event.setting == "module_inserter_config_size" then
            --probably want to in/decrease config and config-tmp and refresh the players ui if it is opened
            GUI.refresh(game.get_player(event.player_index))
        end
    end)
    if err then
        log("ModuleInserter: Error occured")
        log(serpent.block(err))
    end
end
script.on_event(defines.events.on_runtime_mod_setting_changed, on_runtime_mod_setting_changed)

script.on_event(defines.events.on_gui_click, on_gui_click)
script.on_event(defines.events.on_gui_checked_state_changed, on_gui_click)
script.on_event(defines.events.on_gui_elem_changed, on_gui_elem_changed)

local function on_research_finished(event)
    if event.research.name == 'construction-robotics' then
        for _, player in pairs(event.research.force.players) do
            GUI.init(player, true)
        end
    end
end
script.on_event(defines.events.on_research_finished, on_research_finished)

remote.add_interface("mi",
    {
        saveVar = function(name)
            saveVar(global, name)
        end,

        init = function()
            init_global()
            init_players()
        end
    })
