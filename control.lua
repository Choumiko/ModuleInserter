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

local function on_mod_item_opened(e)
    e.player = game.get_player(e.player_index)
    e.pdata = global._pdata[e.player_index]
    mi_gui.open(e)
end
event.on_mod_item_opened(on_mod_item_opened)

event.register("toggle-module-inserter", function(e)
    e.player = game.get_player(e.player_index)
    e.pdata = global._pdata[e.player_index]
    mi_gui.toggle(e)
end)

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
        if not config then
            player.print({"module-inserter-config-not-set"})
            return
        end
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
            if (config.from or config.from == false) and not entities[config.from] then
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
    if not (global.__flib and global.__flib.gui) then
        gui.init()
        gui.build_lookup_tables()
    end
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
    ["4.0.1"]  = function()
        if global.config then
            for name, p in pairs(global.config) do
                for i = #p, 1, -1 do
                    if p[i].from == "" then
                        global.config[name][i].from = nil
                        global.config[name][i].to = {}
                    end
                    if type(p[i].to) ~= "table" then
                        global.config[name][i].to = {}
                    end
                end
            end
        end
        if global["config-tmp"] then
            for name, p in pairs(global["config-tmp"]) do
                for i = #p, 1, -1 do
                    if p[i].from == "" then
                        global["config-tmp"][name][i].from = nil
                        global["config-tmp"][name][i].to = {}
                    end
                    if type(p[i].to) ~= "table" then
                        global["config-tmp"][name][i].to = {}
                    end
                end
            end
        end
        if global.storage then
            for player, store in pairs(global.storage) do
                for name, p in pairs(store) do
                    for i= #p, 1, -1 do
                        if p[i].from == "" then
                            global.storage[player][name][i].from = nil
                            global.storage[player][name][i].to = {}
                        end
                        if type(p[i].to) ~= "table" then
                            global.storage[player][name][i].to = {}
                        end
                    end
                end
            end
        end
    end,
    ["4.0.4"] = function()
        init_global()
        for i, player in pairs(game.players) do
            if player and player.valid then
                init_player(i)
            else
                global.config[i] = nil
                global.settings[i] = nil
                global.storage[i] = nil
                global["config-tmp"][i] = nil
            end
        end
    end,
    ["4.1.0"] = function()
        init_global()
        global.removeTicks = nil
        local check_tick = game.tick + UPDATE_RATE
        local proxies = global.proxies[check_tick] or {}
        local cTable, player
        if global.entitiesToInsert then
            for key, origEntity in pairs(global.entitiesToInsert) do
                if origEntity.entity and origEntity.entity.valid and type(origEntity.modules) == "table" then
                    local ent = origEntity.entity
                    player = origEntity.player and origEntity.player.valid and origEntity.player
                    cTable = {}
                    for _, module in pairs(origEntity.modules) do
                        if module then
                            cTable[module] = (cTable[module] or 0) + 1
                        end
                    end
                    proxies = create_request_proxy(ent, ent.name, origEntity.modules, cTable, proxies, player, ent.surface.create_entity)
                end
                global.entitiesToInsert[key] = nil
            end
            global.proxies[check_tick] = proxies
        end
        global.entitiesToInsert = nil
        conditional_events()
        init_players()
    end,

    ["4.1.1"] = function()
        init_global()
        local pdata
        for pi, player in pairs(game.players) do
            if player.gui.left.mod_gui_frame_flow and player.gui.left.mod_gui_frame_flow then
                for _, egui in pairs(player.gui.left.mod_gui_frame_flow.children) do
                    if egui.get_mod() == "ModuleInserter" then
                        egui.destroy()
                    end
                end
            end
            init_player(pi)
            pdata = global._pdata[pi]
            if global.config and global.config[pi] then
                global.config[pi].loaded = nil
            end
            pdata.gui_elements = global.gui_elements and global.gui_elements[pi] or {}
            pdata.config = global.config and global.config[pi] or {}
            pdata.config_tmp = global["config-tmp"] and global["config-tmp"][pi] or {}
            pdata.storage = global.storage and global.storage[pi] or {}
            pdata.settings = global.settings and global.settings[pi] or {}
        end
        global.gui_elements = nil
        global.config = nil
        global.storage = nil
        global.settings = nil
        global["config-tmp"] = nil
    end,
    ["4.1.2"] = function()
        global.to_create = global.to_create or {}
        local _item_prototypes = game.item_prototypes
        local function create_cTable(tbl)
            for i, item_config in pairs(tbl) do
                item_config.cTable = {}
                local prototype, limitations
                for _, module in pairs(item_config.to) do
                    if module then
                        prototype = _item_prototypes[module]
                        limitations = prototype and prototype.limitations
                        if limitations and next(limitations) then
                            item_config.limitations = true
                        end
                        item_config.cTable[module] = (item_config.cTable[module] or 0) + 1
                    end
                end
            end
        end
        for _, pdata in pairs(global._pdata) do
            create_cTable(pdata.config)
            create_cTable(pdata.config_tmp)
            for _, preset in pairs(pdata.storage) do
                create_cTable(preset)
            end
        end
    end,
    ["4.1.7"] = function()
        init_players()
    end,
    ["5.0.9"] = function()
        gui.init()
        gui.build_lookup_tables()
        init_players()
        local gui_e, pdata
        for i, player in pairs(game.players) do
            pdata = global._pdata[i]
            gui_e = pdata.gui_elements
            if gui_e then
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
            end
            mi_gui.create_main_button(player, pdata)
            gui.update_filters("mod_gui_button", i, {pdata.gui.main_button.index}, "add")
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

event.on_runtime_mod_setting_changed(function(e)
    if e.player_index and e.setting == "module_inserter_hide_button" then
        local pdata = global._pdata[e.player_index]
        local player = game.get_player(e.player_index)
        if pdata.gui.main_button and pdata.gui.main_button.valid then
            pdata.gui.main_button.visible = not player.mod_settings["module_inserter_hide_button"].value
        end
    end
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