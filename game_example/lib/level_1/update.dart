part of 'main.dart';

/// Per-frame simulation for platforming physics, combat, and win/lose state.
extension _Level1Update on _Level1State {
  void _startLoop() {
    _ticker = restartGameLoopTicker(
      tickerProvider: this,
      ticker: _ticker,
      getLastTickTimestamp: () => _lastTickTimestamp,
      setLastTickTimestamp: (Duration? value) {
        _lastTickTimestamp = value;
      },
      onTick: _tick,
    );
  }

  void _tick(double dt) {
    final Level1UpdateState? state = _updateState;
    if (!mounted || state == null) {
      return;
    }
    state.fps = _runtimeApi.updateSmoothedFps(
      previousFps: state.fps,
      dtSeconds: dt,
    );

    if (!state.isGameOver && !state.isWin) {
      _updatePhysics(state, dt);
      final Offset cameraFocus = _resolvePlayerCameraFocusPoint(state);
      // Camera follows player with level-configured offsets.
      _camera
        ..x = cameraFocus.dx + _cameraFollowOffsetX
        ..y = cameraFocus.dy + _cameraFollowOffsetY;
    } else if (!state.canExitEndState) {
      state.endStateElapsedSeconds += dt;
      state.tickCounter += 1;
    }

    _refreshLevel1();
  }

  void _updatePhysics(Level1UpdateState state, double dt) {
    final bool wasStandingOnMovingPlatform = _isStandingOnMovingPlatform(state);
    final Offset movingPlatformDelta = _updateMovingPlatformPath(state, dt);
    if ((movingPlatformDelta.dx != 0 || movingPlatformDelta.dy != 0) &&
        wasStandingOnMovingPlatform) {
      state.playerX += movingPlatformDelta.dx;
      state.playerY += movingPlatformDelta.dy;
    }

    final bool moveLeft = _pressedKeys.contains(LogicalKeyboardKey.arrowLeft) ||
        _pressedKeys.contains(LogicalKeyboardKey.keyA);
    final bool moveRight =
        _pressedKeys.contains(LogicalKeyboardKey.arrowRight) ||
            _pressedKeys.contains(LogicalKeyboardKey.keyD);

    if (moveLeft == moveRight) {
      state.velocityX = 0;
    } else if (moveLeft) {
      state.velocityX = -state.moveSpeedPerSecond;
      state.facingRight = false;
    } else {
      state.velocityX = state.moveSpeedPerSecond;
      state.facingRight = true;
    }

    final bool hasSupport = _isStandingOnFloor(state);
    if (hasSupport && state.velocityY >= 0) {
      state.velocityY = 0;
      state.onGround = true;
      state.isInJumpArc = false;
    } else if (!hasSupport) {
      state.onGround = false;
    }

    if (_jumpQueued && state.onGround) {
      state.velocityY = -state.jumpImpulsePerSecond;
      state.onGround = false;
      state.isInJumpArc = true;
    }
    // Consume queued jump once so one key press cannot trigger repeated jumps.
    _jumpQueued = false;

    if (!state.onGround || state.velocityY < 0) {
      state.velocityY += state.gravityPerSecondSq * dt;
      if (state.velocityY > state.maxFallSpeedPerSecond) {
        state.velocityY = state.maxFallSpeedPerSecond;
      }
    }

    final double previousPlayerX = state.playerX;
    final double previousPlayerY = state.playerY;
    state.playerX += state.velocityX * dt;
    state.playerY += state.velocityY * dt;
    final bool landed = _resolveFloorPenetration(
      state,
      previousX: previousPlayerX,
      previousY: previousPlayerY,
    );
    final bool standingOnFloor = _isStandingOnFloor(state);
    if ((landed || standingOnFloor) && state.velocityY >= 0) {
      state.velocityY = 0;
      state.onGround = true;
      state.isInJumpArc = false;
    } else {
      state.onGround = false;
    }
    _collectTouchedGems(state);
    if (state.isWin) {
      return;
    }
    _handleDragonInteractions(state);

    if (!state.isGameOver && _isTouchingDeathZone(state)) {
      _triggerGameOver(state);
    }

    state.animationTimeSeconds += dt;
    state.tickCounter = (state.animationTimeSeconds * 60).floor();
  }

