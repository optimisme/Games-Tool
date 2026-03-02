part of 'main.dart';

/// Per-frame simulation for movement, collisions, and world state mutations.
extension _Level0Update on _Level0State {
  void _startLoop() {
    _ticker = restartGameLoopTicker(
      tickerProvider: this,
      ticker: _ticker,
      getLastTickTimestamp: () => _lastTickTimestamp,
      setLastTickTimestamp: (Duration? value) {
        _lastTickTimestamp = value;
      },
      onFrame: (double frameDt, double alpha) {
        final Level0UpdateState? state = _updateState;
        if (state == null) {
          return;
        }
        state.fps = _runtimeApi.updateSmoothedFps(
          previousFps: state.fps,
          dtSeconds: frameDt,
        );
        // setState fires exactly once per vsync here, not once per substep.
        // The alpha is forwarded so the painter can lerp the render position.
        _refreshLevel0(null, alpha);
      },
      onTick: _tick,
    );
  }

  void _tick(double dt) {
    final Level0UpdateState? state = _updateState;
    if (!mounted || state == null) {
      return;
    }
    _runtimeApi.beginTick();

    if (!state.isWin) {
      _updateMovement(state, dt);
      final Offset cameraFocus = _resolvePlayerCameraFocusPoint(state);
      state.cameraX = cameraFocus.dx;
      state.cameraY = cameraFocus.dy;
      _runtimeApi.setTransform2D(
        id: _level0PlayerTransformId,
        x: state.playerX,
        y: state.playerY,
      );
      _runtimeApi.setTransform2D(
        id: _level0CameraTransformId,
        x: state.cameraX,
        y: state.cameraY,
      );
      _camera
        ..x = state.cameraX
        ..y = state.cameraY;
    } else if (!state.canExitEndState) {
      state.endStateElapsedSeconds += dt;
      state.tickCounter += 1;
    }
  }

  void _updateMovement(Level0UpdateState state, double dt) {
    final bool up = _pressedKeys.contains(LogicalKeyboardKey.arrowUp) ||
        _pressedKeys.contains(LogicalKeyboardKey.keyW);
    final bool down = _pressedKeys.contains(LogicalKeyboardKey.arrowDown) ||
        _pressedKeys.contains(LogicalKeyboardKey.keyS);
    final bool left = _pressedKeys.contains(LogicalKeyboardKey.arrowLeft) ||
        _pressedKeys.contains(LogicalKeyboardKey.keyA);
    final bool right = _pressedKeys.contains(LogicalKeyboardKey.arrowRight) ||
        _pressedKeys.contains(LogicalKeyboardKey.keyD);

    double inputX = 0;
    double inputY = 0;

    if (left) {
      inputX -= 1;
    }
    if (right) {
      inputX += 1;
    }
    if (up) {
      inputY -= 1;
    }
    if (down) {
      inputY += 1;
    }

    if (inputX != 0 && inputY != 0) {
      // Keep diagonal speed consistent with axis-aligned movement.
      const double diagonalNormalization = 0.70710678118;
      inputX *= diagonalNormalization;
      inputY *= diagonalNormalization;
    }

    final bool hasInput = inputX != 0 || inputY != 0;
    if (hasInput) {
      if (up && left) {
        state.direction = 'upLeft';
      } else if (up && right) {
        state.direction = 'upRight';
      } else if (down && left) {
        state.direction = 'downLeft';
      } else if (down && right) {
        state.direction = 'downRight';
      } else if (up) {
        state.direction = 'up';
      } else if (down) {
        state.direction = 'down';
      } else if (left) {
        state.direction = 'left';
      } else if (right) {
        state.direction = 'right';
      }
    }

    final double dx = inputX * state.speedPerSecond * dt;
    final double dy = inputY * state.speedPerSecond * dt;
    final double previousX = state.playerX;
    final double previousY = state.playerY;

    if (dx != 0) {
      final double nextX = state.playerX + dx;
      if (!_wouldCollideWithBlockedZone(
        state,
        nextX: nextX,
        nextY: state.playerY,
      )) {
        state.playerX = nextX;
      }
    }
    if (dy != 0) {
      final double nextY = state.playerY + dy;
      if (!_wouldCollideWithBlockedZone(
        state,
        nextX: state.playerX,
        nextY: nextY,
      )) {
        state.playerY = nextY;
      }
    }

    state.isMoving = state.playerX != previousX || state.playerY != previousY;
    _clearDecorationTileIfOnArbre(state);
    _updateWinState(state);
    _revealPontAmagatLayerIfEnteringFuturPontZone(state);
    state.isOnPont = _isInsidePontZone(state);
    state.animationTimeSeconds += dt;
    state.tickCounter = (state.animationTimeSeconds * 60).floor();
  }

