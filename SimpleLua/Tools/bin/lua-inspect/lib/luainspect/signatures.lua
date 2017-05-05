local M = {}

local T = require "luainspect.types"

function M.AddSignature(func, func_params, IsStatic)
    local param_min, param_max = 1, 1
    if IsStatic then
        param_min, param_max = 0, 0
    end
    local params = {}
    local types = {}
    for _, param_prop in pairs(func_params) do
        table.insert(params, param_prop.Name)
        table.insert(types, param_prop.Type or "")
        param_max = param_max + 1
        if param_prop.Name == '...' then
            param_max = math.huge
            break
        elseif not param_prop.IsOut and not param_prop.HaveDefault then
            param_min = param_max
        end
    end
    M.value_signatures[func] = {Params=params, Types=types}
    M.argument_counts[func]={param_min, param_max}
end

-- chenliang3
_G.AnnotateType = function() end
-- hack to compat lua53
math.tointeger = function() return 1 end
table.unpack = function() end
-- end hack to compat lua53

-- signatures of known globals
M.global_signatures = {
    assert = {Params = { "v", "message" }},
    collectgarbage = {Params = { "opt", "arg" }},
    dofile = {Params = { "filename" }},
    error = {Params = { "message", "level" }},
    _G = "(table)",
    getfenv = {Params = { "f" }},
    getmetatable = {Params = { "object" }},
    ipairs = {Params = { "t" }},
    load = {Params = { "func", "chunkname" }},
    loadfile = {Params = { "filename" }},
    loadstring = {Params = { "string", "chunkname" }},
    next = {Params = { "table", "index" }},
    pairs = {Params = { "t" }},
    pcall = {Params = { "f", "arg1", "..." }},
    print = {Params = { "..." }},
    rawequal = {Params = { "v1", "v2" }},
    rawget = {Params = { "table", "index" }},
    rawset = {Params = { "table", "index", "value" }},
    select = {Params = { "index", "..." }},
    setfenv = {Params = { "f", "table" }},
    setmetatable = {Params = { "table", "metatable" }},
    tonumber = {Params = { "e", "base" }},
    tostring = {Params = { "e" }},
    type = {Params = { "v" }},
    unpack = {Params = { "list", "i", "j" }},
    _VERSION = "(string)",
    xpcall = {Params = { "f", "err" , "..."}},
    module = {Params = { "name", "..." }},
    require = {Params = { "modname" }},
    coroutine = "(table) coroutine manipulation library",
    debug = "(table) debug facilities library",
    io = "(table) I/O library",
    math = "(table) math functions libary",
    os = "(table) OS facilities library",
    package = "(table) package library",
    string = "(table) string manipulation library",
    table = "(table) table manipulation library",
    AnnotateType = { Params = {"Type", "Var"}},
    ["coroutine.create"] = { Params = { "f" }},
    ["coroutine.resume"] = { Params = { "co", "val1", "..." }},
    ["coroutine.running"] = { Params = { }},
    ["coroutine.status"] = { Params = { "co" }},
    ["coroutine.wrap"] = { Params = { "f" }},
    ["coroutine.yield"] = { Params = { "..." }},
    ["debug.debug"] = { Params = { }},
    ["debug.getfenv"] = { Params = { "o" }},
    ["debug.gethook"] = { Params = { "thread" }},
    ["debug.getinfo"] = { Params = { "thread", "function", "what" }},
    ["debug.getlocal"] = { Params = { "thread", "level", "local" }},
    ["debug.getmetatable"] = { Params = { "object" }},
    ["debug.getregistry"] = { Params = { }},
    ["debug.getupvalue"] = { Params = { "func", "up" }},
    ["debug.setfenv"] = { Params = { "object", "table" }},
    ["debug.sethook"] = { Params = { "thread", "hook", "mask", "count" }},
    ["debug.setlocal"] = { Params = { "thread", "level", "local", "value" }},
    ["debug.setmetatable"] = { Params = { "object", "table" }},
    ["debug.setupvalue"] = { Params = { "func", "up", "value" }},
    ["debug.traceback"] = { Params = { "thread", "message", "level" }},
    ["io.close"] = { Params = { "file" }},
    ["io.flush"] = { Params = { }},
    ["io.input"] = { Params = { "file" }},
    ["io.lines"] = { Params = { "filename" }},
    ["io.open"] = { Params = { "filename", "mode" }},
    ["io.output"] = { Params = { "file" }},
    ["io.popen"] = { Params = { "prog", "mode" }},
    ["io.read"] = { Params = { "..." }},
    ["io.tmpfile"] = { Params = { }},
    ["io.type"] = { Params = { "obj" }},
    ["io.write"] = { Params = { "..." }},
    ["math.abs"] = { Params = { "x" }},
    ["math.acos"] = { Params = { "x" }},
    ["math.asin"] = { Params = { "x" }},
    ["math.atan"] = { Params = { "x" }},
    ["math.atan2"] = { Params = { "y", "x" }},
    ["math.ceil"] = { Params = { "x" }},
    ["math.cos"] = { Params = { "x" }},
    ["math.cosh"] = { Params = { "x" }},
    ["math.deg"] = { Params = { "x" }},
    ["math.exp"] = { Params = { "x" }},
    ["math.floor"] = { Params = { "x" }},
    ["math.fmod"] = { Params = { "x", "y" }},
    ["math.frexp"] = { Params = { "x" }},
    ["math.huge"] = "math.huge",
    ["math.ldexp"] = { Params = { "m", "e" }},
    ["math.log"] = { Params = { "x" }},
    ["math.log10"] = { Params = { "x" }},
    ["math.max"] = { Params = { "x", "..." }},
    ["math.min"] = { Params = { "x", "..." }},
    ["math.modf"] = { Params = { "x" }},
    ["math.pi"] = "math.pi",
    ["math.pow"] = { Params = { "x", "y" }},
    ["math.rad"] = { Params = { "x" }},
    ["math.tointeger"] = { Params = { "x" }},
    ["math.random"] = { Params = { "m", "n" }},
    ["math.randomseed"] = { Params = { "x" }},
    ["math.sin"] = { Params = { "x" }},
    ["math.sinh"] = { Params = { "x" }},
    ["math.sqrt"] = { Params = { "x" }},
    ["math.tan"] = { Params = { "x" }},
    ["math.tanh"] = { Params = { "x" }},
    ["os.clock"] = { Params = { }},
    ["os.date"] = { Params = { "format", "time" }},
    ["os.difftime"] = { Params = { "t2", "t1" }},
    ["os.execute"] = { Params = { "command" }},
    ["os.exit"] = { Params = { "code" }},
    ["os.getenv"] = { Params = { "varname" }},
    ["os.remove"] = { Params = { "filename" }},
    ["os.rename"] = { Params = { "oldname", "newname" }},
    ["os.setlocale"] = { Params = { "locale", "category" }},
    ["os.time"] = { Params = { "table" }},
    ["os.tmpname"] = { Params = { }},
    ["package.cpath"] = "package.cpath",
    ["package.loaded"] = "package.loaded",
    ["package.loaders"] = "package.loaders",
    ["package.loadlib"] = { Params = { "libname", "funcname" }},
    ["package.path"] = "package.path",
    ["package.preload"] = "package.preload",
    ["package.seeall"] = { Params = { "module" }},
    ["string.byte"] = { Params = { "s", "i", "j" }},
    ["string.char"] = { Params = { "..." }},
    ["string.dump"] = { Params = { "function" }},
    ["string.find"] = { Params = { "s", "pattern", "init", "plain" }},
    ["string.format"] = { Params = { "formatstring", "..." }},
    ["string.gmatch"] = { Params = { "s", "pattern" }},
    ["string.gsub"] = { Params = { "s", "pattern", "repl", "n" }},
    ["string.len"] = { Params = { "s" }},
    ["string.lower"] = { Params = { "s" }},
    ["string.match"] = { Params = { "s", "pattern", "init" }},
    ["string.rep"] = { Params = { "s", "n" }},
    ["string.reverse"] = { Params = { "s" }},
    ["string.sub"] = { Params = { "s", "i", "j" }},
    ["string.upper"] = { Params = { "s" }},
    ["table.concat"] = { Params = { "table", "sep", "i", "j" }},
    ["table.insert"] = { Params = { "table", "pos", "value" }},
    ["table.maxn"] = { Params = { "table" }},
    ["table.remove"] = { Params = { "table", "pos" }},
    ["table.sort"] = { Params = { "table", "comp" }},
    ["table.unpack"] = { Params = { "table", "i", "j" }},
}

