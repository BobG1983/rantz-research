-- Isolated engine smoke test only. Require from a COPY of control.lua, create a
-- disposable map, then benchmark that map for 660 ticks. Never load in real saves.
local research = require("scripts.research.controller")
local monitor = require("scripts.research.monitor")
local gui = require("scripts.gui")
local lab_gui = require("scripts.gui.lab")

script.on_nth_tick(1, function(event)
    if event.tick == 1 then
        local force = game.forces.player
        local config = research.ensure_config(force)
        config.enabled = false
        local surface = game.surfaces.nauvis
        surface.request_to_generate_chunks({0, 0}, 1)
        surface.force_generate_chunk_requests()
        for _, entity in pairs(surface.find_entities_filtered{area = {{-10, -10}, {10, 10}}}) do
            if entity.type ~= "character" then entity.destroy() end
        end
        local tiles = {}
        for x = -10, 10 do for y = -10, 10 do tiles[#tiles + 1] = {name = "grass-1", position = {x,y}} end end
        surface.set_tiles(tiles)
        local player = game.players[1]
        if player then player.teleport({0, 0}, surface) end
        local lab = surface.create_entity{name = "lab", position = {0, 0}, force = force}
        local pack = "agricultural-science-pack"
        if player then
        player.opened = lab
        lab_gui.refresh(player)
        gui.toggle_gui(player)
        local row = player.gui.top.rantz_research_gui.flow.allowed_ingredients[pack]
        assert(row.rantz_pack_mode.tooltip[1] == "rantz_research_gui.monitor_required")
        gui.on_click{player_index = player.index, element = player.gui.relative.rantz_research_lab.monitor}
        assert(config.monitored_lab == lab and row.rantz_pack_mode.items[3][1] == "rantz_research_gui.pack_dynamic")
        row.rantz_pack_mode.selected_index = 3
        gui.on_pack_selection_changed{player_index = player.index, element = row.rantz_pack_mode}
        else
            research.set_monitored_lab(force, lab)
            research.set_pack_mode(force, pack, "dynamic")
        end
        config.pack_check_seconds = 1
        config.pack_grace_seconds = 5
        assert(config.dynamic_packs[pack] and not monitor.is_allowed(config, pack))
        local inventory = lab.get_inventory(defines.inventory.lab_input)
        assert(inventory.insert{name = pack, count = 1, quality = "legendary"} == 1)
        monitor.sample(force, config, game.tick)
        assert(monitor.is_allowed(config, pack))
        inventory.clear()
        monitor.sample(force, config, 60)
        monitor.sample(force, config, 359)
        assert(monitor.is_allowed(config, pack))
        monitor.sample(force, config, 360)
        assert(not monitor.is_allowed(config, pack))
        -- Native saved_progress retains work when a research is moved in queue.
        force.research_all_technologies()
        force.technologies.automation.researched = false
        force.technologies.logistics.researched = false
        force.research_queue = {"automation"}
        force.research_progress = 0.25
        force.research_queue = {"logistics", "automation"}
        assert(force.technologies.automation.saved_progress == 0.25)
        force.research_queue = {"automation"}
        -- Test inserter refill of green science while red-only research is active.
        local chest = surface.create_entity{name = "steel-chest", position = {0, 4}, force = force}
        chest.insert{name = "logistic-science-pack", count = 20}
        chest.insert{name = "automation-science-pack", count = 20}
        local inserter = surface.create_entity{name = "burner-inserter", position = {0, 2}, force = force,
            direction = defines.direction.south}
        inserter.pickup_position = {0, 4}
        inserter.drop_position = {0, 0}
        inserter.insert{name = "coal", count = 5}
        storage.engine_check = {lab = lab, player = player, inserter = inserter, chest = chest}
        log("RANTZ_ENGINE_INVENTORY_AND_PROGRESS_OK")
    elseif event.tick == 660 then
        local state = storage.engine_check
        log(serpent.line({lab = state.lab.get_inventory(defines.inventory.lab_input).get_contents(),
            chest = state.chest.get_inventory(defines.inventory.chest).get_contents(),
            fuel = state.inserter.get_fuel_inventory().get_contents(), status = state.inserter.status,
            pickup = state.inserter.pickup_position, drop = state.inserter.drop_position}))
        assert(state.lab.get_inventory(defines.inventory.lab_input).get_item_count("logistic-science-pack") > 0,
            "A lab must refill unused packs to avoid dynamic availability deadlock")
        state.lab.destroy()
        local config = research.get_config(game.forces.player)
        monitor.sample(game.forces.player, config, game.tick)
        gui.refresh_force(game.forces.player)
        assert(not config.monitored_lab)
        if state.player then
        local row = state.player.gui.top.rantz_research_gui.flow.allowed_ingredients["agricultural-science-pack"]
        assert(row.rantz_pack_mode.selected_index == 3 and row.rantz_pack_mode.tooltip[1] == "rantz_research_gui.monitor_required")
        end
        log("RANTZ_ENGINE_REFILL_AND_LOST_LAB_OK")
    end
end)
