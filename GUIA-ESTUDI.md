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

- cada vsync (callback del `Ticker`) calcula `frameDt`.
- `frameDt` es clampa (maxim) per evitar salts gegants en una sola iteracio.
- s'acumula en `accumulatorSeconds`.
- mentre `accumulatorSeconds >= fixedDt`, executa un `onTick(fixedDt)` i resta
  `fixedDt` de l'acumulador.
- si hi ha massa retard, limita substeps (`maxSubsteps`) per evitar
  "spiral of death".
- al final del frame, calcula `alpha = accumulatorSeconds / fixedDt` i crida
  `onFrame(frameDt, alpha)` una sola vegada.

Interpretacio practica:

- `onTick` = simulacio determinista (fisica, collisions, gameplay).
- `onFrame` = render del frame actual (amb alpha).

Exemple curt (`fixedDt = 16.67ms`):

- arriba un frame de `25ms`.
- s'executa 1 tick complet (queden `8.33ms` a l'acumulador).
- `alpha = 8.33 / 16.67 = 0.5`.
- el draw pinta a mig cami entre estat anterior i estat actual.

### 2.2 Contracte d'interpolacio

A cada tick:

1. `runtimeApi.beginTick()` mou transform tracked `current -> previous`.
2. gameplay calcula el nou estat (player, camera, paths, etc.).
3. gameplay publica el nou estat amb `setTransform2D(id, x, y)` com a `current`.

A cada draw:

- `Level*RenderState.from(..., alpha)` crida `sampleTransform2D(id, alpha)`.
- `alpha = 0` retorna gairebe `previous`; `alpha = 1` retorna `current`.
- valors intermedis donen lerp suau entre ticks.

Perque funciona:

- la simulacio no depen del framerate de render.
- el render no "salta" d'un tick al seguent.
- mantens precisio de gameplay + suavitat visual.

Regla d'or:

- tot el que es mou i vols suavitzar ha d'entrar en aquest contracte
  (`beginTick -> setTransform2D` al tick, `sampleTransform2D(alpha)` al draw).
- si un objecte no registra transform tracked, es renderitza "a salts" de tick.

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

Perque aquest sistema es millor (avantatges):

- separacio clara de rols:
  `update.dart` calcula estat i `level_rendering.dart` nomes dibuixa.
- menys regressions:
  canvis de gameplay no toquen draw de baix nivell i a l'inreves.
- ordre de render explicit:
  profunditats/capes/sprites es resolen en una pipeline unica i consistent.
- reutilitzacio:
  `LevelPainter` i helpers compartits serveixen per `level_0` i `level_1`.
- mes rendiment:
  centralitzes culling (tiles/sprites) i evites feina duplicada per nivell.
- extensibilitat:
  afegir HUD/overlay/imatges noves es afegir commands, no reescriure el painter.
- millor depuracio:
  una llista de commands es una "foto" del frame que es pot inspeccionar rapid.

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

   Aixo vol dir: si el player ha quedat una mica "dins" del terra al final del
   tick, es calcula quants pixels ha entrat (`penetration = playerBottom - floorTop`)
   i se li resta aquest valor a `playerY` (+ un petit marge) per deixar-lo just
   recolzat sobre la superficie, sense travessar-la.

Per plataformes en moviment, `_updateLinkedPathBindings(...)` compara
`previousPosition -> nextPosition` de la zona floor per saber si el player
estava damunt del floor anterior i aplicar carry delta.
Aplicar carry delta vol dir sumar al player el mateix desplacament que ha fet
la plataforma en aquell tick (`delta = nextFloorPos - previousFloorPos`), de
manera que "viatgi amb la plataforma" i no es quedi enrere o tremoli.

### 5.2 Gravetat

A `_updatePhysics(...)`:

- si no esta a terra (o encara puja), aplica
  `velocityY += gravityPerSecondSq * dt`.
- clamp (maxim) a `maxFallSpeedPerSecond`.
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
2. mou elements (targets) lligats a paths (layers/zones/sprites).
3. per els elements (targets) que son floor zones:
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
8. `lib/level_0/main.dart` + `lifecycle.dart/update.dart/models.dart/interaction.dart`
9. `lib/level_1/main.dart` + `lifecycle.dart/update.dart/models.dart/interaction.dart`
10. `lib/utils_gamestool/project_data_api.dart`
11. `lib/utils_gamestool/runtime_api.dart`
12. `game_example/README-API.md` (referencia completa)

## 7. Regles practiques per no trencar el runtime

- No facis logica gameplay dins painter.
- Mantingues `onTick` deterministic; `onFrame` nomes per UI/interpolacio.
  
  * A `onTick` posa moviment, fisica, collisions, canvis de vida,
  col.leccio d'items, triggers i mutacions de `gameData`.
 
  * A `onFrame` posa coses visuals depenents del frame (fps smoothing,
  `setState` unic per vsync, i lectura de `alpha` per interpolar posicions).
  
  No moguis gameplay a `onFrame`, perque llavors depen del framerate i es
  torna no-reproduible (resultats diferents a 30fps vs 120fps).

- Si afegeixes objectes moguts per path, fes `setTransform2D` al tick i
  `sampleTransform2D(alpha)` al render.
- Per hot loops, resol llistes de zones/sprites una vegada per tick i reusa-les.
- Quan facis end-state, neteja input i bloqueja sortida fins cooldown.

## 8. Exercicis practics (recomanats)

1. Afegeix un `level_2` clonant l'estructura de `level_1` i canvia
   una mecanica (ex: doble salt o velocitat de gravetat diferent).
2. Implementa una zona nova de gameplay (ex: "wind zone") que modifiqui
   `velocityX` o `velocityY` mentre el player la toca.
3. Afegeix una plataforma amb path `ping_pong` i comprova que el carry delta
   mantingui el player estable sense flicker.
4. Crea un HUD nou amb `HudRenderCommand.progressBar` per energia/stamina.
5. Usa `updateFrameDeltaForSprite(...)` per detectar `entered/exited` d'una
   zona i mostrar missatges nomès en l'entrada.
6. Fes que el Drac amb moviment de path, miri cap a la direcció on es mou
