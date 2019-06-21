local mod_gui = require '__core__/lualib/mod-gui'
--local saveVar = require "__ModuleInserter__/lib_control".saveVar

local GUI = {}

function GUI.init(player, after_research)
    local button = global.gui_elements[player.index].main_button
    if (not (button and button.valid)) and (player.force.technologies["construction-robotics"].researched or after_research) then
        button = mod_gui.get_button_flow(player).add{
            type = "sprite-button",
            name = "module_inserter_config_button",
            style = "module-inserter-button",
            sprite = "technology/modules"
        }
    end
    global.gui_elements[player.index].main_button = button
end

function GUI.destroy(player)
    local frame = global.gui_elements[player.index].config_frame
    if frame and frame.valid then
        frame.destroy()
        global.gui_elements[player.index].config_frame = nil
    end
    local storage = global.gui_elements[player.index].preset_frame
    if storage and storage.valid then
        storage.destroy()
        global.gui_elements[player.index].preset_frame = nil
    end
    --TODO why not keep it?
    --global["config-tmp"][player.index] = nil
    if remote.interfaces.YARM and remote.interfaces.YARM.show_expando and global.settings[player.index].YARM_old_expando then
        remote.call("YARM", "show_expando", player.index)
    end
end

function GUI.refresh(player)
    local frame = global.gui_elements[player.index].config_frame
    local was_opened
    if frame and frame.valid then
        frame.destroy()
        global.gui_elements[player.index].config_frame = nil
        was_opened = true
    end
    local storage = global.gui_elements[player.index].preset_frame
    if storage and storage.valid then
        storage.destroy()
        global.gui_elements[player.index].preset_frame = nil
    end
    if was_opened then
        GUI.open_frame(player, global["config-tmp"][player.index])
    end
end

function GUI.add_preset(storage_table, key)
    local preset_flow = storage_table.add{
        type = "flow",
        direction = "horizontal"
    }
    preset_flow.add{
        type = "button",
        caption = key,
        name = "module_inserter_restore_preset"
    }.style.width = 150
    preset_flow.add{
        type = "sprite-button",
        name = "module_inserter_delete_preset",
        style = "mi_delete_preset",
        sprite = "utility/remove"
    }
end

function GUI.open_frame(player, tmp_config)
    local player_index = player.index
    local frame = global.gui_elements[player_index].config_frame
    if frame and frame.valid then
        GUI.destroy(player)
        return
    end

    -- Temporary config lives as long as the frame is open, so it has to be created
    -- every time the frame is opened.
    global["config-tmp"][player.index] = tmp_config or {}
    local max_config_size = player.mod_settings.module_inserter_config_size.value
    -- We need to copy all items from normal config to temporary config.
    local config_tmp = global["config-tmp"][player.index]
    local config = global["config"][player.index]
    --TODO: what is this stupditiy?!
    for i = 1, max_config_size do
        if i > #config then
            config_tmp[i] = {from = false, to = {}}
        else
            config_tmp[i] = {
                from = config[i].from,
                to = util.table.deepcopy(config[i].to)
            }
        end
    end
    if remote.interfaces.YARM and remote.interfaces.YARM.hide_expando then
        global.settings[player.index].YARM_old_expando = remote.call("YARM", "hide_expando", player.index)
    end
    -- Now we can build the GUI
    local left = mod_gui.get_frame_flow(player)
    frame = left.add{
        type = "frame",
        caption = {"module-inserter-config-frame-title"},
        name = "module-inserter-config-frame",
        direction = "vertical"
    }
    frame.style.maximal_height = 596
    global.gui_elements[player_index].config_frame = frame

    local error_label = frame.add{
        type = "label",
        caption = "---",
        name = "module-inserter-error-label"
    }
    error_label.style.minimal_width = 200

    local scroll_pane = frame.add{
        type = "scroll-pane",
        name = "module-inserter-config-pane"
    }
    local ruleset_grid = scroll_pane.add{
        type = "table",
        column_count = 3,
        name = "module-inserter-ruleset-grid"
    }
    ruleset_grid.add{
        type = "label",
        name = "module-inserter-grid-header-1",
        caption = {"module-inserter-config-header-1"}
    }
    ruleset_grid.add{
        type = "label",
        caption = "  "
    }
    ruleset_grid.add{
        type = "label",
        name = "module-inserter-grid-header-2",
        caption = {"module-inserter-config-header-2"}
    }
    --saveVar(global, "test")
    for i = 1, max_config_size do
        local assembler = config_tmp[i].from
        assembler = assembler or nil
        local tooltip = (assembler  and game.item_prototypes[assembler]) and game.item_prototypes[assembler].localised_name or {"module-inserter-choose-assembler"}
        local choose_button = ruleset_grid.add{
            type = "choose-elem-button",
            name = "module-inserter-from-" .. i,
            style = "slot_button",
            elem_type = "item",
            tooltip = tooltip
        }
        choose_button.elem_value = assembler
        ruleset_grid.add{
            type = "label",
            caption = "  "
        }

        ruleset_grid.add{
            type = "flow",
            name = "module-inserter-slotflow-" .. i,
            direction = "horizontal"
        }
        GUI.update_modules(player,i)
    end

    local button_grid = frame.add{
        type = "table",
        column_count = 2,
        name = "module-inserter-button-grid"
    }
    button_grid.add{
        type = "button",
        name = "module-inserter-apply",
        caption = {"module-inserter-config-button-apply"}
    }
    button_grid.add{
        type = "button",
        name = "module-inserter-clear-all",
        caption = {"module-inserter-config-button-clear-all"}
    }

    local storage_frame = left.add{
        type = "frame",
        name = "module-inserter-storage-frame",
        caption = {"module-inserter-storage-frame-title"},
        direction = "vertical"
    }
    global.gui_elements[player_index].preset_frame = storage_frame
    storage_frame.style.maximal_height = 596
    storage_frame.style.maximal_width = 500

    local storage_frame_buttons = storage_frame.add{
        type = "table",
        column_count = 2,
        name = "module-inserter-storage-buttons"
    }

    storage_frame_buttons.add{
        type = "textfield",
        text = "",
        name = "module-inserter-storage-name"
    }.style.width = 150
    storage_frame_buttons.add{
        type = "button",
        caption = {"gui-save-game.save"},
        name = "module-inserter-storage-store",
        style = "module-inserter-small-button"
    }

    local storage_pane = storage_frame.add{
        type = "scroll-pane",
        name = "module-inserter-storage-pane",
    }
    --scroll_pane.style.maximal_height = 480 * (1 / player.display_scale)
    local storage_table = storage_pane.add{
        type = "flow",
        --column_count = 3,
        direction = "vertical",
        name = "module-inserter-storage-grid"
    }

    if global["storage"][player.index] then
        for key, _ in pairs(global["storage"][player.index]) do
            GUI.add_preset(storage_table, key)
        end
    end
