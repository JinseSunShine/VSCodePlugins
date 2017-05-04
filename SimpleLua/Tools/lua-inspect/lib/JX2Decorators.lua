local LS = require "luainspect.signatures"
local function report(s) io.stderr:write(s, "\n") end

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

local JX2Decorators = {}

local EventListDecorator = function(ast)
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
end
local LocTextDecorator = function(ast, CheckGameDefine)
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
end

local ZOrderDecorator = function(ast)
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
end

local WndDecorator = function(ast)
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

function JX2Decorators:GetTableDecorator(source)
    if string.match(source, "EventList.lua$") then
        return EventListDecorator
    elseif string.match(source, "Wnd.lua$") then
        return ZOrderDecorator
    elseif string.match(source, "ZOrder.lua$") or string.match(source, "UILevelPath.lua$") then
        return WndDecorator
    elseif string.match(source, "LocText[/\\]+LocTextETeamTarget.lua$") then
        return function(ast) LocTextDecorator(ast, true) end
    elseif string.match(source, "LocText[/\\]+LocText[%w_]+.lua$") then
        return LocTextDecorator
    end
end

local function CallDecorator(Decorator, Args, nStartIndex, ValList)
    if Decorator then
        local CallArgs = {}
        if type(Args.n) == 'number' then
            for nIndex = nStartIndex, Args.n do
                CallArgs[nIndex - (nStartIndex - 1)] = Args[nIndex]
            end
            Decorator(ValList, unpack(CallArgs))
        end
    end
end

local GlobalFunctionDecorators = {
    require = function (ValList, FileName)
        if FileName == "UI" and ValList and ValList[1] then
            local JX2Data = require "JX2Data"
            for nID, WndName in pairs(JX2Data:Get("WndID")) do
                ValList[1][WndName] = nID
            end
            for nID, PrefabName in pairs(JX2Data:Get("PrefabID")) do
                ValList[1][PrefabName] = nID
            end
        end
    end
}

function JX2Decorators:DecorateGlobalFunction(FuncName, Args, ValList)
    CallDecorator(GlobalFunctionDecorators[FuncName], Args, 1, ValList)
end

local function WndDecorator(ValList, WndID)
    if type(WndID) == 'number' and ValList and ValList.n == 1 then
        local WndIDMap = require "JX2Data":Get("WndID")
        local szScript = WndIDMap[WndID]
        if szScript then
            szScript = "UI" .. szScript
            if SwordGame_LuaPath[szScript] then
                local LI = require "luainspect.init"
                local Val = LI.require_inspect(szScript, report, SwordGame_LuaPath[szScript]:gsub('[^\\/]+$', ''))
                if Val then
                    ValList[1] = Val
                end
            end
        end
    end
end

local InvokeDecorators = {
    GetWnd = WndDecorator,
    OpenWnd = WndDecorator,
}

function JX2Decorators:DecorateInvokeFunction(FuncName, Args, ValList)
    CallDecorator(InvokeDecorators[FuncName], Args, 2, ValList)
end

return JX2Decorators