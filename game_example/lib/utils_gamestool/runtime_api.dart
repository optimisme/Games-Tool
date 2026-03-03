import 'dart:math' as math;

import 'package:flutter/services.dart';

import 'project_data_api.dart';
import 'runtime_math.dart';
import 'runtime_models.dart';

class GameDataRuntimeApi {
  GameDataRuntimeApi({GamesToolApi? gamesTool})
      : _gamesTool = gamesTool ?? GamesToolApi();

  GamesToolApi _gamesTool;
  Map<String, dynamic> _gameData = <String, dynamic>{};
  int _currentFrameId = 0;
  final Map<String, _CollisionFrameState> _previousStateBySpriteKey =
      <String, _CollisionFrameState>{};
  final Map<String, RuntimeTrackedTransform2D> _transform2DById =
      <String, RuntimeTrackedTransform2D>{};

  GamesToolApi get gamesTool => _gamesTool;
  Map<String, dynamic> get gameData => _gameData;
  bool get isReady => _gameData.isNotEmpty;
  int get currentFrameId => _currentFrameId;

  Future<void> loadFromAssets({
    required AssetBundle bundle,
    String? projectRoot,
  }) async {
    final GamesToolApi loader = projectRoot == null
        ? _gamesTool
        : GamesToolApi(projectFolder: projectRoot);
    _gameData = await loader.loadGameData(bundle);
    _gamesTool = loader;
    resetFrameState();
  }

  void useLoadedGameData(
    Map<String, dynamic> gameData, {
    GamesToolApi? gamesTool,
  }) {
    _gameData = gameData;
    if (gamesTool != null) {
      _gamesTool = gamesTool;
    }
    resetFrameState();
  }

  Object? gameDataGet(List<Object> path) {
    if (path.isEmpty) {
      return _gameData;
    }
    dynamic current = _gameData;
    for (final Object segment in path) {
      final ({bool found, dynamic value}) next = _resolvePathSegment(
        current,
        segment,
      );
      if (!next.found) {
        return null;
      }
      current = next.value;
    }
    return current;
  }

  T? gameDataGetAs<T>(List<Object> path) {
    final Object? value = gameDataGet(path);
    return value is T ? value : null;
  }

  bool gameDataHasPath(List<Object> path) {
    if (path.isEmpty) {
      return isReady;
    }
    dynamic current = _gameData;
    for (final Object segment in path) {
      final ({bool found, dynamic value}) next = _resolvePathSegment(
        current,
        segment,
      );
      if (!next.found) {
        return false;
      }
      current = next.value;
    }
    return true;
  }

  void gameDataSet(List<Object> path, Object? value) {
    if (path.isEmpty) {
      throw ArgumentError('Path must not be empty.');
    }

    dynamic current = _gameData;
    for (int i = 0; i < path.length - 1; i++) {
      final Object segment = path[i];
      final ({bool found, dynamic value}) next = _resolvePathSegment(
        current,
        segment,
      );
      if (!next.found) {
        throw StateError('Invalid path at segment: $segment');
      }
      current = next.value;
    }

    final Object leaf = path.last;
    if (leaf is String && current is Map<String, dynamic>) {
      current[leaf] = value;
      return;
    }
    if (leaf is int && current is List<dynamic>) {
      if (leaf < 0 || leaf >= current.length) {
        throw RangeError.index(leaf, current, 'index');
      }
      current[leaf] = value;
      return;
    }
    throw StateError('Invalid leaf segment: $leaf');
  }

  void gameDataSetMany(List<GameDataPathUpdate> updates) {
    for (final GameDataPathUpdate update in updates) {
      gameDataSet(update.path, update.value);
    }
  }

  Map<String, dynamic>? levelByIndex(int levelIndex) {
    return _gamesTool.findLevelByIndex(_gameData, levelIndex);
  }

  Map<String, dynamic>? levelByName(String levelName) {
    return _gamesTool.findLevelByName(_gameData, levelName);
  }

  List<Rect> zoneRectsByTypeOrName({
    required int levelIndex,
    required String value,
    bool caseInsensitive = true,
    bool requirePositiveSize = true,
  }) {
    final Map<String, dynamic>? level = levelByIndex(levelIndex);
    return _gamesTool.zoneRectsByTypeOrName(
      level,
      value,
      caseInsensitive: caseInsensitive,
      requirePositiveSize: requirePositiveSize,
    );
  }

  RuntimeLevelViewport levelViewportByIndex({
    required int levelIndex,
    double fallbackWidth = GamesToolApi.defaultViewportWidth,
    double fallbackHeight = GamesToolApi.defaultViewportHeight,
    String fallbackAdaptation = GamesToolApi.defaultViewportAdaptation,
  }) {
    final Map<String, dynamic>? level = levelByIndex(levelIndex);
    if (level == null) {
      return RuntimeLevelViewport(
        width: fallbackWidth,
        height: fallbackHeight,
        x: 0,
        y: 0,
        adaptation: fallbackAdaptation,
      );
    }
    return RuntimeLevelViewport(
      width: _gamesTool.levelViewportWidth(level, fallback: fallbackWidth),
      height: _gamesTool.levelViewportHeight(level, fallback: fallbackHeight),
      x: _gamesTool.levelViewportX(level),
      y: _gamesTool.levelViewportY(level),
      adaptation: _gamesTool.levelViewportAdaptation(level,
          fallback: fallbackAdaptation),
      initialColorName: _gamesTool.levelViewportInitialColorName(level),
      previewColorName: _gamesTool.levelViewportPreviewColorName(level),
    );
  }

  Map<String, dynamic>? layerByIndex({
    required int levelIndex,
    required int layerIndex,
  }) {
    final Map<String, dynamic>? level = levelByIndex(levelIndex);
    if (level == null) {
      return null;
    }
    final List<Map<String, dynamic>> layers =
        ((level['layers'] as List<dynamic>?) ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);
    if (layerIndex < 0 || layerIndex >= layers.length) {
      return null;
    }
    return layers[layerIndex];
  }

  Map<String, dynamic>? layerByName({
    required int levelIndex,
    required String layerName,
  }) {
    final Map<String, dynamic>? level = levelByIndex(levelIndex);
    if (level == null) {
      return null;
    }
    final List<Map<String, dynamic>> layers =
        ((level['layers'] as List<dynamic>?) ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);
    for (final Map<String, dynamic> layer in layers) {
      if ((layer['name'] as String?) == layerName) {
        return layer;
      }
    }
    return null;
  }

  Map<String, dynamic>? spriteByIndex({
    required int levelIndex,
    required int spriteIndex,
  }) {
    final Map<String, dynamic>? level = levelByIndex(levelIndex);
    if (level == null) {
      return null;
    }
    final List<Map<String, dynamic>> sprites = _spritesOfLevel(level);
    if (spriteIndex < 0 || spriteIndex >= sprites.length) {
      return null;
    }
    return sprites[spriteIndex];
  }

