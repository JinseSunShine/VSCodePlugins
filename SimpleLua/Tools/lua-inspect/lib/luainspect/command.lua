#!/usr/bin/env lua

-- luainspect.command - LuaInspect command-line interface.
-- This file can be invoked from the command line

package.path = package.path .. ';metalualib/?.lua'
package.path = package.path .. ';lib/?.lua'

require("mobdebug").start(nil, require("mobdebug").port + 1)

local function loadfile(filename)
    local fh = assert(io.open(filename, 'r'))
    local data = fh:read'*a'
    fh:close()
    return data
end

local function writefile(filename, output)
    local fh = assert(io.open(filename, 'wb'))
    fh:write(output)
    fh:close()
end

local function fail(err)
    io.stderr:write(err, '\n')
    os.exit(1)
end

SwordGame_Home = os.getenv("SWORDGAME_HOME")
SwordGame_LuaPath = {}
SwordGame_Wnds = {}
SwordGame_Prefabs = {}
if SwordGame_Home then
    SwordGame_Home = string.gsub(SwordGame_Home, '\\\\', '/')
    SwordGame_Home = string.gsub(SwordGame_Home, '\\', '/')
    local lfs = require"lfs"

    function GatherDir (current_dir, table_dirs)
        local bHaveLuaScript = false
        for item in lfs.dir(current_dir) do
            if item ~= "." and item ~= ".." then
                local item_full = current_dir..'/'..item
                local attr = lfs.attributes (item_full)
                assert (type(attr) == "table")
                if attr.mode == "directory" then
                    GatherDir(item_full, table_dirs)
                elseif attr.mode == "file" and item:match("%.lua$") then
                    bHaveLuaScript = true
                    SwordGame_LuaPath[item:sub(0, -5)] = item_full
                end
            end
        end
        if bHaveLuaScript then
            table.insert(table_dirs, current_dir .. "\\?.lua")
        end
    end
    local all_dirs = {}
    GatherDir(SwordGame_Home .. "/Scripts", all_dirs)
    package.path = package.path..';'..table.concat(all_dirs, ";")

    local json = require"json"
    local wnd_json, err_ = loadfile(SwordGame_Home .. "/Content/GameData/Client/UI/Wnd.json")
    if wnd_json then
        local wnds = json.decode(wnd_json)
        for _, wnd_tab in pairs(wnds[1]) do
            SwordGame_Wnds[wnd_tab.nID] = wnd_tab
        end
    end

    local prefab_json, err_ = loadfile(SwordGame_Home .. "/Content/GameData/Client/UI/Prefab.json")
    if prefab_json then
        local prefabs = json.decode(prefab_json)
        for _, prefab_tab in pairs(prefabs[1]) do
            SwordGame_Prefabs[prefab_tab.nID] = prefab_tab
        end
    end
end

local LA = require "luainspect.ast"
local LI = require "luainspect.init"

-- Warning/status reporting function.
-- CATEGORY: reporting + AST
local function report(s) io.stderr:write(s, "\n") end

-- parse flags
local function getopt(c)
    if arg[1] then
        local x = arg[1]:match('^%-'..c..'(.*)')
        if x then table.remove(arg, 1)
            if x == '' and arg[1] then x = arg[1]; table.remove(arg, 1) end
            return x
        end
    end
end
local fmt = getopt 'f' or 'delimited'
local ast_to_text =
    (fmt == 'delimited') and require 'luainspect.delimited'.ast_to_delimited or
    (fmt == 'html') and require 'luainspect.html'.ast_to_html or
    fail('invalid format specified, -f'..fmt)
local libpath = getopt 'l' or '.'
local outpath = getopt 'o' or '-'

local path = unpack(arg)
if not path then
    fail[[
inspect.lua [options] <path.lua>
  -f {delimited|html} - output format
  -l path   path to library sources (e.g. luainspect.css/js), for html only
  -o path   output path (defaults to standard output (-)
]]
end

local src = loadfile(path)
if src:len() == 0 then
    os.exit(0)
end

local ast, err, linenum, colnum, linenum2 = LA.ast_from_string(src, path)

--require "metalua.table2"; table.print(ast, 'hash', 50)
if ast then
    local tokenlist = LA.ast_to_tokenlist(ast, src)

    LI.inspect(ast, tokenlist, src, report, 1)
    LI.inspect(ast, tokenlist, src, report, 2)
    LI.mark_related_keywords(ast, tokenlist, src)

    local output = ast_to_text(ast, src, tokenlist, {libpath=libpath})

    if outpath == '-' then
        io.stdout:write(output)
    else
        writefile(outpath, output)
    end
else
    local json = require "json"
    local error_json = json.encode({ErrorType="syntax", line = linenum, colnum = colnum, msg = err})
    io.stderr:write(error_json)
    os.exit(1)
end



