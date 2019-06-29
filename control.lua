require "__core__/lualib/util"
local v = require "__ModuleInserter__/semver"

local lib = require "__ModuleInserter__/lib_control"
local debugDump = lib.debugDump
local saveVar = lib.saveVar
local config_exists = lib.config_exists
local GUI = require "__ModuleInserter__/gui"
--local profiler = require "profiler"
local MOD_NAME = "ModuleInserter"

local UPDATE_RATE = 117

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

local function drop_module(entity, name, count, module_inventory, chest, player, create_entity)
    if not (chest and chest.valid) then
        chest = create_entity{
            name = "module_inserter_pickup",
            --name = "wooden-chest",
            position = entity.position,
            force = entity.force,
            create_build_effect_smoke = false
        }
        if not (chest and chest.valid) then
            error("Invalid chest")
        else
            if player and player.valid then
                chest.order_deconstruction(chest.force, player)
            else
                chest.order_deconstruction(chest.force)
            end
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
        local surplus = {}
        local changed
        local diff, chest
        --Drop all modules and done
        if not next(desired) then
            for name, count in pairs(contents) do
                chest = drop_module(entity, name, count, module_inventory, chest, player, create_entity)
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
                chest = drop_module(entity, name, diff, module_inventory, chest, player, create_entity)
                surplus[name] = diff
            end
        end
        for name, count in pairs(contents) do
            diff = count - (desired[name] or 0) -- >0: drop, < 0 missing
            assert(not missing[name] and not surplus[name])
            if diff < 0 then
                missing[name] = -1 * diff
            elseif diff > 0 then
                chest = drop_module(entity, name, diff, module_inventory, chest, player, create_entity)
                surplus[name] = diff
                changed = true
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
            proxies[entity.unit_number] = {name = ent_name, proxy = ghost, modules = modules, cTable = desired, target = entity}
        end
    end
    if same then
        sort_modules(entity, modules, desired)
    end
    return proxies
end

local function on_tick(event)
    local tick = event.tick
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
        script.on_event(defines.events.on_tick, nil)
    end
end

local function delayed_creation(event)
    local tick = event.tick
    local nth_tick = event.nth_tick
    local current = global.to_create[tick]
    if current then
        local check_tick = tick + UPDATE_RATE
        local proxies = global.proxies[check_tick] or {}
        local ent
        for _, data in pairs(current) do
            ent = data.entity
            ent = ent and ent.valid and ent
            proxies = create_request_proxy(ent, data.name, data.modules, data.cTable, proxies, data.player, data.surface.create_entity)
        end
        if next(proxies) then
            global.proxies[check_tick] = proxies
            script.on_event(defines.events.on_tick, on_tick)
        else
            global.proxies[check_tick] = nil
        end
        global.to_create[tick] = nil
    end
    --TODO nth_tick for proxy checks
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
        script.on_event(defines.events.on_tick, nil)
    else
        script.on_event(defines.events.on_tick, on_tick)
    end
    for tick in pairs(global.to_create) do
        script.on_nth_tick(tick, delayed_creation)
    end
end

