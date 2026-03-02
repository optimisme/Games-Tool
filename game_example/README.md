# game_example

## 1. What this project is

`game_example` is a Flutter sample game that consumes level data exported by
`games_tool`. It includes:

- a retro-style main menu,
- a loading screen with progress,
- playable levels (`level_0`, `level_1`) that use runtime helpers for
  rendering, coordinates, and collisions.

## 2. Quick start

From `game_example/`:

```bash
flutter create . # if necessary
flutter pub get
flutter run
```

Desktop target example:

```bash
flutter run -d macos # linux or windows
```

## 3. Project structure

### Assets

- `assets/levels/`: main exported game content.
- `assets/other/`: assets outside the generic export
  (for example custom images or sounds).

### App bootstrap and shared state

- `lib/main.dart`: entry point and window setup
- `lib/app.dart`: initial route to `Menu`.
- `lib/app_data.dart`: central loading/cache state for game data and images.
- `lib/shared/camera.dart`: mutable camera model + conversion to `RuntimeCamera2D`.
- `lib/shared/utils_level.dart`: reusable level flow/lifecycle helpers
  (navigation, fixed-step loop ticker bootstrap with frame callback, viewport bootstrap).
- `lib/shared/utils_painter.dart`: reusable HUD/text painter helpers,
  including shared centered end-state overlays (win/game-over style layers).

### Menu module

- `lib/menu/main.dart`: menu widget and orchestration of module parts.
- `lib/menu/lifecycle.dart`: menu setup/teardown lifecycle.
- `lib/menu/layout.dart`: layout math and UI geometry.
- `lib/menu/interaction.dart`: keyboard/mouse input and navigation.
- `lib/menu/drawing.dart`: `CustomPainter` render logic.

### Loading module

- `lib/loading/main.dart`: loading screen state + navigation to target level.
- `lib/loading/lifecycle.dart`: loading startup and animation lifecycle.
- `lib/loading/layout.dart`: progress/label composition helpers.
- `lib/loading/interaction.dart`: level routing decision logic.
- `lib/loading/drawing.dart`: loading painter.

### Level 0 module

- `lib/level_0/main.dart`: top-down level screen state and wiring.
- `lib/level_0/lifecycle.dart`: level initialization/cleanup.
- `lib/level_0/models.dart`: update/render state models.
- `lib/level_0/interaction.dart`: input handling and menu return actions.
- `lib/level_0/update.dart`: gameplay simulation/update tick logic.
- `lib/level_0/drawing.dart`: world and sprite rendering.
- Win flow: collecting all `Arbre` zones triggers a `TU GUANYES` end-state
  overlay and delayed "press any key" return behavior (aligned with level 1).

### Level 1 module

- `lib/level_1/main.dart`: platformer level screen state and wiring.
- `lib/level_1/lifecycle.dart`: level initialization/cleanup.
- `lib/level_1/models.dart`: update/render state models.
- `lib/level_1/interaction.dart`: input handling and end-state actions.
- `lib/level_1/update.dart`: platforming physics/combat/gameplay tick logic.
- `lib/level_1/drawing.dart`: layered world + character rendering.
- End-state overlays reuse shared painter helpers from `lib/shared/utils_painter.dart`.

## 4. Game flow

Default runtime flow:

1. `Menu` lets the user choose a level.
2. `Loading` ensures data/assets are ready for that level.
3. Selected level screen starts (`level_0` or `level_1`).
4. Level can navigate back to `Menu`.

Timing model used by gameplay levels:

1. `restartGameLoopTicker(...)` collects real frame delta (`frameDt`) in `onFrame`.
2. Simulation `update` (`onTick`) runs at fixed step (`1/60`) via accumulator.
3. HUD/debug FPS can be derived from `frameDt` (not fixed simulation step).

## 5. Key APIs

Most-used methods when integrating gameplay:

- `AppData.ensureLoadedForLevel(levelIndex)`: load/prepare data for a level.
- `GamesToolApi.loadGameData(bundle)`: parse `game_data.json` and attach
  tilemaps, zones, animations.
- `GamesToolApi.collectReferencedImageFiles(gameData)`: gather all referenced
  image paths.
- `GameDataRuntimeApi.beginFrame(frameId?)`: start a collision/frame tick.
- `GameDataRuntimeApi.updateFrameDeltaForSprite(...)`: compute entered/exited/
  staying contacts for a sprite.
- `GameDataRuntimeApi.collideSpriteWithZones(...)`: sprite vs zone collisions.
- `GameDataRuntimeApi.collideSpriteWithSprites(...)`: sprite vs sprite
  collisions.
- `GameDataRuntimeApi.spriteCollisionRects(...)`: resolve world collision rects
  for a sprite (hitboxes + anchored fallback).
- `GameDataRuntimeApi.fpsFromDeltaTime(...)`: convert frame delta (`dt`) to FPS.
- `GameDataRuntimeApi.updateSmoothedFps(...)`: update a stable FPS counter for HUD/debug.
- `GamesToolApi.findLayerIndexByName(...)`: layer lookup by name in a level.
- `GamesToolApi.findZoneIndexByGameplayData(...)`: zone lookup by gameplayData.
- `GamesToolApi.findSpriteIndexByTypeOrName(...)`: sprite index lookup helper.
- `GamesToolRuntimeRenderer.drawLevelTileLayers(...)`: draw visible tile layers.
- `GamesToolRuntimeRenderer.drawAnimatedSprite(...)`: draw animated sprites
  with camera/depth support.
