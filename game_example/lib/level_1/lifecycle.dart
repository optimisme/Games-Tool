part of 'main.dart';

/// Level setup helpers for runtime references, spawn state, and camera defaults.
extension _Level1Initialize on _Level1State {
  void _initializeLevel(AppData appData) {
    _runtimeGameData = cloneGameData(appData.gameData);
    _level = _runtimeGameData == null
        ? null
        : appData.gamesTool
            .findLevelByIndex(_runtimeGameData!, widget.levelIndex);
    if (_runtimeGameData != null) {
      _runtimeApi.useLoadedGameData(
        _runtimeGameData!,
        gamesTool: appData.gamesTool,
      );
    }
    _playerSpriteIndex = appData.gamesTool.findSpriteIndexByName(
      _level,
      _level1PlayerSpriteName,
    );
    if (_playerSpriteIndex == null) {
      throw StateError(
        'Level ${widget.levelIndex} is missing required sprite '
        '"$_level1PlayerSpriteName".',
      );
    }
    _movingPlatformLayerIndex = appData.gamesTool.findLayerIndexByName(
      _level,
      _level1MovingPlatformLayerName,
    );
    final int? movingPlatformLayerIndex = _movingPlatformLayerIndex;
    final List<Map<String, dynamic>> allLayers = _level == null
        ? const <Map<String, dynamic>>[]
        : appData.gamesTool.listLevelLayers(
            _level!,
            visibleOnly: false,
            painterOrder: false,
          );
    _movingPlatformLayer = movingPlatformLayerIndex != null &&
            movingPlatformLayerIndex >= 0 &&
            movingPlatformLayerIndex < allLayers.length
        ? allLayers[movingPlatformLayerIndex]
        : null;
    _movingPlatformFloorZoneIndex =
        appData.gamesTool.findZoneIndexByGameplayData(
      _level,
      _level1MovingPlatformFloorGameplayData,
    );
    final Map<String, dynamic>? resolvedSpawn =
        appData.gamesTool.findSpriteByName(_level, _level1PlayerSpriteName);
    if (resolvedSpawn == null) {
      throw StateError(
        'Level ${widget.levelIndex} is missing required sprite '
        '"$_level1PlayerSpriteName".',
      );
    }
    final Map<String, dynamic> spawn = resolvedSpawn;
    final LevelViewportBootstrap bootstrap = buildLevelViewportBootstrap(
      gamesTool: appData.gamesTool,
      level: _level,
      spawn: spawn,
      fallbackCenterX: 100,
      fallbackCenterY: 120,
    );
    // Camera follow now uses sprite visual-center focus point from runtime API.
    _cameraFollowOffsetX = 0;
    _cameraFollowOffsetY = 0;
    final Offset initialPlatformPosition = _level1MovingPlatformPath.first;

    _updateState = Level1UpdateState(
      playerX: bootstrap.spawnX,
      playerY: bootstrap.spawnY,
      cameraX: bootstrap.viewportCenterX,
      cameraY: bootstrap.viewportCenterY,
      platformX: initialPlatformPosition.dx,
      platformY: initialPlatformPosition.dy,
      playerWidth: (spawn['width'] as num?)?.toDouble() ?? 22,
      playerHeight: (spawn['height'] as num?)?.toDouble() ?? 30,
      gemsCount: 0,
      totalGems: _gemSpriteIndices().length,
    );

    applyBootstrapCamera(
      camera: _camera,
      bootstrap: bootstrap,
    );
    _updateState!
      ..cameraX = _camera.x
      ..cameraY = _camera.y;

    _applyMovingPlatformPose(initialPlatformPosition);
    _runtimeApi.snapTransform2D(
      id: _level1PlayerTransformId,
      x: _updateState!.playerX,
      y: _updateState!.playerY,
    );
    _runtimeApi.snapTransform2D(
      id: _level1CameraTransformId,
      x: _updateState!.cameraX,
      y: _updateState!.cameraY,
    );
    _runtimeApi.snapTransform2D(
      id: _level1MovingPlatformTransformId,
      x: _updateState!.platformX,
      y: _updateState!.platformY,
    );
  }
}
