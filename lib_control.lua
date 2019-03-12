local function debugDump(var, force)
    if false or force then
        for _, player in pairs(game.players) do
            local msg
            if type(var) == "string" then
                msg = var
            else
                msg = serpent.dump(var, {name="var", comment=false, sparse=false, sortkeys=true})
            end
            player.print(msg)
        end
    end
end

local function saveVar(var, name)
    var = var or global
    local n = name or ""
    game.write_file("module"..n..".lua", serpent.block(var, {name="global"}))
end

local function count_keys(hashmap)
    local result = 0
    for _, _ in pairs(hashmap) do
        result = result + 1
    end
    return result
end

local M = {}
M.debugDump = debugDump
M.saveVar = saveVar
M.count_keys = count_keys

return M