  Offset _resolvePlayerCameraFocusPoint(Level1UpdateState state) {
    final int? playerSpriteIndex = _playerSpriteIndex;
    if (playerSpriteIndex == null) {
      return Offset(state.playerX, state.playerY);
    }
    return _runtimeApi.spriteFocusPoint(
      levelIndex: widget.levelIndex,
      spriteIndex: playerSpriteIndex,
      pose: RuntimeSpritePose(
        levelIndex: widget.levelIndex,
        spriteIndex: playerSpriteIndex,
        x: state.playerX,
        y: state.playerY,
        flipX: !state.facingRight,
        elapsedSeconds: state.animationTimeSeconds,
      ),
      elapsedSeconds: state.animationTimeSeconds,
    );
  }

  Offset _updateMovingPlatformPath(Level1UpdateState state, double dt) {
    if (_movingPlatformLayerIndex == null ||
        _movingPlatformFloorZoneIndex == null) {
      return Offset.zero;
    }
    final Offset previousPosition = _movingPlatformPositionAtTime(
      state.platformMotionTimeSeconds,
    );
    state.platformMotionTimeSeconds += dt;
    final Offset platformPosition = _movingPlatformPositionAtTime(
      state.platformMotionTimeSeconds,
    );
    _applyMovingPlatformPose(platformPosition);
    return platformPosition - previousPosition;
  }

  Offset _movingPlatformPositionAtTime(double timeSeconds) {
    if (_level1MovingPlatformPath.length < 3 ||
        _level1MovingPlatformLoopSeconds <= 0) {
      return _level1MovingPlatformPath.first;
    }
    // Motion follows a looping triangle path A->B->C->A at constant speed.
    final Offset a = _level1MovingPlatformPath[0];
    final Offset b = _level1MovingPlatformPath[1];
    final Offset c = _level1MovingPlatformPath[2];
    final double ab = (b - a).distance;
    final double bc = (c - b).distance;
    final double ca = (a - c).distance;
    final double totalDistance = ab + bc + ca;
    if (totalDistance <= 0) {
      return a;
    }

    final double loopTime = timeSeconds % _level1MovingPlatformLoopSeconds;
    double travelled =
        (loopTime / _level1MovingPlatformLoopSeconds) * totalDistance;

    if (travelled <= ab) {
      return Offset.lerp(a, b, ab == 0 ? 0 : travelled / ab) ?? a;
    }
    travelled -= ab;
    if (travelled <= bc) {
      return Offset.lerp(b, c, bc == 0 ? 0 : travelled / bc) ?? b;
    }
    travelled -= bc;
    return Offset.lerp(c, a, ca == 0 ? 0 : travelled / ca) ?? c;
  }

  void _applyMovingPlatformPose(Offset platformPosition) {
    final int? layerIndex = _movingPlatformLayerIndex;
    final int? zoneIndex = _movingPlatformFloorZoneIndex;
    if (layerIndex == null || zoneIndex == null) {
      return;
    }

    _runtimeApi.gameDataSet(
      <Object>['levels', widget.levelIndex, 'layers', layerIndex, 'x'],
      platformPosition.dx,
    );
    _runtimeApi.gameDataSet(
      <Object>['levels', widget.levelIndex, 'layers', layerIndex, 'y'],
      platformPosition.dy,
    );
    _runtimeApi.gameDataSet(
      <Object>['levels', widget.levelIndex, 'zones', zoneIndex, 'x'],
      platformPosition.dx,
    );
    _runtimeApi.gameDataSet(
      <Object>['levels', widget.levelIndex, 'zones', zoneIndex, 'y'],
      platformPosition.dy + _level1MovingPlatformFloorYOffset,
    );
  }

  void _triggerGameOver(Level1UpdateState state) {
    state.isGameOver = true;
    state.endStateElapsedSeconds = 0;
    state.velocityX = 0;
    state.velocityY = 0;
    state.onGround = false;
    state.isInJumpArc = false;
    _jumpQueued = false;
    _pressedKeys.clear();
  }

  void _triggerWin(Level1UpdateState state) {
    state.isWin = true;
    state.endStateElapsedSeconds = 0;
    state.velocityX = 0;
    state.velocityY = 0;
    state.onGround = false;
    state.isInJumpArc = false;
    _jumpQueued = false;
    _pressedKeys.clear();
  }