-- utility function.  Converts e.g. name 'math.sqrt' to its value.
local function resolve_global_helper_(name)
    local o = _G
    for fieldname in name:gmatch'[^%.]+' do o = o[fieldname] end
    return o
end
local function resolve_global(name)
    local a, b = pcall(resolve_global_helper_, name)
    if a then return b else return nil, b end
end

-- Same as global_signatures but maps value (not name) to signature.
M.value_signatures = {}
local isobject = {['function']=true, ['table']=true, ['userdata']=true, ['coroutine']=true}
for name,sig in pairs(M.global_signatures) do
    local val, err = resolve_global(name)
    if isobject[type(val)] then
        M.value_signatures[val] = sig
    end
end

-- min,max argument counts.
M.argument_counts = {
    [assert] = {1,2},
    [collectgarbage] = {1,2},
    [dofile] = {1},
    [error] = {1,2},
    [getfenv or false] = {0,1},
    [getmetatable] = {1,1},
    [ipairs] = {1,1},
    [load] = {1,2},
    [loadfile] = {0,1},
    [loadstring] = {1,2},
    [next] = {1,2},
    [pairs] = {1,1},
    [pcall] = {1,math.huge},
    [print] = {0,math.huge},
    [rawequal] = {2,2},
    [rawget] = {2,2},
    [rawset] = {3,3},
    [select] = {1, math.huge},
    [setfenv or false] = {2,2},
    [setmetatable] = {2,2},
    [tonumber] = {1,2},
    [tostring] = {1},
    [_G.AnnotateType] = {2, 2},
    [type] = {1},
    [unpack] = {1,3},
    [xpcall] = {2,math.huge},
    [module] = {1,math.huge},
    [require] = {1,1},
    [coroutine.create] = {1,1},
    [coroutine.resume] = {1, math.huge},
    [coroutine.running] = {0,0},
    [coroutine.status] = {1,1},
    [coroutine.wrap] = {1,1},
    [coroutine.yield] = {0,math.huge},
    [debug.debug] = {0,0},
    [debug.getfenv or false] = {1,1},
    [debug.gethook] = {0,1},
    [debug.getinfo] = {1,3},
    [debug.getlocal] = {2,3},
    [debug.getmetatable] = {1,1},
    [debug.getregistry] = {0,0},
    [debug.getupvalue] = {2,2},
    [debug.setfenv or false] = {2,2},
    [debug.sethook] = {2,4},
    [debug.setlocal] = {3,4},
    [debug.setmetatable] = {2,2},
    [debug.setupvalue] = {3,3},
    [debug.traceback] = {0,3},
    [io.close] = {0,1},
    [io.flush] = {0,0},
    [io.input] = {0,1},
    [io.lines] = {0,1},
    [io.open] = {1,2},
    [io.output] = {0,1},
    [io.popen] = {1,2},
    [io.read] = {0,math.huge},
    [io.tmpfile] = {0},
    [io.type] = {1},
    [io.write] = {0,math.huge},
    [math.abs] = {1},
    [math.acos] = {1},
    [math.asin] = {1},
    [math.atan] = {1},
    [math.atan2] = {2,2},
    [math.ceil] = {1,1},
    [math.cos] = {1,1},
    [math.cosh] = {1,1},
    [math.deg] = {1,1},
    [math.exp] = {1,1},
    [math.floor] = {1,1},
    [math.fmod] = {2,2},
    [math.frexp] = {1,1},
    [math.ldexp] = {2,2},
    [math.log] = {1,1},
    [math.log10] = {1,1},
    [math.max] = {1,math.huge},
    [math.min] = {1,math.huge},
    [math.modf] = {1,1},
    [math.pow] = {2,2},
    [math.rad] = {1,1},
    [math.random] = {0,2},
    [math.randomseed] = {1,1},
    [math.sin] = {1,1},
    [math.sinh] = {1,1},
    [math.sqrt] = {1,1},
    [math.tan] = {1,1},
    [math.tanh] = {1,1},
    [os.clock] = {0,0},
    [os.date] = {0,2},
    [os.difftime] = {2,2},
    [os.execute] = {0,1},
    [os.exit] = {0,1},
    [os.getenv] = {1,1},
    [os.remove] = {1,1},
    [os.rename] = {2,2},
    [os.setlocale] = {1,2},
    [os.time] = {0,1},
    [os.tmpname] = {0,0},
    [package.loadlib] = {2,2},
    [package.seeall] = {1,1},
    [string.byte] = {1,3},
    [string.char] = {0,math.huge},
    [string.dump] = {1,1},
    [string.find] = {2,4},
    [string.format] = {1,math.huge},
    [string.gmatch] = {2,2},
    [string.gsub] = {3,4},
    [string.len] = {1,1},
    [string.lower] = {1,1},
    [string.match] = {2,3},
    [string.rep] = {2,2},
    [string.reverse] = {1,1},
    [string.sub] = {2,3},
    [string.upper] = {1,1},
    [table.concat] = {1,4},
    [table.insert] = {2,3},
    [table.maxn] = {1,1},
    [table.remove] = {1,2},
    [table.sort] = {1,2},
    [table.unpack] = {1,3}, -- chenliang3
    [math.tointeger] = {1,1}, -- chenliang3
    [false] = nil -- trick (relies on potentially undefined behavior)
}


