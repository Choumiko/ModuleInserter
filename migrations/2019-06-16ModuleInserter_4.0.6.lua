for _, player in pairs(game.players) do
    player.force.reset_recipes()
    player.force.reset_technologies()

    if player.force.technologies["construction-robotics"].researched then
        player.force.recipes["module-inserter"].enabled = true
    end
    if player.gui.top["module-inserter-config-button"] and player.gui.top["module-inserter-config-button"].valid then
        player.gui.top["module-inserter-config-button"].destroy()
    end
    if player.gui.left["choumiko-left"] and player.gui.left["choumiko-left"].valid then
        player.gui.left["choumiko-left"].destroy()
    end
    local frame = player.gui.left["module-inserter-config-frame"]
    if frame and frame.valid then
        frame.destroy()
    end
    local storage = player.gui.left["module-inserter-storage-frame"]
    if storage and storage.valid then
        storage.destroy()
    end
end
