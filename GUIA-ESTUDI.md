# GUIA ESTUDI (actualitzada)

Aquesta guia esta pensada per entendre el codi actual de `game_example` i
construir nous nivells sense trencar el runtime.

## 1. Flux general de pantalles

Flux real del projecte:

1. `lib/main.dart` crea `AppData` (Provider) i inicia `App`.
2. `lib/app.dart` obre `Menu`.
3. `lib/menu/` deixa triar nivell.
4. `lib/loading/` carrega dades + assets (amb minim de temps visual).
5. Entra a `lib/level_0/` o `lib/level_1/`.

Notes importants:

- `AppData.ensureLoadedForLevel(levelIndex)` evita carregues duplicades.
- Cada nivell clona `appData.gameData` a `_runtimeGameData` per poder mutar
  runtime (ex: canviar tiles) sense tocar la font compartida.

## 2. Tick / Update / Draw / Commands

### 2.1 Bucle de joc (fixed-step + interpolacio)

El bucle es defineix a `shared/utils_level.dart` amb `restartGameLoopTicker(...)`:

- cada vsync rep `frameDt`.
- acumula temps i executa `onTick(fixedDt)` tantes vegades com calgui.
- al final del frame crida `onFrame(frameDt, alpha)`.
- `alpha` es factor `[0..1]` entre tick anterior i tick seguent.

Aixo dona:

- simulacio estable (fisica/collisions) en ticks fixos.
- render suau entre ticks amb interpolacio.

### 2.2 Contracte d'interpolacio

A cada tick:

1. `runtimeApi.beginTick()` copia `current -> previous` dels transforms tracked.
2. gameplay actualitza estat (`playerX`, `cameraX`, targets de paths, etc.).
3. gameplay crida `setTransform2D(id, x, y)` per valors "current".

A cada draw:

- `Level*RenderState.from(..., alpha)` fa `sampleTransform2D(id, alpha)`.
- el painter rep posicions interpolades.

Aquest patró es fa a `level_0/update.dart` i `level_1/update.dart`.

### 2.3 Sistema de commands de render

Els nivells no pinten directament gameplay dins `update.dart`.
Construeixen llistes de commands i les passen al painter compartit:

- `LayerRenderCommand`
- `LevelSpriteRenderCommand`
- `HudRenderCommand`
- `OverlayRenderCommand`
- `RenderImageCommand` (world/hud/overlay)

Peces clau:

- `shared/level_rendering.dart` (`LevelPainter` + `paintLevelFrameWithCommands`).
- ordre de draw per profunditat amb `resolveDepthOrderForLayerAndCommands(...)`.
- tile/sprite culling al renderer (`runtime_rendering_api.dart`).

En resum:

- `update.dart` = logica i estat.
- `main.dart` = converteix estat a commands.
- `shared/level_rendering.dart` = executa draw dels commands.

## 3. API actual que has de coneixer

Referencies oficials:

- `game_example/README-API.md`
- `lib/utils_gamestool/project_data_api.dart` (`GamesToolApi`)
- `lib/utils_gamestool/runtime_api.dart` (`GameDataRuntimeApi`)

### 3.1 Carrega i model runtime

- `GamesToolApi.loadGameData(bundle)` (adjunta tilemaps, zones, paths, animacions).
- `GameDataRuntimeApi.useLoadedGameData(gameData, gamesTool: ...)`.
- `GameDataRuntimeApi.loadFromAssets(...)`.

### 3.2 Get/Set estricte per path

- `gameDataGet(path)`, `gameDataGetAs<T>(path)`, `gameDataHasPath(path)`.
- `gameDataSet(path, value)`, `gameDataSetMany(updates)`.

### 3.3 Lookups de nivell/capes/sprites/zones

- `findLevelByIndex`, `findLevelByName`.
- `findLayerIndexByName`, `listLevelLayers`, `listLevelSprites`, `levelZones`.
- `findZoneIndexByGameplayData`.
- `findZoneIndicesByTypeOrName`, `findZonesByTypeOrName`,
  `zoneRectsByTypeOrName`, `zoneMatchesTypeOrName`.
- `findSpriteIndexByTypeOrName`, `findSpriteIndicesByTypeOrName`,
  `findSpriteByName`.

`byTypeOrName` significa:

- match per `type == value` **o** `name == value` (OR, no AND).
- per defecte case-insensitive i amb trim.

### 3.4 Runtime de colisios i coordenades

- `spriteCollisionRects(...)`, `spriteHitBoxes(...)`, `spriteAnchoredRect(...)`.
- `collideSpriteWithZones(...)`, `collideSpriteWithSprites(...)`.
- helpers de grup: `collidesWithAny*`, `collidesWithAll*`, `*WithGroup(...)`.
- CCD downward: `firstDownwardSpriteCollisionAgainstRects(...)`.
- coordenades: `worldToTile`, `tileAt`, `tileWorldRect`, `tileScreenRect`,
  `worldToScreen`, `screenToWorld`.

### 3.5 Frame delta i interpolacio

- `beginFrame()` + `updateFrameDeltaForSprite(...)` per entered/exited/staying.
- `beginTick()`, `setTransform2D(...)`, `snapTransform2D(...)`,
  `sampleTransform2D(...)` per interpolacio visual.

## 4. Com esta fet Level 0

Fitxers clau:

- `lib/level_0/lifecycle.dart`
- `lib/level_0/update.dart`
- `lib/level_0/main.dart`
- `lib/level_0/models.dart`