  List<Rect> spriteCollisionRects({
    required int levelIndex,
    required int spriteIndex,
    RuntimeSpritePose? pose,
    int? frameIndex,
    double elapsedSeconds = 0,
  }) {
    if (!isReady) {
      return const <Rect>[];
    }
    final List<WorldHitBox> hitBoxes = spriteHitBoxes(
      levelIndex: levelIndex,
      spriteIndex: spriteIndex,
      pose: pose,
      frameIndex: frameIndex,
      elapsedSeconds: elapsedSeconds,
    );
    if (hitBoxes.isNotEmpty) {
      return hitBoxes.map((WorldHitBox hitBox) => hitBox.rectWorld).toList(
            growable: false,
          );
    }
    final Rect? anchoredRect = spriteAnchoredRect(
      levelIndex: levelIndex,
      spriteIndex: spriteIndex,
      pose: pose,
      elapsedSeconds: elapsedSeconds,
    );
    if (anchoredRect == null) {
      return const <Rect>[];
    }
    return <Rect>[anchoredRect];
  }

  Rect? spriteAnchoredRect({
    required int levelIndex,
    required int spriteIndex,
    RuntimeSpritePose? pose,
    double elapsedSeconds = 0,
  }) {
    final Map<String, dynamic>? sprite = spriteByIndex(
      levelIndex: levelIndex,
      spriteIndex: spriteIndex,
    );
    if (sprite == null) {
      return null;
    }
    final Map<String, dynamic>? animation =
        _gamesTool.findAnimationForSprite(_gameData, sprite);
    final String? spriteImageFile = _gamesTool.spriteImageFile(sprite);
    final String? animationMediaFile = animation?['mediaFile'] as String?;
    final String effectiveFile =
        (animationMediaFile != null && animationMediaFile.isNotEmpty)
            ? animationMediaFile
            : (spriteImageFile ?? '');
    final Map<String, dynamic>? mediaAsset = effectiveFile.isEmpty
        ? null
        : _gamesTool.findMediaAssetByFile(_gameData, effectiveFile);
    final double frameWidth = mediaAsset == null
        ? _gamesTool.spriteWidth(sprite)
        : _gamesTool.mediaTileWidth(
            mediaAsset,
            fallback: _gamesTool.spriteWidth(sprite),
          );
    final double frameHeight = mediaAsset == null
        ? _gamesTool.spriteHeight(sprite)
        : _gamesTool.mediaTileHeight(
            mediaAsset,
            fallback: _gamesTool.spriteHeight(sprite),
          );
    if (frameWidth <= 0 || frameHeight <= 0) {
      return null;
    }

    double anchorX = GamesToolApi.defaultAnchorX;
    double anchorY = GamesToolApi.defaultAnchorY;
    if (animation != null) {
      final AnimationPlaybackConfig playback =
          _gamesTool.animationPlaybackConfig(animation);
      final int resolvedFrameIndex = pose?.frameIndex ??
          _gamesTool.animationFrameIndexAtTime(
            playback: playback,
            elapsedSeconds: pose?.elapsedSeconds ?? elapsedSeconds,
          );
      anchorX = _gamesTool.animationAnchorXForFrame(
        animation,
        frameIndex: resolvedFrameIndex,
      );
      anchorY = _gamesTool.animationAnchorYForFrame(
        animation,
        frameIndex: resolvedFrameIndex,
      );
    }

    final double worldX = pose?.x ?? _gamesTool.spriteX(sprite);
    final double worldY = pose?.y ?? _gamesTool.spriteY(sprite);
    final double left = worldX - frameWidth * anchorX;
    final double top = worldY - frameHeight * anchorY;
    return Rect.fromLTWH(left, top, frameWidth, frameHeight);
  }

  double depthProjectionFactorForDepth(
    double depth, {
    double sensitivity = GamesToolApi.defaultDepthSensitivity,
  }) {
    return RuntimeCameraMath.depthProjectionFactorForDepth(
      depth,
      sensitivity: sensitivity,
    );
  }

  double cameraScaleForViewport({
    required Size viewportSize,
    required RuntimeCamera2D camera,
  }) {
    return RuntimeCameraMath.cameraScaleForViewport(
      viewportSize: viewportSize,
      focal: camera.focal,
    );
  }

  /// Converts frame delta time to instantaneous FPS.
  /// Returns 0 when `dtSeconds` is non-finite or non-positive.
  double fpsFromDeltaTime(
    double dtSeconds, {
    double minDtSeconds = 0.000001,
  }) {
    if (!dtSeconds.isFinite || dtSeconds <= 0) {
      return 0;
    }
    final double safeDt = dtSeconds < minDtSeconds ? minDtSeconds : dtSeconds;
    return 1 / safeDt;
  }

  /// Exponential moving average FPS counter update.
  ///
  /// `smoothing` closer to 1 produces a steadier value.
  double updateSmoothedFps({
    required double previousFps,
    required double dtSeconds,
    double smoothing = 0.9,
  }) {
    final double current = fpsFromDeltaTime(dtSeconds);
    if (current <= 0) {
      return previousFps.isFinite ? previousFps : 0;
    }
    if (!previousFps.isFinite || previousFps <= 0) {
      return current;
    }
    final double clampedSmoothing = smoothing.clamp(0.0, 0.9999);
    return previousFps * clampedSmoothing + current * (1 - clampedSmoothing);
  }

  Offset worldToScreen({
    required double worldX,
    required double worldY,
    required RuntimeCamera2D camera,
    required Size viewportSize,
    double depth = 0,
    double depthSensitivity = GamesToolApi.defaultDepthSensitivity,
  }) {
    return RuntimeCameraMath.worldToScreen(
      worldX: worldX,
      worldY: worldY,
      camera: camera,
      viewportSize: viewportSize,
      depth: depth,
      depthSensitivity: depthSensitivity,
    );
  }

  Offset? screenToWorld({
    required double screenX,
    required double screenY,
    required RuntimeCamera2D camera,
    required Size viewportSize,
    double depth = 0,
    double depthSensitivity = GamesToolApi.defaultDepthSensitivity,
  }) {
    return RuntimeCameraMath.screenToWorld(
      screenX: screenX,
      screenY: screenY,
      camera: camera,
      viewportSize: viewportSize,
      depth: depth,
      depthSensitivity: depthSensitivity,
    );
  }

