local GUI = {}
GUI.left = "choumiko-left"

GUI.get_left_frame = function(player)
    local left = player.gui.left[GUI.left]
    if left and left.valid then
        return left
    end
end

GUI.get_or_create_left_frame = function(player)
    return GUI.get_left_frame(player) or player.gui.left.add{type = "flow", name = GUI.left, direction = "horizontal"}
end

function GUI.init(player, after_research)
    if not player.gui.top["module-inserter-config-button"]
        and (player.force.technologies["construction-robotics"].researched or after_research) then
        player.gui.top.add{
            type = "sprite-button",
            name = "module-inserter-config-button",
            style = "module-inserter-button",
            sprite = "technology/modules"
        }
    end
    GUI.get_or_create_left_frame(player)
end

function GUI.destroy(player)
    local left = GUI.get_left_frame(player)
    if not left then return end
    local frame = left["module-inserter-config-frame"]
    if frame and frame.valid then
        frame.destroy()
    end
    local storage = left["module-inserter-storage-frame"]
    if storage and storage.valid then
        storage.destroy()
    end
    global["config-tmp"][player.index] = nil
    if remote.interfaces.YARM and remote.interfaces.YARM.show_expando and global.settings[player.index].YARM_old_expando then
        remote.call("YARM", "show_expando", player.index)
    end
end

