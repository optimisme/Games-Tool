# Ruta d'aprenentatge: de zero a entendre els exemples

Aquesta guia és per a principiants que volen començar a programar amb aquest repositori i entendre com funcionen els dos exemples jugables.

## 1. Què estàs construint

En aquest repositori, la idea central és el desenvolupament 2D orientat a dades:

1. Dissenyes el contingut del joc a `games_tool` (nivells, capes, sprites, zones, camins, animacions, viewport).
2. L'eina exporta JSON + assets.
3. Els projectes runtime carreguen aquestes dades i executen la lògica del joc.

Tens dos runtimes:

- `game_example_libgdx` (Java + LibGDX)
- `game_example_flutter` (Flutter/Dart)

Tots dos implementen les mateixes idees de gameplay, així que pots aprendre comparant-los.

## 2. Ordre recomanat per aprendre

1. Obre el README principal: entén l'objectiu del repositori.
2. Obre `games_tool/README.md`: entén l'editor i l'emmagatzematge de projectes.
3. Executa primer un runtime (recomanat: Flutter), després LibGDX.
4. Llegeix els controladors de gameplay:
   - Lògica top-down del nivell 0
   - Lògica de plataformes del nivell 1
5. Compara la implementació LibGDX vs Flutter de cada funcionalitat.

## 3. Configuració mínima i execució

## Runtime Flutter

```bash
cd game_example_flutter
flutter pub get
flutter run -d macos
```

## Runtime LibGDX

```bash
cd game_example_libgdx
./run.sh
```

## 4. Com estan estructurats els exemples

Tots dos exemples segueixen una arquitectura semblant:

- `LevelLoader` llegeix JSON i construeix `LevelData` en runtime.
- `PlayScreen` executa simulació a pas fix i rendering.
- Els controladors de gameplay contenen les regles específiques:
  - `GameplayControllerTopDown` per al nivell 0
  - `GameplayControllerPlatformer` per al nivell 1

Aquesta separació és clau:

- La càrrega de dades és genèrica.
- El rendering és genèric.
- Les regles de joc viuen al codi de gameplay.

## 5. Mecàniques demanades: com estan implementades

A continuació tens cada mecànica i on llegir-la a tots dos runtimes.

## 5.1 Eliminació d'"Arbre" al nivell 0

Què passa:

- Els arbres estan representats per tiles dins una capa de decoració.
- Només els tiles que solapen zones etiquetades com `arbre`/`tree` són col·leccionables.
- Quan el jugador entra en una zona arbre, el tile actual sota el jugador passa a `-1` (s'elimina).

On:

- Flutter:
  - `game_example_flutter/lib/gameplay_controller_top_down.dart`
  - `_buildCollectibleArbreTiles()`
  - `_collectArbreTileIfNeeded()`
- LibGDX:
  - `game_example_libgdx/src/main/java/com/project/GameplayControllerTopDown.java`
  - `buildCollectibleArbreTiles()`
  - `collectArbreTileIfNeeded()`

Detall d'implementació:

- Es fa servir una clau tipus `"tileX:tileY"` per registrar tiles col·leccionables i ja recollits.
- La condició de victòria comprova `collected >= total collectible`.

## 5.2 Mostrar pont ocult al nivell 0

Què passa:

- Una capa anomenada tipus "Pont Amagat" / "hidden bridge" comença oculta.
- En entrar a la zona amb `gameplayData` `futur pont` / `future bridge`, es mostra la capa.

On:

- Flutter:
  - `gameplay_controller_top_down.dart`
  - `_classifyZones()`
  - `_revealHiddenBridgeIfNeeded()`
- LibGDX:
  - `GameplayControllerTopDown.java`
  - `classifyZones()`
  - `revealHiddenBridgeIfNeeded()`

Detall d'implementació:

- La revelació es fa en transició (`inside && !wasInsideBefore`) per evitar escriure l'estat cada frame.

## 5.3 Col·lisions de terra al nivell 1 (incloent anti-tunneling cap avall)

Què passa:

- Els terres es detecten per tokens de tipus/nom (`floor`, `platform`).
- La col·lisió vertical és de plataformes one-way:
  - col·lisiona quan baixes,
  - s'ignora quan puges (pots saltar des de sota).
- El tunneling cap avall es redueix amb comprovacions swept + correcció de penetració com a fallback.

On:

- Flutter:
  - `gameplay_controller_platformer.dart`
  - `_classifyZones()`
  - `_resolveVerticalCollisions()`
  - `_crossedZoneTop()`
  - `_overlapsHorizontallyForSweep()`
- LibGDX:
  - `GameplayControllerPlatformer.java`
  - `classifyZones()`
  - `resolveVerticalCollisions()`

Sobre la pregunta "auto tunneling downward":

- Sí, està tractat explícitament.
- El primer pas usa proves sweep/cross entre la posició anterior i l'actual.
- El fallback empeny el jugador cap amunt si ja hi ha penetració prop del top del terra.

## 5.4 Gravetat al nivell 1

Què passa:

- La gravetat incrementa la velocitat vertical amb el temps.
- La velocitat màxima de caiguda es limita.
- El salt aplica velocitat vertical negativa (cap amunt), i després la gravetat el fa baixar.

On:

- Flutter:
  - `gameplay_controller_platformer.dart`
  - constants: `gravityPerSecondSq`, `maxFallSpeedPerSecond`, `jumpImpulsePerSecond`
  - dins `fixedUpdate()`
- LibGDX:
  - `GameplayControllerPlatformer.java`
  - constants: `GRAVITY_PER_SECOND_SQ`, `MAX_FALL_SPEED_PER_SECOND`, `JUMP_IMPULSE_PER_SECOND`
  - dins `fixedUpdate()`

## 5.5 Matar enemics, rebot i animacions al nivell 1

Què passa:

- El tipus d'enemic es resol com sprites `dragon`.
- Si el jugador solapa el drac mentre cau prou ràpid, el drac mor.
- El jugador rebota cap amunt després del stomp.
- El drac mostra l'animació de mort i després s'amaga/elimina quan acaba la durada.
- Si el contacte no és stomp, el jugador rep dany periòdic.

On:

- Flutter:
  - `gameplay_controller_platformer.dart`
  - `_handleDragonInteractions()`
  - `_startDragonDeath()`
  - `_pruneCompletedDragonDeaths()`
  - `_resolveDragonDeathDurationSeconds()`
- LibGDX:
  - `GameplayControllerPlatformer.java`
  - `handleDragonInteractions()`
  - `startDragonDeath()`
  - `pruneCompletedDragonDeaths()`
  - `resolveDragonDeathDurationSeconds()`

Detall d'implementació:

- La durada de mort es calcula a partir de frames/fps del clip si està disponible.
- Si no, s'usa una durada fallback.

## 5.6 Moure el jugador amb la plataforma

Què passa:

- Les zones de terra/plataforma en moviment es comparen entre transformació anterior i actual.
- Si el jugador estava dret a sobre en el pas anterior, rep el delta de moviment de la plataforma.

On:

- Flutter:
  - `gameplay_controller_platformer.dart`
  - `_applyMovingFloorCarry()`
- LibGDX:
  - `GameplayControllerPlatformer.java`
  - `applyMovingFloorCarry()`

Detall d'implementació:

- Fa servir `zoneRuntimeStates` i `zonePreviousRuntimeStates` capturats a cada tick fix.
- Si hi ha múltiples terres candidats, tria el delta de transport més fort.

## 5.7 Zona de mort

Què passa:

- Les zones etiquetades com `death` provoquen game over quan solapen amb el hitbox del jugador.

On:

- Flutter:
  - `gameplay_controller_platformer.dart`
  - `_classifyZones()` + `_isTouchingDeathZone()` + `_triggerGameOver()`
- LibGDX:
  - `GameplayControllerPlatformer.java`
  - `classifyZones()` + `isTouchingDeathZone()` + `triggerGameOver()`

## 6. Exercicis pràctics recomanats

1. Canvia gravetat i impuls de salt, i observa el "feeling" del moviment.
2. Afegeix una nova zona de mort i valida el comportament de derrota.
3. Afegeix una plataforma amb path i comprova la lògica de transport.
4. Crea un col·leccionable nou copiant el patró arbre/gema.
5. Afegeix una animació nova d'enemic i ajusta la seva durada de mort.

## 7. Consell final

Quan aprenguis una funcionalitat, segueix sempre aquest ordre:

1. Dades al JSON (què està configurat).
2. Carregador (`LevelLoader`) cap a `LevelData`.
3. Actualització runtime (`fixedUpdate`) aplicant regles de gameplay.
4. Actualització d'estat visual (visibilitat, animació, transforms).

Aquest flux és el nucli de l'arquitectura 2D orientada a dades d'aquest repositori.