  /// Resolves an anchor-aware focus point inside the sprite world rect.
  ///
  /// By default this uses animation-level anchors (stable) instead of frame-rig
  /// anchors to avoid camera jitter when per-frame anchor values drift.
  Offset spriteFocusPoint({
    required int levelIndex,
    required int spriteIndex,
    RuntimeSpritePose? pose,
    int? frameIndex,
    double elapsedSeconds = 0,
    double normalizedX = 0.5,
    double normalizedY = 0.5,
    bool useFrameRigAnchor = false,
    double fallbackX = 0,
    double fallbackY = 0,
  }) {
    final double focusX = normalizedX.clamp(0.0, 1.0);
    final double focusY = normalizedY.clamp(0.0, 1.0);

    final Map<String, dynamic>? sprite = spriteByIndex(
      levelIndex: levelIndex,
      spriteIndex: spriteIndex,
    );
    if (sprite == null) {
      return Offset(fallbackX, fallbackY);
    }

    final Map<String, dynamic>? animation =
        _gamesTool.findAnimationForSprite(_gameData, sprite);
    final Size frameSize = _spriteFrameSize(
      sprite: sprite,
      animation: animation,
    );
    if (frameSize.width <= 0 || frameSize.height <= 0) {
      final double baseX = pose?.x ?? _gamesTool.spriteX(sprite);
      final double baseY = pose?.y ?? _gamesTool.spriteY(sprite);
      return Offset(baseX, baseY);
    }

    double anchorX = GamesToolApi.defaultAnchorX;
    double anchorY = GamesToolApi.defaultAnchorY;
    if (animation != null) {
      if (useFrameRigAnchor) {
        final int resolvedFrameIndex = frameIndex ??
            pose?.frameIndex ??
            _resolveAnimationFrameIndex(
              animation: animation,
              elapsedSeconds: pose?.elapsedSeconds ?? elapsedSeconds,
            );
        anchorX = _gamesTool.animationAnchorXForFrame(
          animation,
          frameIndex: resolvedFrameIndex,
        );
        anchorY = _gamesTool.animationAnchorYForFrame(
          animation,
          frameIndex: resolvedFrameIndex,
        );
      } else {
        anchorX = _gamesTool.animationAnchorX(animation);
        anchorY = _gamesTool.animationAnchorY(animation);
      }
    }

    final double baseX = pose?.x ?? _gamesTool.spriteX(sprite);
    final double baseY = pose?.y ?? _gamesTool.spriteY(sprite);
    final double left = baseX - frameSize.width * anchorX;
    final double top = baseY - frameSize.height * anchorY;
    return Offset(
      left + frameSize.width * focusX,
      top + frameSize.height * focusY,
    );
  }

  /// Converts a world position to a tile coordinate in a target layer.
  /// Returns null when coordinates are outside the layer tilemap bounds.
  TileCoord? worldToTile({
    required int levelIndex,
    int? layerIndex,
    String? layerName,
    required double worldX,
    required double worldY,
    double? depthDisplacement,
  }) {
    final Map<String, dynamic>? layer = _resolveLayer(
      levelIndex: levelIndex,
      layerIndex: layerIndex,
      layerName: layerName,
    );
    if (layer == null) {
      return null;
    }

    final List<List<dynamic>> rows = _gamesTool.layerTileMapRows(layer);
    if (rows.isEmpty) {
      return null;
    }
    final int colsCount = rows.first.length;
    if (colsCount <= 0) {
      return null;
    }

    final double tileW = _gamesTool.layerTilesWidth(layer);
    final double tileH = _gamesTool.layerTilesHeight(layer);
    if (tileW <= 0 || tileH <= 0) {
      return null;
    }

    _resolveLayerDepthDisplacement(
      layer: layer,
      depthDisplacement: depthDisplacement,
    );
    final double localX = worldX - _gamesTool.layerX(layer);
    final double localY = worldY - _gamesTool.layerY(layer);
    final int tileX = (localX / tileW).floor();
    final int tileY = (localY / tileH).floor();

    if (tileX < 0 || tileY < 0 || tileY >= rows.length || tileX >= colsCount) {
      return null;
    }
    return TileCoord(tileX, tileY);
  }

  TileCoord? screenToTile({
    required int levelIndex,
    int? layerIndex,
    String? layerName,
    required double screenX,
    required double screenY,
    required RuntimeCamera2D camera,
    required Size viewportSize,
    double? depthDisplacement,
    double? depthSensitivity,
  }) {
    final Map<String, dynamic>? layer = _resolveLayer(
      levelIndex: levelIndex,
      layerIndex: layerIndex,
      layerName: layerName,
    );
    final Map<String, dynamic>? level = levelByIndex(levelIndex);
    if (layer == null || level == null) {
      return null;
    }
    final double resolvedDepth = _resolveLayerDepthDisplacement(
      layer: layer,
      depthDisplacement: depthDisplacement,
    );
    final double resolvedDepthSensitivity =
        depthSensitivity ?? _gamesTool.levelDepthSensitivity(level);
    final Offset? world = screenToWorld(
      screenX: screenX,
      screenY: screenY,
      camera: camera,
      viewportSize: viewportSize,
      depth: resolvedDepth,
      depthSensitivity: resolvedDepthSensitivity,
    );
    if (world == null) {
      return null;
    }

    return worldToTile(
      levelIndex: levelIndex,
      layerIndex: layerIndex,
      layerName: layerName,
      worldX: world.dx,
      worldY: world.dy,
      depthDisplacement: resolvedDepth,
    );
  }

  /// Reads tile id at a coordinate and returns -1 when unavailable/invalid.
  int tileAt({
    required int levelIndex,
    int? layerIndex,
    String? layerName,
    required int tileX,
    required int tileY,
  }) {
    final Map<String, dynamic>? layer = _resolveLayer(
      levelIndex: levelIndex,
      layerIndex: layerIndex,
      layerName: layerName,
    );
    if (layer == null) {
      return -1;
    }
    final List<List<dynamic>> rows = _gamesTool.layerTileMapRows(layer);
    if (tileY < 0 ||
        tileX < 0 ||
        tileY >= rows.length ||
        rows.isEmpty ||
        tileX >= rows[tileY].length) {
      return -1;
    }
    return (rows[tileY][tileX] as num?)?.toInt() ?? -1;
  }

  Rect? tileWorldRect({
    required int levelIndex,
    int? layerIndex,
    String? layerName,
    required int tileX,
    required int tileY,
    double? depthDisplacement,
  }) {
    final Map<String, dynamic>? layer = _resolveLayer(
      levelIndex: levelIndex,
      layerIndex: layerIndex,
      layerName: layerName,
    );
    if (layer == null) {
      return null;
    }
    final double tileW = _gamesTool.layerTilesWidth(layer);
    final double tileH = _gamesTool.layerTilesHeight(layer);
    if (tileW <= 0 || tileH <= 0) {
      return null;
    }
    _resolveLayerDepthDisplacement(
      layer: layer,
      depthDisplacement: depthDisplacement,
    );
    final double left = _gamesTool.layerX(layer) + tileX * tileW;
    final double top = _gamesTool.layerY(layer) + tileY * tileH;
    return Rect.fromLTWH(left, top, tileW, tileH);
  }

