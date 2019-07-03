local mod_gui = require '__core__/lualib/mod-gui'
local lib = require "__ModuleInserter__/lib_control"
local debugDump = lib.debugDump

local _entity_prototypes = {}
local function get_entity_from_item_name(name)
    if _entity_prototypes[name] == nil then
        local item = game.item_prototypes[name]
        _entity_prototypes[name] = item and item.place_result or false
    end
    return _entity_prototypes[name]
end

local function show_yarm(pdata, player_index)
    if remote.interfaces.YARM and remote.interfaces.YARM.set_filter then
        remote.call("YARM", "set_filter", player_index, pdata.settings.YARM_active_filter)
    end
end

local function hide_yarm(pdata, player_index)
    if remote.interfaces.YARM and remote.interfaces.YARM.set_filter then
        pdata.settings.YARM_active_filter = remote.call("YARM", "set_filter", player_index, "none")
    end
end

local GUI = {}
local START_SIZE = 10
local gui_functions = {
    main_button = function(event, pdata, _)
        local gui_elements = pdata.gui_elements
        if (gui_elements.config_frame and gui_elements.config_frame.valid) or
            gui_elements.preset_frame and gui_elements.preset_frame.valid then
            GUI.close(pdata, event.player_index)
        else
            GUI.open_config_frame(pdata, event.player)
        end
    end,

    save_changes = function(event, pdata)
        for _, c in pairs(pdata.config_tmp) do
            assert(type(c.to) == "table")
        end
        pdata.config = util.table.deepcopy(pdata.config_tmp)
        GUI.close(pdata, event.player_index)
    end,

    clear_all = function(_, pdata)
        local gui_elements = pdata.gui_elements
        local frame = gui_elements.config_frame
        if not (frame and frame.valid) then return end

        local ruleset_grid = gui_elements.ruleset_grid

        for i = 1, #pdata.config_tmp do
            if i <= START_SIZE then
                pdata.config_tmp[i]= {to = {}, cTable = {}}
                ruleset_grid.children[i].assembler.elem_value = nil
                GUI.update_modules(pdata, i)
            else
                pdata.config_tmp[i] = nil
                GUI.deregister_action(ruleset_grid.children[i], pdata, true)
            end
        end
        GUI.update_rows(pdata)
        local storage_frame = gui_elements.preset_frame
        if (storage_frame and storage_frame.valid) then
            gui_elements.textfield.text = ""
        end
    end,

    save_preset = function(event, pdata)
        local gui_elements = pdata.gui_elements
        local storage_frame = gui_elements.preset_frame
        if not (storage_frame and storage_frame.valid) then return end
        local textfield = gui_elements.textfield
        local name = textfield.text

        if name == "" then
            GUI.display_message(event.player, {"module-inserter-storage-name-not-set"}, true)
            return
        end
        if pdata.storage[name] then
            if not event.player.mod_settings["module_inserter_overwrite"].value then
                GUI.display_message(event.player, {"module-inserter-storage-name-in-use", name}, true)
                textfield.select_all()
                textfield.focus()
                return
            else
                pdata.storage[name] = util.table.deepcopy(pdata.config_tmp)
                GUI.display_message(event.player, {"module-inserter-storage-updated", name}, "success")
                return
            end
        end

        pdata.storage[name] = util.table.deepcopy(pdata.config_tmp)
        GUI.add_preset(pdata, gui_elements.storage_grid, name)
        textfield.text = ""
    end,

    restore_preset = function(event, pdata, args)
        local name = args.name
        local gui_elements = pdata.gui_elements
        local frame = gui_elements.config_frame
        local storage_frame = gui_elements.preset_frame
        if not (frame and frame.valid and storage_frame and storage_frame.valid) then return end

        local preset = pdata.storage[name]
        if not preset then return end

        pdata.config_tmp = util.table.deepcopy(preset)
        pdata.config = util.table.deepcopy(preset)
        local row
        local ruleset_grid = gui_elements.ruleset_grid
        local children = ruleset_grid.children
        for i, config in pairs(preset) do
            row = children[i] and children[i].valid and children[i]
            if row then
                row.assembler.elem_value = config.from or nil
                GUI.update_modules(pdata, i)
            else
                GUI.add_config_row(pdata, i, ruleset_grid)
            end
        end
        local c = #ruleset_grid.children
        local c_preset = #preset
        if c > c_preset then
            for i = c_preset + 1, c do
                GUI.deregister_action(ruleset_grid.children[i], pdata, true)
            end
        end
        gui_elements.textfield.text = name or ""
        GUI.close(pdata, event.player_index)
        GUI.display_message(event.player, {"module-inserter-storage-loaded", name}, "success")
    end,

    delete_preset = function(event, pdata, args)
        local storage_frame = pdata.gui_elements.preset_frame
        if not (storage_frame and storage_frame.valid) then return end
        GUI.deregister_action(event.element.parent, pdata, true)
        pdata.storage[args.name] = nil
    end,

    set_assembler = function(event, pdata, args)
        if event.name ~= defines.events.on_gui_elem_changed then return end
        local ruleset_grid = pdata.gui_elements.ruleset_grid
        if not (ruleset_grid and ruleset_grid.valid) then return end
        local index = args.index
        local element = event.element
        local elem_value = element.elem_value
        local config_tmp = pdata.config_tmp
        local config = config_tmp[index]
        if elem_value == config.from then return end
        if not elem_value then
            GUI.clear_rule(pdata, index, element)
            return
        end

        local proto = get_entity_from_item_name(elem_value)
        if not proto then
            element.elem_value = config.from
            event.player.print("No entity/invalid entity found for item: " .. elem_value)
            return
        end
        local name = proto.name
        if not global.nameToSlots[name] then
            element.elem_value = config.from
            GUI.display_message(event.player, {"module-inserter-item-no-slots"}, true)
            return
        end

        for i = 1, #config_tmp do
            if index ~= i and config_tmp[i].from == name then
                GUI.display_message(event.player, {"module-inserter-item-already-set"}, true)
                GUI.clear_rule(pdata, index, element)
                return
            end
        end
        config.from = name
        config.to = {}
        config.cTable = {}
        element.elem_value = name
        element.tooltip = proto.localised_name
        GUI.update_modules(pdata, index)

        local c = #config_tmp
        if index == c and config.from then
            GUI.add_config_row(pdata, index + 1, ruleset_grid)
            ruleset_grid.scroll_to_bottom()
        elseif c > START_SIZE and index == c - 1 and not config.from then
            GUI.deregister_action(ruleset_grid.children[c], pdata, true)
            config_tmp[c] = nil
        end
    end,

    set_module = function(event, pdata, args)
        if event.name ~= defines.events.on_gui_elem_changed then return end
        local frame = pdata.gui_elements.config_frame
        local config_tmp = pdata.config_tmp
        if not (frame and frame.valid and config_tmp) then return end
        local _item_prototypes = game.item_prototypes
        local elem_value = event.element.elem_value
        local proto = elem_value and _item_prototypes[elem_value]
        local index, slot = args.index, args.slot

        local config = config_tmp[index]
        local modules = config.to

        if proto and config.from and proto.type == "module" then
            local entity_proto = get_entity_from_item_name(config.from)
            local itemEffects = proto.module_effects
            if entity_proto and entity_proto.type == "beacon" and itemEffects and itemEffects.productivity then
                if itemEffects.productivity ~= 0 and not entity_proto.allowed_effects['productivity'] then
                    GUI.display_message(event.player, {"inventory-restriction.cant-insert-module", proto.localised_name, entity_proto.localised_name}, true)
                    modules[slot] = nil
                end
            else
                modules[slot] = proto.name
            end
        elseif not proto then
            modules[slot] = nil
        end
        config.to = modules
        config.productivity = nil

        local cTable = {}
        local prototype, limitations
        for _, module in pairs(modules) do
            if module then
                prototype = _item_prototypes[module]
                limitations = prototype and prototype.limitations
                if limitations and next(limitations) then
                    config.limitations = true
                end
                cTable[module] = (cTable[module] or 0) + 1
            end
        end
        config.cTable = cTable
        GUI.update_modules(pdata, index)
    end,
}

