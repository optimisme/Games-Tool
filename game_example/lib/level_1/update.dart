part of 'main.dart';

/// Per-frame simulation for platforming physics, combat, and win/lose state.
extension _Level1Update on _Level1State {
  /// Starts the fixed-step loop ticker for level 1.
  void _startLoop() {
    _ticker = restartGameLoopTicker(
      tickerProvider: this,
      ticker: _ticker,
      getLastTickTimestamp: () => _lastTickTimestamp,
      setLastTickTimestamp: (Duration? value) {
        _lastTickTimestamp = value;
      },
      onFrame: (double frameDt, double alpha) {
        final Level1UpdateState? state = _updateState;
        if (state == null) {
          return;
        }
        state.fps = _runtimeApi.updateSmoothedFps(
          previousFps: state.fps,
          dtSeconds: frameDt,
        );
        // setState fires exactly once per vsync here, not once per substep.
        // The alpha is forwarded so the painter can lerp the render position.
        _refreshLevel1(null, alpha);
      },
      onTick: _tick,
    );
  }

  /// Advances one fixed simulation tick.
  void _tick(double dt) {
    final Level1UpdateState? state = _updateState;
    if (!mounted || state == null) {
      return;
    }
    _runtimeApi.beginTick();

    if (!state.isGameOver && !state.isWin) {
      _updatePhysics(state, dt);
      final Offset cameraFocus = _resolvePlayerCameraFocusPoint(state);
      state.cameraX = cameraFocus.dx + _cameraFollowOffsetX;
      state.cameraY = cameraFocus.dy + _cameraFollowOffsetY;
      _runtimeApi.setTransform2D(
        id: _level1PlayerTransformId,
        x: state.playerX,
        y: state.playerY,
      );
      _runtimeApi.setTransform2D(
        id: _level1CameraTransformId,
        x: state.cameraX,
        y: state.cameraY,
      );
      // Camera follows player with level-configured offsets.
      _camera
        ..x = state.cameraX
        ..y = state.cameraY;
    } else if (!state.canExitEndState) {
      state.endStateElapsedSeconds += dt;
      state.tickCounter += 1;
    }
  }

  /// Updates movement, collisions, combat, and end-state transitions.
  void _updatePhysics(Level1UpdateState state, double dt) {
    final Offset movingFloorDelta = _updateLinkedPathBindings(state, dt);
    if (movingFloorDelta.dx != 0 || movingFloorDelta.dy != 0) {
      state.playerX += movingFloorDelta.dx;
      state.playerY += movingFloorDelta.dy;
    }
    // Resolve zone rects once per simulation tick after moving path bindings.
    final List<Rect> floors = _runtimeApi.zoneRectsByTypeOrName(
      levelIndex: widget.levelIndex,
      value: _level1FloorZoneName,
    );
    final List<Rect> deathZones = _runtimeApi.zoneRectsByTypeOrName(
      levelIndex: widget.levelIndex,
      value: _level1DeathZoneName,
    );

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

    final bool hasSupport = _isStandingOnFloor(
      state,
      floors: floors,
    );
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
      floors: floors,
    );
    final bool standingOnFloor = _isStandingOnFloor(
      state,
      floors: floors,
    );
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

    if (!state.isGameOver &&
        _isTouchingDeathZone(
          state,
          deathZones: deathZones,
        )) {
      _triggerGameOver(state);
    }

