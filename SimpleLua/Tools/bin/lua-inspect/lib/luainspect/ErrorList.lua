-- luainspect.delimited - Convert AST to delimited text using LuaInspect info embedded.
--

--! require 'luainspect.typecheck' (context)

local ErrorList = {}
local json = require "json"
local LI = require"luainspect.init"
local LA = require "luainspect.ast"
local Types = require "luainspect.types"
local LS = require "luainspect.signatures"

local function HaveAttr(AttrList, Attr)
    for _, Item in pairs(AttrList) do
        if Attr == Item then
            return true
        end
    end
    return false
end

local function describe(token, tokenlist, src)
    if token then
        if token.tag == 'String' and token.parent and token.parent.tag == 'Call' and token.parent[1].value == require then
            local filename = token.value
            if Types.iserror[token.parent.value] then
                return {ValueDesc = string.format("%s didn't exist", filename)}
            end
        end

        local ast = token.ast
        local Attributes = LI.get_var_attributes(ast)
        if HaveAttr(Attributes, "unknown") and HaveAttr(Attributes, "global") then
            return {ValueDesc = "unknown global"}
        elseif ast.CustormError then
            return {ValueDesc = ast.CustormError}
        end

        local vast = ast.seevalue or ast
        if Types.IsVSCodeError[vast.value] then
            return {ValueDesc = tostring(vast.value)}
        end
    end
end


function ErrorList.ast_to_ErrorList(ast, src, tokenlist)
    local fmt_tokens = {}
    for _, token in ipairs(tokenlist) do
        local fline_1, fcol_1 = LA.pos_to_linecol(token.fpos, src)
        local fline_2, fcol_2 = LA.pos_to_linecol(token.lpos, src)
        local desc = describe(token, tokenlist, src)
        if desc and string.match(token[1], "^[_%w]+$") then
            desc.Line = fline_1
            desc.Token = token[1]
            fmt_tokens[#fmt_tokens + 1] = desc
        end
    end

    return fmt_tokens
end

return ErrorList