-- functions with zero or nearly zero side-effects, and with deterministic results, that may be evaluated by the analyzer.
M.safe_function = {
    [require] = true,
    [rawequal] = true,
    [rawget] = true,
    [require] = true,  -- sort of
    [select] = true,
    [tonumber] = true,
    [tostring] = true,
    [type] = true,
    [unpack] = true,
    [coroutine.create] = true,
    -- [coroutine.resume]
    [coroutine.running] = true,
    [coroutine.status] = true,
    [coroutine.wrap] = true,
    --[coroutine.yield]
    -- [debug.debug]
    --[debug.getfenv] = true,
    [debug.gethook] = true,
    [debug.getinfo] = true,
    [debug.getlocal] = true,
    [debug.getmetatable] = true,
    [debug.getregistry] = true,
    [debug.getupvalue] = true,
    -- [debug.setfenv]
    -- [debug.sethook]
    -- [debug.setlocal]
    -- [debug.setmetatable]
    -- [debug.setupvalue]
    -- [debug.traceback] = true,
    [io.type] = true,
    -- skip all other io.*
    [math.abs] = true,
    [math.acos] = true,
    [math.asin] = true,
    [math.atan] = true,
    [math.atan2] = true,
    [math.ceil] = true,
    [math.cos] = true,
    [math.cosh] = true,
    [math.deg] = true,
    [math.exp] = true,
    [math.floor] = true,
    [math.fmod] = true,
    [math.frexp] = true,
    [math.ldexp] = true,
    [math.log] = true,
    [math.log10] = true,
    [math.max] = true,
    [math.min] = true,
    [math.modf] = true,
    [math.pow] = true,
    [math.rad] = true,
    --[math.random]
    --[math.randomseed]
    [math.sin] = true,
    [math.sinh] = true,
    [math.sqrt] = true,
    [math.tan] = true,
    [math.tanh] = true,
    [math.tointeger] = true,
    [os.clock] = true, -- safe but non-deterministic
    [os.date]  = true,-- safe but non-deterministic
    [os.difftime] = true,
    --[os.execute]
    --[os.exit]
    [os.getenv] = true, -- though depends on environment
    --[os.remove]
    --[os.rename]
    --[os.setlocale]
    [os.time] = true, -- safe but non-deterministic
    --[os.tmpname]
    [string.byte] = true,
    [string.char] = true,
    [string.dump] = true,
    [string.find] = true,
    [string.format] = true,
    [string.gmatch] = true,
    [string.gsub] = true,
    [string.len] = true,
    [string.lower] = true,
    [string.match] = true,
    [string.rep] = true,
    [string.reverse] = true,
    [string.sub] = true,
    [string.upper] = true,
    [table.maxn] = true,
}

