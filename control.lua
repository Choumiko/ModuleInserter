local event = require("__flib__.event")
local gui = require("__flib__.gui")
local migration = require("__flib__.migration")
local mi_gui = require("scripts.gui")

local lib = require "__ModuleInserter__/lib_control"
local debugDump = lib.debugDump
local UPDATE_RATE = 117

--TODO: use script.register_on_entity_destroyed(entity) to remove proxies or sort the modules?

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
    --Don't sort empty inventories
    if not next(modules) then return end
    local inventory = entity.get_module_inventory()
    local contents = inventory and inventory.get_contents()
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

local function drop_module(entity, name, count, module_inventory, chest, create_entity)
    if not (chest and chest.valid) then
        chest = create_entity{
            name = "module_inserter_pickup",
            position = entity.position,
            force = entity.force,
            create_build_effect_smoke = false
        }
        if not (chest and chest.valid) then
            error("Invalid chest")
        end
    end

    local stack = {name = name, count = count}
    stack.count = chest.insert(stack)
    if module_inventory.remove(stack) ~= stack.count then
        log("Not all modules removed")
    end
    return chest
end

local function create_request_proxy(entity, ent_name, modules, desired, proxies, player, create_entity)
    local module_inventory = entity.get_module_inventory()
    if not module_inventory then
        return proxies
    end

    local contents = module_inventory.get_contents()
    local same = compare_contents(desired, contents)

    if not same then
        local missing = {}
        --local surplus = {}
        local changed
        local diff
        local chest = false
        --Drop all modules and done
        if not next(desired) then
            for name, count in pairs(contents) do
                chest = drop_module(entity, name, count, module_inventory, chest, create_entity)
            end
            if chest and chest.valid then
                if player and player.valid then
                    chest.order_deconstruction(chest.force, player)
                else
                    chest.order_deconstruction(chest.force)
                end
            end
            return proxies
        end
        --Request all modules and done
        if not next(contents) then
            missing = desired
            local module_proxy = {
                name = "item-request-proxy",
                position = entity.position,
                force = entity.force,
                target = entity,
                modules = missing
            }
            local ghost = create_entity(module_proxy)
            proxies[entity.unit_number] = {proxy = ghost, modules = modules, cTable = desired, target = entity}
            return proxies
        end
        for name, count in pairs(desired) do
            diff = (contents[name] or 0) - count -- >0: drop, < 0 missing
            contents[name] = nil
            if diff < 0 then
                missing[name] = -1 * diff
            elseif diff > 0 then
                chest = drop_module(entity, name, diff, module_inventory, chest, create_entity)
                --surplus[name] = diff
            end
        end
        for name, count in pairs(contents) do
            diff = count - (desired[name] or 0) -- >0: drop, < 0 missing
            --assert(not missing[name] and not surplus[name])
            if diff < 0 then
                missing[name] = -1 * diff
            elseif diff > 0 then
                chest = drop_module(entity, name, diff, module_inventory, chest, create_entity)
                --surplus[name] = diff
                changed = true
            end
        end
        if chest and chest.valid then
            if player and player.valid then
                chest.order_deconstruction(chest.force, player)
            else
                chest.order_deconstruction(chest.force)
            end
        end
        if changed then
            contents = module_inventory.get_contents()
            same = compare_contents(desired, contents)
        end
        if not same and next(missing) then
            local module_proxy = {
                name = "item-request-proxy",
                position = entity.position,
                force = entity.force,
                target = entity,
                modules = missing
            }
            local ghost = create_entity(module_proxy)
            --script.register_on_entity_destroyed(ghost)
            proxies[entity.unit_number] = {name = ent_name, proxy = ghost, modules = modules, cTable = desired, target = entity}
        end
    end
    if same then
        sort_modules(entity, modules, desired)
    end
    return proxies
end

local function on_tick(e)
    local tick = e.tick
    local current = global.proxies[tick]
    if current then
        local check_tick = tick + UPDATE_RATE
        local check = global.proxies[check_tick] or {}
        local entity
        for k, data in pairs(current) do
            if data.proxy then
                entity = (data.target and data.target.valid) and data.target
                if not data.proxy.valid then
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
        end
        global.proxies[tick] = nil
    end
    if not next(global.proxies) then
        event.on_tick(nil)
    end
end

