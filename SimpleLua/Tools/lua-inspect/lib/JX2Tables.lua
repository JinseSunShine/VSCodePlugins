local LS = require "luainspect.signatures"
local EventTemplate =
{
    AddListener = {{Name = "obj"}, {Name = "func_name"}},
    DelListener = {{Name = "obj"}},
    Dispatch = {{Name = "..."}},
    BindDataFunction = {{Name = "func_get_data"}, {Name = "interval", HaveDefault=true}, {Name = "copy_depth", HaveDefault=true}},
    BindDataField = {{Name = "obj"}, {Name = "field_name"}, {Name = "interval", HaveDefault=true}, {Name = "copy_depth", HaveDefault=true}},
    BindDataMethod = {{Name = "obj"}, {Name = "method_name"}, {Name = "interval", HaveDefault=true}, {Name = "copy_depth", HaveDefault=true}},
    UnBindData = {},
}

local EventTemplateValue = {}
for FuncName, Params in pairs(EventTemplate) do
    local func = function() end
    EventTemplateValue[FuncName] = func
    LS.AddSignature(func, Params)
end

local JX2Tables = {
    EventList = function(ast)
        local Result = {}
        for _,east in pairs(ast) do
            if type(east) == 'table' and east.tag == 'Pair' then
                local k, v = east[1].value, east[2].value
                if type(k) == "string" and type(v) == "table" and #v == 0 then
                    if Result[k] then
                        east[1].JX2Error = "Duplicate Events"
                    else
                        Result[k] = EventTemplateValue
                    end
                end
            end
        end
        ast.value = Result
    end,
    LocText = function(ast, CheckGameDefine)
        local ExistKey = {}
        local ExistText = {}
        local Result = {}
        
        local GameDefine
        if CheckGameDefine then
            local bSuccess, ValueOrErr = pcall(require, "GameDefine")
            if bSuccess then
                GameDefine = ValueOrErr
            end
        end

        for nIndex, east in ipairs(ast) do
            if type(east) == 'table' and east.tag ~= 'Pair' then
                local key = east[4].value -- Param2 of NSLOCTEXT
                local text = east[5].value -- Param3 of NSLOCTEXT
                if key and type(key) == "string" and text and type(text) == "string" then
                    local JX2Error
                    if ExistKey[key] then
                        JX2Error = "Duplicate Key"
                    elseif ExistText[text] then
                        JX2Error = "Duplicate Text"
                    elseif GameDefine then
                        local KeyValue = GameDefine[key]
                        if not KeyValue then
                            JX2Error = string.format("%s is not defined", key)
                        elseif KeyValue ~= (nIndex - 1) then
                            JX2Error = string.format("%s is defined as the %d enum", key, KeyValue+1)
                        end
                    end

                    if JX2Error then
                        east[2].JX2Error = JX2Error
                    else
                        Result[key] = {}
                    end
                    ExistKey[key] = true
                    ExistText[text] = true
                end
            end
        end
        ast.value = Result
    end,
    CheckZOrder = function(ast)
        local bSuccess, ZOrder = pcall(require, "ZOrder")
        if bSuccess then
            for _, east in ipairs(ast) do
                if type(east) == 'table' and east.tag == 'Pair' then
                    local k = east[1].value
                    if type(k) == "string" and not ZOrder[k] then
                        east[1].JX2Error = "Assign a ZOrder to this wnd"
                    end
                end
            end
        end
    end,
    CheckWnd = function(ast)
        local bSuccess, Wnd = pcall(require, "Wnd")
        if bSuccess then
            local ExistKeys = {}
            for _, east in ipairs(ast) do
                if type(east) == 'table' and east.tag == 'Pair' then
                    local k = east[1].value
                    if type(k) == "string" and not Wnd[k] then
                        east[1].JX2Error = "This wnd didn't exist"
                    elseif ExistKeys[k] then
                        east[1].JX2Error = "Duplicate Name"
                    end
                    ExistKeys[k] = true
                end
            end
        end
    end
}

return JX2Tables