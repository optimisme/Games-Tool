# GameData API (game_example)

This document describes the implemented runtime API in:

- `game_example/lib/utils_gamestool/utils_gamestool.dart` (barrel export)
- `game_example/lib/utils_gamestool/project_data_api.dart` (`GamesToolApi`)
- `game_example/lib/utils_gamestool/runtime_math.dart` (`RuntimeCameraMath`)
- `game_example/lib/utils_gamestool/runtime_rendering_api.dart` (`GamesToolRuntimeRenderer`)
- `game_example/lib/utils_gamestool/runtime_models.dart` (runtime value objects)
- `game_example/lib/utils_gamestool/runtime_api.dart` (`GameDataRuntimeApi`)

The API is designed for 2D gameplay runtime access:

- strict `get/set` by path,
- tile/world/screen coordinate helpers,
- anchor-aware hitbox resolution,
- sprite-vs-zone and sprite-vs-sprite collisions,
- group collision helpers (`any` / `all`),
- stateful frame-delta transitions (`entered` / `exited` / `staying`).

## Runtime data root

`GameDataRuntimeApi.gameData` is a `Map<String, dynamic>` enriched at load:

- loads base `game_data.json`
- attaches `layer.tileMap` from `tileMapFile`
- attaches `level.zones` and `level.zoneGroups` from `zonesFile`
- attaches `gameData.animations` and `gameData.animationGroups` from `animationsFile`

## Main types

- `RuntimeCamera2D(x, y, focal)`
- `TileCoord(x, y)`
- `GameDataPathUpdate(path, value)`
- `RuntimeSpritePose(levelIndex, spriteIndex, x?, y?, flipX?, flipY?, frameIndex?, elapsedSeconds)`
- `WorldHitBox`
- `ZoneContact`
- `SpriteContact`
- `CollisionTransition<T>`
- `SpriteFrameDelta`

## Core methods

### Load and state

- `loadFromAssets(bundle, projectRoot?)`
- `useLoadedGameData(gameData, gamesTool?)`
- `isReady`
- `currentFrameId`
- `resetFrameState()`
- `beginFrame(frameId?)`

### Strict path get/set

- `gameDataGet(path)`
- `gameDataGetAs<T>(path)`
- `gameDataHasPath(path)`
- `gameDataSet(path, value)`
- `gameDataSetMany(updates)`

`path` is `List<Object>` with:

- `String` for map keys
- `int` for list indexes

Example:

```dart
api.gameDataSet(['levels', 0, 'backgroundColorHex'], '#AABBCC');
final fps = api.gameDataGetAs<num>(['animations', 0, 'fps']);
```

### Node lookups

- `levelByIndex(levelIndex)`
- `levelByName(levelName)`
- `layerByIndex(levelIndex, layerIndex)`
- `layerByName(levelIndex, layerName)`
- `spriteByIndex(levelIndex, spriteIndex)`

## Tile/coordinate helpers

- `parallaxFactorForDepth(depth, sensitivity?)`
- `cameraScaleForViewport(viewportSize, camera)`
- `worldToScreen(worldX, worldY, camera, viewportSize, depth?, parallaxSensitivity?)`
- `screenToWorld(screenX, screenY, camera, viewportSize, depth?, parallaxSensitivity?)`
- `worldToTile(levelIndex, layerIndex?|layerName?, worldX, worldY)`
- `screenToTile(levelIndex, layerIndex?|layerName?, screenX, screenY, camera, viewportSize)`
- `tileAt(levelIndex, layerIndex?|layerName?, tileX, tileY)` returns `-1` if invalid/empty
- `tileWorldRect(levelIndex, layerIndex?|layerName?, tileX, tileY)`

Notes:

- You must provide exactly one of `layerIndex` or `layerName`.
- `screenToTile` honors camera scale and layer parallax.

## Rendering helpers (Flutter Canvas)

`GamesToolRuntimeRenderer` includes reusable helpers for games that share this data model:

- `levelParallaxSensitivity(gamesTool, level?)`
- `cameraScale(viewportSize, camera)`
- `worldToScreen(...)`
- `drawLevelTileLayers(canvas, painterSize, level, gamesTool, imagesCache, camera, ...)`
- `drawAnimatedSpriteByType(canvas, painterSize, gameData, level, gamesTool, imagesCache, camera, spriteType, elapsedSeconds, ...)`
- `drawAnimatedSprite(canvas, painterSize, gameData, gamesTool, imagesCache, sprite, camera, elapsedSeconds, ...)`
- `drawConnectionIndicator(canvas, painterSize, isConnected)`

## Hitboxes and collisions

### Hitbox resolution

- `spriteHitBoxes(levelIndex, spriteIndex, pose?, frameIndex?, elapsedSeconds)`

Behavior:

1. Resolves sprite animation from `animationId` (or media fallback).
2. Resolves frame index from explicit `frameIndex`, pose, or animation playback time.
3. Uses `frameRigs[frame].hitBoxes` if present, otherwise animation-level `hitBoxes`.
4. Applies per-frame `anchorX/anchorY` (fallback to animation anchor).
5. Applies sprite `flipX/flipY` by mirroring normalized hitboxes.
6. Converts hitboxes to world-space `Rect`.

If an animation has no hitboxes, API provides a fallback full-body hitbox:

- id: `__auto__body`
- normalized rect: `(0,0,1,1)`

### Zone collisions

- `collideSpriteWithZones(levelIndex, spriteIndex, spritePose?, zoneTypes?, frameIndex?, elapsedSeconds)`

Returns a list of `ZoneContact` with:

- `zoneKey` (`L{level}_Z{index}`)
- `zoneIndex`, `zoneType`, `zoneGroupId`
- `hitBoxId`
- `intersectionRect`

### Sprite collisions

- `collideSpriteWithSprites(levelIndex, spriteIndex, spritePose?, candidateSpriteIndices?, candidatePoses?, frameIndex?, frameIndexBySprite?, elapsedSeconds)`

Returns `SpriteContact` with:

- `otherSpriteKey` (`L{level}_S{index}`)
- `otherSpriteIndex`, `otherSpriteGroupId`
- colliding hitbox ids
- `intersectionRect`

## Group helpers

- `spriteIndicesInGroup(levelIndex, groupId)`
- `zoneIndicesInGroup(levelIndex, groupId)`
- `zoneContactsWithGroup(...)`
- `spriteContactsWithGroup(...)`
- `collidesWithAnyZoneInGroup(...)`
- `collidesWithAllZonesInGroup(...)`
- `collidesWithAnySpriteInGroup(...)`
- `collidesWithAllSpritesInGroup(...)`

Rule for `All*` checks:

- returns `false` when target group has no candidates.

## Stateful frame-delta collisions

- `updateFrameDeltaForSprite(...) -> SpriteFrameDelta`

Tracked transitions per sprite:

- zones (`zoneKeys`)
- zone types (`zoneTypes`)
- zone groups (`zoneGroups`)
- collided sprites (`spriteKeys`)
- collided sprite groups (`spriteGroups`)

Each transition is `CollisionTransition<String>`:

- `entered`
- `exited`
- `staying`
- `current`

Call pattern:

1. `beginFrame()` once per game frame.
2. `updateFrameDeltaForSprite(...)` for each sprite you track.

## Path and key conventions

- sprite key: `L{levelIndex}_S{spriteIndex}`
- zone key: `L{levelIndex}_Z{zoneIndex}`

## Important implementation notes

- Collision math is AABB-based with world-space rectangles.
- Sprite/world position uses anchor semantics (`x/y` are anchor world coordinates).
- Layer tile math uses `layer.x`, `layer.y`, `tilesWidth`, `tilesHeight`.
- Parallax in `screenToTile` uses:
  - `factor = exp(-depth * sensitivity)`
  - clamped to `[0.25, 4.0]`.
