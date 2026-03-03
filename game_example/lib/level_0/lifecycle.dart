part of 'main.dart';

/// Level bootstrapping and teardown-adjacent setup.
extension _Level0Initialize on _Level0State {
  /// Loads level runtime data and initializes simulation/camera state.
  void _initializeLevel(AppData appData) {
    // Work on a cloned game-data tree so runtime tile edits stay level-local.
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
    _heroSpriteIndex = appData.gamesTool.findSpriteIndexByName(
      _level,
      _level0PlayerSpriteName,
    );
    if (_heroSpriteIndex == null) {
      throw StateError(
        'Level ${widget.levelIndex} is missing required sprite '
        '"$_level0PlayerSpriteName".',
      );
    }
    _decoracionsLayerIndex = appData.gamesTool
        .findLayerIndexByName(_level, _level0DecoracionsLayerName);
    _pontAmagatLayerIndex = appData.gamesTool
        .findLayerIndexByName(_level, _level0PontAmagatLayerName);

    final Map<String, dynamic>? resolvedSpawn =
        appData.gamesTool.findSpriteByName(_level, _level0PlayerSpriteName);
    if (resolvedSpawn == null) {
      throw StateError(
        'Level ${widget.levelIndex} is missing required sprite '
        '"$_level0PlayerSpriteName".',
      );
    }
    final Map<String, dynamic> spawn = resolvedSpawn;
    final LevelViewportBootstrap bootstrap = buildLevelViewportBootstrap(
      gamesTool: appData.gamesTool,
      level: _level,
      spawn: spawn,
      fallbackCenterX: 100,
      fallbackCenterY: 100,
    );
    _cameraFollowOffsetX = 0;
    _cameraFollowOffsetY = 0;
    final Set<String> collectibleArbreTileKeys = _collectLevel0ArbreTileKeys(
      gamesTool: appData.gamesTool,
      level: _level,
      decoracionsLayerIndex: _decoracionsLayerIndex,
    );

    _updateState = Level0UpdateState(
      playerX: bootstrap.spawnX,
      playerY: bootstrap.spawnY,
      cameraX: bootstrap.viewportCenterX,
      cameraY: bootstrap.viewportCenterY,
      playerWidth: (spawn['width'] as num?)?.toDouble() ?? 20,
      playerHeight: (spawn['height'] as num?)?.toDouble() ?? 20,
      speedPerSecond: 95,
      totalArbres: collectibleArbreTileKeys.length,
      collectibleArbreTileKeys: collectibleArbreTileKeys,
    );

    // Camera tracks player world coordinates directly in this level.
    applyBootstrapCamera(
      camera: _camera,
      bootstrap: bootstrap,
    );
    _updateState!
      ..cameraX = _camera.x
      ..cameraY = _camera.y;
    _runtimeApi.snapTransform2D(
      id: _level0PlayerTransformId,
      x: _updateState!.playerX,
      y: _updateState!.playerY,
    );
    _runtimeApi.snapTransform2D(
      id: _level0CameraTransformId,
      x: _updateState!.cameraX,
      y: _updateState!.cameraY,
    );
  }
}