function GUI.deregister_action(element, pdata, destroy)
    if not (element and element.valid) then return end
    local player_gui_actions = pdata.gui_actions
    if not player_gui_actions then
        return
    end
    player_gui_actions[element.index] = nil
    for k, child in pairs(element.children) do
        GUI.deregister_action(child, pdata)
    end
    if destroy then
        element.destroy()
    end
end

--[[
    params = {
        type: function name
    }
--]]
function GUI.register_action(pdata, element, params)
    local player_gui_actions = pdata.gui_actions
    if not player_gui_actions then
        pdata.gui_actions = {}
        player_gui_actions = pdata.gui_actions
    end
    player_gui_actions[element.index] = params
end

function GUI.get_event_name(i)
    for key, v in pairs(defines.events) do
        if v == i then
            return key
        end
    end
end

function GUI.remove_invalid_actions(pdata)
    local before = table_size(pdata.gui_actions)
    local index_valid = {}
    local function _recurse(element, key)
        index_valid[element.index] = {name = element.name, type = element.type, key = key}
        for _, child in pairs(element.children) do
            if child and child.valid then
                _recurse(child)
            end
        end
    end
    for key, element in pairs(pdata.gui_elements) do
        if element and element.valid then
            _recurse(element, key)
        else
            pdata.gui_elements[key] = nil
            log("Invalid element: " .. key)
        end
    end
    log("Valid gui elements: " .. table_size(index_valid))
    for index, _ in pairs(pdata.gui_actions) do
        if not index_valid[index] then
            pdata.gui_actions[index] = nil
        end
    end
    local after = table_size(pdata.gui_actions)
    for index, action in pairs(pdata.gui_elements) do
        log(index .. ": " .. serpent.line(action))
    end
    log("Removed " .. tostring(before - after) .. " invalid gui actions.")
    log("Remaining valid actions: " .. tostring(after))
