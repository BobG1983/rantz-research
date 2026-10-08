local monitor = {}
monitor.interval = 60

function monitor.valid_lab(lab, force)
    return lab and lab.valid and lab.type == "lab" and lab.force == force
end

function monitor.has_lab(config)
    local lab = config.monitored_lab
    return lab ~= nil and lab.valid and lab.type == "lab"
end

function monitor.is_allowed(config, name)
    if config.dynamic_packs and config.dynamic_packs[name] then
        return monitor.has_lab(config) and config.dynamic_available and config.dynamic_available[name] == true
    end
    return config.allowed_ingredients[name] == true
end

-- One inventory per monitored force; no entity searches and no quality filtering.
function monitor.sample(force, config, tick)
    config.dynamic_available = config.dynamic_available or {}
    config.pack_empty_since = config.pack_empty_since or {}
    local changed = false
    local lab = config.monitored_lab
    if lab and not monitor.valid_lab(lab, force) then
        config.monitored_lab = nil
        changed = true
    end
    local inventory = config.monitored_lab and config.monitored_lab.get_inventory(defines.inventory.lab_input)
    local contents = {}
    if inventory then
        for _, item in ipairs(inventory.get_contents()) do
            if item.count > 0 then contents[item.name] = true end
        end
    end
    for name, dynamic in pairs(config.dynamic_packs or {}) do
        if dynamic then
            local before = config.dynamic_available[name] == true
            local available = before
            if not inventory then
                available = false
                config.pack_empty_since[name] = nil
            elseif contents[name] then
                available = true
                config.pack_empty_since[name] = nil
            else
                config.pack_empty_since[name] = config.pack_empty_since[name] or tick
                if tick - config.pack_empty_since[name] >= (config.pack_grace_seconds or 60) * 60 then available = false end
            end
            config.dynamic_available[name] = available
            if available ~= before then changed = true end
        end
    end
    return changed
end

return monitor
