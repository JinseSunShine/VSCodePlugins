local LS_Types = require "luainspect.types"

local CommonUtils = {}
function CommonUtils.SetStaticTable(TabVar, Depth)
    local MetaTable = getmetatable(TabVar)
    if not MetaTable then
        MetaTable = {}
    end
    MetaTable.__index = function(Table, Key)
        if type(Key) == "string" and Key ~= "unknown" then
            return LS_Types.VSCodeError("Non Exist Key")
        end
    end
    MetaTable.__newindex = function(Table, Key)
        if type(Key) == "string" and Key ~= "unknown" then
            Table[Key] = LS_Types.VSCodeError("Non Exist Key")
        end
    end
    setmetatable(TabVar, MetaTable)

    if Depth > 0 then
        for _, v in pairs(TabVar) do
            if type(v) == 'table' then
                CommonUtils.SetStaticTable(v, Depth - 1)
            end
        end
    end
end

return CommonUtils