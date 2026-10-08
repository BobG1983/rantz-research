local fixtures = {}

function fixtures.element(spec, parent)
    local node = {parent = parent, children = {}, style = {}, valid = true,
        visible = spec.visible ~= false, enabled = spec.enabled ~= false,
        tags = spec.tags or {}, text = spec.text or ""}
    for name, value in pairs(spec) do if name ~= "style" then node[name] = value end end
    node.add = function(child_spec)
        assert(node.valid)
        local child = fixtures.element(child_spec, node)
        assert(not child.name or node[child.name] == nil, "Duplicate GUI name")
        node.children[#node.children + 1] = child
        if child.name then node[child.name] = child end
        return child
    end
    node.get_index_in_parent = function()
        for i, child in ipairs(parent.children) do if child == node then return i end end
    end
    node.swap_children = function(a, b)
        assert(node.children[a] and node.children[b])
        node.children[a], node.children[b] = node.children[b], node.children[a]
    end
    node.clear = function()
        while #node.children > 0 do node.children[#node.children].destroy() end
    end
    node.destroy = function()
        node.clear()
        if parent then
            local index = node.get_index_in_parent()
            if index then table.remove(parent.children, index) end
            if node.name then parent[node.name] = nil end
        end
        node.valid = false
    end
    return node
end

function fixtures.force(properties)
    local current_queue = properties.research_queue or {}
    properties.research_queue = nil
    properties.current_research = nil
    properties.queue_writes = 0
    properties.players = properties.players or {}
    return setmetatable(properties, {
        __index = function(_, name)
            if name == "current_research" then return current_queue[1] end
            if name == "research_queue" then
                local result = {}
                for i, tech in ipairs(current_queue) do result[i] = tech end
                return result
            end
        end,
        __newindex = function(force, name, value)
            if name ~= "research_queue" then rawset(force, name, value); return end
            assert(#value <= 7, "Factorio queue capacity exceeded")
            local resolved = {}
            for i, entry in ipairs(value) do
                local tech = type(entry) == "string" and force.technologies[entry] or entry
                assert(tech and not tech.researched, "Invalid queued technology")
                resolved[i] = tech
            end
            current_queue = resolved
            force.queue_writes = force.queue_writes + 1
        end
    })
end

return fixtures
