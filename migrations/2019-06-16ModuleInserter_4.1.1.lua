local mod_gui = require '__core__/lualib/mod-gui'
global.proxies = global.proxies or {}
global._pdata = global._pdata or {}

for pi, p in pairs(game.players) do
    local left = mod_gui.get_button_flow(p)
    if (left.module_inserter_config_button and left.module_inserter_config_button.valid) then
        local id = left.module_inserter_config_button.index
        left.module_inserter_config_button.destroy()
        if global._pdata[pi] then
            if global._pdata[pi].gui_elements then
                global._pdata[pi].gui_elements.main_button = nil
            end
            if global._pdata[pi].gui_actions then
                global._pdata[pi].gui_actions[id] = nil
            end
        end
    end
end