  void _handleDragonInteractions(Level1UpdateState state) {
    _pruneFinishedDragonDeaths(state);
    if (state.isGameOver) {
      return;
    }
    final List<Rect> playerRects = _playerCollisionRectsForPose(
      state,
      y: state.playerY,
      elapsedSeconds: state.animationTimeSeconds,
    );
    if (playerRects.isEmpty) {
      return;
    }
    final bool foxyIsFalling = !state.onGround && state.velocityY > 25;
    final List<int> dragons = _dragonSpriteIndices();
    final Set<int> touchingDragonsNow = <int>{};
    for (final int dragonIndex in dragons) {
      if (state.removedDragonSpriteIndices.contains(dragonIndex) ||
          state.dragonDeathStartSeconds.containsKey(dragonIndex)) {
        continue;
      }
      final List<Rect> dragonRects = _runtimeApi.spriteCollisionRects(
        levelIndex: widget.levelIndex,
        spriteIndex: dragonIndex,
        elapsedSeconds: state.animationTimeSeconds,
      );
      if (!_rectsOverlapAny(playerRects, dragonRects)) {
        continue;
      }
      if (foxyIsFalling) {
        // Stomp rule: falling onto dragon kills dragon and bounces player up.
        state.dragonDeathStartSeconds[dragonIndex] = state.animationTimeSeconds;
        state.velocityY = -state.jumpImpulsePerSecond * 0.38;
        state.onGround = false;
        continue;
      }
      touchingDragonsNow.add(dragonIndex);
      if (state.touchingDragonSpriteIndices.contains(dragonIndex)) {
        continue;
      }
      _applyDragonDamage(state);
      if (state.isGameOver) {
        state.touchingDragonSpriteIndices
          ..clear()
          ..addAll(touchingDragonsNow);
        return;
      }
    }
    state.touchingDragonSpriteIndices
      ..clear()
      ..addAll(touchingDragonsNow);
  }

  void _applyDragonDamage(Level1UpdateState state) {
    state.lifePercent -= _level1DragonDamagePercent;
    if (state.lifePercent < 0) {
      state.lifePercent = 0;
    }
    if (state.lifePercent == 0) {
      _triggerGameOver(state);
    }
  }

  void _pruneFinishedDragonDeaths(Level1UpdateState state) {
    if (state.dragonDeathStartSeconds.isEmpty) {
      return;
    }
    final double deathDuration = _dragonDeathDurationSeconds();
    final List<int> finished = <int>[];
    state.dragonDeathStartSeconds.forEach((int spriteIndex, double startTime) {
      final double elapsed = state.animationTimeSeconds - startTime;
      if (elapsed >= deathDuration) {
        finished.add(spriteIndex);
      }
    });
    if (finished.isEmpty) {
      return;
    }
    for (final int spriteIndex in finished) {
      state.dragonDeathStartSeconds.remove(spriteIndex);
      state.removedDragonSpriteIndices.add(spriteIndex);
    }
  }

  double _dragonDeathDurationSeconds() {
    final GamesToolApi gamesTool = _runtimeApi.gamesTool;
    final Map<String, dynamic> gameData = _runtimeApi.gameData;
    final Map<String, dynamic>? animation = gamesTool.findAnimationByName(
      gameData,
      _level1AnimDragonDeath,
    );
    if (animation == null) {
      return 0.7;
    }
    final AnimationPlaybackConfig playback =
        gamesTool.animationPlaybackConfig(animation);
    final double duration = playback.frameCount / playback.fps;
    if (!duration.isFinite || duration <= 0) {
      return 0.7;
    }
    return duration;
  }

  bool _rectsOverlapAny(List<Rect> a, List<Rect> b) {
    for (final Rect ra in a) {
      for (final Rect rb in b) {
        if (ra.overlaps(rb)) {
          return true;
        }
      }
    }
    return false;
  }

  bool _isTouchingDeathZone(Level1UpdateState state) {
    final List<Rect> deathZones = _resolveLevel1DeathZones(_level);
    if (deathZones.isEmpty) {
      return false;
    }
    final List<Rect> playerRects = _playerCollisionRectsForPose(
      state,
      y: state.playerY,
      elapsedSeconds: state.animationTimeSeconds,
    );
    for (final Rect playerRect in playerRects) {
      for (final Rect deathZone in deathZones) {
        if (playerRect.overlaps(deathZone)) {
          return true;
        }
      }
    }
    return false;
  }

