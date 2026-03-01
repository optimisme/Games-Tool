import 'dart:convert';
import 'dart:io';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_example/utils_flame/utils_flame.dart';
import 'package:game_example/utils_gt/utils_gt.dart';

class _DiskAssetBundle extends CachingAssetBundle {
  _DiskAssetBundle({required this.projectRootPath, required this.assetPaths});

  final String projectRootPath;
  final Set<String> assetPaths;

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.json') {
      final Map<String, List<String>> manifest = <String, List<String>>{
        for (final String path in assetPaths) path: const <String>[],
      };
      final Uint8List bytes = Uint8List.fromList(
        utf8.encode(jsonEncode(manifest)),
      );
      return ByteData.sublistView(bytes);
    }

    final String normalizedKey = key.replaceAll('\\', '/');
    final File file = File('$projectRootPath/$normalizedKey');
    if (!await file.exists()) {
      throw FlutterError('Unable to load asset: "$key".');
    }

    final Uint8List bytes = await file.readAsBytes();
    return ByteData.sublistView(bytes);
  }
}

Future<Set<String>> _collectAssetPaths(String projectRootPath) async {
  final Directory assetsDirectory = Directory('$projectRootPath/assets');
  final Set<String> paths = <String>{};

  await for (final FileSystemEntity entity in assetsDirectory.list(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is! File) {
      continue;
    }
    final String normalized = entity.path.replaceAll('\\', '/');
    final String prefix = '$projectRootPath/'.replaceAll('\\', '/');
    if (!normalized.startsWith(prefix)) {
      continue;
    }
    paths.add(normalized.substring(prefix.length));
  }

  return paths;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GamesToolProjectRepository repository;

  setUpAll(() async {
    final String projectRootPath = Directory.current.path.replaceAll('\\', '/');
    final Set<String> assetPaths = await _collectAssetPaths(projectRootPath);
    repository = GamesToolProjectRepository(
      bundle: _DiskAssetBundle(
        projectRootPath: projectRootPath,
        assetPaths: assetPaths,
      ),
    );
  });

  test('discovers exported Games Tool projects from assets', () async {
    final List<String> roots = await repository.discoverProjectRoots();

    expect(roots, contains('assets/exemple_0'));
  });

  test('loads an exported Games Tool project with linked files', () async {
    final GamesToolLoadedProject loaded = await repository.loadFromAssets(
      projectRoot: 'assets/exemple_0',
    );

    expect(loaded.project.name, 'Exemple 0');
    expect(loaded.project.levels.length, 2);
    expect(loaded.project.mediaAssets.length, 4);
    expect(loaded.project.animations, isNotEmpty);

    final GamesToolLevel firstLevel = loaded.project.levels.first;
    final GamesToolLayer firstLayer = firstLevel.layers.first;
    final GamesToolTileMapFile? tileMap = loaded.tileMapForLayer(firstLayer);

    expect(tileMap, isNotNull);
    expect(tileMap!.rowCount, greaterThan(0));
    expect(tileMap.columnCount, greaterThan(0));

    final GamesToolZonesFile? levelZones = loaded.zonesForLevel(firstLevel);
    expect(levelZones, isNotNull);
    expect(levelZones!.zones, isNotEmpty);

    expect(
      loaded.resolveAssetPath('media/16x16 Idle-Sheet.png'),
      'assets/exemple_0/media/16x16 Idle-Sheet.png',
    );
  });

  test('resolves preferred root with typo-like mismatch', () async {
    final GamesToolFlameLoader flameLoader = GamesToolFlameLoader(
      repository: repository,
    );

    final GamesToolProjectRootResolution resolution = await flameLoader
        .resolveProjectRoot(preferredRoot: 'assets/example_0');

    expect(resolution.resolvedRoot, 'assets/exemple_0');
    expect(resolution.availableRoots, contains('assets/exemple_0'));
  });

  test('resolves preferred root with misspelled assets prefix', () async {
    final GamesToolFlameLoader flameLoader = GamesToolFlameLoader(
      repository: repository,
    );

    final GamesToolProjectRootResolution resolution = await flameLoader
        .resolveProjectRoot(preferredRoot: 'asstes/example_0');

    expect(resolution.resolvedRoot, 'assets/exemple_0');
    expect(resolution.usedFallback, isTrue);
  });

  test('strict false skips missing sprite images during mount', () async {
    final GamesToolLevel level = GamesToolLevel(
      name: 'Level',
      description: '',
      layers: const <GamesToolLayer>[],
      layerGroups: const <GamesToolGroup>[],
      sprites: const <GamesToolSprite>[
        GamesToolStaticSprite(
          name: 'Missing',
          type: 'Test',
          imageFile: 'media/does_not_exist.png',
          x: 10,
          y: 20,
          width: 16,
          height: 16,
          flipX: false,
          flipY: false,
          depth: 0,
          groupId: '__main__',
        ),
      ],
      spriteGroups: const <GamesToolGroup>[],
      groupId: '__main__',
      viewportWidth: 320,
      viewportHeight: 180,
      viewportX: 0,
      viewportY: 0,
      viewportAdaptation: 'letterbox',
      backgroundColorHex: '#000000',
      zonesFile: '',
    );
    final GamesToolProject project = GamesToolProject(
      name: 'Project',
      projectComments: '',
      levels: <GamesToolLevel>[level],
      levelGroups: const <GamesToolGroup>[],
      mediaAssets: const <GamesToolMediaAsset>[],
      mediaGroups: const <GamesToolGroup>[],
      animations: const <GamesToolAnimation>[],
      animationGroups: const <GamesToolGroup>[],
      zoneTypes: const <GamesToolZoneType>[],
    );
    final GamesToolLoadedProject loadedProject = GamesToolLoadedProject(
      projectRoot: 'assets/exemple_0',
      project: project,
      tileMapsByRelativePath: const <String, GamesToolTileMapFile>{},
      zonesByRelativePath: const <String, GamesToolZonesFile>{},
      availableAssetPaths: const <String>{},
      missingMediaRelativePaths: const <String>{'media/does_not_exist.png'},
      rawJson: const <String, dynamic>{},
    );

    final GamesToolFlameLoader flameLoader = GamesToolFlameLoader();
    final FlameGame game = FlameGame();
    final GamesToolFlameMountResult result = await flameLoader.mountLoadedLevel(
      game: game,
      loadedProject: loadedProject,
      strict: false,
    );
    expect(result.spriteHandles, isEmpty);
  });

  test('sprite draw order follows sprite list order', () async {
    final GamesToolLevel level = GamesToolLevel(
      name: 'Level',
      description: '',
      layers: const <GamesToolLayer>[],
      layerGroups: const <GamesToolGroup>[],
      sprites: const <GamesToolSprite>[
        GamesToolStaticSprite(
          name: 'Back',
          type: 'Test',
          imageFile: 'media/16x16 Idle-Sheet.png',
          x: 0,
          y: 0,
          width: 20,
          height: 20,
          flipX: false,
          flipY: false,
          depth: 999,
          groupId: '__main__',
        ),
        GamesToolStaticSprite(
          name: 'Front',
          type: 'Test',
          imageFile: 'media/16x16 Idle-Sheet.png',
          x: 5,
          y: 5,
          width: 20,
          height: 20,
          flipX: false,
          flipY: false,
          depth: -999,
          groupId: '__main__',
        ),
      ],
      spriteGroups: const <GamesToolGroup>[],
      groupId: '__main__',
      viewportWidth: 320,
      viewportHeight: 180,
      viewportX: 0,
      viewportY: 0,
      viewportAdaptation: 'letterbox',
      backgroundColorHex: '#000000',
      zonesFile: '',
    );
    final GamesToolProject project = GamesToolProject(
      name: 'Project',
      projectComments: '',
      levels: <GamesToolLevel>[level],
      levelGroups: const <GamesToolGroup>[],
      mediaAssets: const <GamesToolMediaAsset>[
        GamesToolMediaAsset(
          name: 'Sheet',
          fileName: 'media/16x16 Idle-Sheet.png',
          mediaType: 'spritesheet',
          tileWidth: 20,
          tileHeight: 20,
          selectionColorHex: '#FFCC00',
          groupId: '__main__',
        ),
      ],
      mediaGroups: const <GamesToolGroup>[],
      animations: const <GamesToolAnimation>[],
      animationGroups: const <GamesToolGroup>[],
      zoneTypes: const <GamesToolZoneType>[],
    );
    final GamesToolLoadedProject loadedProject = GamesToolLoadedProject(
      projectRoot: 'assets/exemple_0',
      project: project,
      tileMapsByRelativePath: const <String, GamesToolTileMapFile>{},
      zonesByRelativePath: const <String, GamesToolZonesFile>{},
      availableAssetPaths: const <String>{
        'assets/exemple_0/media/16x16 Idle-Sheet.png',
      },
      missingMediaRelativePaths: const <String>{},
      rawJson: const <String, dynamic>{},
    );

    final GamesToolFlameLoader flameLoader = GamesToolFlameLoader();
    final FlameGame game = FlameGame();
    final GamesToolFlameMountResult result = await flameLoader.mountLoadedLevel(
      game: game,
      loadedProject: loadedProject,
      strict: true,
    );

    expect(result.spriteHandles.map((h) => h.sprite.name), <String>[
      'Back',
      'Front',
    ]);
    expect(
      result.spriteHandles[0].component.priority,
      lessThan(result.spriteHandles[1].component.priority),
    );
  });

  test('loaded level exposes reorder methods for draw-order lists', () async {
    final GamesToolLoadedProject loaded = await repository.loadFromAssets(
      projectRoot: 'assets/exemple_0',
    );
    final GamesToolLoadedLevel loadedLevel = loaded.loadedLevel(0);

    final String firstLayerName = loadedLevel.layers.first.name;
    loadedLevel.moveLayer(0, 1);
    expect(loadedLevel.layers[1].name, firstLayerName);

    final GamesToolLevel syntheticLevel = GamesToolLevel(
      name: 'Synthetic',
      description: '',
      layers: const <GamesToolLayer>[],
      layerGroups: const <GamesToolGroup>[],
      sprites: <GamesToolSprite>[
        GamesToolStaticSprite(
          name: 'One',
          type: 'Test',
          imageFile: 'media/16x16 Idle-Sheet.png',
          x: 0,
          y: 0,
          width: 20,
          height: 20,
          flipX: false,
          flipY: false,
          depth: 0,
          groupId: '__main__',
        ),
        GamesToolStaticSprite(
          name: 'Two',
          type: 'Test',
          imageFile: 'media/16x16 Idle-Sheet.png',
          x: 0,
          y: 0,
          width: 20,
          height: 20,
          flipX: false,
          flipY: false,
          depth: 0,
          groupId: '__main__',
        ),
      ],
      spriteGroups: const <GamesToolGroup>[],
      groupId: '__main__',
      viewportWidth: 320,
      viewportHeight: 180,
      viewportX: 0,
      viewportY: 0,
      viewportAdaptation: 'letterbox',
      backgroundColorHex: '#000000',
      zonesFile: '',
    );
    syntheticLevel.moveSprite(0, 1);
    expect(syntheticLevel.sprites.map((s) => s.name), <String>['Two', 'One']);

    if (loadedLevel.zones.length >= 2) {
      final String firstZoneType = loadedLevel.zones.first.type;
      loadedLevel.moveZone(0, 1);
      expect(loadedLevel.zones[1].type, firstZoneType);
    }
  });
}