end

function GUI.generic_event(event)
    local gui = event.element
    if not (gui and gui.valid) then return end
    local player_index = event.player_index
    local pdata = global._pdata[player_index]
    local player_gui_actions = pdata.gui_actions
    if not player_gui_actions then return end

    local action = player_gui_actions[gui.index]
    if not action then return end

    local player = game.get_player(player_index)
    local status, err = xpcall(function()
        --TODO: is that smart?
        for key, element in pairs(pdata.gui_elements) do
            if element and not element.valid then
                player.print("[ModuleInserter] Invalid element: " .. key)
                --pdata.gui_elements[key] = nil
            end
        end
        event.player = player
        gui_functions[action.type](event, pdata, action)
    end, debug.traceback)
    -- log{"", "Inner: ", profile_inner}
    --log("Selected: " .. tostring(pdata.selected))
    --log("Registered gui actions:" .. table_size(player_gui_actions))
    if not status then
        log("Error running event: " .. tostring(GUI.get_event_name(event.name)))
        log("Event: " .. serpent.line(event))
        log("Action: " ..serpent.line(action and action.type))
        -- for _, c in pairs(pdata.config_tmp) do
        --     log(serpent.line(c))
        -- end
        --log(serpent.block(pdata.config_tmp, {name = "config_tmp", comment = false}))
        debugDump(err, true)
        log(err)
        local s
        for name, elem in pairs(pdata.gui_elements) do
            s = name .. ": "
            if elem and not elem.valid then
                log(s .. "invalid")
            elseif not elem then
                log(s .. "nil")
            end
        end
    end
end

function GUI.init(player, pdata, after_research)
    if (player.force.technologies["construction-robotics"].researched or after_research) then
        local button_flow = mod_gui.get_button_flow(player)
        local button = button_flow.module_inserter_config_button
        if (not (button and button.valid)) then
            button = button_flow.add{
                type = "sprite-button",
                name = "module_inserter_config_button",
                style = "module-inserter-button",
                sprite = "technology/modules"
            }
        end
        GUI.register_action(pdata, button, {type = "main_button"})
        pdata.gui_elements.main_button = button
    end
