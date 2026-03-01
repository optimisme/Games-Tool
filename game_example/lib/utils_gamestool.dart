import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

class AnimationPlaybackConfig {
  const AnimationPlaybackConfig({
    required this.startFrame,
    required this.endFrame,
    required this.fps,
    required this.loop,
  });

  final int startFrame;
  final int endFrame;
  final double fps;
  final bool loop;

  int get frameCount => math.max(1, endFrame - startFrame + 1);
}

class GamesToolApi {
  const GamesToolApi({this.projectFolder = 'example_0'});
  static const double defaultParallaxSensitivity = 0.08;
  static const double defaultAnimationFps = 12.0;

  final String projectFolder;

  String get projectAssetsRoot => 'assets/$projectFolder';
  String get gameDataAssetPath => '$projectAssetsRoot/game_data.json';

  String toRelativeAssetKey(String relativePath) {
    final String normalizedPath = _normalizePath(relativePath);
    return '$projectFolder/$normalizedPath';
  }

  String toBundleAssetPath(String relativePath) {
    return 'assets/${toRelativeAssetKey(relativePath)}';
  }

  Future<Map<String, dynamic>> loadGameData(AssetBundle bundle) async {
    final String jsonString = await bundle.loadString(gameDataAssetPath);
    final Map<String, dynamic> parsed =
        jsonDecode(jsonString) as Map<String, dynamic>;
    await _attachTileMaps(bundle, parsed);
    await _attachZones(bundle, parsed);
    return parsed;
  }

  Set<String> collectReferencedImageFiles(Map<String, dynamic> gameData) {
    final Set<String> imageFiles = <String>{};
    final List<dynamic> levels =
        (gameData['levels'] as List<dynamic>?) ?? const <dynamic>[];

    for (final dynamic level in levels) {
      final List<dynamic> layers =
          (level['layers'] as List<dynamic>?) ?? const <dynamic>[];
      for (final dynamic layer in layers) {
        final Object? tilesSheetFile = layer['tilesSheetFile'];
        if (tilesSheetFile is String && tilesSheetFile.isNotEmpty) {
          imageFiles.add(_normalizePath(tilesSheetFile));
        }
      }

      final List<dynamic> sprites =
          (level['sprites'] as List<dynamic>?) ?? const <dynamic>[];
      for (final dynamic sprite in sprites) {
        final Object? imageFile = sprite['imageFile'];
        if (imageFile is String && imageFile.isNotEmpty) {
          imageFiles.add(_normalizePath(imageFile));
        }
      }
    }

    final List<dynamic> mediaAssets =
        (gameData['mediaAssets'] as List<dynamic>?) ?? const <dynamic>[];
    for (final dynamic media in mediaAssets) {
      final Object? fileName = media['fileName'];
      if (fileName is String && fileName.isNotEmpty) {
        imageFiles.add(_normalizePath(fileName));
      }
    }

    return imageFiles;
  }

