return {
    Debug = {
        Value = false
    },
    GWithEditor = {
        Value = false
    },
    GWorld = {
        Value = {}
    },
    printscreen = {
        Value = function() end,
        Params = {
            {Name="...",Type="Any",IsRef=false,HaveDefault=false},
        },
    },
    spawnactor = {
        Value = function() end,
        Params = {
            {Name="World",Type="UWorld*",IsRef=false,HaveDefault=false},
            {Name="Class",Type="UClass*",IsRef=false,HaveDefault=false},
        },
    },
    class = {
        Value = function() end,
        Params = {
            {Name="Object",Type="Any",IsRef=false,HaveDefault=false},
            {Name="SuperClass",Type="UClass*",IsRef=false,HaveDefault=false},
        },
    },
    log = {
        Value = function() end,
        Params = {
            {Name="...",Type="Any",IsRef=false,HaveDefault=false},
        },
    },
    logwarning = {
        Value = function() end,
        Params = {
            {Name="...",Type="Any",IsRef=false,HaveDefault=false},
        },
    },
    logerror = {
        Value = function() end,
        Params = {
            {Name="...",Type="Any",IsRef=false,HaveDefault=false},
        },
    },
    logdebug = {
        Value = function() end,
        Params = {
            {Name="...",Type="Any",IsRef=false,HaveDefault=false},
        },
    },
    LoadBlueprintClass = {
        Value = function() end,
        Params = {
            {Name="AssetPath",Type="Path",IsRef=false,HaveDefault=false},
        },
    },
    createdelegate = {
        Value = function() end,
        Params = {
            {Name="Delegate",Type="DelegateProperty",IsRef=false,HaveDefault=false},
            {Name="func",Type="function",IsRef=false,HaveDefault=false},
        },
    },
    getcontentdir = {
        Value = function() end
    },
    luaholder = {
        Value = function() end,
        Params = {
            {Name="Object",Type="Any",IsRef=false,HaveDefault=false},
        },
    },
    exposetable = {
        Value = function() end,
        Params = {
            {Name="tab",Type="Table",IsRef=false,HaveDefault=false},
        },
    },
    taketableref = {
        Value = function() end,
        Params = {
            {Name="tab",Type="Table",IsRef=false,HaveDefault=false},
        },
    },
    uetype = {
        Value = function() end,
        Params = {
            {Name="Var",Type="Any",IsRef=false,HaveDefault=false},
        },
    },
}