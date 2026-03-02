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
  GamesToolApi({this.projectFolder = 'levels'});
  static const double defaultDepthSensitivity = 0.08;
  static const double defaultAnimationFps = 12.0;
  static const double defaultAnchorX = 0.5;
  static const double defaultAnchorY = 0.5;
  static const double defaultViewportWidth = 320;
  static const double defaultViewportHeight = 180;
  static const String defaultViewportAdaptation = 'letterbox';

  final String projectFolder;
  String? _resolvedProjectFolder;

  String get activeProjectFolder => _resolvedProjectFolder ?? projectFolder;

  String get projectAssetsRoot => 'assets/$activeProjectFolder';
  String get gameDataAssetPath => '$projectAssetsRoot/game_data.json';

  String toRelativeAssetKey(String relativePath) {
    final String normalizedPath = _normalizePath(relativePath);
    return '$activeProjectFolder/$normalizedPath';
  }

  String toBundleAssetPath(String relativePath) {
    return 'assets/${toRelativeAssetKey(relativePath)}';
  }

  /// Loads exported game data and enriches it with tilemaps, zones, and animations.
  Future<Map<String, dynamic>> loadGameData(AssetBundle bundle) async {
    final ({String projectRoot, String jsonString}) loaded =
        await _loadGameDataJsonString(bundle);
    _resolvedProjectFolder = loaded.projectRoot;
    final String jsonString = loaded.jsonString;
    final Map<String, dynamic> parsed =
        jsonDecode(jsonString) as Map<String, dynamic>;
    await _attachTileMaps(bundle, parsed);
    await _attachZones(bundle, parsed);
    await _attachAnimations(bundle, parsed);
    return parsed;
  }

  /// Collects every image referenced by levels and media assets for preloading.
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

  double levelDepthSensitivity(
    Map<String, dynamic> level, {
    double fallback = defaultDepthSensitivity,
  }) {
    final double? raw = (level['depthSensitivity'] as num?)?.toDouble();
    if (raw == null || !raw.isFinite || raw < 0) {
      return fallback;
    }
    return raw;
  }

  double levelViewportWidth(
    Map<String, dynamic> level, {
    double fallback = defaultViewportWidth,
  }) {
    return _positiveFiniteDouble(level['viewportWidth'], fallback);
  }

  double levelViewportHeight(
    Map<String, dynamic> level, {
    double fallback = defaultViewportHeight,
  }) {
    return _positiveFiniteDouble(level['viewportHeight'], fallback);
  }

  double levelViewportX(
    Map<String, dynamic> level, {
    double fallback = 0,
  }) {
    return _finiteDouble(level['viewportX'], fallback);
  }

  double levelViewportY(
    Map<String, dynamic> level, {
    double fallback = 0,
  }) {
    return _finiteDouble(level['viewportY'], fallback);
  }

  String levelViewportAdaptation(
    Map<String, dynamic> level, {
    String fallback = defaultViewportAdaptation,
  }) {
    final String? adaptation = (level['viewportAdaptation'] as String?)?.trim();
    if (adaptation == null || adaptation.isEmpty) {
      return fallback;
    }
    return adaptation;
  }

  String? levelViewportInitialColorName(Map<String, dynamic> level) {
    final String? value = (level['viewportInitialColor'] as String?)?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  String? levelViewportPreviewColorName(Map<String, dynamic> level) {
    final String? value = (level['viewportPreviewColor'] as String?)?.trim();
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  String levelBackgroundColorHex(
    Map<String, dynamic> level, {
    String fallback = '#000000',
  }) {
    final String? value = (level['backgroundColorHex'] as String?)?.trim();
    if (value == null || value.isEmpty) {
      return fallback;
    }
    return value;
  }

  double levelViewportCenterX(
    Map<String, dynamic> level, {
    double fallbackWidth = defaultViewportWidth,
    double fallbackX = 0,
  }) {
    return levelViewportX(level, fallback: fallbackX) +
        levelViewportWidth(level, fallback: fallbackWidth) * 0.5;
  }

  double levelViewportCenterY(
    Map<String, dynamic> level, {
    double fallbackHeight = defaultViewportHeight,
    double fallbackY = 0,
  }) {
    return levelViewportY(level, fallback: fallbackY) +
        levelViewportHeight(level, fallback: fallbackHeight) * 0.5;
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

  double spriteDepth(Map<String, dynamic> sprite, {double fallback = 0}) {
    final double? value = (sprite['depth'] as num?)?.toDouble();
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

  Map<String, dynamic>? findAnimationById(
    Map<String, dynamic> gameData,
    String animationId,
  ) {
    if (animationId.isEmpty) {
      return null;
    }
    final List<dynamic> animations =
        (gameData['animations'] as List<dynamic>?) ?? const <dynamic>[];
    for (final dynamic animation in animations) {
      if (animation is Map<String, dynamic> && animation['id'] == animationId) {
        return animation;
      }
    }
    return null;
  }

  Map<String, dynamic>? findAnimationForSprite(
    Map<String, dynamic> gameData,
    Map<String, dynamic> sprite,
  ) {
    final String animationId = (sprite['animationId'] as String?) ?? '';
    final Map<String, dynamic>? byId = findAnimationById(gameData, animationId);
    if (byId != null) {
      return byId;
    }

    final String? spriteFile = spriteImageFile(sprite);
    if (spriteFile == null) {
      return null;
    }

    final String normalizedSpriteFile = _normalizePath(spriteFile);
    final List<dynamic> animations =
        (gameData['animations'] as List<dynamic>?) ?? const <dynamic>[];
    for (final dynamic animation in animations) {
      if (animation is! Map<String, dynamic>) {
        continue;
      }
      final Object? mediaFile = animation['mediaFile'];
      if (mediaFile is String &&
          _normalizePath(mediaFile) == normalizedSpriteFile) {
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

  double animationAnchorX(
    Map<String, dynamic> animationData, {
    double fallback = defaultAnchorX,
  }) {
    return _normalizedAnchorValue(animationData['anchorX'], fallback);
  }

  double animationAnchorY(
    Map<String, dynamic> animationData, {
    double fallback = defaultAnchorY,
  }) {
    return _normalizedAnchorValue(animationData['anchorY'], fallback);
  }

  double animationAnchorXForFrame(
    Map<String, dynamic> animationData, {
    required int frameIndex,
    double fallback = defaultAnchorX,
  }) {
    final Map<String, dynamic>? frameRig =
        animationFrameRig(animationData, frameIndex: frameIndex);
    if (frameRig != null) {
      return _normalizedAnchorValue(
        frameRig['anchorX'],
        animationAnchorX(animationData, fallback: fallback),
      );
    }
    return animationAnchorX(animationData, fallback: fallback);
  }

  double animationAnchorYForFrame(
    Map<String, dynamic> animationData, {
    required int frameIndex,
    double fallback = defaultAnchorY,
  }) {
    final Map<String, dynamic>? frameRig =
        animationFrameRig(animationData, frameIndex: frameIndex);
    if (frameRig != null) {
      return _normalizedAnchorValue(
        frameRig['anchorY'],
        animationAnchorY(animationData, fallback: fallback),
      );
    }
    return animationAnchorY(animationData, fallback: fallback);
  }

  Map<String, dynamic>? animationFrameRig(
    Map<String, dynamic> animationData, {
    required int frameIndex,
  }) {
    final List<dynamic> frameRigs =
        (animationData['frameRigs'] as List<dynamic>?) ?? const <dynamic>[];
    for (final dynamic rig in frameRigs) {
      if (rig is! Map<String, dynamic>) {
        continue;
      }
      final int? rigFrame = (rig['frame'] as num?)?.toInt();
      if (rigFrame == frameIndex) {
        return rig;
      }
    }
    return null;
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

  Future<void> _attachAnimations(
    AssetBundle bundle,
    Map<String, dynamic> gameData,
  ) async {
    final Object? animationsFile = gameData['animationsFile'];
    if (animationsFile is! String || animationsFile.isEmpty) {
      return;
    }

    final String animationsJson =
        await bundle.loadString(toBundleAssetPath(animationsFile));
    final Map<String, dynamic> animationsData =
        jsonDecode(animationsJson) as Map<String, dynamic>;

    final Object? animations = animationsData['animations'];
    if (animations is List<dynamic>) {
      gameData['animations'] = animations;
    }

    final Object? animationGroups = animationsData['animationGroups'];
    if (animationGroups is List<dynamic>) {
      gameData['animationGroups'] = animationGroups;
    }
  }

  Future<({String projectRoot, String jsonString})> _loadGameDataJsonString(
    AssetBundle bundle,
  ) async {
    final List<String> candidates = <String>[
      _normalizeRootFolder(projectFolder),
      'levels',
      'exemple_0',
      'example_0',
      ...await _discoverProjectRoots(bundle),
    ];

    final Set<String> tried = <String>{};
    for (final String candidate in candidates) {
      final String normalized = _normalizeRootFolder(candidate);
      if (normalized.isEmpty || tried.contains(normalized)) {
        continue;
      }
      tried.add(normalized);
      final String gameDataPath = 'assets/$normalized/game_data.json';
      try {
        final String jsonString = await bundle.loadString(gameDataPath);
        return (projectRoot: normalized, jsonString: jsonString);
      } catch (_) {
        // Keep trying additional candidates until one resolves.
      }
    }

    throw StateError(
      'Unable to locate games_tool export data. Tried: '
      '${tried.map((root) => 'assets/$root/game_data.json').join(', ')}',
    );
  }

  Future<List<String>> _discoverProjectRoots(AssetBundle bundle) async {
    try {
      final String manifestRaw = await bundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifest =
          jsonDecode(manifestRaw) as Map<String, dynamic>;
      final Set<String> roots = <String>{};
      for (final String key in manifest.keys) {
        final String normalized = key.replaceAll('\\', '/');
        if (!normalized.startsWith('assets/') ||
            !normalized.endsWith('/game_data.json')) {
          continue;
        }
        final String root = normalized
            .substring(
                'assets/'.length, normalized.length - '/game_data.json'.length)
            .trim();
        if (root.isNotEmpty) {
          roots.add(_normalizeRootFolder(root));
        }
      }
      return roots.toList(growable: false);
    } catch (_) {
      return const <String>[];
    }
  }

  String _normalizePath(String path) {
    String normalized = path.replaceAll('\\', '/');
    if (normalized.startsWith('assets/')) {
      normalized = normalized.substring('assets/'.length);
    }
    final String activeRoot = activeProjectFolder;
    if (normalized.startsWith('$activeRoot/')) {
      normalized = normalized.substring(activeRoot.length + 1);
    }
    if (normalized.startsWith('/')) {
      normalized = normalized.substring(1);
    }
    return normalized;
  }

  String _normalizeRootFolder(String path) {
    String normalized = path.replaceAll('\\', '/').trim();
    if (normalized.startsWith('assets/')) {
      normalized = normalized.substring('assets/'.length);
    }
    if (normalized.endsWith('/game_data.json')) {
      normalized =
          normalized.substring(0, normalized.length - '/game_data.json'.length);
    }
    while (normalized.startsWith('/')) {
      normalized = normalized.substring(1);
    }
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  double _normalizedAnchorValue(Object? value, double fallback) {
    final double fallbackSafe =
        fallback.isFinite ? fallback.clamp(0.0, 1.0).toDouble() : 0.5;
    final double? raw = (value as num?)?.toDouble();
    if (raw == null || !raw.isFinite) {
      return fallbackSafe;
    }
    return raw.clamp(0.0, 1.0).toDouble();
  }

  double _positiveFiniteDouble(Object? value, double fallback) {
    final double safeFallback =
        (fallback.isFinite && fallback > 0) ? fallback : 1;
    final double? raw = (value as num?)?.toDouble();
    if (raw == null || !raw.isFinite || raw <= 0) {
      return safeFallback;
    }
    return raw;
  }

  double _finiteDouble(Object? value, double fallback) {
    final double safeFallback = fallback.isFinite ? fallback : 0;
    final double? raw = (value as num?)?.toDouble();
    if (raw == null || !raw.isFinite) {
      return safeFallback;
    }
    return raw;
  }
}
