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
    _heroSpriteIndex = _resolveHeroSpriteIndex(_level);
    _decoracionsLayerIndex =
        _resolveLayerIndexByName(_level, _level0DecoracionsLayerName);
    _pontAmagatLayerIndex =
        _resolveLayerIndexByName(_level, _level0PontAmagatLayerName);
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
        ? 100
        : appData.gamesTool.levelViewportCenterY(
            _level!,
            fallbackHeight: GamesToolApi.defaultViewportHeight,
            fallbackY: 0,
          );

    final Map<String, dynamic>? spawn = _level == null
        ? null
        : appData.gamesTool.findSpriteByType(_level!, 'Heroi') ??
            appData.gamesTool.findFirstSprite(_level!);

    _updateState = Level0UpdateState(
      playerX: (spawn?['x'] as num?)?.toDouble() ?? levelViewportCenterX,
      playerY: (spawn?['y'] as num?)?.toDouble() ?? levelViewportCenterY,
      playerWidth: (spawn?['width'] as num?)?.toDouble() ?? 20,
      playerHeight: (spawn?['height'] as num?)?.toDouble() ?? 20,
      speedPerSecond: 95,
    );

    _camera
      // Camera tracks player world coordinates directly in this level.
      ..x = levelViewportCenterX
      ..y = levelViewportCenterY
      ..focal = levelViewportWidth;
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

  int? _resolveHeroSpriteIndex(Map<String, dynamic>? level) {
    if (level == null) {
      return null;
    }
    final List<dynamic> sprites =
        (level['sprites'] as List<dynamic>?) ?? const <dynamic>[];
    for (int i = 0; i < sprites.length; i++) {
      final dynamic sprite = sprites[i];
      if (sprite is! Map<String, dynamic>) {
        continue;
      }
      final String type = (sprite['type'] as String?)?.trim() ?? '';
      final String name = (sprite['name'] as String?)?.trim() ?? '';
      if (type == 'Heroi' || name == 'Heroi') {
        return i;
      }
    }
    if (sprites.isEmpty) {
      return null;
    }
    return 0;
  }

  int? _resolveLayerIndexByName(Map<String, dynamic>? level, String layerName) {
    if (level == null) {
      return null;
    }
    final List<dynamic> layers =
        (level['layers'] as List<dynamic>?) ?? const <dynamic>[];
    for (int i = 0; i < layers.length; i++) {
      final dynamic layer = layers[i];
      if (layer is! Map<String, dynamic>) {
        continue;
      }
      final String name = (layer['name'] as String?)?.trim() ?? '';
      if (name == layerName) {
        return i;
      }
    }
    return null;
  }
}