  Rect? tileScreenRect({
    required int levelIndex,
    int? layerIndex,
    String? layerName,
    required int tileX,
    required int tileY,
    required RuntimeCamera2D camera,
    required Size viewportSize,
    double? depthDisplacement,
    double? depthSensitivity,
  }) {
    final Map<String, dynamic>? layer = _resolveLayer(
      levelIndex: levelIndex,
      layerIndex: layerIndex,
      layerName: layerName,
    );
    final Map<String, dynamic>? level = levelByIndex(levelIndex);
    if (layer == null || level == null) {
      return null;
    }
    final Rect? worldRect = tileWorldRect(
      levelIndex: levelIndex,
      layerIndex: layerIndex,
      layerName: layerName,
      tileX: tileX,
      tileY: tileY,
      depthDisplacement: depthDisplacement,
    );
    if (worldRect == null) {
      return null;
    }

    final double resolvedDepth = _resolveLayerDepthDisplacement(
      layer: layer,
      depthDisplacement: depthDisplacement,
    );
    final double resolvedDepthSensitivity =
        depthSensitivity ?? _gamesTool.levelDepthSensitivity(level);
    final Offset topLeft = worldToScreen(
      worldX: worldRect.left,
      worldY: worldRect.top,
      camera: camera,
      viewportSize: viewportSize,
      depth: resolvedDepth,
      depthSensitivity: resolvedDepthSensitivity,
    );
    final double scale = cameraScaleForViewport(
      viewportSize: viewportSize,
      camera: camera,
    );
    final double depthScale = RuntimeCameraMath.depthScaleForDepth(
      resolvedDepth,
      sensitivity: resolvedDepthSensitivity,
    );
    if (scale == 0) {
      return null;
    }

    return Rect.fromLTWH(
      topLeft.dx,
      topLeft.dy,
      worldRect.width * scale * depthScale,
      worldRect.height * scale * depthScale,
    );
  }

  List<int> spriteIndicesInGroup({
    required int levelIndex,
    required String groupId,
  }) {
    final Map<String, dynamic>? level = levelByIndex(levelIndex);
    if (level == null) {
      return const <int>[];
    }
    final List<Map<String, dynamic>> sprites = _spritesOfLevel(level);
    final List<int> indices = <int>[];
    for (int i = 0; i < sprites.length; i++) {
      if ((sprites[i]['groupId'] as String? ?? '') == groupId) {
        indices.add(i);
      }
    }
    return indices;
  }

  List<int> zoneIndicesInGroup({
    required int levelIndex,
    required String groupId,
  }) {
    final Map<String, dynamic>? level = levelByIndex(levelIndex);
    if (level == null) {
      return const <int>[];
    }
    final List<Map<String, dynamic>> zones = _zonesOfLevel(level);
    final List<int> indices = <int>[];
    for (int i = 0; i < zones.length; i++) {
      if ((zones[i]['groupId'] as String? ?? '') == groupId) {
        indices.add(i);
      }
    }
    return indices;
  }

  List<WorldHitBox> spriteHitBoxes({
    required int levelIndex,
    required int spriteIndex,
    RuntimeSpritePose? pose,
    int? frameIndex,
    double elapsedSeconds = 0,
  }) {
    final Map<String, dynamic>? sprite = spriteByIndex(
      levelIndex: levelIndex,
      spriteIndex: spriteIndex,
    );
    if (sprite == null) {
      return const <WorldHitBox>[];
    }

    final String spriteKey = _spriteKey(levelIndex, spriteIndex);
    final double spriteX = pose?.x ?? _gamesTool.spriteX(sprite);
    final double spriteY = pose?.y ?? _gamesTool.spriteY(sprite);
    final bool flipX = pose?.flipX ?? (sprite['flipX'] == true);
    final bool flipY = pose?.flipY ?? (sprite['flipY'] == true);

    final Map<String, dynamic>? animation =
        _gamesTool.findAnimationForSprite(_gameData, sprite);
    final double animationTime = pose?.elapsedSeconds ?? elapsedSeconds;
    final int resolvedFrame = frameIndex ??
        pose?.frameIndex ??
        _resolveAnimationFrameIndex(
          animation: animation,
          elapsedSeconds: animationTime,
        );

    final Size frameSize = _spriteFrameSize(
      sprite: sprite,
      animation: animation,
    );
    if (frameSize.width <= 0 || frameSize.height <= 0) {
      return const <WorldHitBox>[];
    }

    final double anchorX = animation == null
        ? GamesToolApi.defaultAnchorX
        : _gamesTool.animationAnchorXForFrame(
            animation,
            frameIndex: resolvedFrame,
          );
    final double anchorY = animation == null
        ? GamesToolApi.defaultAnchorY
        : _gamesTool.animationAnchorYForFrame(
            animation,
            frameIndex: resolvedFrame,
          );

    final List<Map<String, dynamic>> rawHitBoxes = _hitBoxesForAnimationFrame(
      animation: animation,
      frameIndex: resolvedFrame,
    );

    if (rawHitBoxes.isEmpty) {
      return const <WorldHitBox>[];
    }

    final List<WorldHitBox> resolved = <WorldHitBox>[];
    for (final Map<String, dynamic> hitBox in rawHitBoxes) {
      final String hitBoxId = (hitBox['id'] as String?) ?? '__hitbox__';
      final String hitBoxName = (hitBox['name'] as String?) ?? hitBoxId;
      final String hitBoxColor = (hitBox['color'] as String?) ?? 'blue';

      final double hbX = _asFiniteDouble(hitBox['x'], 0).clamp(0.0, 1.0);
      final double hbY = _asFiniteDouble(hitBox['y'], 0).clamp(0.0, 1.0);
      final double hbW = _asFiniteDouble(hitBox['width'], 0).clamp(0.0, 1.0);
      final double hbH = _asFiniteDouble(hitBox['height'], 0).clamp(0.0, 1.0);
      if (hbW <= 0 || hbH <= 0) {
        continue;
      }

      final double mirroredX = flipX ? (1.0 - hbX - hbW) : hbX;
      final double mirroredY = flipY ? (1.0 - hbY - hbH) : hbY;
      final double left =
          spriteX - (anchorX * frameSize.width) + mirroredX * frameSize.width;
      final double top =
          spriteY - (anchorY * frameSize.height) + mirroredY * frameSize.height;

      resolved.add(
        WorldHitBox(
          ownerSpriteKey: spriteKey,
          ownerSpriteIndex: spriteIndex,
          hitBoxId: hitBoxId,
          hitBoxName: hitBoxName,
          hitBoxColor: hitBoxColor,
          rectWorld: Rect.fromLTWH(
            left,
            top,
            hbW * frameSize.width,
            hbH * frameSize.height,
          ),
        ),
      );
    }
    return resolved;
  }