local function on_player_selected_area(event)
    local status, err = pcall(function()
        local player_index = event.player_index
        if event.item ~= "module-inserter" or not player_index then return end
        local player = game.get_player(player_index)
        local pdata = global._pdata[player_index]
        local config = pdata.config
        local ent_type, ent_name
        local entity_configs = {}
        local surface = player.surface
        local restricted_modules = global.restricted_modules
        local delay = event.tick
        local max_proxies = settings.global["module_inserter_proxies_per_tick"].value
        local message = false
        for i, entity in pairs(event.entities) do
            ent_name = entity.name
            --remove existing proxies if we have a config for it's target
            if ent_name == "item-request-proxy" then
                local target = entity.proxy_target
                if target and target.valid and config_exists(config, target.name) then
                    for tick, proxy in pairs(global.proxies) do
                        if proxy[target.unit_number] then
                            proxy[target.unit_number] = nil
                            if not next(proxy) then
                                global.proxies[tick] = nil
                            end
                            entity.destroy{}
                            goto continue
                        end
                    end
                end
            end
            if not global.nameToSlots[ent_name] then
                goto continue
            end
            if entity_configs[ent_name] == nil then
                entity_configs[ent_name] = config_exists(config, ent_name)
            end
            local entity_config = entity_configs[ent_name]
            if not entity_config then
                goto continue
            end
            ent_type = entity.type
            local recipe = ent_type == "assembling-machine" and entity.get_recipe()
            if ent_type == "assembling-machine" and not recipe then
                player.print("Can't insert modules in assembler without recipe")
                goto continue
            end
            local cTable = entity_config.cTable
            if entity_config.limitations and recipe then
                local message2 = false
                recipe = recipe.name
                for module, _ in pairs(cTable) do
                    if restricted_modules[module] and not restricted_modules[module][recipe] then
                        if not message2 then
                            message2 = "item-limitation.production-module-usable-only-on-intermediates"
                            message = message2
                        end
                        break
                    end
                end
                if message2 then
                    goto continue
                end
            end
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

local function on_player_alt_selected_area(event)
    local status, err = pcall(function()
        if not event.item == "module-inserter" then return end
        for _, entity in pairs(event.entities) do
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

script.on_event(defines.events.on_player_selected_area, on_player_selected_area)
script.on_event(defines.events.on_player_alt_selected_area, on_player_alt_selected_area)

--TODO get # of slots only when necessary
local function create_lookup_tables()
    global.nameToSlots = {}
    for name, prototype in pairs(game.entity_prototypes) do
        if prototype.module_inventory_size and prototype.module_inventory_size > 0 then
            global.nameToSlots[name] = prototype.module_inventory_size
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
    local function _remove(tbl)
        for _, config in pairs(tbl) do
            if config.from and not items[config.from] then
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

local function init_player(player)
    local i = player.index
    local pdata = global._pdata[player.index] or {}
    global._pdata[i] = {
        config = pdata.config or {},
        storage = pdata.storage or {},
        settings = pdata.settings or {},

        gui_actions = pdata.gui_actions or {},
        gui_elements = pdata.gui_elements or {},

    }

    GUI.init(player, global._pdata[i])
end

local function init_players()
    for _, player in pairs(game.players) do
        init_player(player)
    end
end

local function on_init()
    init_global()
    create_lookup_tables()
end

local function on_load()
    -- set metatables, register conditional event handlers, local references to global
    conditional_events()
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
            end

            if oldVersion < v"4.0.4" then
                --just to make extra sure all is set
                init_global()
                for i, player in pairs(game.players) do
                    if player and player.valid then
                        init_player(player)
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
            end

            if oldVersion < v'4.1.1' then
                init_global()
                local pdata
                for pi, p in pairs(game.players) do
                    init_player(p)
                    pdata = global._pdata[pi]
                    global.config[pi].loaded = nil
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
            end
            if oldVersion < v'4.1.2' then
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
                for pi, player in pairs(game.players) do
                    GUI.close(global._pdata[pi], pi)
                    GUI.init(player, global._pdata[pi])
                end
            end
            global.version = tostring(newVersion) --do i really need that?
        end
    end
    create_lookup_tables()
    remove_invalid_items()
    conditional_events(true)
    --check for other mods
end

local function on_player_created(event)
    init_player(game.players[event.player_index])
end

local function on_pre_player_removed(event)
    GUI.delete(global._pdata[event.player_index])
    global._pdata[event.player_index] = nil
end

script.on_init(on_init)
script.on_load(on_load)
script.on_configuration_changed(on_configuration_changed)
script.on_event(defines.events.on_player_created, on_player_created)
script.on_event(defines.events.on_pre_player_removed, on_pre_player_removed)

script.on_event(defines.events.on_gui_click, GUI.generic_event)
script.on_event(defines.events.on_gui_elem_changed, GUI.generic_event)

local function on_runtime_mod_setting_changed(event)
    local _, err = pcall(function()
        if event.player_index and event.setting == "module_inserter_config_size"then
            local pi = event.player_index
            local pdata = global._pdata[pi]
            GUI.close(pdata, pi)
        end
    end)
    if err then
        log("ModuleInserter: Error occured")
        log(serpent.block(err))
    end
end
script.on_event(defines.events.on_runtime_mod_setting_changed, on_runtime_mod_setting_changed)

local function on_pre_mined_item(event)
    if event.entity and event.entity.valid and global.nameToSlots[event.entity.name] then
        local status, err = pcall(function()
                local id = event.entity.unit_number
                for tick, proxies in pairs(global.proxies) do
                    if proxies[id] then
                        proxies[id] = nil
                        if not next(proxies) then
                            global.proxies[tick] = nil
                        end
                    end
                end
                conditional_events()
        end)
        if not status then
            debugDump(err, true)
            conditional_events(true)
        end
    end
end

script.on_event({
    defines.events.on_pre_player_mined_item,
    defines.events.on_robot_pre_mined,
    defines.events.on_entity_died,
    defines.events.script_raised_destroy},
    on_pre_mined_item
)

local function on_research_finished(event)
    if event.research.name == 'construction-robotics' then
        for pi, player in pairs(event.research.force.players) do
            GUI.init(player, global._pdata[pi], true)
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
        end,

        -- profile = function(m, n, fast)
        --     local ents = game.player.surface.find_entities_filtered{type = {"assembling-machine", "beacon", "mining-drill", "lab", "furnace", "rocket-silo"}}
        --     log(#ents)
        --     local profiler_raw = profiler
        --     if fast then
        --         profiler = {
        --             p = false,
        --             Start = function() profiler.p = game.create_profiler() end,
        --             Stop = function() profiler.p.stop() end
        --         }
        --     end
        --     m = m or 10
        --     n = n or 10
        --     for j = 1, m do
        --         profiler.Start()
        --         for i = 1, n do
        --             local event = {entities = ents, player_index = game.player.index, item = "module-inserter", tick = game.tick+i}
        --             on_player_selected_area(event)
        --             if fast then profiler.Stop() end
        --             for _, current in pairs(global.proxies) do
        --                 for k, data in pairs(current) do
        --                     if data.proxy and data.proxy.valid then
        --                         data.proxy.destroy()
        --                     end
        --                 end
        --             end
        --             global.proxies = {}
        --             global.to_create = {}
        --             if fast then profiler.p.restart() end
        --         end
        --         if fast then
        --             profiler.Stop()
        --             profiler.p.divide(10)
        --             log{"", profiler.p}
        --             profiler.p.divide(m*n)
        --             log(profiler.p)
        --         end
        --         profiler.Stop()
        --     end
        --     profiler = profiler_raw
        -- end,

        -- profile_once = function()
        --     local ents = game.player.surface.find_entities_filtered{type = {"assembling-machine", "beacon", "mining-drill", "lab", "furnace", "rocket-silo"}}
        --     --profiler.Start(true)
        --     local event = {entities = ents, player_index = game.player.index, item = "module-inserter", tick = game.tick}
        --     on_player_selected_area(event)
        -- end,
    })
