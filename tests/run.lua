-- From the mod root: lua tests/run.lua (Lua 5.2).
local suites = {
    "gui_sections", "gui_sorting", "research_strategies", "research_targets",
    "refactor_regressions", "dynamic_packs", "pack_defaults"
}
for _, name in ipairs(suites) do
    local environment = setmetatable({}, {__index = _G})
    environment._G = environment
    environment.package = {loaded = {}}
    environment.require = function(module)
        local loaded = environment.package.loaded
        if loaded[module] ~= nil then return loaded[module] end
        local path = module:gsub("%.", "/") .. ".lua"
        local chunk = assert(loadfile(path, "t", environment))
        local result = chunk()
        if result == nil then result = true end
        loaded[module] = result
        return result
    end
    assert(loadfile("tests/" .. name .. ".lua", "t", environment))()
end
print("All " .. #suites .. " suites passed")