end

function GUI.save_changes(player, name)
    -- Saving changes consists in:
    --   1. copying config-tmp to config
    --   2. removing config-tmp
    --   3. closing the frame

    local tmp = {}
    for i = 1, #global["config-tmp"][player.index] do
        -- Rule can be saved only if both "from" and "to" fields are set. <-- WHY????

        if not global["config-tmp"][player.index][i] or type(global["config-tmp"][player.index][i].to) ~= "table" then
            tmp[i] = { from = false, to = {} }
        else
            tmp[i] = {
                from = global["config-tmp"][player.index][i].from,
                to = global["config-tmp"][player.index][i].to
            }
        end
    end
    global["config"][player.index] = tmp
    local storage_frame = global.gui_elements[player.index].preset_frame
    if (storage_frame and storage_frame.valid) then
        local textfield = storage_frame["module-inserter-storage-buttons"]["module-inserter-storage-name"]
        textfield.text = name or ""
    end
    --global["config-tmp"][player.index] = nil
    --saveVar(global, "saved")
    -- local frame = global.gui_elements[player.index].config_frame
    -- local storage_frame = global.gui_elements[player.index].preset_frame

    -- if frame then
    --     frame.destroy()
    --     if storage_frame then
    --         storage_frame.destroy()
    --     end
    --     if remote.interfaces.YARM and remote.interfaces.YARM.show_expando and global.settings[player.index].YARM_old_expando then
    --         remote.call("YARM", "show_expando", player.index)
    --     end
    -- end
end

function GUI.clear_all(player)
    local player_index = player.index
    local frame = global.gui_elements[player_index].config_frame
    if not (frame and frame.valid) then return end
    local ruleset_grid = frame["module-inserter-config-pane"]["module-inserter-ruleset-grid"]

    for i = 1, player.mod_settings.module_inserter_config_size.value do
        global["config-tmp"][player_index][i] = { from = false, to = {} }
        ruleset_grid["module-inserter-from-" .. i].elem_value = nil
        GUI.update_modules(player, i)
    end
    local storage_frame = global.gui_elements[player_index].preset_frame
    if (storage_frame and storage_frame.valid) then
        local textfield = storage_frame["module-inserter-storage-buttons"]["module-inserter-storage-name"]
        textfield.text = ""
    end
end

function GUI.display_message(frame, storage, message)
    local label_name = "module-inserter-"
    if storage then label_name = label_name .. "storage-" end
    label_name = label_name .. "error-label"

    local error_label = frame[label_name]
    if not (error_label and error_label.valid) then return end

    if message ~= "---" and not type(message) == "table" then
        message = {message}
    end
    error_label.caption = message
end