end

function GUI.delete(pdata)
    if not (pdata and pdata.gui_elements) then return end
    for _, element in pairs(pdata.gui_elements) do
        GUI.deregister_action(element, pdata, true)
    end
    pdata.gui_elements = {}
    pdata.gui_actions = {}
end

function GUI.add_preset(pdata, storage_table, key)
    local preset_flow = storage_table.add{
        type = "flow",
        direction = "horizontal",
    }
    local load = preset_flow.add{
        type = "button",
        caption = key,
    }
    load.style.width = 150
    GUI.register_action(pdata, load, {type = "restore_preset", name = key})

    GUI.register_action(pdata,
        preset_flow.add{
            type = "sprite-button",
            style = "mi_delete_preset",
            sprite = "utility/remove"
        },
        {type = "delete_preset", name = key}
    )
end

function GUI.add_config_row(pdata, index, scroll_pane)
    local config_tmp = pdata.config_tmp
    if not config_tmp[index] then
        config_tmp[index] = {to = {}, cTable = {}}
    end
    local assembler = config_tmp[index].from
    local entity_flow = scroll_pane.add{
        type = "flow",
        direction = "horizontal",
    }
    local assembler_proto = assembler and game.item_prototypes[assembler]
    local tooltip = assembler_proto and assembler_proto.localised_name or {"module-inserter-choose-assembler"}
    local choose_button = entity_flow.add{
        type = "choose-elem-button",
        name = "assembler",
        style = "slot_button",
        elem_type = "item",
        tooltip = tooltip
    }
    choose_button.elem_value = assembler or nil
    choose_button.style.right_margin = 8

    GUI.register_action(pdata, choose_button, {type = "set_assembler", index = index})

    entity_flow.add{
        type = "flow",
        direction = "horizontal",
        name = "modules"
    }
    GUI.update_modules(pdata, index)
end

function GUI.close(pdata, player_index)
    local gui_elements = pdata.gui_elements
    GUI.deregister_action(gui_elements.config_frame, pdata, true)
    gui_elements.config_frame = nil
    gui_elements.ruleset_grid = nil

    GUI.deregister_action(gui_elements.preset_frame, pdata, true)
    gui_elements.preset_frame = nil
    gui_elements.storage_grid = nil
    gui_elements.textfield = nil

    show_yarm(pdata, player_index)
end

function GUI.open_config_frame(pdata, player)

    hide_yarm(pdata, player.index)

    pdata.config_tmp = util.table.deepcopy(pdata.config)
    local config_tmp = pdata.config_tmp
    local max_config_size = #config_tmp
    max_config_size = (max_config_size > START_SIZE) and max_config_size or START_SIZE

    local left = mod_gui.get_frame_flow(player)
    local frame = left.add{
        type = "frame",
        name = "module_inserter_config_frame",
        caption = {"module-inserter-config-frame-title"},
        direction = "vertical"
    }
    frame.style.maximal_height = 596
    pdata.gui_elements.config_frame = frame
    local bordered_frame = frame.add{
        type = "frame",
        style = "bordered_frame",
        direction = "vertical",
    }
    bordered_frame.style.horizontally_stretchable = true
    local scroll_pane = bordered_frame.add{
        type = "scroll-pane",
        --vertical_scroll_policy = "auto-and-reserve-space"
    }
    pdata.gui_elements.ruleset_grid = scroll_pane
    for i = 1, max_config_size do
        GUI.add_config_row(pdata, i, scroll_pane)
    end
    --always add one empty row
    if config_tmp[max_config_size] and config_tmp[max_config_size].from then
        GUI.add_config_row(pdata, max_config_size + 1, scroll_pane)
    end

    local button_grid = bordered_frame.add{
        type = "table",
        column_count = 2,
    }
    button_grid.style.top_margin = 8

    local apply = button_grid.add{
        type = "button",
        caption = {"module-inserter-config-button-apply"}
    }
    GUI.register_action(pdata, apply, {type = "save_changes"})

    local clear = button_grid.add{
        type = "button",
        caption = {"module-inserter-config-button-clear-all"}
    }
    GUI.register_action(pdata, clear, {type = "clear_all"})
    GUI.open_storage_frame(pdata, left)
