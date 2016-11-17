local UE4 = require "UE4"
local json = require "json"
local Snippets = {}
for k, _ in pairs(UE4.Globals) do
    Snippets[k] = {
        prefix= k,
        body= k,
        description= k,
        scope= "source.lua"
    }
end
for k, _ in pairs(UE4.EnumDefs) do
    Snippets[k] = {
        prefix= k,
        body= k,
        description= k,
        scope= "source.lua"
    }
end
for class, class_def in pairs(UE4.ClassDefs) do
    local bHaveStatic = false
    for func_name, func_prop in pairs(class_def.FuncDefs) do
        if func_prop.IsStatic then
            bHaveStatic = true
            break
        end
    end
    if bHaveStatic then
        Snippets[class] = {
            prefix= class,
            body= class,
            description= class,
            scope= "source.lua"
        }
    end
end

local function writefile(filename, output)
    local fh = assert(io.open(filename, 'wb'))
    fh:write(output)
    fh:close()
end
writefile("../snippets/UE4Snippets.json", json.encode(Snippets))