  /// Computes sprite-vs-zone contacts using resolved per-frame world hitboxes.
  List<ZoneContact> collideSpriteWithZones({
    required int levelIndex,
    required int spriteIndex,
    RuntimeSpritePose? spritePose,
    Set<String>? zoneTypes,
    int? frameIndex,
    double elapsedSeconds = 0,
  }) {
    final Map<String, dynamic>? level = levelByIndex(levelIndex);
    if (level == null) {
      return const <ZoneContact>[];
    }
    final List<WorldHitBox> spriteHitBoxesWorld = spriteHitBoxes(
      levelIndex: levelIndex,
      spriteIndex: spriteIndex,
      pose: spritePose,
      frameIndex: frameIndex,
      elapsedSeconds: elapsedSeconds,
    );
    if (spriteHitBoxesWorld.isEmpty) {
      return const <ZoneContact>[];
    }

    final Set<String>? normalizedZoneTypes =
        zoneTypes?.map((type) => type.trim()).toSet();
    final List<Map<String, dynamic>> zones = _zonesOfLevel(level);
    final String spriteKey = _spriteKey(levelIndex, spriteIndex);
    final List<ZoneContact> contacts = <ZoneContact>[];

    for (int zoneIndex = 0; zoneIndex < zones.length; zoneIndex++) {
      final Map<String, dynamic> zone = zones[zoneIndex];
      final String zoneType = (zone['type'] as String?)?.trim() ?? '';
      if (normalizedZoneTypes != null &&
          !normalizedZoneTypes.contains(zoneType)) {
        continue;
      }

      final Rect zoneRect = Rect.fromLTWH(
        _asFiniteDouble(zone['x'], 0),
        _asFiniteDouble(zone['y'], 0),
        math.max(0, _asFiniteDouble(zone['width'], 0)),
        math.max(0, _asFiniteDouble(zone['height'], 0)),
      );
      if (zoneRect.width <= 0 || zoneRect.height <= 0) {
        continue;
      }

      for (final WorldHitBox hitBox in spriteHitBoxesWorld) {
        final Rect? intersection =
            _intersectionRect(hitBox.rectWorld, zoneRect);
        if (intersection == null) {
          continue;
        }
        contacts.add(
          ZoneContact(
            spriteKey: spriteKey,
            zoneKey: _zoneKey(levelIndex, zoneIndex),
            zoneIndex: zoneIndex,
            zoneType: zoneType,
            zoneGroupId: (zone['groupId'] as String?) ?? '',
            hitBoxId: hitBox.hitBoxId,
            intersectionRect: intersection,
          ),
        );
      }
    }
    return contacts;
  }

  /// Computes sprite-vs-sprite contacts against candidate sprites in the level.
  List<SpriteContact> collideSpriteWithSprites({
    required int levelIndex,
    required int spriteIndex,
    RuntimeSpritePose? spritePose,
    Iterable<int>? candidateSpriteIndices,
    Map<int, RuntimeSpritePose>? candidatePoses,
    int? frameIndex,
    Map<int, int>? frameIndexBySprite,
    double elapsedSeconds = 0,
  }) {
    final Map<String, dynamic>? level = levelByIndex(levelIndex);
    if (level == null) {
      return const <SpriteContact>[];
    }
    final List<Map<String, dynamic>> sprites = _spritesOfLevel(level);
    if (spriteIndex < 0 || spriteIndex >= sprites.length) {
      return const <SpriteContact>[];
    }

    final List<WorldHitBox> myHitBoxes = spriteHitBoxes(
      levelIndex: levelIndex,
      spriteIndex: spriteIndex,
      pose: spritePose,
      frameIndex: frameIndex,
      elapsedSeconds: elapsedSeconds,
    );
    if (myHitBoxes.isEmpty) {
      return const <SpriteContact>[];
    }

    final Iterable<int> candidates =
        candidateSpriteIndices ?? Iterable<int>.generate(sprites.length);
    final String spriteKey = _spriteKey(levelIndex, spriteIndex);
    final List<SpriteContact> contacts = <SpriteContact>[];

    for (final int otherIndex in candidates) {
      if (otherIndex == spriteIndex ||
          otherIndex < 0 ||
          otherIndex >= sprites.length) {
        continue;
      }
      final RuntimeSpritePose? otherPose = candidatePoses?[otherIndex];
      final int? otherFrameIndex = frameIndexBySprite?[otherIndex];
      final List<WorldHitBox> otherHitBoxes = spriteHitBoxes(
        levelIndex: levelIndex,
        spriteIndex: otherIndex,
        pose: otherPose,
        frameIndex: otherFrameIndex,
        elapsedSeconds: otherPose?.elapsedSeconds ?? elapsedSeconds,
      );
      if (otherHitBoxes.isEmpty) {
        continue;
      }

      final String otherKey = _spriteKey(levelIndex, otherIndex);
      final String otherGroupId =
          (sprites[otherIndex]['groupId'] as String?) ?? '';
      for (final WorldHitBox myHitBox in myHitBoxes) {
        for (final WorldHitBox otherHitBox in otherHitBoxes) {
          final Rect? intersection =
              _intersectionRect(myHitBox.rectWorld, otherHitBox.rectWorld);
          if (intersection == null) {
            continue;
          }
          contacts.add(
            SpriteContact(
              spriteKey: spriteKey,
              otherSpriteKey: otherKey,
              otherSpriteIndex: otherIndex,
              otherSpriteGroupId: otherGroupId,
              hitBoxId: myHitBox.hitBoxId,
              otherHitBoxId: otherHitBox.hitBoxId,
              intersectionRect: intersection,
            ),
          );
        }
      }
    }
    return contacts;
  }

