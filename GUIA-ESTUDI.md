# GUIA ESTUDI

Aquesta guia esta pensada per a estudiants que volen entendre aquest projecte i construir nous jocs a partir de la mateixa estructura.

## 1. Que cal aprendre primer

- Com es connecten les pantalles: `Menu -> Loading -> Level`.
- Com es carrega la dada del joc des de `assets/levels/game_data.json`.
- Com es divideix cada modul per responsabilitats:
  - `main.dart`: cablejat i estat de pantalla.
  - `lifecycle.dart`: inici i tancament.
  - `interaction.dart`: entrades i accions de l'usuari.
  - `update.dart`: pas de simulacio de gameplay.
  - `drawing.dart`: renderitzat.
  - `lib/shared/` conte helpers reutilitzables de nivell i de painter
    (`utils_level.dart`, `utils_painter.dart`).

## 2. Ordre de lectura recomanat

1. `lib/main.dart`
2. `lib/app.dart`
3. `lib/menu/main.dart`
4. `lib/loading/main.dart`
5. `lib/app_data.dart`
6. `lib/level_0/main.dart`, i despres:
   - `lib/level_0/lifecycle.dart`
   - `lib/level_0/interaction.dart`
   - `lib/level_0/update.dart`
   - `lib/level_0/drawing.dart`
7. `lib/level_1/main.dart` amb el mateix ordre.
8. `lib/utils_gamestool/` nomes quan ja entenguis un flux complet de nivell.

## 3. Metodes clau per entendre

- `AppData.ensureLoadedForLevel(levelIndex)`
  - Controla quan les dades i assets ja estan preparats.
- `GamesToolApi.loadGameData(bundle)`
  - Carrega i enriqueix les dades exportades del nivell.
- `GamesToolApi.collectReferencedImageFiles(gameData)`
  - Defineix quines imatges s'han de precarregar.
- `GameDataRuntimeApi.worldToTile(...)`
  - Converteix posicions del mon en coordenades de tile.
- `GameDataRuntimeApi.tileAt(...)`
  - Llegeix valors de tile per a decisions de gameplay.
- `GameDataRuntimeApi.collideSpriteWithZones(...)`
  - Comprovacions base de triggers/col.lisions amb zones.
- `GameDataRuntimeApi.collideSpriteWithSprites(...)`
  - Comprovacions d'interaccio personatge/enemic.
- `GameDataRuntimeApi.updateFrameDeltaForSprite(...)`
  - Detecta col.lisions entrades/sortides/estables per frame.
- `GamesToolApi.findLayerIndexByName(...)`
  - Busca index de capa per nom en un nivell.
- `GamesToolApi.findZoneIndexByGameplayData(...)`
  - Busca index de zona per camp `gameplayData`.
- `GameDataRuntimeApi.spriteCollisionRects(...)`
  - Obte els rectangles de col.lisio en mon (hitboxes o fallback ancorat).
- `GamesToolRuntimeRenderer.drawLevelTileLayers(...)`
  - Dibuixa tilemaps de manera eficient.
- `GamesToolRuntimeRenderer.drawAnimatedSprite(...)`
  - Dibuixa sprites animats amb camera/profunditat.

## 4. Exercicis practics (no s'entreguen)

1. Afegeix una nova opcio de menu per a un nou nivell.
2. Duplica `level_0` com a `level_2` i fes un canvi de gameplay.
3. Afegeix un tipus de zona nou i activa comportament a `update.dart`.
4. Afegeix un comptador HUD que canvii segons col.lisions.

## 5. Consells per entendre el codi mes rapid

- Segueix un valor de dada d'inici a fi (per exemple `x/y` del jugador).
- Llegeix `update.dart` i `drawing.dart` conjuntament.
- Mantingues una nota curta: "input -> actualitzacio d'estat -> render".
- Fes canvis petits i prova sovint; evita grans refactors al principi.
- Quan afegeixis funcionalitat, prioritza noms clars i funcions curtes.

## 6. Errors habituals a evitar

- Barrejar logica de simulacio de gameplay dins `drawing.dart`.
- Fer logica de navegacio dins codi de baix nivell de render/helpers.
- Saltar-se `Loading` i usar assets abans que estiguin carregats.
- Repetir valors hardcoded en molts fitxers en lloc d'una constant de modul.

## 7. Crea el teu propi joc a partir d'aquest template

Checklist minim:

1. Nous assets de nivell a `assets/levels/`.
2. Nou modul de nivell (`main`, `lifecycle`, `interaction`, `update`, `drawing`).
3. Opcio de menu per entrar al nivell.
4. El flux de loading suporta el nou index de nivell.
5. Un objectiu de gameplay clar (recollir, sobreviure, arribar a meta, etc).

Per al detall complet de l'API de runtime, consulta `README-API.md`.