  Offset _resolvePlayerCameraFocusPoint(Level0UpdateState state) {
    final int? spriteIndex = _heroSpriteIndex;
    if (spriteIndex == null) {
      return Offset(state.playerX, state.playerY);
    }
    return _runtimeApi.spriteFocusPoint(
      levelIndex: widget.levelIndex,
      spriteIndex: spriteIndex,
      pose: RuntimeSpritePose(
        levelIndex: widget.levelIndex,
        spriteIndex: spriteIndex,
        x: state.playerX,
        y: state.playerY,
        elapsedSeconds: state.animationTimeSeconds,
      ),
      useFrameRigAnchor: false,
      elapsedSeconds: state.animationTimeSeconds,
    );
  }

  bool _wouldCollideWithBlockedZone(
    Level0UpdateState state, {
    required double nextX,
    required double nextY,
  }) {
    final int? spriteIndex = _heroSpriteIndex;
    if (spriteIndex == null) {
      return false;
    }
    return _runtimeApi
        .collideSpriteWithZones(
          levelIndex: widget.levelIndex,
          spriteIndex: spriteIndex,
          spritePose: RuntimeSpritePose(
            levelIndex: widget.levelIndex,
            spriteIndex: spriteIndex,
            x: nextX,
            y: nextY,
            elapsedSeconds: state.animationTimeSeconds,
          ),
          zoneTypes: _level0BlockedZoneTypes,
          elapsedSeconds: state.animationTimeSeconds,
        )
        .isNotEmpty;
  }

  bool _isInsidePontZone(Level0UpdateState state) {
    final int? spriteIndex = _heroSpriteIndex;
    if (spriteIndex == null) {
      return false;
    }
    return _runtimeApi
        .collideSpriteWithZones(
          levelIndex: widget.levelIndex,
          spriteIndex: spriteIndex,
          spritePose: RuntimeSpritePose(
            levelIndex: widget.levelIndex,
            spriteIndex: spriteIndex,
            x: state.playerX,
            y: state.playerY,
            elapsedSeconds: state.animationTimeSeconds,
          ),
          zoneTypes: const <String>{'Pont'},
          elapsedSeconds: state.animationTimeSeconds,
        )
        .isNotEmpty;
  }

  void _clearDecorationTileIfOnArbre(Level0UpdateState state) {
    final int? spriteIndex = _heroSpriteIndex;
    final int? layerIndex = _decoracionsLayerIndex;
    if (spriteIndex == null || layerIndex == null) {
      return;
    }
    final bool isInsideArbre = _runtimeApi
        .collideSpriteWithZones(
          levelIndex: widget.levelIndex,
          spriteIndex: spriteIndex,
          spritePose: RuntimeSpritePose(
            levelIndex: widget.levelIndex,
            spriteIndex: spriteIndex,
            x: state.playerX,
            y: state.playerY,
            elapsedSeconds: state.animationTimeSeconds,
          ),
          zoneTypes: const <String>{'Arbre'},
          elapsedSeconds: state.animationTimeSeconds,
        )
        .isNotEmpty;
    if (!isInsideArbre) {
      return;
    }

    final TileCoord? tile = _runtimeApi.worldToTile(
      levelIndex: widget.levelIndex,
      layerIndex: layerIndex,
      worldX: state.playerX,
      worldY: state.playerY,
    );
    if (tile == null) {
      return;
    }
    final int tileId = _runtimeApi.tileAt(
      levelIndex: widget.levelIndex,
      layerIndex: layerIndex,
      tileX: tile.x,
      tileY: tile.y,
    );
    final String tileKey = _level0TileKey(tile.x, tile.y);
    if (!state.collectibleArbreTileKeys.contains(tileKey) || tileId < 0) {
      return;
    }
    if (state.collectedArbreTileKeys.contains(tileKey)) {
      return;
    }

    _runtimeApi.gameDataSet(
      <Object>[
        'levels',
        widget.levelIndex,
        'layers',
        layerIndex,
        'tileMap',
        tile.y,
        tile.x,
      ],
      -1,
    );
    state.collectedArbreTileKeys.add(tileKey);
    state.arbresRemovedCount = state.collectedArbreTileKeys.length;
  }

