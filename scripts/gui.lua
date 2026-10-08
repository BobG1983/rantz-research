local research = require("scripts.research.controller")
local technology = require("scripts.research.technology")
local window = require("scripts.gui.window")
local sections = require("scripts.gui.sections")
local controls = require("scripts.gui.controls")
local packs = require("scripts.gui.packs")
local lists = require("scripts.gui.technology_lists")
local gui = {}

function gui.remove_legacy_controls(player)
    local frame = window.get(player)
    if not frame or not frame.flow then return end
    for _, parent in ipairs({frame.flow, frame.flow.settings}) do
        if parent.rantz_research_announce_completed then parent.rantz_research_announce_completed.destroy() end
    end
end

local function refresh_player(player, config, prepared)
    local frame = window.ensure(player, config)
    if not frame then return end
    gui.remove_legacy_controls(player)
    controls.sync(frame.flow, config)
    packs.update(frame.flow.allowed_ingredients, config)
    lists.update(frame.flow, prepared, config)
end

function gui.refresh_force(force)
    local config = research.ensure_config(force)
    local prepared
    for _, player in pairs(force.players) do
        if window.get(player) then
            prepared = prepared or lists.prepare(force, config)
            refresh_player(player, config, prepared)
        end
    end
end

function gui.toggle_gui(player)
    local frame = window.get(player)
    if frame then
        sections.capture(player, frame.flow)
        frame.destroy()
    else
        local config = research.ensure_config(player.force)
        window.create(player, config)
        refresh_player(player, config, lists.prepare(player.force, config))
    end
end

local function event_player(event)
    if not event.element or not event.element.valid then return end
    local player = game.players[event.player_index]
    local frame = player and window.get(player)
    if not frame then return end
    -- Ignore similarly named elements owned by other mods or stale windows.
    local parent = event.element
    while parent and parent ~= frame do parent = parent.parent end
    if parent == frame then return player, frame end
end

function gui.on_checkbox_click(event)
    local player = event_player(event)
    if not player then return end
    local field = controls.setting_field(event.element.name)
    if field then research.set_setting(player.force, field, event.element.state); return end
    local ingredient = string.match(event.element.name, "^rantz_research_allow_ingredient%-(.+)$")
    if ingredient then research.set_pack_allowed(player.force, ingredient, event.element.state) end
end

local function target_update(player, field, name)
    local text, target = field.text, tonumber(field.text)
    local config = research.ensure_config(player.force)
    if text ~= "" and (not string.match(text, "^%d+$") or not target or target > 4294967295) then
        field.text = config.target_levels[name] and tostring(config.target_levels[name]) or ""
        field.tags = {tech_name = name, saved_text = field.text}
        return nil
    end
    -- Committed input is no longer a draft when the resulting refresh occurs.
    field.tags = {tech_name = name, saved_text = text}
    return {value = target}
end

function gui.on_click(event)
    local player, frame = event_player(event)
    if not player then return end
    local name = event.element.name
    local section = string.match(name, "^rantz_research_toggle_(.*)$")
    if sections.definitions[section] then
        local expanded = not frame.flow[sections.definitions[section].content].visible
        sections.set_expanded(frame.flow, section, expanded)
        sections.get_expanded(player)[section] = expanded
        return
    end
    local strategy = string.match(name, "^rantz_research_research_(.*)$")
    if strategy then research.set_strategy(player.force, strategy); return end
    local action, tech_name = string.match(name, "^rantz_research_([^-]*)-(.*)$")
    if action == "disable" or action == "enable" then
        local field = event.element.parent["rantz_research_target-" .. tech_name]
        local update
        if field and field.enabled and field.text ~= field.tags.saved_text then
            update = target_update(player, field, tech_name)
        end
        research.set_blacklisted(player.force, tech_name, action == "disable", update)
    end
end

function gui.on_target_confirmed(event)
    local player = event_player(event)
    if not player then return end
    local field = event.element
    local name = string.match(field.name, "^rantz_research_target%-(.+)$")
    local tech = name and player.force.technologies[name]
    if not tech or not technology.is_infinite(tech) then return end
    local update = target_update(player, field, name)
    if update then research.set_target_level(player.force, name, update.value) end
end

research.set_change_listener(gui.refresh_force)
return gui
