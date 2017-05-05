local JX2Data = {}

local DataCache = {}
function JX2Data:Get(Name)
    if DataCache[Name] then
        return DataCache[Name]
    end

    local Result = {}
    if Name == "WndID" then
        local bSuccess, Wnd = pcall(require, "Wnd")
        if bSuccess then
            local nID = 0
            for WndName, _ in pairs(Wnd) do
                Result[nID] = WndName:sub(4)
                nID = nID + 1
            end
        end
    elseif Name == "PrefabID" then
        local bSuccess, Prefab = pcall(require, "Prefab")
        if bSuccess then
            local nID = 0
            for PrefabName, _ in pairs(Prefab) do
                Result[nID] = PrefabName:sub(2)
                nID = nID + 1
            end
        end
    end
    DataCache[Name] = Result
    return Result
end
return JX2Data