local function delayed_creation(e)
    local tick = e.tick
    local nth_tick = e.nth_tick
    local current = global.to_create[tick]
    if current then
        local check_tick = tick + UPDATE_RATE
        local proxies = global.proxies[check_tick] or {}
        local ent
        for _, data in pairs(current) do
            ent = data.entity
            ent = ent and ent.valid and ent
            if ent and ent.valid then
                proxies = create_request_proxy(ent, data.name, data.modules, data.cTable, proxies, data.player, data.surface.create_entity)
            end
        end
        if next(proxies) then
            global.proxies[check_tick] = proxies
            event.on_tick(on_tick)
        else
            global.proxies[check_tick] = nil
        end
        global.to_create[tick] = nil
    end
    if nth_tick ~= UPDATE_RATE then
        script.on_nth_tick(nth_tick, nil)
    end
end

local function conditional_events(check)
    if check then
        for tick, proxies in pairs(global.proxies) do
            for id, data in pairs(proxies) do
                if not (data.target and data.target.valid) then
                    proxies[id] = nil
                end
            end
            if tick < game.tick or not next(proxies) then
                log("Removed old tick: " .. tick .. "(current: " .. game.tick ..")")
                global.proxies[tick] = nil
            end
        end
        for tick, to_create in pairs(global.to_create) do
            for id, data in pairs(to_create) do
                if not (data.entity and data.entity.valid) then
                    to_create[id] = nil
                end
            end
            if not next(to_create) then
                global.to_create[tick] = nil
            end
        end
    end
    if not next(global.proxies) then
        event.on_tick(nil)
    else
        event.on_tick(on_tick)
    end
    for tick in pairs(global.to_create) do
        script.on_nth_tick(tick, delayed_creation)
    end
end

local function modules_allowed(recipe, modules)
    local restricted_modules = global.restricted_modules
    for module, _ in pairs(modules) do
        if restricted_modules[module] and not restricted_modules[module][recipe] then
            return false
        end
    end
    return true
end

local function on_player_selected_area(e)
    local status, err = pcall(function()
        local player_index = e.player_index
        if e.item ~= "module-inserter" or not player_index then return end
        local player = game.get_player(player_index)
        local pdata = global._pdata[player_index]
        local config = pdata.config_by_entity
        local ent_type, ent_name, target
        local surface = player.surface
        local delay = e.tick
        local max_proxies = settings.global["module_inserter_proxies_per_tick"].value
        local message = false
        for i, entity in pairs(e.entities) do
            ent_name = entity.name
            --remove existing proxies if we have a config for it's target
            if ent_name == "item-request-proxy" then
                target = entity.proxy_target
                if target and target.valid and config[target.name] then
                    target = target.unit_number
                    entity.destroy{}
                    --TODO only cleanup after all entities are processed?
                    for tick, proxy in pairs(global.proxies) do
                        if proxy[target] then
                            proxy[target] = nil
                            if not next(proxy) then
                                global.proxies[tick] = nil
                            end
                            goto continue
                        end
                    end
                end
            end

            local entity_configs = config[ent_name]
            if not entity_configs then
                goto continue
            end

            ent_type = entity.type
            local recipe = ent_type == "assembling-machine" and entity.get_recipe()
            recipe = recipe and recipe.name
            local entity_config = nil
            local cTable = nil
            if recipe then
                for _, e_config in pairs(entity_configs) do
                    if e_config.limitations then
                        if modules_allowed(recipe, e_config.cTable) then
                            entity_config = e_config
                            cTable = e_config.cTable
                            break
                        else
                            message = "item-limitation.production-module-usable-only-on-intermediates"
                        end
                    else
                        entity_config = e_config
                        cTable = e_config.cTable
                        break
                    end
                end
            else
                entity_config = entity_configs[1]
                cTable = entity_config.cTable
            end
            if entity_config then
                if (i % max_proxies == 0) then
                    delay = delay + 1
                end
                if not global.to_create[delay] then global.to_create[delay] = {} end
                global.to_create[delay][entity.unit_number] = {
                    entity = entity,
                    name = ent_name,
                    modules = entity_config.to,
                    cTable = cTable,
                    player = player,
                    surface = surface
                }
            end
            ::continue::
        end
        if message then
            player.print({message})
        end
        conditional_events()
    end)
    if not status then
        debugDump(err, true)
        conditional_events(true)
    end
end

local function on_player_alt_selected_area(e)
    local status, err = pcall(function()
        if not e.item == "module-inserter" then return end
        for _, entity in pairs(e.entities) do
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
            end
        end
        conditional_events()
    end)
    if not status then
        debugDump(err, true)
        conditional_events(true)
    end
end

