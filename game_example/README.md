# game_example

Flutter + Flame sample with reusable `utils_gt` and `utils_flame` libraries that load
projects exported from `games_tool` (stored under `assets/<project_name>`).

## Architecture

- `lib/utils_gt/utils_gt.dart`: Data library public API.
- `lib/utils_gt/src/models.dart`: Typed project models.
- `lib/utils_gt/src/repository.dart`: Asset discovery and loading.
- `lib/utils_gt/src/errors.dart`: Typed loading/format exceptions.
- `lib/utils_flame/utils_flame.dart`: Flame integration API (game setup/runtime).
- `lib/utils_flame/src/static_tile_layer_batch_component.dart`: Batched tile renderer.

## What the library gives you

- Discover exported projects in assets (`game_data.json` roots).
- Load and parse:
  - `game_data.json`
  - linked `tilemaps/*.json`
  - linked `zones/*.json`
- Validate referenced media assets.
- Use typed accessors for levels, layers, sprites, animations, zones, and media.

## Quick usage

```dart
import 'package:game_example/utils_gt/utils_gt.dart';

final repository = GamesToolProjectRepository();

final roots = await repository.discoverProjectRoots();
final loaded = await repository.loadFromAssets(projectRoot: roots.first);

print(loaded.project.name);
print(loaded.project.levels.length);
print(loaded.project.animations.length);
```

## Flame setup usage

```dart
import 'package:game_example/utils_flame/utils_flame.dart';

final flameLoader = GamesToolFlameLoader();
await flameLoader.mountLevel(
  game: game,
  projectRoot: 'assets/example_0',
  levelIndex: 0,
);
```