  void _updateWinState(Level0UpdateState state) {
    if (state.isWin || state.totalArbres <= 0) {
      return;
    }
    if (state.arbresRemovedCount >= state.totalArbres) {
      _triggerWin(state);
    }
  }

  void _triggerWin(Level0UpdateState state) {
    state.isWin = true;
    state.endStateElapsedSeconds = 0;
    state.isMoving = false;
    _pressedKeys.clear();
  }

  bool _isInsideZoneWithGameplayData(
    Level0UpdateState state,
    String gameplayDataValue,
  ) {
    final int? spriteIndex = _heroSpriteIndex;
    if (spriteIndex == null) {
      return false;
    }
    final List<ZoneContact> zoneContacts = _runtimeApi.collideSpriteWithZones(
      levelIndex: widget.levelIndex,
      spriteIndex: spriteIndex,
      spritePose: RuntimeSpritePose(
        levelIndex: widget.levelIndex,
        spriteIndex: spriteIndex,
        x: state.playerX,
        y: state.playerY,
        elapsedSeconds: state.animationTimeSeconds,
      ),
      elapsedSeconds: state.animationTimeSeconds,
    );
    final Set<int> checkedZoneIndices = <int>{};
    final String targetGameplayData = gameplayDataValue.trim();
    for (final ZoneContact contact in zoneContacts) {
      // A sprite can intersect multiple hitboxes in one zone; evaluate each zone once.
      if (!checkedZoneIndices.add(contact.zoneIndex)) {
        continue;
      }
      final String zoneGameplayData = (_runtimeApi.gameDataGetAs<String>(
                <Object>[
                  'levels',
                  widget.levelIndex,
                  'zones',
                  contact.zoneIndex,
                  'gameplayData',
                ],
              ) ??
              '')
          .trim();
      if (zoneGameplayData == targetGameplayData) {
        return true;
      }
    }
    return false;
  }

  void _revealLayerIfHidden(int layerIndex) {
    final bool isVisible = _runtimeApi.gameDataGetAs<bool>(
          <Object>[
            'levels',
            widget.levelIndex,
            'layers',
            layerIndex,
            'visible'
          ],
        ) ??
        false;
    if (isVisible) {
      return;
    }
    _runtimeApi.gameDataSet(
      <Object>['levels', widget.levelIndex, 'layers', layerIndex, 'visible'],
      true,
    );
  }

  void _revealPontAmagatLayerIfEnteringFuturPontZone(Level0UpdateState state) {
    final int? layerIndex = _pontAmagatLayerIndex;
    if (layerIndex == null) {
      return;
    }
    final bool isInsideFuturPontZone =
        _isInsideZoneWithGameplayData(state, _level0FuturPontGameplayData);
    final bool enteredFuturPontZone =
        isInsideFuturPontZone && !state.wasInsideFuturPontGameplayZone;
    if (enteredFuturPontZone) {
      _revealLayerIfHidden(layerIndex);
    }
    state.wasInsideFuturPontGameplayZone = isInsideFuturPontZone;
  }
}