M.mock_functions = {}

-- TODO:IMPROVE
local function mockfunction(func, ...)
    local inputs = {n=0}
    local outputs = {n=0}
    local isoutputs
    for i=1,select('#', ...) do
        local v = select(i, ...)
        if type(v) == 'table' then v = v[1] end
        if v == 'N' or v == 'I' then v = T.number end
        if v == '->' then
            isoutputs = true
        elseif isoutputs then
            outputs[#outputs+1] = v; outputs.n = outputs.n + 1
        else
            inputs[#inputs+1] = v; inputs.n = inputs.n + 1
        end
    end
    M.mock_functions[func] = {inputs=inputs, outputs=outputs}
end


mockfunction(type, {T.universal}, '->', {T.string})

mockfunction(math.abs, 'N', '->', {'N',0,math.huge})
mockfunction(math.acos, {'N',-1,1}, '->', {'N',0,math.pi/2})
mockfunction(math.asin, {'N',-1,1}, '->', {'N',-math.pi/2,math.pi/2})
mockfunction(math.atan, {'N',-math.huge,math.huge}, '->',
    {'N',-math.pi/2,math.pi/2})
--FIX atan2
mockfunction(math.ceil, 'N','->','I')
mockfunction(math.cos, 'N','->',{'N',-1,1})
mockfunction(math.cosh, 'N','->',{'N',1,math.huge})
mockfunction(math.deg, 'N','->','N')
mockfunction(math.exp, 'N','->',{'N',0,math.huge})
mockfunction(math.floor, 'N','->','I')
mockfunction(math.fmod, 'N','N','->','N')
mockfunction(math.frexp, 'N','->',{'N',-1,1},'->','I')
mockfunction(math.ldexp, {'N','I'},'->','N')
mockfunction(math.log, {'N',0,math.huge},'->','N')
mockfunction(math.log10, {'N',0,math.huge},'->','N')
-- function max(...) print 'NOT IMPL'end
-- function min(...) print 'NOT IMPL'end
mockfunction(math.modf, 'N','->','I',{'N',-1,1})

mockfunction(math.pow, 'N','N','->','N') -- improve?
mockfunction(math.rad, 'N','->','N')
mockfunction(math.tointeger, 'N','->','N')
-- random = function() print 'NOT IMPL' end
mockfunction(math.randomseed, 'N')
mockfunction(math.sin, 'N','->',{'N',-1,1})
mockfunction(math.sinh, 'N','->','N')
mockfunction(math.sqrt, {'N',0,math.huge},'->',{'N',0,math.huge})
mockfunction(math.tan, 'N','->','N') -- improve?
mockfunction(math.tanh, 'N','->',{'N',-1,1})


return M
