# GameData API (game_example)

This document describes the implemented runtime API in:

- `game_example/lib/utils_gamestool/utils_gamestool.dart` (barrel export)
- `game_example/lib/utils_gamestool/project_data_api.dart` (`GamesToolApi`)
- `game_example/lib/utils_gamestool/runtime_math.dart` (`RuntimeCameraMath`)
- `game_example/lib/utils_gamestool/runtime_rendering_api.dart` (`GamesToolRuntimeRenderer`)
- `game_example/lib/utils_gamestool/runtime_models.dart` (runtime value objects)
- `game_example/lib/utils_gamestool/runtime_api.dart` (`GameDataRuntimeApi`)

Scope note: this reference is for `utils_gamestool` runtime APIs. Shared
level/painter helpers under `game_example/lib/shared/` (for example
`drawCenteredEndOverlay` in `utils_painter.dart`) are intentionally documented
in `README.md`, not here.

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
- `SweptRectCollision`
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
- `levelViewportByIndex(levelIndex, fallbackWidth?, fallbackHeight?, fallbackAdaptation?)`
- `layerByIndex(levelIndex, layerIndex)`
- `layerByName(levelIndex, layerName)`
- `spriteByIndex(levelIndex, spriteIndex)`
- `listLevelSprites(level)` (`GamesToolApi`)
- `findLayerIndexByName(level, layerName, caseInsensitive?)` (`GamesToolApi`)
- `findZoneIndexByGameplayData(level, gameplayData, caseInsensitive?)` (`GamesToolApi`)
- `findSpriteIndexByTypeOrName(level, value, caseInsensitive?)` (`GamesToolApi`)
- `firstSpriteIndex(level)` (`GamesToolApi`)

## Tile/coordinate helpers

- `depthProjectionFactorForDepth(depth, sensitivity?)`
- `cameraScaleForViewport(viewportSize, camera)`
- `worldToScreen(worldX, worldY, camera, viewportSize, depth?, depthSensitivity?)`
- `screenToWorld(screenX, screenY, camera, viewportSize, depth?, depthSensitivity?)`
- `worldViewportRect(camera, viewportSize, depth?, depthSensitivity?, paddingWorld?)`
- `worldToTile(levelIndex, layerIndex?|layerName?, worldX, worldY, depthDisplacement?)`
- `screenToTile(levelIndex, layerIndex?|layerName?, screenX, screenY, camera, viewportSize, depthDisplacement?, depthSensitivity?)`
- `tileAt(levelIndex, layerIndex?|layerName?, tileX, tileY)` returns `-1` if invalid/empty
- `tileWorldRect(levelIndex, layerIndex?|layerName?, tileX, tileY, depthDisplacement?)`
- `tileScreenRect(levelIndex, layerIndex?|layerName?, tileX, tileY, camera, viewportSize, depthDisplacement?, depthSensitivity?)`

Notes:

- You must provide exactly one of `layerIndex` or `layerName`.
- `screenToTile` honors camera scale and layer depth projection.

## Rendering helpers (Flutter Canvas)

`GamesToolRuntimeRenderer` includes reusable helpers for games that share this data model:

- `levelDepthSensitivity(gamesTool, level?)`
- `cameraScale(viewportSize, camera)`
- `worldToScreen(...)`
- `levelViewport(gamesTool, level, ...)`
- `resolveViewportLayout(painterSize, viewport)`
- `withViewport(canvas, painterSize, viewport, drawInViewport, ...)`
- `colorFromName(name, fallback?)`
- `drawLevelTileLayers(canvas, painterSize, level, gamesTool, imagesCache, camera, ...)`
- `drawAnimatedSpriteByType(canvas, painterSize, gameData, level, gamesTool, imagesCache, camera, spriteType, elapsedSeconds, ...)`
- `drawAnimatedSprite(canvas, painterSize, gameData, gamesTool, imagesCache, sprite, camera, elapsedSeconds, ...)`

Runtime culling now included:

- tile layers: visible tile-range culling per layer (row/column window from viewport in world space)
- sprites: offscreen culling (`cullWhenOffscreen = true` by default)
- sprite depth displacement: `drawAnimatedSprite(...)` now uses sprite `depth` by default (or explicit `depth` override)

## Hitboxes and collisions

### Hitbox resolution

- `spriteHitBoxes(levelIndex, spriteIndex, pose?, frameIndex?, elapsedSeconds)`
- `spriteCollisionRects(levelIndex, spriteIndex, pose?, frameIndex?, elapsedSeconds)`
- `spriteAnchoredRect(levelIndex, spriteIndex, pose?, elapsedSeconds)`

Behavior:

1. Resolves sprite animation from `animationId` (or media fallback).
2. Resolves frame index from explicit `frameIndex`, pose, or animation playback time.
3. Uses `frameRigs[frame].hitBoxes` if present, otherwise animation-level `hitBoxes`.
4. Applies per-frame `anchorX/anchorY` (fallback to animation anchor).
5. Applies sprite `flipX/flipY` by mirroring normalized hitboxes.
6. Converts hitboxes to world-space `Rect`.

If an animation/frame has no hitboxes, `spriteHitBoxes` returns an empty list and no hitbox-based collisions are detected for that sprite in that frame.

`spriteCollisionRects(...)` is the recommended high-level helper:

1. Returns world hitbox rects when hitboxes exist.
2. Falls back to one anchored sprite rect when hitboxes are missing.

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

### Swept collisions (CCD)

- `firstDownwardCollisionAgainstRects(previousRects, currentRects, staticRects)`
- `firstDownwardSpriteCollisionAgainstRects(levelIndex, spriteIndex, previousPose, currentPose, staticRects, previousFrameIndex?, currentFrameIndex?)`

Returns `SweptRectCollision?` with:

- `time` normalized in `[0, 1]` from previous to current frame
- `movingRectStart`, `movingRectEnd`
- `movingRectAtImpact` (derived getter)
- `staticRect`
- `normal` (top hit is `Offset(0, -1)`)

Notes:

- This is continuous collision detection for downward movement to prevent floor tunneling at high fall speeds.
- It complements per-frame overlap checks; existing collision methods remain unchanged.

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
- Depth projection in `screenToTile` uses:
  - `factor = exp(-depth * sensitivity)`
  - clamped to `[0.25, 4.0]`.