    state.animationTimeSeconds += dt;
    state.tickCounter = (state.animationTimeSeconds * 60).floor();
  }

  /// Resolves camera focus from the player's anchor-aware pose.
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
      useFrameRigAnchor: false,
      elapsedSeconds: state.animationTimeSeconds,
    );
  }

  /// Advances all path bindings and returns floor carry delta for the player.
  Offset _updateLinkedPathBindings(Level1UpdateState state, double dt) {
    if (_pathBindings.isEmpty) {
      return Offset.zero;
    }
    final double previousTime = state.pathMotionTimeSeconds;
    final double nextTime = previousTime + dt;
    state.pathMotionTimeSeconds = nextTime;
    final List<Rect> playerRectsBefore = _playerCollisionRectsForPose(
      state,
      y: state.playerY + 0.5,
      elapsedSeconds: state.animationTimeSeconds,
    );
    Offset carryDelta = Offset.zero;
    double carryDeltaMagnitudeSq = 0;

    for (final _Level1PathBindingRuntime binding in _pathBindings) {
      if (!binding.enabled) {
        continue;
      }
      final Offset previousPosition =
          _bindingPositionAtTime(binding, previousTime);
      final Offset nextPosition = _bindingPositionAtTime(binding, nextTime);
      binding.targetObject['x'] = nextPosition.dx;
      binding.targetObject['y'] = nextPosition.dy;
      _runtimeApi.setTransform2D(
        id: _level1PathTargetTransformId(
          targetType: binding.targetType,
          targetIndex: binding.targetIndex,
        ),
        x: nextPosition.dx,
        y: nextPosition.dy,
      );

      if (!binding.isFloorZone) {
        continue;
      }
      final double width =
          (binding.targetObject['width'] as num?)?.toDouble() ?? 0;
      final double height =
          (binding.targetObject['height'] as num?)?.toDouble() ?? 0;
      if (width <= 0 || height <= 0) {
        continue;
      }
      final Rect previousFloorRect = Rect.fromLTWH(
        previousPosition.dx,
        previousPosition.dy,
        width,
        height,
      );
      if (!_isStandingOnFloorRects(
          playerRectsBefore, <Rect>[previousFloorRect])) {
        continue;
      }
      final Offset candidateDelta = nextPosition - previousPosition;
      final double candidateMagnitudeSq = candidateDelta.distanceSquared;
      if (candidateMagnitudeSq <= carryDeltaMagnitudeSq) {
        continue;
      }
      carryDelta = candidateDelta;
      carryDeltaMagnitudeSq = candidateMagnitudeSq;
    }

    return carryDelta;
  }

  /// Samples one binding world position at the provided time.
  Offset _bindingPositionAtTime(
    _Level1PathBindingRuntime binding,
    double timeSeconds,
  ) {
    final double progress = _pathProgressAtTime(
      behavior: binding.behavior,
      durationSeconds: binding.durationSeconds,
      timeSeconds: timeSeconds,
    );
    final Offset pathPosition = binding.path.sampleAtProgress(progress);
    if (!binding.relativeToInitialPosition) {
      return pathPosition;
    }
    final Offset offset = pathPosition - binding.path.firstPoint;
    return Offset(
      binding.initialX + offset.dx,
      binding.initialY + offset.dy,
    );
  }

  /// Resolves normalized path progress for restart/ping-pong/once modes.
  double _pathProgressAtTime({
    required String behavior,
    required double durationSeconds,
    required double timeSeconds,
  }) {
    if (!durationSeconds.isFinite || durationSeconds <= 0) {
      return 0;
    }
    final double t = timeSeconds < 0 ? 0 : timeSeconds;
    switch (behavior) {
      case _level1PathBehaviorPingPong:
        final double cycle = durationSeconds * 2;
        if (cycle <= 0) {
          return 0;
        }
        final double cycleTime = t % cycle;
        if (cycleTime <= durationSeconds) {
          return cycleTime / durationSeconds;
        }
        final double backwardsTime = cycleTime - durationSeconds;
        return 1 - (backwardsTime / durationSeconds);
      case _level1PathBehaviorOnce:
        return (t / durationSeconds).clamp(0.0, 1.0);
      case _level1PathBehaviorRestart:
      default:
        return (t % durationSeconds) / durationSeconds;
    }
  }

  /// Returns whether a zone should be treated as floor support.
  bool _isFloorZone(Map<String, dynamic> zone) {
    return _runtimeApi.gamesTool.zoneMatchesTypeOrName(
      zone,
      _level1FloorZoneName,
    );
  }

  /// Applies game-over state and clears active input.
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

  /// Applies win state and clears active input.
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

  /// Handles player-vs-dragon interactions and stomp/damage rules.
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

  /// Applies one dragon hit of damage to the player.
  void _applyDragonDamage(Level1UpdateState state) {
    state.lifePercent -= _level1DragonDamagePercent;
    if (state.lifePercent < 0) {
      state.lifePercent = 0;
    }
    if (state.lifePercent == 0) {
      _triggerGameOver(state);
    }
  }

  /// Removes dragons whose death animation has completed.
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

  /// Resolves dragon death animation duration from runtime animation data.
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

  /// Returns true when any rect from set A overlaps set B.
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

  /// Checks whether the player currently overlaps death zones.
  bool _isTouchingDeathZone(
    Level1UpdateState state, {
    required List<Rect> deathZones,
  }) {
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

  /// Checks whether player collision rects are currently grounded.
  bool _isStandingOnFloor(
    Level1UpdateState state, {
    required List<Rect> floors,
  }) {
    if (floors.isEmpty) {
      return false;
    }
    final List<Rect> playerRects = _playerCollisionRectsForPose(
      state,
      y: state.playerY + 0.5,
      elapsedSeconds: state.animationTimeSeconds,
    );
    return _isStandingOnFloorRects(playerRects, floors);
  }

  /// Evaluates floor support by horizontal overlap and top-edge proximity.
  bool _isStandingOnFloorRects(List<Rect> playerRects, List<Rect> floors) {
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

  /// Collects gems touched by player collision rects.
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

  /// Resolves all gem sprite indices for this level.
  List<int> _gemSpriteIndices() {
    final Map<String, dynamic>? level = _level;
    return _runtimeApi.gamesTool.findSpriteIndicesByTypeOrName(
      level,
      _level1GemSpriteName,
    );
  }

  /// Resolves all dragon sprite indices for this level.
  List<int> _dragonSpriteIndices() {
    final Map<String, dynamic>? level = _level;
    return _runtimeApi.gamesTool.findSpriteIndicesByTypeOrName(
      level,
      _level1DragonSpriteName,
    );
  }

  /// Resolves player collision rects for a given pose sample.
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

  /// Corrects downward floor penetration using swept and overlap checks.
  bool _resolveFloorPenetration(
    Level1UpdateState state, {
    required double previousX,
    required double previousY,
    required List<Rect> floors,
  }) {
    if (state.velocityY < 0) {
      return false;
    }
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
