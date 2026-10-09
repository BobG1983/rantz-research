local configuration = require("scripts.research.configuration")
local selection = require("scripts.research.selection")
local queue = require("scripts.research.queue")
local technology = require("scripts.research.technology")
local monitor = require("scripts.research.monitor")

local research = {}
local change_listener
local boolean_settings = {
    enabled = true, prioritized_only = true, allow_switching = true,
    deprioritize_infinite_tech = true
}
local strategies = {fast = true, slow = true, cheap = true, expensive = true, balanced = true, random = true}

research.get_config = configuration.get
research.ensure_config = configuration.ensure
research.initialize = configuration.initialize

function research.set_change_listener(listener)
    change_listener = listener
end

function research.start_next_research(force, override_throttle)
    local config = configuration.ensure(force)
    if not config.enabled then return end
    queue.remove_capped(force, config)
    queue.yield_to_player(force, config)
    if force.current_research and not config.allow_switching then return end
    if not override_throttle and config.last_research_finish_tick == game.tick then return end
    -- Retain the historical saved key; this is a per-force scheduling throttle.
    config.last_research_finish_tick = game.tick
    queue.promote(force, selection.choose(force, config), config)
end

local function changed(force)
    research.start_next_research(force, true)
    if change_listener then change_listener(force) end
end

function research.set_setting(force, name, value)
    if not force or not boolean_settings[name] or type(value) ~= "boolean" then return false end
    configuration.ensure(force)[name] = value
    changed(force)
    return true
end

function research.set_rantz_research(force, value) return research.set_setting(force, "enabled", value) end
function research.set_queued_only(force, value) return research.set_setting(force, "prioritized_only", value) end
function research.set_allow_switching(force, value) return research.set_setting(force, "allow_switching", value) end
function research.set_deprioritize_infinite_tech(force, value) return research.set_setting(force, "deprioritize_infinite_tech", value) end

function research.set_strategy(force, strategy)
    if not force or not strategies[strategy] then return false end
    configuration.ensure(force).research_strategy = strategy
    changed(force)
    return true
end

function research.set_pack_mode(force, name, mode)
    if not force or (mode ~= "on" and mode ~= "off" and mode ~= "dynamic") then return false end
    local config = configuration.ensure(force)
    if config.allowed_ingredients[name] == nil then return false end
    if mode == "dynamic" and not monitor.valid_lab(config.monitored_lab, force) then return false end
    if config.pack_defaults then config.pack_defaults[name] = nil end
    config.dynamic_packs[name] = mode == "dynamic" or nil
    config.dynamic_available[name] = nil
    config.pack_empty_since[name] = nil
    if mode ~= "dynamic" then config.allowed_ingredients[name] = mode == "on" end
    monitor.sample(force, config, game.tick)
    changed(force)
    return true
end

function research.set_pack_allowed(force, name, value)
    if type(value) ~= "boolean" then return false end
    return research.set_pack_mode(force, name, value and "on" or "off")
end

function research.set_monitored_lab(force, lab)
    if not force or (lab and not monitor.valid_lab(lab, force)) then return false end
    local config = configuration.ensure(force)
    config.monitored_lab = lab
    config.dynamic_available = {}
    config.pack_empty_since = {}
    monitor.sample(force, config, game.tick)
    config.last_pack_check_tick = game.tick
    changed(force)
    return true
end

function research.on_monitored_lab_removed(event)
    local lab = event and event.entity
    if not lab then return end
    local force = lab.force
    if not force then return end
    local config = configuration.get(force)
    if not config or config.monitored_lab ~= lab then return end
    config.monitored_lab = nil
    config.dynamic_available = {}
    config.pack_empty_since = {}
    config.last_pack_check_tick = nil
    changed(force)
end

function research.set_monitor_timing(force, name, value)
    if not force or (name ~= "pack_check_seconds" and name ~= "pack_grace_seconds") then return false end
    local minimum = name == "pack_check_seconds" and 1 or 0
    if type(value) ~= "number" or value ~= value or value < minimum or value > 3600
        or value ~= math.floor(value) then return false end
    local config = configuration.ensure(force)
    config[name] = value
    config.last_pack_check_tick = nil
    if change_listener then change_listener(force) end
    return true
end

function research.poll_monitors()
    for force_name, config in pairs(storage.rantz_research_config or {}) do
        local force = game.forces[force_name]
        if not force then
            storage.rantz_research_config[force_name] = nil
        elseif (config.monitored_lab or next(config.dynamic_packs or {})) and
            (not config.last_pack_check_tick or game.tick - config.last_pack_check_tick >= (config.pack_check_seconds or 10) * 60) then
            config.last_pack_check_tick = game.tick
            local availability_changed, stock_changed = monitor.sample(force, config, game.tick)
            if availability_changed then changed(force)
            elseif stock_changed and change_listener then change_listener(force) end
        end
    end
end

local function valid_target(tech, value)
    return tech and technology.is_infinite(tech) and (value == nil or
        (type(value) == "number" and value == value and value >= 0
            and value <= 4294967295 and value == math.floor(value)))
end

function research.set_blacklisted(force, name, value, target_update)
    if not force or not force.technologies[name] or type(value) ~= "boolean" then return false end
    if target_update and not valid_target(force.technologies[name], target_update.value) then return false end
    local config = configuration.ensure(force)
    -- Apply a pending GUI edit before scheduling the newly allowed technology.
    -- A table distinguishes clearing the limit from leaving it unchanged.
    if target_update then config.target_levels[name] = target_update.value end
    for i = #config.deprioritized_techs, 1, -1 do
        if config.deprioritized_techs[i] == name then table.remove(config.deprioritized_techs, i) end
    end
    if value then config.deprioritized_techs[#config.deprioritized_techs + 1] = name end
    changed(force)
    return true
end

function research.set_target_level(force, name, value)
    local tech = force and force.technologies[name]
    if not valid_target(tech, value) then return false end
    configuration.ensure(force).target_levels[name] = value
    changed(force)
    return true
end

function research.on_research_finished(event)
    local force = event.research.force
    local config = configuration.ensure(force)
    if config.automatic_research == event.research.name then config.automatic_research = nil end
    configuration.refresh(force, config)
    for _, names in ipairs({config.prioritized_techs, config.deprioritized_techs}) do
        for i = #names, 1, -1 do
            local tech = force.technologies[names[i]]
            if not tech or tech.researched then table.remove(names, i) end
        end
    end
    research.start_next_research(force)
    if change_listener then change_listener(force) end
end

function research.on_research_queued(event)
    if not event.player_index then return end
    local config = configuration.ensure(event.force)
    if config.automatic_research == event.research.name then config.automatic_research = nil end
    changed(event.force)
end

function research.on_research_moved(event)
    if not event.player_index then return end
    -- A manually arranged queue is now the player's explicit ordering.
    configuration.ensure(event.force).automatic_research = nil
    if change_listener then change_listener(event.force) end
end

function research.on_research_cancelled(event)
    if not event.player_index then return end
    local config = configuration.ensure(event.force)
    if config.automatic_research and event.research[config.automatic_research] then
        config.automatic_research = nil
    end
    -- Do not immediately restore a choice the player has just cancelled.
    if change_listener then change_listener(event.force) end
end

return research