end

function GUI.open_storage_frame(pdata, left)
    local storage_frame = left.add{
        type = "frame",
        caption = {"module-inserter-storage-frame-title"},
        direction = "vertical"
    }
    pdata.gui_elements.preset_frame = storage_frame
    storage_frame.style.maximal_height = 596
    storage_frame.style.maximal_width = 500

    local storage_frame_buttons = storage_frame.add{
        type = "table",
        column_count = 2,
    }

    local textfield = storage_frame_buttons.add{
        type = "textfield",
        text = "",
    }
    textfield.style.width = 150
    pdata.gui_elements.textfield = textfield

    local save_button = storage_frame_buttons.add{
        type = "button",
        caption = {"gui-save-game.save"},
        style = "module-inserter-small-button"
    }
    GUI.register_action(pdata, save_button, {type = "save_preset"})

    local storage_pane = storage_frame.add{
        type = "scroll-pane",
    }
    --scroll_pane.style.maximal_height = 480 * (1 / player.display_scale)
    -- local storage_table = storage_pane.add{
    --     type = "flow",
    --     --column_count = 3,
    --     direction = "vertical",
    -- }
    pdata.gui_elements.storage_grid = storage_pane

    if pdata.storage then
        for key, _ in pairs(pdata.storage) do
            GUI.add_preset(pdata, storage_pane, key)
        end
    end
end

function GUI.display_message(player, message, sound)
    player.surface.create_entity{name = "flying-text", position = player.position, text = message, color = {r=1, g=1, b=1}}
    if sound then
        if sound == "success" then
            player.play_sound{path = "utility/console_message", position = player.position}
        else
            player.play_sound{path = "utility/cannot_build", position = player.position}
        end
    end
end

function GUI.clear_rule(pdata, index, element)
    element.elem_value = nil
    element.tooltip = {"module-inserter-choose-assembler"}
    pdata.config_tmp[index] = {to = {}, cTable = {}}
    GUI.update_modules(pdata, index)
    GUI.update_rows(pdata)
end

function GUI.update_rows(pdata)
    local size = #pdata.config_tmp
    local children = pdata.gui_elements.ruleset_grid.children
    local c_size = #children
    local start = size > c_size and size or c_size
    if start > START_SIZE then
        local config_tmp = pdata.config_tmp
        for i = start, START_SIZE + 1, -1 do
            if not config_tmp[i] or (not config_tmp[i].from and not config_tmp[i-1].from) then
                config_tmp[i] = nil
                GUI.deregister_action(children[i], pdata, true)
            else
                break
            end
        end
    end
end

function GUI.update_modules(pdata, index)
    local config_tmp = pdata.config_tmp[index]
    local slots = config_tmp and config_tmp.from and global.nameToSlots[config_tmp.from] or 1
    local modules = config_tmp and config_tmp.to or {}
    local flow = pdata.gui_elements.ruleset_grid.children[index].modules

    local locked = not config_tmp.from
    local tooltip = {"module-inserter-choose-module"}
    local child_count = #flow.children

    local _item_prototypes = game.item_prototypes
    for i, child in pairs(flow.children) do
        if i <= slots then
            child.elem_value = modules[i] or nil
            child.tooltip = modules[i] and _item_prototypes[modules[i]].localised_name or tooltip
            child.locked = locked
            if not locked then
                GUI.register_action(pdata, child, {type = "set_module", index = index, slot = i})
            end
        else
            GUI.deregister_action(child, pdata, true)
        end
    end
    if child_count < slots then
        for i = child_count + 1 , slots do
            local choose_button = flow.add{
                type = "choose-elem-button",
                style = "slot_button",
                elem_type = "item",
            }
            choose_button.elem_value = modules[i] or nil
            choose_button.tooltip = modules[i] and _item_prototypes[modules[i]].localised_name or tooltip
            choose_button.locked = locked
            GUI.register_action(pdata, choose_button, {type = "set_module", index = index, slot = i})
        end
    end
end

return GUI