  /// Continuous collision detection against static rects for downward motion.
  ///
  /// This complements `spriteCollisionRects(...)` by testing movement between
  /// previous and current rect locations to avoid tunneling at high speed.
  SweptRectCollision? firstDownwardCollisionAgainstRects({
    required List<Rect> previousRects,
    required List<Rect> currentRects,
    required Iterable<Rect> staticRects,
  }) {
    final int movingCount = math.min(previousRects.length, currentRects.length);
    if (movingCount <= 0) {
      return null;
    }
    final List<Rect> solidRects = staticRects
        .where((rect) => rect.width > 0 && rect.height > 0)
        .toList(growable: false);
    if (solidRects.isEmpty) {
      return null;
    }

    SweptRectCollision? bestHit;
    for (int i = 0; i < movingCount; i++) {
      final Rect start = previousRects[i];
      final Rect end = currentRects[i];
      final double deltaX = end.left - start.left;
      final double deltaY = end.top - start.top;
      if (deltaY <= 0) {
        continue;
      }

      for (final Rect solidRect in solidRects) {
        final _SweptAabbResult? sweep = _sweptAabb(
          movingRect: start,
          deltaX: deltaX,
          deltaY: deltaY,
          staticRect: solidRect,
        );
        if (sweep == null || sweep.normal.dy >= 0) {
          continue;
        }

        final SweptRectCollision candidate = SweptRectCollision(
          time: sweep.time,
          movingRectStart: start,
          movingRectEnd: end,
          staticRect: solidRect,
          normal: sweep.normal,
        );
        if (bestHit == null || candidate.time < bestHit.time) {
          bestHit = candidate;
        }
      }
    }
    return bestHit;
  }

  SweptRectCollision? firstDownwardSpriteCollisionAgainstRects({
    required int levelIndex,
    required int spriteIndex,
    required RuntimeSpritePose previousPose,
    required RuntimeSpritePose currentPose,
    required Iterable<Rect> staticRects,
    int? previousFrameIndex,
    int? currentFrameIndex,
  }) {
    final List<Rect> previousRects = spriteCollisionRects(
      levelIndex: levelIndex,
      spriteIndex: spriteIndex,
      pose: previousPose,
      frameIndex: previousFrameIndex,
      elapsedSeconds: previousPose.elapsedSeconds,
    );
    final List<Rect> currentRects = spriteCollisionRects(
      levelIndex: levelIndex,
      spriteIndex: spriteIndex,
      pose: currentPose,
      frameIndex: currentFrameIndex,
      elapsedSeconds: currentPose.elapsedSeconds,
    );
    return firstDownwardCollisionAgainstRects(
      previousRects: previousRects,
      currentRects: currentRects,
      staticRects: staticRects,
    );
  }

  List<ZoneContact> zoneContactsWithGroup({
    required int levelIndex,
    required int spriteIndex,
    required String targetGroupId,
    RuntimeSpritePose? spritePose,
    Set<String>? zoneTypes,
    int? frameIndex,
    double elapsedSeconds = 0,
  }) {
    final List<ZoneContact> contacts = collideSpriteWithZones(
      levelIndex: levelIndex,
      spriteIndex: spriteIndex,
      spritePose: spritePose,
      zoneTypes: zoneTypes,
      frameIndex: frameIndex,
      elapsedSeconds: elapsedSeconds,
    );
    return contacts
        .where((contact) => contact.zoneGroupId == targetGroupId)
        .toList(growable: false);
  }

  List<SpriteContact> spriteContactsWithGroup({
    required int levelIndex,
    required int spriteIndex,
    required String targetGroupId,
    RuntimeSpritePose? spritePose,
    Iterable<int>? candidateSpriteIndices,
    Map<int, RuntimeSpritePose>? candidatePoses,
    int? frameIndex,
    Map<int, int>? frameIndexBySprite,
    double elapsedSeconds = 0,
  }) {
    final List<SpriteContact> contacts = collideSpriteWithSprites(
      levelIndex: levelIndex,
      spriteIndex: spriteIndex,
      spritePose: spritePose,
      candidateSpriteIndices: candidateSpriteIndices,
      candidatePoses: candidatePoses,
      frameIndex: frameIndex,
      frameIndexBySprite: frameIndexBySprite,
      elapsedSeconds: elapsedSeconds,
    );
    return contacts
        .where((contact) => contact.otherSpriteGroupId == targetGroupId)
        .toList(growable: false);
  }

  bool collidesWithAnyZoneInGroup({
    required int levelIndex,
    required int spriteIndex,
    required String targetGroupId,
    RuntimeSpritePose? spritePose,
    Set<String>? zoneTypes,
    int? frameIndex,
    double elapsedSeconds = 0,
  }) {
    return zoneContactsWithGroup(
      levelIndex: levelIndex,
      spriteIndex: spriteIndex,
      targetGroupId: targetGroupId,
      spritePose: spritePose,
      zoneTypes: zoneTypes,
      frameIndex: frameIndex,
      elapsedSeconds: elapsedSeconds,
    ).isNotEmpty;
  }

  bool collidesWithAllZonesInGroup({
    required int levelIndex,
    required int spriteIndex,
    required String targetGroupId,
    RuntimeSpritePose? spritePose,
    Set<String>? zoneTypes,
    int? frameIndex,
    double elapsedSeconds = 0,
  }) {
    final List<int> zoneIndices = zoneIndicesInGroup(
      levelIndex: levelIndex,
      groupId: targetGroupId,
    );
    if (zoneIndices.isEmpty) {
      return false;
    }
    final Set<int> collided = zoneContactsWithGroup(
      levelIndex: levelIndex,
      spriteIndex: spriteIndex,
      targetGroupId: targetGroupId,
      spritePose: spritePose,
      zoneTypes: zoneTypes,
      frameIndex: frameIndex,
      elapsedSeconds: elapsedSeconds,
    ).map((contact) => contact.zoneIndex).toSet();
    for (final int zoneIndex in zoneIndices) {
      if (!collided.contains(zoneIndex)) {
        return false;
      }
    }
    return true;
  }

  bool collidesWithAnySpriteInGroup({
    required int levelIndex,
    required int spriteIndex,
    required String targetGroupId,
    RuntimeSpritePose? spritePose,
    Iterable<int>? candidateSpriteIndices,
    Map<int, RuntimeSpritePose>? candidatePoses,
    int? frameIndex,
    Map<int, int>? frameIndexBySprite,
    double elapsedSeconds = 0,
  }) {
    return spriteContactsWithGroup(
      levelIndex: levelIndex,
      spriteIndex: spriteIndex,
      targetGroupId: targetGroupId,
      spritePose: spritePose,
      candidateSpriteIndices: candidateSpriteIndices,
      candidatePoses: candidatePoses,
      frameIndex: frameIndex,
      frameIndexBySprite: frameIndexBySprite,
      elapsedSeconds: elapsedSeconds,
    ).isNotEmpty;
  }

