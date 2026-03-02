part of 'main.dart';

extension _Level1Initialize on _Level1State {
  void _initializeLevel(AppData appData) {
    _runtimeApi.useLoadedGameData(
      appData.gameData,
      gamesTool: appData.gamesTool,
    );
    _level = appData.getLevelByIndex(widget.levelIndex);
    _playerSprite = _resolveLevel1PlayerSprite(_level);
    _playerSpriteIndex = _resolveLevel1PlayerSpriteIndex(_level);
    _movingPlatformLayerIndex = _resolveLevel1LayerIndexByName(
      _level,
      _level1MovingPlatformLayerName,
    );
    _movingPlatformFloorZoneIndex = _resolveLevel1ZoneIndexByGameplayData(
      _level,
      _level1MovingPlatformFloorGameplayData,
    );
    unawaited(_ensureBackIconLoaded(appData));
    final Map<String, dynamic>? spawn = _playerSprite;
    final double levelViewportWidth = _level == null
        ? GamesToolApi.defaultViewportWidth
        : appData.gamesTool.levelViewportWidth(
            _level!,
            fallback: GamesToolApi.defaultViewportWidth,
          );
    final double levelViewportCenterX = _level == null
        ? 100
        : appData.gamesTool.levelViewportCenterX(
            _level!,
            fallbackWidth: GamesToolApi.defaultViewportWidth,
            fallbackX: 0,
          );
    final double levelViewportCenterY = _level == null
        ? 120
        : appData.gamesTool.levelViewportCenterY(
            _level!,
            fallbackHeight: GamesToolApi.defaultViewportHeight,
            fallbackY: 0,
          );

    final double spawnX =
        (spawn?['x'] as num?)?.toDouble() ?? levelViewportCenterX;
    final double spawnY =
        (spawn?['y'] as num?)?.toDouble() ?? levelViewportCenterY;
    _cameraFollowOffsetX = 0;
    _cameraFollowOffsetY = levelViewportCenterY - spawnY;

    _updateState = Level1UpdateState(
      playerX: spawnX,
      playerY: spawnY,
      playerWidth: (spawn?['width'] as num?)?.toDouble() ?? 22,
      playerHeight: (spawn?['height'] as num?)?.toDouble() ?? 30,
      gemsCount: 0,
      totalGems: _gemSpriteIndices().length,
    );

    _camera
      ..x = levelViewportCenterX
      ..y = levelViewportCenterY
      ..focal = levelViewportWidth;

    _applyMovingPlatformPose(_level1MovingPlatformPath.first);
  }

  Future<void> _ensureBackIconLoaded(AppData appData) async {
    if (_backIconImage != null) {
      return;
    }
    try {
      final ui.Image iconImage =
          await appData.getImage(_level1BackIconAssetPath);
      if (!mounted) {
        return;
      }
      _refreshLevel1(() {
        _backIconImage = iconImage;
      });
    } catch (_) {
      // Keep text-only fallback if asset load fails.
    }
  }
}