  bool _isStandingOnFloor(Level1UpdateState state) {
    final List<Rect> floors = _resolveLevel1FloorZones(_level);
    if (floors.isEmpty) {
      return false;
    }
    final List<Rect> playerRects = _playerCollisionRectsForPose(
      state,
      y: state.playerY + 0.5,
      elapsedSeconds: state.animationTimeSeconds,
    );
    for (final Rect playerRect in playerRects) {
      for (final Rect floor in floors) {
        final bool overlapsHorizontally =
            playerRect.right > floor.left && playerRect.left < floor.right;
        if (!overlapsHorizontally) {
          continue;
        }
        final double bottomDelta = (playerRect.bottom - floor.top).abs();
        if (bottomDelta <= 1.0) {
          return true;
        }
      }
    }
    return false;
  }

  bool _isStandingOnMovingPlatform(Level1UpdateState state) {
    final List<Rect> floors = _movingPlatformFloorRects();
    if (floors.isEmpty) {
      return false;
    }
    final List<Rect> playerRects = _playerCollisionRectsForPose(
      state,
      y: state.playerY + 0.5,
      elapsedSeconds: state.animationTimeSeconds,
    );
    for (final Rect playerRect in playerRects) {
      for (final Rect floor in floors) {
        final bool overlapsHorizontally =
            playerRect.right > floor.left && playerRect.left < floor.right;
        if (!overlapsHorizontally) {
          continue;
        }
        final double bottomDelta = (playerRect.bottom - floor.top).abs();
        if (bottomDelta <= 1.0) {
          return true;
        }
      }
    }
    return false;
  }

  List<Rect> _movingPlatformFloorRects() {
    final int? zoneIndex = _movingPlatformFloorZoneIndex;
    final Map<String, dynamic>? level = _level;
    if (zoneIndex == null || level == null) {
      return const <Rect>[];
    }
    final List<Map<String, dynamic>> zones =
        ((level['zones'] as List<dynamic>?) ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);
    if (zoneIndex < 0 || zoneIndex >= zones.length) {
      return const <Rect>[];
    }
    final Map<String, dynamic> zone = zones[zoneIndex];
    final double x = (zone['x'] as num?)?.toDouble() ?? 0;
    final double y = (zone['y'] as num?)?.toDouble() ?? 0;
    final double width = (zone['width'] as num?)?.toDouble() ?? 0;
    final double height = (zone['height'] as num?)?.toDouble() ?? 0;
    if (width <= 0 || height <= 0) {
      return const <Rect>[];
    }
    return <Rect>[Rect.fromLTWH(x, y, width, height)];
  }

  void _collectTouchedGems(Level1UpdateState state) {
    final List<int> candidateGemIndices = _gemSpriteIndices()
        .where((index) => !state.collectedGemSpriteIndices.contains(index))
        .toList(growable: false);
    if (candidateGemIndices.isEmpty) {
      return;
    }
    final List<Rect> playerRects = _playerCollisionRectsForPose(
      state,
      y: state.playerY,
      elapsedSeconds: state.animationTimeSeconds,
    );
    if (playerRects.isEmpty) {
      return;
    }

    final List<int> newlyCollected = <int>[];
    for (final int gemIndex in candidateGemIndices) {
      final List<Rect> gemRects = _runtimeApi.spriteCollisionRects(
        levelIndex: widget.levelIndex,
        spriteIndex: gemIndex,
        elapsedSeconds: state.animationTimeSeconds,
      );
      bool collided = false;
      for (final Rect playerRect in playerRects) {
        for (final Rect gemRect in gemRects) {
          if (playerRect.overlaps(gemRect)) {
            collided = true;
            break;
          }
        }
        if (collided) {
          break;
        }
      }
      if (collided) {
        newlyCollected.add(gemIndex);
      }
    }
    if (newlyCollected.isEmpty) {
      return;
    }
    state.collectedGemSpriteIndices.addAll(newlyCollected);
    state.gemsCount += newlyCollected.length;
    if (state.totalGems > 0 && state.gemsCount >= state.totalGems) {
      _triggerWin(state);
    }
  }