local function create_lookup_tables()
    global.nameToSlots = {}
    global.module_entities = {}
    local i = 1
    for name, prototype in pairs(game.entity_prototypes) do
        if prototype.module_inventory_size and prototype.module_inventory_size > 0 then
            global.nameToSlots[name] = prototype.module_inventory_size
            global.module_entities[i] = name
            i = i + 1
        end
    end
    global.restricted_modules = {}
    local limitations
    for name, module in pairs(game.item_prototypes) do
        if module.type == "module" then
            limitations = module.limitations
            if limitations and next(limitations) then
                global.restricted_modules[name] = {}
                for _, recipe in pairs(limitations) do
                    global.restricted_modules[name][recipe] = true
                end
            end
        end
    end
end

local function remove_invalid_items()
    local items = game.item_prototypes
    local entities = game.entity_prototypes
    local function _remove(tbl)
        for _, config in pairs(tbl) do
            if config.from and not entities[config.from] then
                config.from = nil
                config.to = {}
                config.cTable = {}
            end
            config.limitations = nil
            for k, m in pairs(config.to) do
                if m and not items[m] then
                    config.to[k] = nil
                    config.cTable[m] = nil
                end
                if global.restricted_modules[m] then
                    config.limitations = true
                end
            end
        end
    end
    for _, pdata in pairs(global._pdata) do
        _remove(pdata.config)
        if pdata.config_tmp then
            _remove(pdata.config_tmp)
        end
        for _, preset in pairs(pdata.storage) do
            _remove(preset)
        end
    end
end

local function init_global()
    global.proxies = global.proxies or {}
    global.to_create = global.to_create or {}
    global.nameToSlots = global.nameToSlots or {}
    global.restricted_modules = global.restricted_modules or {}
    global._pdata = global._pdata or {}
end

local function init_player(i)
    init_global()
    local pdata = global._pdata[i] or {}
    global._pdata[i] = {
        last_preset = pdata.last_preset or "",
        config = pdata.config or {},
        storage = pdata.storage or {},
        gui = pdata.gui or {},
    }
    mi_gui.create_main_button(game.get_player(i), global._pdata[i])
end

local function init_players()
    for i, _ in pairs(game.players) do
        init_player(i)
    end
end

event.on_init(function()
    gui.init()
    gui.build_lookup_tables()
    create_lookup_tables()
    init_global()
    init_players()
end)

event.on_load(function()
    gui.build_lookup_tables()
    conditional_events()
end)

local migrations = {
    ["5.0.9"] = function()
        gui.init()
        gui.build_lookup_tables()
        local gui_e, pdata
        for i, _ in pairs(game.players) do
            game.write_file("mi_old", serpent.block(global._pdata[i]))
            pdata = global._pdata[i]
            gui_e = pdata.gui_elements
            if gui_e.config_frame and gui_e.config_frame.valid then
                gui_e.config_frame.destroy()
            end
            if gui_e.preset_frame and gui_e.preset_frame.valid then
                gui_e.preset_frame.destroy()
            end
            init_player(i)
            pdata = global._pdata[i]
            if gui_e.main_button and gui_e.main_button.valid then
                gui.update_filters("mod_gui_button", i, {gui_e.main_button.index}, "add")
                pdata.gui.main_button = gui_e.main_button
            end

            pdata.last_preset = ""
            local config_by_entity = {}
            for _, config in pairs(pdata.config) do
                if config.from then
                    config_by_entity[config.from] = config_by_entity[config.from] or {}
                    config_by_entity[config.from][table_size(config_by_entity[config.from])+1] = {to = config.to, cTable = config.cTable, limitations = config.limitations}
                end
            end
            pdata.config_by_entity = config_by_entity

            pdata.gui_elements = nil
            pdata.gui_actions = nil
            pdata.settings = nil
        end
    end
}

event.on_configuration_changed(function(e)
    if migration.on_config_changed(e, migrations) then
        gui.check_filter_validity()
    end
    create_lookup_tables()
    remove_invalid_items()
    conditional_events(true)
end)

event.on_player_selected_area(on_player_selected_area)
event.on_player_alt_selected_area(on_player_alt_selected_area)

mi_gui.register_handlers()

event.on_player_created(function(e)
    init_player(e.player_index)
end)

-- event.on_entity_destroyed(function(e)
--     log(serpent.block(e))
-- end)

commands.add_command("mi_clean", "", function()
    for _, egui in pairs(game.player.gui.screen.children) do
        if egui.get_mod() == "ModuleInserter" then
            egui.destroy()
        end
    end
end)