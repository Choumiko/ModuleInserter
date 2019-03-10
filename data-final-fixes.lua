local copyPrototype = require "__ModuleInserter__/lib"

local function checkProductivity()
    for _, beacon in pairs(data.raw.beacon) do
        for _, effect in pairs(beacon.allowed_effects) do
            if effect == "productivity" then
                return true
            end
        end
    end
end

if checkProductivity() then
    local metaBeacon = copyPrototype("selection-tool","module-inserter","module-inserter-beacon")
    metaBeacon.flags = metaBeacon.flags or {}
    table.insert(metaBeacon.flags, "hidden")
    data:extend({metaBeacon})
end