  bool collidesWithAllSpritesInGroup({
    required int levelIndex,
    required int spriteIndex,
    required String targetGroupId,
    RuntimeSpritePose? spritePose,
    Iterable<int>? candidateSpriteIndices,
    Map<int, RuntimeSpritePose>? candidatePoses,
    int? frameIndex,
    Map<int, int>? frameIndexBySprite,
    double elapsedSeconds = 0,
  }) {
    final List<int> spriteIndices = spriteIndicesInGroup(
      levelIndex: levelIndex,
      groupId: targetGroupId,
    ).where((index) => index != spriteIndex).toList(growable: false);
    if (spriteIndices.isEmpty) {
      return false;
    }
    final Set<int> collided = spriteContactsWithGroup(
      levelIndex: levelIndex,
      spriteIndex: spriteIndex,
      targetGroupId: targetGroupId,
      spritePose: spritePose,
      candidateSpriteIndices: candidateSpriteIndices,
      candidatePoses: candidatePoses,
      frameIndex: frameIndex,
      frameIndexBySprite: frameIndexBySprite,
      elapsedSeconds: elapsedSeconds,
    ).map((contact) => contact.otherSpriteIndex).toSet();
    for (final int targetIndex in spriteIndices) {
      if (!collided.contains(targetIndex)) {
        return false;
      }
    }
    return true;
  }

  void beginFrame({int? frameId}) {
    _currentFrameId = frameId ?? (_currentFrameId + 1);
  }

  /// Advances interpolation history for all tracked transforms.
  ///
  /// Call once at the beginning of each fixed simulation tick before mutating
  /// positions, similar to Unity Rigidbody interpolation behavior.
  void beginTick() {
    if (_transform2DById.isEmpty) {
      return;
    }
    _transform2DById.updateAll((String _, RuntimeTrackedTransform2D value) {
      return value.copyWith(
        previousX: value.currentX,
        previousY: value.currentY,
      );
    });
  }

  bool hasTransform2D(String id) => _transform2DById.containsKey(id);

  RuntimeTrackedTransform2D? transform2D(String id) {
    return _transform2DById[id];
  }

  /// Registers or updates current transform. New ids are initialized snapped.
  void setTransform2D({
    required String id,
    required double x,
    required double y,
  }) {
    final RuntimeTrackedTransform2D? existing = _transform2DById[id];
    if (existing == null) {
      _transform2DById[id] = RuntimeTrackedTransform2D(
        previousX: x,
        previousY: y,
        currentX: x,
        currentY: y,
      );
      return;
    }
    _transform2DById[id] = existing.copyWith(
      currentX: x,
      currentY: y,
    );
  }

  /// Sets previous and current to the same value to avoid interpolation smear.
  void snapTransform2D({
    required String id,
    required double x,
    required double y,
  }) {
    _transform2DById[id] = RuntimeTrackedTransform2D(
      previousX: x,
      previousY: y,
      currentX: x,
      currentY: y,
    );
  }

  void removeTransform2D(String id) {
    _transform2DById.remove(id);
  }

  void clearTransform2D() {
    _transform2DById.clear();
  }

  /// Returns an interpolated transform sample for rendering.
  Offset sampleTransform2D(
    String id, {
    double alpha = 1.0,
    double fallbackX = 0,
    double fallbackY = 0,
  }) {
    final RuntimeTrackedTransform2D? tracked = _transform2DById[id];
    if (tracked == null) {
      return Offset(fallbackX, fallbackY);
    }
    return tracked.sample(alpha: alpha);
  }

  void resetFrameState() {
    _currentFrameId = 0;
    _previousStateBySpriteKey.clear();
    _transform2DById.clear();
  }

  /// Builds per-frame entered/exited/staying collision sets for one sprite.
  /// Call beginFrame() once per tick before collecting deltas.
  SpriteFrameDelta updateFrameDeltaForSprite({
    required int levelIndex,
    required int spriteIndex,
    RuntimeSpritePose? spritePose,
    Set<String>? zoneTypes,
    Iterable<int>? candidateSpriteIndices,
    Map<int, RuntimeSpritePose>? candidatePoses,
    int? frameIndex,
    Map<int, int>? frameIndexBySprite,
    double elapsedSeconds = 0,
  }) {
    final String spriteKey = _spriteKey(levelIndex, spriteIndex);
    final List<ZoneContact> zoneContacts = collideSpriteWithZones(
      levelIndex: levelIndex,
      spriteIndex: spriteIndex,
      spritePose: spritePose,
      zoneTypes: zoneTypes,
      frameIndex: frameIndex,
      elapsedSeconds: elapsedSeconds,
    );
    final List<SpriteContact> spriteContacts = collideSpriteWithSprites(
      levelIndex: levelIndex,
      spriteIndex: spriteIndex,
      spritePose: spritePose,
      candidateSpriteIndices: candidateSpriteIndices,
      candidatePoses: candidatePoses,
      frameIndex: frameIndex,
      frameIndexBySprite: frameIndexBySprite,
      elapsedSeconds: elapsedSeconds,
    );

    final _CollisionFrameState current = _CollisionFrameState(
      zoneKeys: zoneContacts.map((contact) => contact.zoneKey).toSet(),
      zoneTypes: zoneContacts.map((contact) => contact.zoneType).toSet(),
      zoneGroups: zoneContacts.map((contact) => contact.zoneGroupId).toSet(),
      spriteKeys:
          spriteContacts.map((contact) => contact.otherSpriteKey).toSet(),
      spriteGroups:
          spriteContacts.map((contact) => contact.otherSpriteGroupId).toSet(),
    );
    final _CollisionFrameState previous =
        _previousStateBySpriteKey[spriteKey] ??
            const _CollisionFrameState(
              zoneKeys: <String>{},
              zoneTypes: <String>{},
              zoneGroups: <String>{},
              spriteKeys: <String>{},
              spriteGroups: <String>{},
            );

    final SpriteFrameDelta delta = SpriteFrameDelta(
      frameId: _currentFrameId,
      spriteKey: spriteKey,
      zoneKeys: _diffSet(previous.zoneKeys, current.zoneKeys),
      zoneTypes: _diffSet(previous.zoneTypes, current.zoneTypes),
      zoneGroups: _diffSet(previous.zoneGroups, current.zoneGroups),
      spriteKeys: _diffSet(previous.spriteKeys, current.spriteKeys),
      spriteGroups: _diffSet(previous.spriteGroups, current.spriteGroups),
    );
    _previousStateBySpriteKey[spriteKey] = current;
    return delta;
  }

  CollisionTransition<T> _diffSet<T>(Set<T> previous, Set<T> current) {
    final Set<T> entered = current.difference(previous);
    final Set<T> exited = previous.difference(current);
    final Set<T> staying = current.intersection(previous);
    return CollisionTransition<T>(
      entered: entered,
      exited: exited,
      staying: staying,
      current: current,
    );
  }

  ({bool found, dynamic value}) _resolvePathSegment(
    dynamic current,
    Object segment,
  ) {
    if (segment is String && current is Map<String, dynamic>) {
      if (!current.containsKey(segment)) {
        return (found: false, value: null);
      }
      return (found: true, value: current[segment]);
    }
    if (segment is int && current is List<dynamic>) {
      if (segment < 0 || segment >= current.length) {
        return (found: false, value: null);
      }
      return (found: true, value: current[segment]);
    }
    return (found: false, value: null);
  }

