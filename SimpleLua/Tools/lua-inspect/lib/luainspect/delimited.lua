-- luainspect.delimited - Convert AST to delimited text using LuaInspect info embedded.
--

--! require 'luainspect.typecheck' (context)

local M = {}

local LI = require"luainspect.init"
local LA = require "luainspect.ast"
local T = require "luainspect.types"
local LS = require "luainspect.signatures"

local function escape(s)
    s = s:gsub('\n', '\\n') -- escape new lines
    -- s = s:gsub('"', '""') -- escape double quotes
    -- if s:match'[\r\n]' then s = '"'..s..'"' end -- escape with double quotes
    return s
end


local function describe(token, tokenlist, src, ID_Value_Map)
    if token then
        local ast = token.ast
        if token.tag == 'Id' or ast.isfield then
            local line = {}
            if ast.id then line.id = ast.id end
            line.Attributes = LI.get_var_attributes(ast)
            line.ValueDesc = LI.get_value_details(ast, tokenlist, src, ID_Value_Map)
            return line
        elseif token.tag == 'String' and token.parent and token.parent.tag == 'Call' and token.parent[1].value == require then
            local filename = token.value
            if SwordGame_LuaPath[filename] then
                return {RequirePath = SwordGame_LuaPath[filename]}
            elseif T.iserror[token.parent.value] then
                return {RequirePath = false}
            end
        end
    end
end


function M.ast_to_delimited(ast, src, tokenlist)
    local fmt_tokens = {}

    local require_candidates = {}
    for k, _ in pairs(SwordGame_LuaPath) do
        table.insert(require_candidates, k)
    end
    local json = require "json"
    fmt_tokens[#fmt_tokens + 1] = json.encode({RequireCandidates = require_candidates})

    local global_completions = {}
    for k, v in pairs(LI.GetGlobalsFromUE4()) do
        if type(v) == 'table' then
            local field_names = {}
            for name, _ in pairs(v) do
                table.insert( field_names, name )
            end
            table.insert(global_completions, {Name = k, Fields = field_names})
        end
    end
    fmt_tokens[#fmt_tokens + 1] = json.encode({GlobalCompletions = global_completions})

    local global_signatures = {}
    for name, sig in pairs(LS.global_signatures) do
        if type(sig) == 'table' then
            table.insert(global_signatures, {Name=name, Signature=sig})
        end
    end
    fmt_tokens[#fmt_tokens + 1] = json.encode({GlobalSignatures = global_signatures})

    local ID_Value_Map = {}
    for _, token in ipairs(tokenlist) do
        local fline_1, fcol_1 = LA.pos_to_linecol(token.fpos, src)
        local fline_2, fcol_2 = LA.pos_to_linecol(token.lpos, src)
        local desc = describe(token, tokenlist, src, ID_Value_Map)
        if desc then
            desc.Line1 = fline_1
            desc.Col1 = fcol_1
            desc.Line2 = fline_2
            desc.Col2 = fcol_2
            fmt_tokens[#fmt_tokens + 1] = json.encode(desc)
        end
    end

    local ID_Value_Array = {}
    for ID, Value in pairs(ID_Value_Map) do
        table.insert(ID_Value_Array, {ID=ID, Value=Value})
    end
    fmt_tokens[#fmt_tokens + 1] = json.encode({ID_Value_Map = ID_Value_Array})

    local result = table.concat(fmt_tokens, "\n")
    if result:len() > math.pow(2, 23) then
        result = json.encode({ErrorType="file", line = 1, colnum = 1, msg = "Too big a file"})
    end
    return result
end

return M
