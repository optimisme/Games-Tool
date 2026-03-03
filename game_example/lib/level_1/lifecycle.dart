part of 'main.dart';

/// Level setup helpers for runtime references, spawn state, and camera defaults.
extension _Level1Initialize on _Level1State {
  /// Loads level data and initializes player, camera, and bindings.
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

    _updateState = Level1UpdateState(
      playerX: bootstrap.spawnX,
      playerY: bootstrap.spawnY,
      cameraX: bootstrap.viewportCenterX,
      cameraY: bootstrap.viewportCenterY,
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

    _initializePathBindings();
    _applyPathBindingsAtCurrentTime(_updateState!);
    _snapPathBindingTransforms();
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
  }

  /// Builds runtime path-binding descriptors for movable targets.
  void _initializePathBindings() {
    _pathBindings.clear();
    final Map<String, dynamic>? level = _level;
    if (level == null) {
      return;
    }

    final List<Map<String, dynamic>> layers = _runtimeApi.gamesTool
        .listLevelLayers(level, visibleOnly: false, painterOrder: false);
    final List<Map<String, dynamic>> zones = _runtimeApi.gamesTool.levelZones(
      level,
    );
    final List<Map<String, dynamic>> sprites =
        _runtimeApi.gamesTool.listLevelSprites(level);

    final List<Map<String, dynamic>> paths =
        ((level['paths'] as List<dynamic>?) ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);
    final Map<String, _Level1PathRuntime> pathById =
        <String, _Level1PathRuntime>{};
    for (final Map<String, dynamic> path in paths) {
      final String pathId = ((path['id'] as String?) ?? '').trim();
      if (pathId.isEmpty) {
        continue;
      }
      final List<Map<String, dynamic>> points =
          ((path['points'] as List<dynamic>?) ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .toList(growable: false);
      if (points.length < 2) {
        continue;
      }
      final List<Offset> parsedPoints =
          points.map((Map<String, dynamic> point) {
        final double x = (point['x'] as num?)?.toDouble() ?? 0;
        final double y = (point['y'] as num?)?.toDouble() ?? 0;
        return Offset(x, y);
      }).toList(growable: false);
      final List<double> cumulativeDistances = <double>[0];
      double totalDistance = 0;
      for (int i = 1; i < parsedPoints.length; i++) {
        totalDistance += (parsedPoints[i] - parsedPoints[i - 1]).distance;
        cumulativeDistances.add(totalDistance);
      }
      pathById[pathId] = _Level1PathRuntime(
        id: pathId,
        points: parsedPoints,
        cumulativeDistances: cumulativeDistances,
        totalDistance: totalDistance,
      );
    }

    final List<Map<String, dynamic>> bindings =
        ((level['pathBindings'] as List<dynamic>?) ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);
    for (final Map<String, dynamic> binding in bindings) {
      final bool enabled = binding['enabled'] as bool? ?? true;
      if (!enabled) {
        continue;
      }
      final String pathId = ((binding['pathId'] as String?) ?? '').trim();
      final _Level1PathRuntime? path = pathById[pathId];
      if (path == null) {
        continue;
      }

      final String targetType =
          ((binding['targetType'] as String?) ?? '').trim().toLowerCase();
      final int targetIndex = (binding['targetIndex'] as num?)?.toInt() ?? -1;
      final Map<String, dynamic>? targetObject;
      switch (targetType) {
        case _level1PathTargetTypeLayer:
          targetObject = targetIndex >= 0 && targetIndex < layers.length
              ? layers[targetIndex]
              : null;
          break;
        case _level1PathTargetTypeZone:
          targetObject = targetIndex >= 0 && targetIndex < zones.length
              ? zones[targetIndex]
              : null;
          break;
        case _level1PathTargetTypeSprite:
          targetObject = targetIndex >= 0 && targetIndex < sprites.length
              ? sprites[targetIndex]
              : null;
          break;
        default:
          targetObject = null;
          break;
      }
      if (targetObject == null) {
        continue;
      }

      final String behavior =
          ((binding['behavior'] as String?) ?? '').trim().toLowerCase();
      final int durationMs = (binding['durationMs'] as num?)?.toInt() ??
          _level1PathDefaultDurationMs;
      final double durationSeconds = durationMs > 0
          ? durationMs / 1000.0
          : _level1PathDefaultDurationMs / 1000.0;
      final bool relativeToInitialPosition =
          binding['relativeToInitialPosition'] as bool? ?? true;
      final double initialX = (targetObject['x'] as num?)?.toDouble() ?? 0;
      final double initialY = (targetObject['y'] as num?)?.toDouble() ?? 0;
      final bool isFloorZone =
          targetType == _level1PathTargetTypeZone && _isFloorZone(targetObject);
      _pathBindings.add(
        _Level1PathBindingRuntime(
          path: path,
          targetObject: targetObject,
          targetType: targetType,
          targetIndex: targetIndex,
          behavior: behavior,
          enabled: enabled,
          relativeToInitialPosition: relativeToInitialPosition,
          durationSeconds: durationSeconds,
          initialX: initialX,
          initialY: initialY,
          isFloorZone: isFloorZone,
        ),
      );
    }
  }

  /// Applies bound path positions using current path motion time.
  void _applyPathBindingsAtCurrentTime(Level1UpdateState state) {
    if (_pathBindings.isEmpty) {
      return;
    }
    for (final _Level1PathBindingRuntime binding in _pathBindings) {
      final Offset position = _bindingPositionAtTime(
        binding,
        state.pathMotionTimeSeconds,
      );
      binding.targetObject['x'] = position.dx;
      binding.targetObject['y'] = position.dy;
    }
  }

  /// Snaps path-target transforms so first rendered frame is stable.
  void _snapPathBindingTransforms() {
    if (_pathBindings.isEmpty) {
      return;
    }
    for (final _Level1PathBindingRuntime binding in _pathBindings) {
      if (!binding.enabled) {
        continue;
      }
      final double x = (binding.targetObject['x'] as num?)?.toDouble() ?? 0;
      final double y = (binding.targetObject['y'] as num?)?.toDouble() ?? 0;
      _runtimeApi.snapTransform2D(
        id: _level1PathTargetTransformId(
          targetType: binding.targetType,
          targetIndex: binding.targetIndex,
        ),
        x: x,
        y: y,
      );
    }
  }
}
