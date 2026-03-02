part of 'main.dart';

/// Level bootstrapping and teardown-adjacent setup.
extension _Level0Initialize on _Level0State {
  void _initializeLevel(AppData appData) {
    // Work on a cloned game-data tree so runtime tile edits stay level-local.
    _runtimeGameData = _cloneGameData(appData.gameData);
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
    _heroSpriteIndex =
        appData.gamesTool.findSpriteIndexByTypeOrName(_level, 'Heroi') ??
            appData.gamesTool.firstSpriteIndex(_level);
    _decoracionsLayerIndex = appData.gamesTool
        .findLayerIndexByName(_level, _level0DecoracionsLayerName);
    _pontAmagatLayerIndex = appData.gamesTool
        .findLayerIndexByName(_level, _level0PontAmagatLayerName);
    unawaited(
      ensureStateImageLoaded(
        appData: appData,
        assetPath: _level0BackIconAssetPath,
        currentImage: _backIconImage,
        isMounted: () => mounted,
        refresh: (VoidCallback update) {
          _refreshLevel0(update);
        },
        assignImage: (ui.Image image) {
          _backIconImage = image;
        },
      ),
    );

    final Map<String, dynamic>? spawn = _level == null
        ? null
        : appData.gamesTool.findSpriteByType(_level!, 'Heroi') ??
            appData.gamesTool.findFirstSprite(_level!);
    final LevelViewportBootstrap bootstrap = buildLevelViewportBootstrap(
      gamesTool: appData.gamesTool,
      level: _level,
      spawn: spawn,
      fallbackCenterX: 100,
      fallbackCenterY: 100,
    );
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
      playerWidth: (spawn?['width'] as num?)?.toDouble() ?? 20,
      playerHeight: (spawn?['height'] as num?)?.toDouble() ?? 20,
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

  Map<String, dynamic>? _cloneGameData(Map<String, dynamic> source) {
    if (source.isEmpty) {
      return null;
    }
    final dynamic clone = jsonDecode(jsonEncode(source));
    if (clone is Map<String, dynamic>) {
      return clone;
    }
    return null;
  }
}
