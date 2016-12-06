local UE4 = require "UE4"
local json = require "json"
require "metalua.table2"

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

local func_index = {}
for class, class_def in pairs(UE4.ClassDefs) do
    for func_name, func_prop in pairs(class_def.FuncDefs) do
        if not func_prop.IsStatic then
            if not func_index[func_name] then
                func_index[func_name] = {}
            end
            local param_min, param_max = 0, 0
            local params = {}
            local types = {}
            for _, param_prop in pairs(func_prop.Params) do
                table.insert(params, param_prop.Name)
                table.insert(types, param_prop.Type)
                param_max = param_max + 1
                if not param_prop.IsRef and not param_prop.HaveDefault then
                    param_min = param_max
                end
            end
            table.insert(func_index[func_name], {ClassName=class, Params=params, Types=types, Min=param_min, Max=param_max})
        end
    end
end
writefile("../out/CandidateFuncs.json", json.encode(func_index))
