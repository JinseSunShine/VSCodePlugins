local CommonUtils = require "CommonUtils"

return function (VarAst)
    local VarValue = VarAst.localdefinition and VarAst.localdefinition.value
    CommonUtils.SetStaticTable(VarValue, 3)
end