function GUI.open_frame(player)
    local left = GUI.get_or_create_left_frame(player)
    local frame = left["module-inserter-config-frame"]
    if frame then
        GUI.destroy(player)
        return
    end

    -- If player config does not exist, we need to create it.
    global["config"][player.index] = global["config"][player.index] or {}

    -- Temporary config lives as long as the frame is open, so it has to be created
    -- every time the frame is opened.
    global["config-tmp"][player.index] = {}

    -- We need to copy all items from normal config to temporary config.
    for i = 1, MAX_CONFIG_SIZE do
        if i > #global["config"][player.index] then
            global["config-tmp"][player.index][i] = {from = false, to = {}}
        else
            global["config-tmp"][player.index][i] = {
                from = global["config"][player.index][i].from,
                to = util.table.deepcopy(global["config"][player.index][i].to)
            }
        end
    end
    if remote.interfaces.YARM and remote.interfaces.YARM.hide_expando then
        global.settings[player.index].YARM_old_expando = remote.call("YARM", "hide_expando", player.index)
    end
    -- Now we can build the GUI
    frame = left.add{
        type = "frame",
        caption = {"module-inserter-config-frame-title"},
        name = "module-inserter-config-frame",
        direction = "vertical"
    }
    local error_label = frame.add{
        type = "label",
        caption = "---",
        name = "module-inserter-error-label"
    }
    error_label.style.minimal_width = 200
    local ruleset_grid = frame.add{
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
    for i = 1, MAX_CONFIG_SIZE do
        local assembler = global["config-tmp"][player.index][i].from
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
        column_count = 3,
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
    if DEBUG then
        button_grid.add{
            type="button",
            name = "module-inserter-debug",
            caption = "D"
        }
    else
        button_grid.add{type="label", caption=""}
    end
    button_grid.add{
        type = "button",
        name = "module-inserter-save-as",
        caption = {"module-inserter-config-button-save-as"}
    }

    local saveText = button_grid.add{
        type = "textfield",
        name = "module-inserter-save-as-text"
    }
    saveText.text = global.config[player.index].loaded or ""

    local storage_frame = left.add{
        type = "frame",
        name = "module-inserter-storage-frame",
        caption = {"module-inserter-storage-frame-title"},
        direction = "vertical"
    }
    local storage_frame_error_label = storage_frame.add{
        type = "label",
        name = "module-inserter-storage-error-label",
        caption = "---"
    }
    storage_frame_error_label.style.minimal_width = 200
    local storage_frame_buttons = storage_frame.add{
        type = "table",
        column_count = 3,
        name = "module-inserter-storage-buttons"
    }
    storage_frame_buttons.add{
        type = "label",
        caption = {"module-inserter-storage-name-label"},
        name = "module-inserter-storage-name-label"
    }
    storage_frame_buttons.add{
        type = "textfield",
        text = "",
        name = "module-inserter-storage-name"
    }
    storage_frame_buttons.add{
        type = "button",
        caption = {"module-inserter-storage-store"},
        name = "module-inserter-storage-store",
        style = "module-inserter-small-button"
    }
    local storage_grid = storage_frame.add{
        type = "table",
        column_count = 3,
        name = "module-inserter-storage-grid"
    }

    if global["storage"][player.index] then
        local i = 1
        for key, _ in pairs(global["storage"][player.index]) do
            storage_grid.add{
                type = "label",
                caption = key .. "        ",
                name = "module-inserter-storage-entry-" .. i
            }
            storage_grid.add{
                type = "button",
                caption = {"module-inserter-storage-restore"},
                name = "module-inserter-restore-" .. i,
                style = "module-inserter-small-button"
            }
            storage_grid.add{
                type = "button",
                caption = {"module-inserter-storage-remove"},
                name = "module-inserter-remove-" .. i,
                style = "module-inserter-small-button"
            }
            i = i + 1
        end
    end
end

function GUI.save_changes(player, name)
    -- Saving changes consists in:
    --   1. copying config-tmp to config
    --   2. removing config-tmp
    --   3. closing the frame

    if global["config-tmp"][player.index] then
        global["config"][player.index] = {}

        for i = 1, #global["config-tmp"][player.index] do
            -- Rule can be saved only if both "from" and "to" fields are set. <-- WHY????

            if not global["config-tmp"][player.index][i] or type(global["config-tmp"][player.index][i].to) ~= "table" then
                global["config"][player.index][i] = { from = false, to = {} }
            else
                global["config"][player.index][i] = {
                    from = global["config-tmp"][player.index][i].from,
                    to = global["config-tmp"][player.index][i].to
                }
            end
        end
        global["config-tmp"][player.index] = nil
    end
    global.config[player.index].loaded = name or nil
    --saveVar(global, "saved")
    local left = GUI.get_left_frame(player)
    local frame = left["module-inserter-config-frame"]
    local storage_frame = left["module-inserter-storage-frame"]

    if frame then
        frame.destroy()
        if storage_frame then
            storage_frame.destroy()
        end
        if remote.interfaces.YARM and remote.interfaces.YARM.show_expando and global.settings[player.index].YARM_old_expando then
            remote.call("YARM", "show_expando", player.index)
        end
    end
end

function GUI.clear_all(player)
    local left = GUI.get_left_frame(player)
    if not left then return end
    local frame = left["module-inserter-config-frame"]
    if not frame then return end
    local ruleset_grid = frame["module-inserter-ruleset-grid"]
    global.config[player.index].loaded = nil
    frame["module-inserter-button-grid"]["module-inserter-save-as-text"].text = ""

    for i = 1, MAX_CONFIG_SIZE do
        global["config-tmp"][player.index][i] = { from = false, to = {} }
        ruleset_grid["module-inserter-from-" .. i].elem_value = nil
        GUI.update_modules(player, i)
    end
end

function GUI.display_message(frame, storage, message)
    local label_name = "module-inserter-"
    if storage then label_name = label_name .. "storage-" end
    label_name = label_name .. "error-label"

    local error_label = frame[label_name]
    if not error_label then return end

    if message ~= "---" then
        message = {message}
    end
    error_label.caption = message
end

function GUI.set_rule(player, index, proto, element)
    local left = GUI.get_left_frame(player)
    if not left then return end
    local frame = left["module-inserter-config-frame"]
    if not frame or not global["config-tmp"][player.index] then return end

    if proto and proto.module_inventory_size == 0 then
        GUI.display_message(frame, false, "module-inserter-item-no-slots")
        return
    end

    local name = proto and proto.name
    if name then
        for i = 1, #global["config-tmp"][player.index] do
            if index ~= i and global["config-tmp"][player.index][i].from == name then
                GUI.display_message(frame, false, "module-inserter-item-already-set")
                element.elem_value = nil
                --saveVar(global, "test")
                return
            end
        end
    end

    if name ~= global["config-tmp"][player.index][index].from then
        global["config-tmp"][player.index][index].to = {}
    end
    global["config-tmp"][player.index][index].from = name
    local ruleset_grid = frame["module-inserter-ruleset-grid"]
    local sprite = global["config-tmp"][player.index][index].from or nil
    local tooltip = proto and proto.localised_name or {"module-inserter-choose-assembler"}

    local choose_button = ruleset_grid["module-inserter-from-" .. index]
    choose_button.elem_value = sprite
    choose_button.tooltip = tooltip

    --local slots = global.nameToSlots[global["config-tmp"][player.index][index].from] or "-"
    --ruleset_grid["module-inserter-slots-" .. index].caption = slots
    --saveVar(global, "test")
    GUI.update_modules(player, index)
end

function GUI.set_modules(player, index, slot, proto)
    local left = GUI.get_left_frame(player)
    if not left then return end
    local frame = left["module-inserter-config-frame"]
    if not frame or not global["config-tmp"][player.index] then return end

    local config = global["config-tmp"][player.index][index]
    local modules = type(config.to) == "table" and config.to or {}

    if proto and proto.type == "module" then
        local itemEffects = proto.module_effects
        if game.entity_prototypes[config.from].type == "beacon" and itemEffects and itemEffects.productivity then
            if not game.item_prototypes["module-inserter-beacon"] and itemEffects.productivity ~= 0 then
                GUI.display_message(frame,false,"module-inserter-no-productivity-beacon")
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
    global["config-tmp"][player.index][index].to = modules
    --saveVar(global, "test2")
    GUI.update_modules(player, index)
end

function GUI.update_modules(player, index)
    local left = GUI.get_left_frame(player)
    if not left then return end
    local frame = left["module-inserter-config-frame"]
    local slots = global.nameToSlots[global["config-tmp"][player.index][index].from] or 1
    local modules = global["config-tmp"][player.index][index].to
    local flow = frame["module-inserter-ruleset-grid"]["module-inserter-slotflow-" .. index]
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
    global["storage"][player.index] = global["storage"][player.index] or {}
    local left = GUI.get_left_frame(player)
    if not left then return end
    local storage_frame = left["module-inserter-storage-frame"]
    if not storage_frame then return end
    local textfield = storage_frame["module-inserter-storage-buttons"]["module-inserter-storage-name"]
    local name = textfield.text
    name = string.match(name, "^%s*(.-)%s*$")

    if not name then
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

    local storage_grid = storage_frame["module-inserter-storage-grid"]
    local index = count_keys(global["storage"][player.index]) + 1
    if index > MAX_STORAGE_SIZE + 1 then
        GUI.display_message(storage_frame, true, "module-inserter-storage-too-long")
        return
    end

    storage_grid.add{
        type = "label",
        caption = name .. "        ",
        name = "module-inserter-storage-entry-" .. index
    }

    storage_grid.add{
        type = "button",
        caption = {"module-inserter-storage-restore"},
        name = "module-inserter-restore-" .. index,
        style = "module-inserter-small-button"
    }

    storage_grid.add{
        type = "button",
        caption = {"module-inserter-storage-remove"},
        name = "module-inserter-remove-" .. index,
        style = "module-inserter-small-button"
    }
    GUI.display_message(storage_frame, true, "---")
    textfield.text = ""
    --saveVar(global, "stored")
end

function GUI.save_as(player)
    global["storage"][player.index] = global["storage"][player.index] or {}
    local left = GUI.get_left_frame(player)
    if not left then return end
    local storage_frame = left["module-inserter-storage-frame"]
    local frame = left["module-inserter-config-frame"]

    if not storage_frame or not frame then return end
    local textfield = frame["module-inserter-button-grid"]["module-inserter-save-as-text"]
    local name = textfield.text
    name = string.match(name, "^%s*(.-)%s*$")

    if not name or name == "" then
        GUI.display_message(frame, true, "module-inserter-storage-name-not-set")
        return
    end
    local index = count_keys(global["storage"][player.index]) + 1
    if not global["storage"][player.index][name] and index > MAX_STORAGE_SIZE then
        GUI.display_message(frame, false, "module-inserter-storage-too-long")
        return
    end

    global["storage"][player.index][name] = {}
    for i = 1, #global["config-tmp"][player.index] do
        global["storage"][player.index][name][i] = {
            from = global["config-tmp"][player.index][i].from,
            to = util.table.deepcopy(global["config-tmp"][player.index][i].to)
        }
    end
    GUI.save_changes(player, name)
end

function GUI.restore(player, index)
    local left = GUI.get_left_frame(player)
    if not left then return end
    local frame = left["module-inserter-config-frame"]
    local storage_frame = left["module-inserter-storage-frame"]
    if not frame or not storage_frame then return end

    local storage_grid = storage_frame["module-inserter-storage-grid"]
    local storage_entry = storage_grid["module-inserter-storage-entry-" .. index]
    if not storage_entry then return end

    local name = string.match(storage_entry.caption, "^%s*(.-)%s*$")
    if not global["storage"][player.index] or not global["storage"][player.index][name] then return end

    global["config-tmp"][player.index] = {}
    local ruleset_grid = frame["module-inserter-ruleset-grid"]
    for i = 1, MAX_CONFIG_SIZE do
        if i > #global["storage"][player.index][name] then
            global["config-tmp"][player.index][i] = {from = false, to = {}}
        else
            global["config-tmp"][player.index][i] = {
                from = global["storage"][player.index][name][i].from,
                to = util.table.deepcopy(global["storage"][player.index][name][i].to)
            }
        end
        local assembler = global["config-tmp"][player.index][i].from or nil
        ruleset_grid["module-inserter-from-" .. i].elem_value = assembler
        GUI.update_modules(player, i)
    end
    GUI.display_message(storage_frame, true, "---")
    GUI.save_changes(player, name)
end

function GUI.remove(player, index)
    if not global["storage"][player.index] then return end
    local left = GUI.get_left_frame(player)
    if not left then return end
    local storage_frame = left["module-inserter-storage-frame"]
    if not storage_frame then return end
    local storage_grid = storage_frame["module-inserter-storage-grid"]
    local label = storage_grid["module-inserter-storage-entry-" .. index]
    local btn1 = storage_grid["module-inserter-restore-" .. index]
    local btn2 = storage_grid["module-inserter-remove-" .. index]

    if not label or not btn1 or not btn2 then return end

    local name = string.match(label.caption, "^%s*(.-)%s*$")
    label.destroy()
    btn1.destroy()
    btn2.destroy()

    global["storage"][player.index][name] = nil
    GUI.display_message(storage_frame, true, "---")
end

return GUI