  List<Map<String, dynamic>> listLevels(Map<String, dynamic> gameData) {
    final List<dynamic> levels =
        (gameData['levels'] as List<dynamic>?) ?? const <dynamic>[];
    return levels.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  Map<String, dynamic>? findLevelByIndex(
    Map<String, dynamic> gameData,
    int levelIndex,
  ) {
    final List<Map<String, dynamic>> levels = listLevels(gameData);
    if (levels.isEmpty) {
      return null;
    }
    final int safeIndex = levelIndex.clamp(0, levels.length - 1);
    return levels[safeIndex];
  }

  String levelNameByIndex(Map<String, dynamic> gameData, int levelIndex) {
    final Map<String, dynamic>? level = findLevelByIndex(gameData, levelIndex);
    return (level?['name'] as String?) ?? 'Level $levelIndex';
  }

  List<Map<String, dynamic>> listLevelLayers(
    Map<String, dynamic> level, {
    bool visibleOnly = false,
    bool painterOrder = false,
  }) {
    final List<Map<String, dynamic>> layers =
        ((level['layers'] as List<dynamic>?) ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .where((Map<String, dynamic> layer) {
      if (!visibleOnly) {
        return true;
      }
      return layer['visible'] == true;
    }).toList(growable: false);

    if (!painterOrder) {
      return layers;
    }
    return layers.reversed.toList(growable: false);
  }

  List<Map<String, dynamic>> levelZones(Map<String, dynamic> level) {
    return ((level['zones'] as List<dynamic>?) ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  List<Map<String, dynamic>> levelZoneGroups(Map<String, dynamic> level) {
    return ((level['zoneGroups'] as List<dynamic>?) ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  List<List<dynamic>> layerTileMapRows(Map<String, dynamic> layer) {
    return ((layer['tileMap'] as List<dynamic>?) ?? const <dynamic>[])
        .whereType<List<dynamic>>()
        .toList(growable: false);
  }

  String? layerTilesSheetFile(Map<String, dynamic> layer) {
    final Object? value = layer['tilesSheetFile'];
    if (value is! String || value.isEmpty) {
      return null;
    }
    return value;
  }

  double layerTilesWidth(Map<String, dynamic> layer, {double fallback = 16}) {
    final double? value = (layer['tilesWidth'] as num?)?.toDouble();
    if (value == null || !value.isFinite || value <= 0) {
      return fallback;
    }
    return value;
  }

  double layerTilesHeight(Map<String, dynamic> layer, {double fallback = 16}) {
    final double? value = (layer['tilesHeight'] as num?)?.toDouble();
    if (value == null || !value.isFinite || value <= 0) {
      return fallback;
    }
    return value;
  }

  double layerX(Map<String, dynamic> layer) {
    return (layer['x'] as num?)?.toDouble() ?? 0;
  }

  double layerY(Map<String, dynamic> layer) {
    return (layer['y'] as num?)?.toDouble() ?? 0;
  }

  double layerDepth(Map<String, dynamic> layer) {
    return (layer['depth'] as num?)?.toDouble() ?? 0;
  }

  double levelParallaxSensitivity(
    Map<String, dynamic> level, {
    double fallback = defaultParallaxSensitivity,
  }) {
    final double? raw = (level['parallaxSensitivity'] as num?)?.toDouble();
    if (raw == null || !raw.isFinite || raw < 0) {
      return fallback;
    }
    return raw;
  }

  double spriteWidth(Map<String, dynamic> sprite, {double fallback = 16}) {
    final double? value = (sprite['width'] as num?)?.toDouble();
    if (value == null || !value.isFinite || value <= 0) {
      return fallback;
    }
    return value;
  }

  double spriteHeight(Map<String, dynamic> sprite, {double fallback = 16}) {
    final double? value = (sprite['height'] as num?)?.toDouble();
    if (value == null || !value.isFinite || value <= 0) {
      return fallback;
    }
    return value;
  }

  double spriteX(Map<String, dynamic> sprite, {double fallback = 0}) {
    final double? value = (sprite['x'] as num?)?.toDouble();
    if (value == null || !value.isFinite) {
      return fallback;
    }
    return value;
  }

  double spriteY(Map<String, dynamic> sprite, {double fallback = 0}) {
    final double? value = (sprite['y'] as num?)?.toDouble();
    if (value == null || !value.isFinite) {
      return fallback;
    }
    return value;
  }

  String? spriteImageFile(Map<String, dynamic> sprite) {
    final Object? value = sprite['imageFile'];
    if (value is! String || value.isEmpty) {
      return null;
    }
    return value;
  }

  Map<String, dynamic>? findLevelByName(
    Map<String, dynamic> gameData,
    String levelName,
  ) {
    final List<Map<String, dynamic>> levels = listLevels(gameData);
    for (final Map<String, dynamic> level in levels) {
      if (level['name'] == levelName) {
        return level;
      }
    }
    return null;
  }

  Map<String, dynamic>? findSpriteByType(
    Map<String, dynamic> level,
    String spriteType,
  ) {
    final List<dynamic> sprites =
        (level['sprites'] as List<dynamic>?) ?? const <dynamic>[];
    for (final dynamic sprite in sprites) {
      if (sprite is Map<String, dynamic> && sprite['type'] == spriteType) {
        return sprite;
      }
    }
    return null;
  }

  Map<String, dynamic>? findFirstSprite(Map<String, dynamic> level) {
    final List<dynamic> sprites =
        (level['sprites'] as List<dynamic>?) ?? const <dynamic>[];
    if (sprites.isNotEmpty && sprites.first is Map<String, dynamic>) {
      return sprites.first as Map<String, dynamic>;
    }
    return null;
  }

  Map<String, dynamic>? findAnimationByName(
    Map<String, dynamic> gameData,
    String animationName,
  ) {
    final List<dynamic> animations =
        (gameData['animations'] as List<dynamic>?) ?? const <dynamic>[];
    for (final dynamic animation in animations) {
      if (animation is Map<String, dynamic> &&
          animation['name'] == animationName) {
        return animation;
      }
    }
    return null;
  }

  Map<String, dynamic>? findMediaAssetByFile(
    Map<String, dynamic> gameData,
    String fileName,
  ) {
    final String normalizedFileName = _normalizePath(fileName);
    final List<dynamic> mediaAssets =
        (gameData['mediaAssets'] as List<dynamic>?) ?? const <dynamic>[];
    for (final dynamic media in mediaAssets) {
      if (media is! Map<String, dynamic>) {
        continue;
      }
      final Object? mediaFileName = media['fileName'];
      if (mediaFileName is String &&
          _normalizePath(mediaFileName) == normalizedFileName) {
        return media;
      }
    }
    return null;
  }

  double mediaTileWidth(Map<String, dynamic> mediaAsset,
      {double fallback = 16}) {
    final double? value = (mediaAsset['tileWidth'] as num?)?.toDouble();
    if (value == null || !value.isFinite || value <= 0) {
      return fallback;
    }
    return value;
  }

  double mediaTileHeight(
    Map<String, dynamic> mediaAsset, {
    double fallback = 16,
  }) {
    final double? value = (mediaAsset['tileHeight'] as num?)?.toDouble();
    if (value == null || !value.isFinite || value <= 0) {
      return fallback;
    }
    return value;
  }

  AnimationPlaybackConfig animationPlaybackConfig(
    Map<String, dynamic> animationData, {
    double fallbackFps = defaultAnimationFps,
  }) {
    final int startFrame = (animationData['startFrame'] as num?)?.toInt() ?? 0;
    final int rawEndFrame =
        (animationData['endFrame'] as num?)?.toInt() ?? startFrame;
    final int endFrame = rawEndFrame < startFrame ? startFrame : rawEndFrame;
    final double rawFps =
        (animationData['fps'] as num?)?.toDouble() ?? fallbackFps;
    final double fps = rawFps.isFinite && rawFps > 0 ? rawFps : fallbackFps;
    final bool loop = (animationData['loop'] as bool?) ?? true;

    return AnimationPlaybackConfig(
      startFrame: startFrame,
      endFrame: endFrame,
      fps: fps,
      loop: loop,
    );
  }

  int animationFrameIndexAtTime({
    required AnimationPlaybackConfig playback,
    required double elapsedSeconds,
  }) {
    final int frameCount = playback.frameCount;
    int frameOffset = (elapsedSeconds * playback.fps).floor();
    if (playback.loop) {
      frameOffset = frameOffset % frameCount;
    } else if (frameOffset >= frameCount) {
      frameOffset = frameCount - 1;
    }
    return playback.startFrame + frameOffset;
  }

  Future<void> _attachTileMaps(
    AssetBundle bundle,
    Map<String, dynamic> gameData,
  ) async {
    final List<dynamic> levels =
        (gameData['levels'] as List<dynamic>?) ?? const <dynamic>[];

    for (final dynamic level in levels) {
      final List<dynamic> layers =
          (level['layers'] as List<dynamic>?) ?? const <dynamic>[];
      for (final dynamic layer in layers) {
        final Object? tileMapFile = layer['tileMapFile'];
        if (tileMapFile is! String || tileMapFile.isEmpty) {
          continue;
        }
        final String tileMapJson =
            await bundle.loadString(toBundleAssetPath(tileMapFile));
        final Map<String, dynamic> tileMapData =
            jsonDecode(tileMapJson) as Map<String, dynamic>;
        final Object? tileMap = tileMapData['tileMap'];
        if (tileMap is List<dynamic>) {
          layer['tileMap'] = tileMap;
        }
      }
    }
  }

  Future<void> _attachZones(
    AssetBundle bundle,
    Map<String, dynamic> gameData,
  ) async {
    final List<dynamic> levels =
        (gameData['levels'] as List<dynamic>?) ?? const <dynamic>[];

    for (final dynamic level in levels) {
      if (level is! Map<String, dynamic>) {
        continue;
      }

      final Object? zonesFile = level['zonesFile'];
      if (zonesFile is! String || zonesFile.isEmpty) {
        continue;
      }

      final String zonesJson =
          await bundle.loadString(toBundleAssetPath(zonesFile));
      final Map<String, dynamic> zonesData =
          jsonDecode(zonesJson) as Map<String, dynamic>;

      final Object? zones = zonesData['zones'];
      if (zones is List<dynamic>) {
        level['zones'] = zones;
      }

      final Object? zoneGroups = zonesData['zoneGroups'];
      if (zoneGroups is List<dynamic>) {
        level['zoneGroups'] = zoneGroups;
      }
    }
  }

  String _normalizePath(String path) {
    String normalized = path.replaceAll('\\', '/');
    if (normalized.startsWith('assets/')) {
      normalized = normalized.substring('assets/'.length);
    }
    if (normalized.startsWith('$projectFolder/')) {
      normalized = normalized.substring(projectFolder.length + 1);
    }
    if (normalized.startsWith('/')) {
      normalized = normalized.substring(1);
    }
    return normalized;
  }
}
