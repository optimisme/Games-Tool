# Games-Tool

`Games-Tool` is a repository with two related parts:

1. `games_tool`: a Flutter level editor used to create and export 2D game data.
2. `game_example`: a Flutter runtime sample that loads exported data and runs it
   as a playable game.

The goal is to provide both sides of the workflow in one place:
design content with the editor, then run/validate that content in a game app.

## Repository structure

- `games_tool/`: editor application (authoring side).
- `game_example/`: runtime/game sample (consumer side).
- `Enunciat.md`: project statement/context.

## Documentation map

### Editor docs

- `games_tool/README.md`
  - Setup and run instructions for the editor.
  - Project storage paths and project-management behavior.

### Runtime docs (`game_example`)

- `game_example/README.md`
  - Runtime project overview, architecture, module layout, and game flow.
  - Best starting point to understand how the playable sample is organized.

- `game_example/README-API.md`
  - Detailed runtime API reference for `utils_gamestool`.
  - Documents `GamesToolApi`, `GameDataRuntimeApi`, rendering helpers, math,
    collisions, and frame-delta behavior.
  - Includes generic zone lookup helpers (`type` OR `name`) and hot-loop
    guidance for resolving zone rects once per simulation tick.

- `GUIA-ESTUDI.md`
  - Learning guide in Catalan for students.
  - Recommends reading order, key methods, practical exercises, and common
    mistakes when building new levels/games from this template.

## Suggested reading order

1. `games_tool/README.md` (understand the editor and exported data source).
2. `game_example/README.md` (understand runtime app structure).
3. `game_example/README-API.md` (deep dive into runtime API surface).
4. `GUIA-ESTUDI.md` (Catalan guided learning path).
