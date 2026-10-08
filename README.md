# Rantz Research

By Rantz. Automatic research for Factorio 2.1 with selectable strategies, research
pack filters, whitelists, blacklists, and per-technology infinite research targets.
Open the collapsible research panel with **Shift+T** (configurable in Controls).

## Code layout

- `control.lua`: event and remote-interface registration only.
- `scripts/events.lua`: lifecycle initialization and event dispatch.
- `scripts/remote.lua`: Rantz Research's `rantz_research` remote interface.
- `scripts/research/configuration.lua`: saved defaults and prototype refresh.
  `get` only reads; `ensure` supplies missing defaults; `initialize` refreshes packs.
  None of these functions schedule research or call another mod.
- `scripts/research/controller.lua`: validated mutations, scheduling, and a GUI
  change listener installed when the runtime modules load.
- `scripts/research/selection.lua`: select an eligible candidate without modifying
  the queue. User-prioritized technologies take precedence.
- `scripts/research/queue.lua`: remove capped entries and promote candidates.
  Existing entries are retained; a full queue won't evict work to insert a new
  candidate. With switching disabled, eligible current research stays in place.
- `scripts/research/technology.lua`: eligibility, prerequisite traversal, scoring,
  and shared finite/infinite ordering. Pack weights are in `pack_costs.lua`.
- `scripts/gui.lua`: GUI event handling and force-wide refresh coordination.
- `scripts/gui/`: window construction, reusable sections, settings controls,
  pack controls, and incremental technology-list rendering.
- `data.lua`: GUI styles and keyboard shortcut. All icons use Factorio's native `item/...` and `utility/...` sprites.

## Conventions and saved games

Internal Lua names use snake_case. GUI names, styles, locale keys, the shortcut,
saved configuration, and the remote interface use the `rantz_research` prefix.
Research options, monitored labs, and dynamic pack modes are configured in the
mod GUI. Saves must already use these
identifiers; migration from the previous identifiers has been removed.
External integrations must call the `rantz_research` remote interface. Old unused
counter and announcement fields are discarded during configuration normalization.
Saved GUI windows are versioned and rebuilt when necessary, retaining expanded
sections. No game or storage access occurs while requiring runtime modules.

Research targets apply through their specified level; blank means unlimited.
Target fields retain unconfirmed input during ordinary refreshes and reordering.
Enter or moving the technology between lists commits a target; another player's
committed changes won't overwrite a local draft. Removing a researched row
necessarily removes its editor.

Fast/Slow use unit count times unit duration. Cheap/Expensive use unit count
times weighted pack quantities. Balanced uses duration times weighted pack
quantities, counting research units once. Pack weights estimate progression,
not exact raw-material prices. When enabled, infinite deprioritization is a
separate priority group, so it doesn't reverse Slow/Expensive within that group.

## Tests

From the mod root, using Lua 5.2:

```sh
lua tests/run.lua
```

The runner isolates each suite's globals and module cache. Shared fixtures model
GUI hierarchy, destruction, reordering, queue limits, name-to-technology
resolution, and the current research changing with the queue.

Tests cover strategy scoring, caps, GUI sorting, saved preferences, initialization,
queue preservation, prerequisite diamonds, finite/infinite ordering, multiplayer
and remote synchronization, and drafts surviving refreshes. These are Lua tests
with simulated Factorio objects; visual rendering still needs an in-game check.
