local LS_Types = require "luainspect.types"
local LS_Signatures = require "luainspect.signatures"
local CustomTypes = {}

local function SetStaticTable(TabVar, Depth)
    local MetaTable = getmetatable(TabVar)
    if not MetaTable then
        MetaTable = {}
    end
    MetaTable.__index = function(Table, Key)
        if Key ~= nil then
            return LS_Types.VSCodeError("Non Exist Key")
        end
    end
    MetaTable.__newindex = function(Table, Key)
        if Key ~= nil then
            Table[Key] = LS_Types.VSCodeError("Non Exist Key")
        end
    end
    setmetatable(TabVar, MetaTable)

    if Depth > 0 then
        for _, v in pairs(TabVar) do
            if type(v) == 'table' then
                SetStaticTable(v, Depth - 1)
            end
        end
    end
end

local TypeAnnotateFuncs = {}

TypeAnnotateFuncs.Config = function (VarAst)
    local VarValue = VarAst.localdefinition and VarAst.localdefinition.value
    SetStaticTable(VarValue, 3)
end

local CreateDefaultValueFromTypeInfo
local function GetDefaultValueFromUE4(TypeName, Depth)
    if string.match(TypeName, "%*$") then
        TypeName = string.sub(TypeName, 2, -2)
    end

    local UE4 = require "UE4"
    local DefInfo = UE4.StructDefs[TypeName] or UE4.ClassDefs[TypeName]
    if DefInfo then
        return CreateDefaultValueFromTypeInfo(DefInfo, Depth)
    end

    local bSuccess, ResultOrError = pcall(require, string.format("CustomTypes.%s", TypeName))
    if bSuccess then
        return CreateDefaultValueFromTypeInfo(ResultOrError, Depth)
    end
end

CreateDefaultValueFromTypeInfo = function (Info, Depth)
    local DefaultValue = {}
    if Info.FuncDefs then
        for func_name, func_info in pairs(Info.FuncDefs) do
            DefaultValue[func_name] = function() end
            LS_Signatures.AddSignature(DefaultValue[func_name], func_info.Params, func_info.Static)
        end
    end
    if Info.FieldDefs then
        for field_name, field_info in pairs(Info.FieldDefs) do
            if field_info.Params then
                local ParamsDescs = {}
                for _, ParamInfo in pairs(field_info.Params) do
                    table.insert(ParamsDescs, string.format("%s %s", ParamInfo.Type, ParamInfo.Name))
                end
                DefaultValue[field_name] = string.format("Event %s(%s)", field_name, table.concat(ParamsDescs, ","))
            else
                local FieldDefaultValue
                if Depth > 0 then
                    FieldDefaultValue = GetDefaultValueFromUE4(field_info.Type, Depth-1)
                end

                if FieldDefaultValue then
                    DefaultValue[field_name] = FieldDefaultValue
                else
                    DefaultValue[field_name] = field_info.Type
                end
            end
        end
    end
    SetStaticTable(DefaultValue, Depth)
    return DefaultValue
end

function CustomTypes.GetAnnotateFunc(Type)
    if not TypeAnnotateFuncs[Type] then
        local DefaultValue = GetDefaultValueFromUE4(Type, 3)
        if DefaultValue then
            TypeAnnotateFuncs[Type] = function (VarAst)
                local VarValue = VarAst.localdefinition and VarAst.localdefinition.value
                if VarValue then
                    VarValue.pWidgetRef = DefaultValue
                    SetStaticTable(VarValue.pWidgetRef, 3)
                end
            end
        end
    end

    return TypeAnnotateFuncs[Type]
end

return CustomTypes