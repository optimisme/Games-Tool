part of 'main.dart';

extension _Level0Update on _Level0State {
  void _startLoop() {
    _ticker?.dispose();
    _lastTickTimestamp = null;
    _ticker = createTicker((Duration elapsed) {
      final Duration? previous = _lastTickTimestamp;
      _lastTickTimestamp = elapsed;

      final double dt = previous == null
          ? 1 / 60
          : (elapsed - previous).inMicroseconds / 1000000;

      _tick(dt.clamp(0.0, 0.05));
    });
    _ticker?.start();
  }

  void _tick(double dt) {
    final Level0UpdateState? state = _updateState;
    if (!mounted || state == null) {
      return;
    }

    _updateMovement(state, dt);
    _camera
      ..x = state.playerX
      ..y = state.playerY;

    _refreshLevel0();
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
    _revealPontAmagatLayerIfEnteringFuturPontZone(state);
    state.isOnPont = _isInsidePontZone(state);
    state.animationTimeSeconds += dt;
    state.tickCounter = (state.animationTimeSeconds * 60).floor();
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
    if (tileId < 0) {
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
    state.arbresRemovedCount += 1;
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
