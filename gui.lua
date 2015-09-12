GUI = {
  styleprefix = "st_",

  defaultStyles = {
    label = "label",
    button = "button",
    checkbox = "checkbox"
  },

  windows = {
    root = "stGui",
    settings = {"settings"},
    trainInfo = {"trainInfo"}},

  position = "left",

  new = function(index, player)
    local new = {}
    setmetatable(new, {__index=GUI})
    return new
  end,

  create_or_update = function(trainInfo, player_index)
    local player = game.players[player_index]
    if player.valid then
      local main = GUI.buildGui(player)
      GUI.showSettingsButton(main)
      if player.opened and player.opened.type == "locomotive" then
        GUI.showTrainInfoWindow(main, trainInfo, player_index)
      end
      GUI.showTrainLinesWindow(main,trainInfo, player_index)
    end
  end,

  buildGui = function (player)
    GUI.destroyGui(player.gui[GUI.position][GUI.windows.root])
    local stGui = GUI.add(player.gui[GUI.position], {type="frame", name="stGui", direction="vertical", style="outer_frame_style"})
    return GUI.add(stGui, {type="table", name="rows", colspan=1})
  end,

  showSettingsButton = function(parent)
    local gui = parent
    if gui.toggleSTSettings ~= nil then
      gui.toggleSTSettings.destroy()
    end
    GUI.addButton(gui, {name="toggleSTSettings", caption = {"text-st-settings"}})
  end,

  destroyGui = function (guiA)
    if guiA ~= nil and guiA.valid then
      guiA.destroy()
    end
  end,

  destroy = function(player_index)
    local player = false
    if type1(player_index) == "number" then
      player = game.players[player_index]
    else
      player = player_index
    end
    if player.valid then
      GUI.destroyGui(player.gui[GUI.position][GUI.windows.root])
    end
  end,

  add = function(parent, e, bind)
    local type, name = e.type, e.name
    if not e.style and (type == "button" or type == "label") then
      e.style = "st_"..type
    end
    if bind then
      if type == "checkbox" then
        e.state = global[bind]
      end
    end
    if type == "checkbox" and not (e.state == true or e.state == false) then
      e.state = false
    end
    return parent.add(e)
  end,

  addButton = function(parent, e, bind)
    e.type="button"
    return GUI.add(parent, e, bind)
  end,

  addLabel = function(parent, e, bind)
    local e = e
    if type1(e) == "string" or type1(e) == "number" or (type1(e) == "table" and e[1]) then
      e = {caption=e}
    end
    e.type="label"
    return GUI.add(parent,e,bind)
  end,

  addTextfield = function(parent, e, bind)
    e.type="textfield"
    return GUI.add(parent, e, bind)
  end,

  addPlaceHolder = function(parent, count)
    local c = count or 1
    for i=1,c do
      GUI.add(parent, {type="label", caption=""})
    end
  end,

  sanitizeName = function(name)
    local name = string.gsub(name, "_", " ")
    name = string.gsub(name, "^%s", "")
    name = string.gsub(name, "%s$", "")
    local pattern = "(%w+)__([%w%s%-%#%!%$]*)_*([%w%s%-%#%!%$]*)_*(%w*)"
    local element = "activeLine__"..name.."__".."something"
    local t1,t2,t3,t4 = element:match(pattern)
    if t1 == "activeLine" and t2 == name and t3 == "something" then
      return name
    else
      return false
    end
  end,

  sanitizeNumber = function(number, default)
    return tonumber(number) or default
  end
}

function gui_init(player, after_research)
  if not player.gui.top["module-inserter-config-button"]
    and (player.force.technologies["automated-construction"].researched or after_research) then
    player.gui.top.add{
      type = "button",
      name = "module-inserter-config-button",
      style = "module-inserter-button"
    }
    global.guiVersion[player.name] = "0.0.9"
  end
end

