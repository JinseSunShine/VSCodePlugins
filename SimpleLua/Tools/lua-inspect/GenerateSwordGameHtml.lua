SwordGame_Home = os.getenv("SWORDGAME_HOME")
if SwordGame_Home then
    local lfs = require"lfs"
    local htmls_dir = lfs.currentdir() .. '/' .. "htmls"
    local attr = lfs.attributes (htmls_dir)
    if attr and attr.mode == "directory" then
        lfs.rmdir(htmls_dir)
    end
    lfs.mkdir(htmls_dir)
    lfs.chdir(htmls_dir)
    local Map_lua_html = {}
    function GenerateDir (current_dir)
        for item in lfs.dir(current_dir) do
            if item ~= "." and item ~= ".." then
                local item_full = current_dir..'/'..item
                local attr = lfs.attributes (item_full)
                assert (type(attr) == "table")
                if attr.mode == "directory" then
                    lfs.mkdir(item)
                    lfs.chdir(item)
                    GenerateDir(item_full)
                    lfs.chdir("..")
                elseif attr.mode == "file" and item:match("%.lua$") then
                    Map_lua_html[item_full] = string.format("%s/%s.html", lfs.currentdir(), item:sub(0, -5))
                end
            end
        end
    end
    GenerateDir(SwordGame_Home .. "/Scripts/Client/UI/Prefab/")
    lfs.chdir("..")
    for lua_path, html_path in pairs(Map_lua_html) do
        os.execute(string.format("lua luainspect -fhtml -l%s/htmllib %s > %s", lfs.currentdir(), lua_path, html_path))
    end
end