### 4.1 Treure "Arbres"

No n'hi ha prou amb comptar zones `Arbre`.
El que compta al joc son **tiles reals de la capa Decoracions** que cauen dins
zones Arbre.

Flux:

1. init: `_collectLevel0ArbreTileKeys(...)` calcula quins tiles son
   collectible/objectiu.
2. tick: `_clearDecorationTileIfOnArbre(...)`:
   - comprova overlap player vs zones `Arbre`.
   - converteix posicio player a tile (`worldToTile`).
   - llegeix tile (`tileAt`).
   - si el tile es collectible, escriu `-1` amb `gameDataSet(...)`.
3. actualitza `arbresRemovedCount` i win quan arriba a `totalArbres`.

Perque aixi i no "nombre de zones Arbre":

- una zona pot cobrir molts tiles.
- pot haver-hi zones sense tile valid.
- el progress ha de seguir "arbre visual eliminat" (tile), no trigger abstracte.

### 4.2 Mostrar pont ocult

Flux:

1. `_isInsideZoneWithGameplayData(state, 'Futur Pont')`.
2. detecta entrada (edge): `insideNow && !wasInsideBefore`.
3. `_revealLayerIfHidden(_pontAmagatLayerIndex)` posa `visible = true`.

Aixo evita toggles repetits cada tick.

## 5. Com esta fet Level 1

Fitxers clau:

- `lib/level_1/lifecycle.dart`
- `lib/level_1/update.dart`
- `lib/level_1/main.dart`
- `lib/level_1/models.dart`

### 5.1 Colisio Floor "previous/next frame" (linia temporal del tick)

Hi ha dues capes de proteccio:

1. **Suport de peu**: `_isStandingOnFloor(...)` i `_isStandingOnFloorRects(...)`
   fan check d'overlap horitzontal + proximat de `player.bottom` a `floor.top`.
2. **Anti-tunneling downward**:
   `_resolveFloorPenetration(...)` usa
   `firstDownwardSpriteCollisionAgainstRects(previousPose, currentPose, floors)`
   i fa correccio de penetracio.

Per plataformes en moviment, `_updateLinkedPathBindings(...)` compara
`previousPosition -> nextPosition` de la zona floor per saber si el player
estava damunt del floor anterior i aplicar carry delta.

### 5.2 Gravetat

A `_updatePhysics(...)`:

- si no esta a terra (o encara puja), aplica
  `velocityY += gravityPerSecondSq * dt`.
- clamp a `maxFallSpeedPerSecond`.
- despres integra posicio i resol penetracio de terra.

Constants a `Level1UpdateState`:

- `gravityPerSecondSq = 2088`
- `jumpImpulsePerSecond = 708`
- `maxFallSpeedPerSecond = 840`

### 5.3 Matar enemics, bounce i animacions

`_handleDragonInteractions(...)`:

- si Foxy cau sobre dragon (`!onGround && velocityY > 25`):
  - marca inici de mort: `dragonDeathStartSeconds[dragonIndex] = time`.
  - aplica rebot: `velocityY = -jumpImpulse * 0.38`.
- si colisio lateral/repetida:
  - danya player amb `_applyDragonDamage(...)` (`-25%` vida).

Animacio:

- render del dragon usa `animationName = 'Dragon Death'` mentre esta morint.
- `_pruneFinishedDragonDeaths(...)` elimina sprite quan acaba durada animacio
  (durada resolta via `_dragonDeathDurationSeconds()`).

### 5.4 Moure's amb plataforma

`_updateLinkedPathBindings(state, dt)`:

1. avanca temps de path.
2. mou targetes lligades a paths (layers/zones/sprites).
3. per targets que son floor zones:
   - comprova si player estava damunt del rect anterior del floor.
   - calcula `candidateDelta = nextPosition - previousPosition`.
   - aplica el delta de major magnitud com `carryDelta`.
4. `_updatePhysics` suma `carryDelta` al player abans de gravetat/input.

### 5.5 Death zone

Cada tick (despres de moviment/combat):

- `deathZones = zoneRectsByTypeOrName(levelIndex, 'Foxy Death')`.
- `_isTouchingDeathZone(state, deathZones: deathZones)` fa overlap amb hitboxes
  del player.
- si true -> `_triggerGameOver(state)`.

## 6. Ordre de lectura recomanat (actual)

1. `lib/main.dart`
2. `lib/app.dart`
3. `lib/app_data.dart`
4. `lib/menu/main.dart`
5. `lib/loading/main.dart`
6. `lib/shared/utils_level.dart`
7. `lib/shared/level_rendering.dart`
8. `lib/level_0/main.dart` + `lifecycle/update/models/interaction`
9. `lib/level_1/main.dart` + `lifecycle/update/models/interaction`
10. `lib/utils_gamestool/project_data_api.dart`
11. `lib/utils_gamestool/runtime_api.dart`
12. `game_example/README-API.md` (referencia completa)

## 7. Regles practiques per no trencar el runtime

- No facis logica gameplay dins painter.
- Mantingues `onTick` deterministic; `onFrame` nomes per UI/interpolacio.
- Si afegeixes objectes moguts per path, fes `setTransform2D` al tick i
  `sampleTransform2D(alpha)` al render.
- Per hot loops, resol llistes de zones/sprites una vegada per tick i reusa-les.
- Quan facis end-state, neteja input i bloqueja sortida fins cooldown.