  Map<String, dynamic>? _resolveLayer({
    required int levelIndex,
    int? layerIndex,
    String? layerName,
  }) {
    if ((layerIndex == null) == (layerName == null)) {
      throw ArgumentError(
        'Provide exactly one of layerIndex or layerName.',
      );
    }
    return layerIndex != null
        ? layerByIndex(levelIndex: levelIndex, layerIndex: layerIndex)
        : layerByName(levelIndex: levelIndex, layerName: layerName!);
  }

  List<Map<String, dynamic>> _spritesOfLevel(Map<String, dynamic> level) {
    return ((level['sprites'] as List<dynamic>?) ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _zonesOfLevel(Map<String, dynamic> level) {
    return ((level['zones'] as List<dynamic>?) ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _hitBoxesForAnimationFrame({
    required Map<String, dynamic>? animation,
    required int frameIndex,
  }) {
    if (animation == null) {
      return const <Map<String, dynamic>>[];
    }
    final Map<String, dynamic>? rig = _gamesTool.animationFrameRig(
      animation,
      frameIndex: frameIndex,
    );
    final List<Map<String, dynamic>> rigHitBoxes =
        ((rig?['hitBoxes'] as List<dynamic>?) ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);
    if (rigHitBoxes.isNotEmpty) {
      return rigHitBoxes;
    }
    return ((animation['hitBoxes'] as List<dynamic>?) ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  Size _spriteFrameSize({
    required Map<String, dynamic> sprite,
    required Map<String, dynamic>? animation,
  }) {
    final String? spriteImageFile = _gamesTool.spriteImageFile(sprite);
    final String? animationMediaFile = animation?['mediaFile'] as String?;
    final String effectiveFile =
        (animationMediaFile != null && animationMediaFile.isNotEmpty)
            ? animationMediaFile
            : (spriteImageFile ?? '');

    final Map<String, dynamic>? mediaAsset = effectiveFile.isEmpty
        ? null
        : _gamesTool.findMediaAssetByFile(_gameData, effectiveFile);

    final double width = mediaAsset == null
        ? _gamesTool.spriteWidth(sprite)
        : _gamesTool.mediaTileWidth(
            mediaAsset,
            fallback: _gamesTool.spriteWidth(sprite),
          );
    final double height = mediaAsset == null
        ? _gamesTool.spriteHeight(sprite)
        : _gamesTool.mediaTileHeight(
            mediaAsset,
            fallback: _gamesTool.spriteHeight(sprite),
          );
    return Size(width, height);
  }

  int _resolveAnimationFrameIndex({
    required Map<String, dynamic>? animation,
    required double elapsedSeconds,
  }) {
    if (animation == null) {
      return 0;
    }
    final AnimationPlaybackConfig playback =
        _gamesTool.animationPlaybackConfig(animation);
    return _gamesTool.animationFrameIndexAtTime(
      playback: playback,
      elapsedSeconds: elapsedSeconds,
    );
  }

  double _resolveLayerDepthDisplacement({
    required Map<String, dynamic> layer,
    double? depthDisplacement,
  }) {
    if (depthDisplacement != null && depthDisplacement.isFinite) {
      return depthDisplacement;
    }
    return _gamesTool.layerDepth(layer);
  }

  double _asFiniteDouble(Object? value, double fallback) {
    final double? parsed = (value as num?)?.toDouble();
    if (parsed == null || !parsed.isFinite) {
      return fallback;
    }
    return parsed;
  }

  Rect? _intersectionRect(Rect a, Rect b) {
    final double left = math.max(a.left, b.left);
    final double top = math.max(a.top, b.top);
    final double right = math.min(a.right, b.right);
    final double bottom = math.min(a.bottom, b.bottom);
    if (right <= left || bottom <= top) {
      return null;
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  _SweptAabbResult? _sweptAabb({
    required Rect movingRect,
    required double deltaX,
    required double deltaY,
    required Rect staticRect,
  }) {
    if (deltaX == 0 && deltaY == 0) {
      return null;
    }

    double xEntry;
    double xExit;
    if (deltaX > 0) {
      xEntry = (staticRect.left - movingRect.right) / deltaX;
      xExit = (staticRect.right - movingRect.left) / deltaX;
    } else if (deltaX < 0) {
      xEntry = (staticRect.right - movingRect.left) / deltaX;
      xExit = (staticRect.left - movingRect.right) / deltaX;
    } else {
      final bool separatedX = movingRect.right <= staticRect.left ||
          movingRect.left >= staticRect.right;
      if (separatedX) {
        return null;
      }
      xEntry = double.negativeInfinity;
      xExit = double.infinity;
    }

    double yEntry;
    double yExit;
    if (deltaY > 0) {
      yEntry = (staticRect.top - movingRect.bottom) / deltaY;
      yExit = (staticRect.bottom - movingRect.top) / deltaY;
    } else if (deltaY < 0) {
      yEntry = (staticRect.bottom - movingRect.top) / deltaY;
      yExit = (staticRect.top - movingRect.bottom) / deltaY;
    } else {
      final bool separatedY = movingRect.bottom <= staticRect.top ||
          movingRect.top >= staticRect.bottom;
      if (separatedY) {
        return null;
      }
      yEntry = double.negativeInfinity;
      yExit = double.infinity;
    }

    final double entryTime = math.max(xEntry, yEntry);
    final double exitTime = math.min(xExit, yExit);

    if (entryTime > exitTime || entryTime < 0 || entryTime > 1) {
      return null;
    }

    final Offset normal;
    if (xEntry > yEntry) {
      normal = deltaX > 0 ? const Offset(-1, 0) : const Offset(1, 0);
    } else {
      normal = deltaY > 0 ? const Offset(0, -1) : const Offset(0, 1);
    }

    return _SweptAabbResult(
      time: entryTime,
      normal: normal,
    );
  }

  String _spriteKey(int levelIndex, int spriteIndex) =>
      'L${levelIndex}_S$spriteIndex';
  String _zoneKey(int levelIndex, int zoneIndex) =>
      'L${levelIndex}_Z$zoneIndex';
}

class _CollisionFrameState {
  const _CollisionFrameState({
    required this.zoneKeys,
    required this.zoneTypes,
    required this.zoneGroups,
    required this.spriteKeys,
    required this.spriteGroups,
  });

  final Set<String> zoneKeys;
  final Set<String> zoneTypes;
  final Set<String> zoneGroups;
  final Set<String> spriteKeys;
  final Set<String> spriteGroups;
}

class _SweptAabbResult {
  const _SweptAabbResult({
    required this.time,
    required this.normal,
  });

  final double time;
  final Offset normal;
}