function gui_open_frame(player)
  local frame = player.gui.left["module-inserter-config-frame"]
  local storage_frame = player.gui.left["module-inserter-storage-frame"]

  if frame then
    frame.destroy()
    if storage_frame then
      storage_frame.destroy()
    end
    global["config-tmp"][player.name] = nil
    return
  end

  -- If player config does not exist, we need to create it.
  global["config"][player.name] = global["config"][player.name] or {}

  -- Temporary config lives as long as the frame is open, so it has to be created
  -- every time the frame is opened.
  global["config-tmp"][player.name] = {}

  -- We need to copy all items from normal config to temporary config.
  local i = 0
  for i = 1, MAX_CONFIG_SIZE do
    if i > #global["config"][player.name] then
      global["config-tmp"][player.name][i] = { from = "", to = {} }
    else
      global["config-tmp"][player.name][i] = {
        from = global["config"][player.name][i].from,
        to = global["config"][player.name][i].to
      }
    end
  end

  -- Now we can build the GUI.
  frame = player.gui.left.add{
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
    colspan = 3,
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

  for i = 1, MAX_CONFIG_SIZE do
    local style = global["config-tmp"][player.name][i].from or "style"
    style = style == "" and "style" or style
    ruleset_grid.add{
      type = "checkbox",
      name = "module-inserter-from-" .. i,
      style = "mi-icon-" ..style,
      state = false
    --caption = get_config_item(player, i, "from")
    }
    ruleset_grid.add{
      type = "label",
      caption = "  "
    }

    local slots = ruleset_grid.add{
      type = "flow",
      name = "module-inserter-slotflow-" .. i,
      direction = "horizontal"
    }
    gui_update_modules(player,i)
  end

  local button_grid = frame.add{
    type = "table",
    colspan = 3,
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
  end

  storage_frame = player.gui.left.add{
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
    colspan = 3,
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
    colspan = 3,
    name = "module-inserter-storage-grid"
  }

  if global["storage"][player.name] then
    i = 1
    for key, _ in pairs(global["storage"][player.name]) do
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

function gui_save_changes(player)
  -- Saving changes consists in:
  --   1. copying config-tmp to config
  --   2. removing config-tmp
  --   3. closing the frame

  if global["config-tmp"][player.name] then
    local i = 0
    global["config"][player.name] = {}

    for i = 1, #global["config-tmp"][player.name] do
      -- Rule can be saved only if both "from" and "to" fields are set.
      if global["config-tmp"][player.name][i].from == "" or global["config-tmp"][player.name][i].to == "" then
        global["config"][player.name][i] = { from = "", to = "" }
      else
        global["config"][player.name][i] = {
          from = global["config-tmp"][player.name][i].from,
          to = global["config-tmp"][player.name][i].to
        }
      end
    end
    global["config-tmp"][player.name] = nil
  end
  --saveVar(global, "saved")
  local frame = player.gui.left["module-inserter-config-frame"]
  local storage_frame = player.gui.left["module-inserter-storage-frame"]

  if frame then
    frame.destroy()
    if storage_frame then
      storage_frame.destroy()
    end
  end
end

function gui_clear_all(player)
  local i = 0
  local frame = player.gui.left["module-inserter-config-frame"]
  if not frame then return end
  local ruleset_grid = frame["module-inserter-ruleset-grid"]
  for i = 1, MAX_CONFIG_SIZE do
    global["config-tmp"][player.name][i] = { from = "", to = {} }
    ruleset_grid["module-inserter-from-" .. i].style = "mi-icon-style"
    gui_update_modules(player, i)
  end
end

function gui_display_message(frame, storage, message)
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

function gui_set_rule(player, type1, index)
  local frame = player.gui.left["module-inserter-config-frame"]
  if not frame or not global["config-tmp"][player.name] then return end

  local stack = player.cursor_stack
  if not stack.valid_for_read then
    stack = {type = "empty", name = ""}
    global["config-tmp"][player.name][index].from = ""
    --gui_display_message(frame, false, "module-inserter-item-empty")
    --return
  end

  if type1 ~= "to" then
    local opposite = "from"
    local i = 0
    if type1 == "from" then
      opposite = "to"
      for i = 1, #global["config-tmp"][player.name] do
        if stack.type ~= "empty" and index ~= i and global["config-tmp"][player.name][i].from == stack.name then
          gui_display_message(frame, false, "module-inserter-item-already-set")
          return
        end
      end
    end
    if stack.type ~= "empty" and not nameToSlots[stack.name] then
      gui_display_message(frame, false, "module-inserter-item-no-slots")
      return
    end
  end
  if stack.type == "empty" or stack.name ~= global["config-tmp"][player.name][index][type1] then
    global["config-tmp"][player.name][index].to = {}
  end
  global["config-tmp"][player.name][index][type1] = stack.name
  local ruleset_grid = frame["module-inserter-ruleset-grid"]
  local style = global["config-tmp"][player.name][index].from ~= "" and "mi-icon-"..global["config-tmp"][player.name][index].from or "mi-icon-style"
  ruleset_grid["module-inserter-" .. type1 .. "-" .. index].style = style
  ruleset_grid["module-inserter-" .. type1 .. "-" .. index].state = false
  if type1 == "from" then
    --local slots = nameToSlots[global["config-tmp"][player.name][index].from] or "-"
    --ruleset_grid["module-inserter-slots-" .. index].caption = slots
    gui_update_modules(player, index)
  end
end

function gui_set_modules(player, index, slot)
  local frame = player.gui.left["module-inserter-config-frame"]
  if not frame or not global["config-tmp"][player.name] then return end

  local stack = player.cursor_stack
  if not stack.valid_for_read then
    --gui_display_message(frame, false, "module-inserter-item-empty")
    stack = {type = "empty", name = ""}
  end
  if global["config-tmp"][player.name][index].from == "" then
    gui_display_message(frame, false, "module-inserter-item-no-entity")
    return
  end

  local type1 = "to"
  local config = global["config-tmp"][player.name][index]
  local modules = type(config[type1]) == "table" and config[type1] or {}
  local maxSlots = nameToSlots[config.from]
  if stack.type == "module" then
    if game.entity_prototypes[config.from].type == "beacon" and game.item_prototypes[stack.name].module_effects and game.item_prototypes[stack.name].module_effects["productivity"] then
      if game.item_prototypes[stack.name].module_effects["productivity"] ~= 0 then
        gui_display_message(frame,false,"module-inserter-no-productivity-beacon")
        return
      end
    end
    modules[slot] = stack.name
  elseif stack.type == "empty" then
    modules[slot] = false
  else
    gui_display_message(frame,false,"module-inserter-item-no-module")
    return
  end
  --debugDump(modules,true)
  global["config-tmp"][player.name][index][type1] = modules
  gui_update_modules(player, index)
end

function gui_update_modules(player, index)
  local frame = player.gui.left["module-inserter-config-frame"]
  local slots = nameToSlots[global["config-tmp"][player.name][index].from] or 1
  local modules = global["config-tmp"][player.name][index].to
  local flow = frame["module-inserter-ruleset-grid"]["module-inserter-slotflow-" .. index]
  for i=#flow.children_names,1,-1 do
    flow[flow.children_names[i]].destroy()
  end
  for i=1,slots do
    local style = modules[i] and "mi-icon-" .. modules[i] or "mi-icon-style"
    if flow["module-inserter-to-" .. index .. "-" .. i] then
      flow["module-inserter-to-" .. index .. "-" .. i].style = style
      flow["module-inserter-to-" .. index .. "-" .. i].state = false
    else
      flow.add{
        type = "checkbox",
        name = "module-inserter-to-" .. index .. "-" .. i,
        style = style,
        state = false
      }
    end
  end
end

function gui_store(player)
  global["storage"][player.name] = global["storage"][player.name] or {}
  local storage_frame = player.gui.left["module-inserter-storage-frame"]
  if not storage_frame then return end
  local textfield = storage_frame["module-inserter-storage-buttons"]["module-inserter-storage-name"]
  local name = textfield.text
  name = string.match(name, "^%s*(.-)%s*$")

  if not name or name == "" then
    gui_display_message(storage_frame, true, "module-inserter-storage-name-not-set")
    return
  end
  if global["storage"][player.name][name] then
    gui_display_message(storage_frame, true, "module-inserter-storage-name-in-use")
    return
  end

  global["storage"][player.name][name] = {}
  local i = 0
  for i = 1, #global["config-tmp"][player.name] do
    global["storage"][player.name][name][i] = {
      from = global["config-tmp"][player.name][i].from,
      to = util.table.deepcopy(global["config-tmp"][player.name][i].to)
    }
  end

  local storage_grid = storage_frame["module-inserter-storage-grid"]
  local index = count_keys(global["storage"][player.name]) + 1
  if index > MAX_STORAGE_SIZE + 1 then
    gui_display_message(storage_frame, true, "module-inserter-storage-too-long")
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
  gui_display_message(storage_frame, true, "---")
  textfield.text = ""
  --saveVar(global, "stored")
end

function gui_restore(player, index)
  local frame = player.gui.left["module-inserter-config-frame"]
  local storage_frame = player.gui.left["module-inserter-storage-frame"]
  if not frame or not storage_frame then return end

  local storage_grid = storage_frame["module-inserter-storage-grid"]
  local storage_entry = storage_grid["module-inserter-storage-entry-" .. index]
  if not storage_entry then return end

  local name = string.match(storage_entry.caption, "^%s*(.-)%s*$")
  if not global["storage"][player.name] or not global["storage"][player.name][name] then return end

  global["config-tmp"][player.name] = {}
  local i = 0
  local ruleset_grid = frame["module-inserter-ruleset-grid"]
  for i = 1, MAX_CONFIG_SIZE do
    if i > #global["storage"][player.name][name] then
      global["config-tmp"][player.name][i] = { from = "", to = "" }
    else
      global["config-tmp"][player.name][i] = {
        from = global["storage"][player.name][name][i].from,
        to = global["storage"][player.name][name][i].to
      }
    end
    local style = global["config-tmp"][player.name][i].from ~= "" and "mi-icon-"..global["config-tmp"][player.name][i].from or "mi-icon-style"
    ruleset_grid["module-inserter-from-" .. i].style = style
    ruleset_grid["module-inserter-from-" .. i].state = false
    gui_update_modules(player, i)
  end
  gui_display_message(storage_frame, true, "---")
end

function gui_remove(player, index)
  if not global["storage"][player.name] then return end

  local storage_frame = player.gui.left["module-inserter-storage-frame"]
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

  global["storage"][player.name][name] = nil
  gui_display_message(storage_frame, true, "---")
end
