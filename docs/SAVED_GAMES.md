# Saved Games

Saving and loading games, the start menu, and the in-game menu. Built 2026-10-27 on `feature/saved-games` at the owner's request.

## What The Player Gets

- **A start menu** when the game launches: **Continue** (the newest save, autosave included), **New world**, **Load game**, **Quit**.
- **An in-game menu** from the **Menu** button at the right of every top bar (atlas, regional map, town), or Escape wherever the game does not already use Escape (the town view uses it to drop the selection). The menu pauses the game: **Resume**, **Save game**, **Load game**, **Quit to start menu**, **Quit game**.
- **Named saves**, as many as wanted. Saving under an existing name overwrites it (the button says so); saves can be deleted from the load list.
- **One autosave**, rewritten every in-game season, when leaving to the start menu, and when quitting (window close included). A game still on the atlas has nothing worth resuming and is not autosaved.

These are owner decisions (2026-10-27): named slots plus an autosave, a start menu, autosave each season and on quit.

Saves live in `user://saves/` (on Windows `%APPDATA%\Godot\app_userdata\<project name>\saves\`), one `.save` file per slot.

## Architecture

| Part | File | Role |
| --- | --- | --- |
| App | `scripts/app.gd`, `scenes/app.tscn` (the project's main scene) | Start menu, starting and loading games (`scenes/main.tscn`), the in-game menu, saving, autosave. Pauses a game under the menu by disabling its processing. |
| Menus | `scripts/ui/game_menu.gd` | Every menu page, built from Godot controls (it needs a text field, a list, and keyboard focus). Only shows pages and emits choices. |
| Game state | `scripts/persistence/game_state.gd` | What a save holds (`capture`), how it goes back into `main.gd` (`restore`), the load list's header (`describe`), and the world fingerprint. |
| Codec | `scripts/persistence/save_codec.gd` | Copies an object's script variables to plain data and back. |
| Store | `scripts/persistence/save_store.gd` | Files on disk: write, list, read, delete. |

`main.gd` knows nothing about files or menus. It emits `menu_requested` (Menu button), `autosave_due` (season change) and `load_failed`, and restores `pending_save_state` once its world is built. Tests and tools create `main.gd` directly and never meet the app.

## Decisions And Why

- **The planet is rebuilt, not saved.** It is a pure function of its seed (`WorldGenerator`), and the regional land of the planet, so a save holds the seed and the player's neighbourhood origin. A save stays small and fast to write: a founded town's save measured about 27 KB, most of it the town map, written in about 10 ms (2026-10-27).
- **A fingerprint guards the rebuild.** A save records a hash of the world (seed, region partition, settlement names). If this build would rebuild the seed differently (the generator changed), the save is refused with a message rather than putting a town onto different land. *Consequence:* changing `WorldGenerator` or `WorldFieldBuilder` output makes existing saves unloadable. That is acceptable while the game is in development; storing the world in the save, or keeping old generators, is the fix if it stops being acceptable.
- **Everything play changes is saved whole.** Every town in the neighbourhood (families, buildings, stores, construction queue, plots, travel layout), the player's spur road, trade routes, calendar, clock, view, and regional camera. Town maps are saved rather than regenerated: construction marks them, and a change to the town map generator must not shift a town under its buildings.
- **State is captured generically.** `SaveCodec` takes every script variable of a domain object, so a field added to `Household`, `Building`, `City`, or `ConstructionProject` is saved without anyone remembering to. Object-valued variables are skipped (their owner saves them, in `GameState`), and so are the caches named in `GameState` (travel grid and route caches, fixed calendar tables).
- **Binary Variant files, zstd-compressed.** JSON rounds floats (the town would drift after a load) and needs type tags for vectors and typed arrays. Godot's Variant encoding keeps every value exact. Objects are never decoded (`FileAccess.get_var` default), so a save file cannot run code. Each file holds a small header first, so the load list reads headers without loading games.
- **Writes are atomic.** A save is written to a temporary file and renamed over the old one, so a crash mid-write keeps the previous save.
- **The domain's randomness needs no saving.** Every random roll in `City` and its helpers is seeded from a hash of the town and the moment (`founding_seed`, tile, household, month), so a loaded town rolls the same as the original would have. `main.gd`'s own `rng` only picks a new house's work preference and the founding seed, and is not saved.
- **Format version.** `GameState.FORMAT` is written in every header; saves from a newer format are hidden from the list. Missing fields in an older save keep their defaults, and fields a newer build no longer has are ignored, so most additions need no version bump. Known losses so far: saves from before routes ran on the lines between tiles (2026-10-27) lose their worn paths, because wear moved from tiles to route cells (`TownLogistics.cell_wear`); the town is otherwise unchanged and wears new paths as it plays.

## Not Saved

- The pending founding site and its survey (the player picks it again).
- The town view's camera (a loaded town opens fitted to the window) and the atlas camera.
- The route grid and its per-cell and per-tile values, and the woods' spreading frontier: rebuilt from the town map when first needed.
- Hover, selection, open panels, and the trade menu.

## When You Change The Game

- New fields on domain objects are saved automatically. A new **object-valued** field, or a new **cache**, needs a line in `GameState` (save its contents, or add it to a skip list).
- New state in **`main.gd`** that play changes must be added to `GameState.capture` and `restore` by hand.
- `tests/save_game_validation.gd` plays a town, saves and loads it, plays both copies 120 more days, and requires them to stay identical. A missed field in a town shows up there as the first differing value.

## Testing

- `tests/save_game_validation.gd` (headless): exact round trip and identical play afterwards; a generated world saved while exploring; an atlas save; refusal of a save whose world cannot be rebuilt; the store (names, ordering, overwrite, delete, newer formats hidden); the app's menus (start, save, resume, leave, load).
- `tests/visual/menu_capture.gd` (needs a window): screenshots of the start menu, pause, save, and load pages, using its own save folder.

## Remaining Work And Limitations

- **Loading waits on the world build** (about 3.4 s, plus about 1 s for the regional terrain) behind a "Loading..." page with no progress bar. Loading in-game rebuilds the world even for the same seed.
- **No cloud sync, no save thumbnails, no confirmation before overwriting** (the Save button reads "Overwrite" instead).
- **The game's title** on the start menu is the project name (`application/config/name`), still "New Game Project".