function GUI.set_rule(player, index, proto, element)
    local frame = global.gui_elements[player.index].config_frame
    local config_tmp = global["config-tmp"][player.index]
    if not (frame and frame.valid and config_tmp) then return end

    if proto and (not proto.module_inventory_size or proto.module_inventory_size == 0) then
        GUI.display_message(frame, false, "module-inserter-item-no-slots")
        element.elem_value = nil
        return
    end

    local name = proto and proto.name
    if name then
        for i = 1, #config_tmp do
            if index ~= i and config_tmp[i].from == name then
                GUI.display_message(frame, false, "module-inserter-item-already-set")
                element.elem_value = nil
                --saveVar(global, "test")
                return
            end
        end
    end

    if name ~= config_tmp[index].from then
        config_tmp[index].to = {}
    end
    config_tmp[index].from = name
    local ruleset_grid = frame["module-inserter-config-pane"]["module-inserter-ruleset-grid"]
    local sprite = config_tmp[index].from or nil
    local tooltip = proto and proto.localised_name or {"module-inserter-choose-assembler"}

    local choose_button = ruleset_grid["module-inserter-from-" .. index]
    choose_button.elem_value = sprite
    choose_button.tooltip = tooltip

    GUI.update_modules(player, index)
end

function GUI.set_modules(player, index, slot, proto)
    local frame = global.gui_elements[player.index].config_frame
    local config_tmp = global["config-tmp"][player.index]
    if not (frame and frame.valid and config_tmp) then return end

    local config = config_tmp[index]
    local modules = type(config.to) == "table" and config.to or {}

    if proto and proto.type == "module" then
        local entity_proto = game.entity_prototypes[config.from]
        local itemEffects = proto.module_effects
        if entity_proto.type == "beacon" and itemEffects and itemEffects.productivity then
            if itemEffects.productivity ~= 0 and not entity_proto.allowed_effects['productivity'] then
                GUI.display_message(frame,false,{"inventory-restriction.cant-insert-module", proto.localised_name, entity_proto.localised_name})
                modules[slot] = false
            end
        else
            modules[slot] = proto.name
        end
    elseif not proto then
        modules[slot] = false
    -- else
    --     GUI.display_message(frame,false,"module-inserter-item-no-module")
    --     return
    end
    config.to = modules
    --saveVar(global, "test2")
    GUI.update_modules(player, index)
end

function GUI.update_modules(player, index)
    local frame = global.gui_elements[player.index].config_frame
    local slots = global.nameToSlots[global["config-tmp"][player.index][index].from] or 1
    local modules = global["config-tmp"][player.index][index].to
    local flow = frame["module-inserter-config-pane"]["module-inserter-ruleset-grid"]["module-inserter-slotflow-" .. index]
    flow.clear()
    local tooltip = {"module-inserter-choose-module"}
    for i=1,slots do
        local choose_button = flow.add{
            type = "choose-elem-button",
            name = "module-inserter-to-" .. index .. "-" .. i,
            style = "slot_button",
            elem_type = "item",
        }
        choose_button.elem_value = modules[i] or nil
        choose_button.tooltip = modules[i] and game.item_prototypes[modules[i]].localised_name or tooltip
    end
end

function GUI.store(player)
    local storage_frame = global.gui_elements[player.index].preset_frame
    if not (storage_frame and storage_frame.valid) then return end
    local textfield = storage_frame["module-inserter-storage-buttons"]["module-inserter-storage-name"]
    local name = textfield.text

    if name == "" then
        GUI.display_message(storage_frame, true, "module-inserter-storage-name-not-set")
        return
    end
    if global["storage"][player.index][name] then
        GUI.display_message(storage_frame, true, "module-inserter-storage-name-in-use")
        return
    end

    global["storage"][player.index][name] = {}
    for i = 1, #global["config-tmp"][player.index] do
        global["storage"][player.index][name][i] = {
            from = global["config-tmp"][player.index][i].from,
            to = util.table.deepcopy(global["config-tmp"][player.index][i].to)
        }
    end

    local storage_grid = storage_frame["module-inserter-storage-pane"]["module-inserter-storage-grid"]
    GUI.add_preset(storage_grid, name)
    textfield.text = ""
    --saveVar(global, "stored")
end

function GUI.restore(player, element)
    local player_index = player.index
    local frame = global.gui_elements[player_index].config_frame
    local storage_frame = global.gui_elements[player_index].preset_frame
    if not (frame and frame.valid and storage_frame and storage_frame.valid) then return end

    local name = element.caption
    local preset = global["storage"][player_index][name]
    if not preset then return end

    global["config-tmp"][player_index] = {}
    local ruleset_grid = frame["module-inserter-config-pane"]["module-inserter-ruleset-grid"]
    local config_tmp = global["config-tmp"][player_index]
    for i = 1, player.mod_settings.module_inserter_config_size.value do
        if i > #preset then
            config_tmp[i] = {from = false, to = {}}
        else
            config_tmp[i] = {
                from = preset[i].from,
                to = util.table.deepcopy(preset[i].to)
            }
        end
        local assembler = config_tmp[i].from or nil
        ruleset_grid["module-inserter-from-" .. i].elem_value = assembler
        GUI.update_modules(player, i)
    end
    GUI.save_changes(player, name)
end

function GUI.remove(player, element)
    if not global["storage"][player.index] then return end
    local storage_frame = global.gui_elements[player.index].preset_frame
    if not (storage_frame and storage_frame.valid) then return end
    local preset_flow = element.parent
    local name = preset_flow.children[1]
    name = (name and name.valid) and name.caption
    preset_flow.destroy()

    global["storage"][player.index][name] = nil
end

return GUI