  List<int> _gemSpriteIndices() {
    final Map<String, dynamic>? level = _level;
    if (level == null) {
      return const <int>[];
    }
    final List<Map<String, dynamic>> sprites =
        _runtimeApi.gamesTool.listLevelSprites(level);
    final List<int> indices = <int>[];
    for (int i = 0; i < sprites.length; i++) {
      if (_isLevel1GemSprite(sprites[i])) {
        indices.add(i);
      }
    }
    return indices;
  }

  List<int> _dragonSpriteIndices() {
    final Map<String, dynamic>? level = _level;
    if (level == null) {
      return const <int>[];
    }
    final List<Map<String, dynamic>> sprites =
        _runtimeApi.gamesTool.listLevelSprites(level);
    final List<int> indices = <int>[];
    for (int i = 0; i < sprites.length; i++) {
      if (_isLevel1DragonSprite(sprites[i])) {
        indices.add(i);
      }
    }
    return indices;
  }

  List<Rect> _playerCollisionRectsForPose(
    Level1UpdateState state, {
    required double y,
    required double elapsedSeconds,
  }) {
    final int? playerSpriteIndex = _playerSpriteIndex;
    if (playerSpriteIndex == null || !_runtimeApi.isReady || _level == null) {
      return const <Rect>[];
    }
    return _runtimeApi.spriteCollisionRects(
      levelIndex: widget.levelIndex,
      spriteIndex: playerSpriteIndex,
      elapsedSeconds: elapsedSeconds,
      pose: RuntimeSpritePose(
        levelIndex: widget.levelIndex,
        spriteIndex: playerSpriteIndex,
        x: state.playerX,
        y: y,
        flipX: !state.facingRight,
        elapsedSeconds: elapsedSeconds,
      ),
    );
  }

  bool _resolveFloorPenetration(
    Level1UpdateState state, {
    required double previousX,
    required double previousY,
  }) {
    if (state.velocityY < 0) {
      return false;
    }
    final List<Rect> floors = _resolveLevel1FloorZones(_level);
    if (floors.isEmpty) {
      return false;
    }

    final int? playerSpriteIndex = _playerSpriteIndex;
    if (playerSpriteIndex != null) {
      final SweptRectCollision? sweptCollision =
          _runtimeApi.firstDownwardSpriteCollisionAgainstRects(
        levelIndex: widget.levelIndex,
        spriteIndex: playerSpriteIndex,
        previousPose: RuntimeSpritePose(
          levelIndex: widget.levelIndex,
          spriteIndex: playerSpriteIndex,
          x: previousX,
          y: previousY,
          flipX: !state.facingRight,
          elapsedSeconds: state.animationTimeSeconds,
        ),
        currentPose: RuntimeSpritePose(
          levelIndex: widget.levelIndex,
          spriteIndex: playerSpriteIndex,
          x: state.playerX,
          y: state.playerY,
          flipX: !state.facingRight,
          elapsedSeconds: state.animationTimeSeconds,
        ),
        staticRects: floors,
      );

      if (sweptCollision != null) {
        final double penetration =
            sweptCollision.movingRectEnd.bottom - sweptCollision.staticRect.top;
        state.playerY -= (penetration > 0 ? penetration : 0) + 0.01;
        return true;
      }
    }

    double correctedY = state.playerY;
    bool landed = false;
    for (int i = 0; i < 6; i++) {
      final List<Rect> playerRects = _playerCollisionRectsForPose(
        state,
        y: correctedY,
        elapsedSeconds: state.animationTimeSeconds,
      );
      double maxPenetration = 0;
      for (final Rect playerRect in playerRects) {
        for (final Rect floor in floors) {
          final bool overlapsHorizontally =
              playerRect.right > floor.left && playerRect.left < floor.right;
          if (!overlapsHorizontally) {
            continue;
          }
          final bool crossedTop =
              playerRect.bottom > floor.top && playerRect.top < floor.top + 4;
          if (!crossedTop) {
            continue;
          }
          final double penetration = playerRect.bottom - floor.top;
          if (penetration > maxPenetration) {
            maxPenetration = penetration;
          }
        }
      }
      if (maxPenetration <= 0) {
        break;
      }
      correctedY -= maxPenetration + 0.01;
      landed = true;
    }
    state.playerY = correctedY;
    return landed;
  }
}
