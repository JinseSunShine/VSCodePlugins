local LS_Signatures = require "luainspect.signatures"
local CommonUtils = require "CommonUtils"

local CustomTypes = {}
local TypeAnnotateFuncs = {}

local function GetMannualType(TypeName)
    local bSuccess, ResultOrError = pcall(require, string.format("CustomTypes.%s", TypeName))
    if bSuccess then
        return ResultOrError
    end
end

local CreateDefaultValueFromTypeInfo
local function GetDefaultValueFromUE4(TypeName, Depth)
    if "UPanelSlot*" == TypeName then -- Hack to adapt the slot problem
        TypeName = "UCanvasPanelSlot*"
    end

    if string.match(TypeName, "%*$") then
        TypeName = string.sub(TypeName, 2, -2)
    end

    local bSuccess, UE4 = pcall(require, "UE4")
    if bSuccess then
        local DefInfo = UE4.StructDefs[TypeName] or UE4.ClassDefs[TypeName]
        if DefInfo then
            return CreateDefaultValueFromTypeInfo(DefInfo, Depth)
        end

        local bSuccess, ResultOrError = pcall(require, string.format("CustomTypes.%s", TypeName))
        if bSuccess then
            return CreateDefaultValueFromTypeInfo(ResultOrError, Depth)
        end
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
    CommonUtils.SetStaticTable(DefaultValue, Depth)
    return DefaultValue
end

function CustomTypes.GetAnnotateFunc(Type)
    if TypeAnnotateFuncs[Type] then
        return TypeAnnotateFuncs[Type]
    end

    if string.match(Type, "^U[IP]_") then
        local DefaultValue = GetDefaultValueFromUE4(Type, 3)
        if DefaultValue then
            TypeAnnotateFuncs[Type] = function (VarAst)
                local VarValue = VarAst.localdefinition and VarAst.localdefinition.value
                if VarValue then
                    VarValue.pWidgetRef = DefaultValue
                    CommonUtils.SetStaticTable(VarValue.pWidgetRef, 3, true)
                    local bSuccess, ResultOrError = pcall(require, string.format("CustomTypes.%s", Type))
                    if bSuccess and ResultOrError.FieldDefs then
                        for field_name, field_info in pairs(ResultOrError.FieldDefs) do
                            if field_info.Type and string.match(field_info.Type, "^UUP_") then
                                VarValue[field_name] = {}
                            end
                        end
                    end
                end
            end
            return TypeAnnotateFuncs[Type]
        end
    end

    local AnnotateFunc = GetMannualType(Type)
    if AnnotateFunc then
        TypeAnnotateFuncs[Type] = AnnotateFunc
        return TypeAnnotateFuncs[Type]
    end

end

return CustomTypes
