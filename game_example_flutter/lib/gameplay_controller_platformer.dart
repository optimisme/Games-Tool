import 'dart:math' as math;

import 'port_libdgx/gdx.dart';
import 'port_libdgx/gdx_collections.dart';
import 'gameplay_controller_base.dart';
import 'level_data.dart';
import 'level_renderer.dart';
import 'port_libdgx/math_types.dart';
import 'runtime_transform.dart';

class GameplayControllerPlatformer extends GameplayControllerBase {
  static const double MOVE_SPEED_PER_SECOND = 150;
  static const double GRAVITY_PER_SECOND_SQ = 2088;
  static const double JUMP_IMPULSE_PER_SECOND = 708;
  static const double MAX_FALL_SPEED_PER_SECOND = 840;
  static const double FLOOR_SUPPORT_DELTA = 1;
  static const double COLLISION_EPSILON = 1.2;
  static const double FLOOR_WALL_LIKE_RATIO = 1.2;
  static const double DRAGON_STOMP_MIN_FALL_SPEED = 25;
  static const double DRAGON_DAMAGE_PERCENT = 20;
  static const double DRAGON_TOUCH_DAMAGE_INTERVAL_SECONDS = 0.5;
  static const double START_LIFE_PERCENT = 100;
  static const double DRAGON_DEATH_FALLBACK_DURATION_SECONDS = 0.7;
  static const String DRAGON_DEATH_ANIMATION_NAME = 'Dragon Death';
  static const double DEFAULT_ANIMATION_FPS = 8;

  final IntArray floorZoneIndices = IntArray();
  final IntArray solidZoneIndices = IntArray();
  final IntArray deathZoneIndices = IntArray();
  late final IntArray gemSpriteIndices;
  late final IntArray dragonSpriteIndices;
  final IntFloatMap dragonDeathStartSecondsBySprite = IntFloatMap();
  final IntArray completedDragonDeathSpriteIndices = IntArray();
  final IntSet collectedGemSpriteIndices = IntSet();
  final IntSet removedDragonSpriteIndices = IntSet();
  final IntSet touchingDragonSpriteIndices = IntSet();
  final IntSet touchingDragonNowCache = IntSet();
  final IntFloatMap nextDragonDamageSecondsBySprite = IntFloatMap();
  final IntArray expiredDragonDamageSpriteIndices = IntArray();
  final Rectangle previousPlayerRectCache = Rectangle();

  late final double dragonDeathDurationSeconds;
  double velocityX = 0;
  double velocityY = 0;
  double lifePercent = START_LIFE_PERCENT;
  double simulationTimeSeconds = 0;
  bool onGround = false;
  bool gameOver = false;
  bool win = false;
  bool jumpQueued = false;
  bool facingRight = true;

  GameplayControllerPlatformer(
    LevelData levelData,
    Array<SpriteRuntimeState> spriteRuntimeStates,
    List<bool> layerVisibilityStates,
    Array<RuntimeTransform> zoneRuntimeStates,
    Array<RuntimeTransform> zonePreviousRuntimeStates,
  ) : super(
        levelData,
        spriteRuntimeStates,
        layerVisibilityStates,
        zoneRuntimeStates,
        zonePreviousRuntimeStates,
      ) {
    _classifyZones();
    gemSpriteIndices = findSpriteIndicesByTypeOrName(<String>['gem']);
    dragonSpriteIndices = findSpriteIndicesByTypeOrName(<String>['dragon']);
    dragonDeathDurationSeconds = _resolveDragonDeathDurationSeconds();
    onGround = _isStandingOnFloor();
    _updatePlayerAnimationSelection();
    syncPlayerToSpriteRuntime();
  }

  int getCollectedGemsCount() => collectedGemSpriteIndices.size;

  int getTotalGemsCount() => gemSpriteIndices.size;

  double getLifePercent() => lifePercent;

  bool isGameOver() => gameOver;

  bool isWin() => win;

  @override
  void handleInput() {
    if (Gdx.input.isKeyJustPressed(Input.Keys.SPACE) ||
        Gdx.input.isKeyJustPressed(Input.Keys.W) ||
        Gdx.input.isKeyJustPressed(Input.Keys.UP)) {
      jumpQueued = true;
    }
  }

  @override
  void fixedUpdate(double dtSeconds) {
    simulationTimeSeconds += math.max(0, dtSeconds);
    _pruneCompletedDragonDeaths();

    if (playerSpriteIndex < 0) {
      return;
    }

    if (gameOver || win) {
      velocityX = 0;
      velocityY = 0;
      jumpQueued = false;
      _updatePlayerAnimationSelection();
      syncPlayerToSpriteRuntime();
      return;
    }

    final bool moveLeft =
        Gdx.input.isKeyPressed(Input.Keys.LEFT) ||
        Gdx.input.isKeyPressed(Input.Keys.A);
    final bool moveRight =
        Gdx.input.isKeyPressed(Input.Keys.RIGHT) ||
        Gdx.input.isKeyPressed(Input.Keys.D);

    if (moveLeft == moveRight) {
      velocityX = 0;
    } else if (moveLeft) {
      velocityX = -MOVE_SPEED_PER_SECOND;
      facingRight = false;
    } else {
      velocityX = MOVE_SPEED_PER_SECOND;
      facingRight = true;
    }
    setPlayerFlip(!facingRight, false);

    _applyMovingFloorCarry();

    final bool hasSupport = _isStandingOnFloor();
    if (hasSupport && velocityY >= 0) {
      velocityY = 0;
      onGround = true;
    } else if (!hasSupport) {
      onGround = false;
    }

    if (jumpQueued && onGround) {
      velocityY = -JUMP_IMPULSE_PER_SECOND;
      onGround = false;
    }
    jumpQueued = false;

    if (!onGround || velocityY < 0) {
      velocityY += GRAVITY_PER_SECOND_SQ * dtSeconds;
      if (velocityY > MAX_FALL_SPEED_PER_SECOND) {
        velocityY = MAX_FALL_SPEED_PER_SECOND;
      }
    }

    final double previousY = playerY;
    final double previousX = playerX;

    playerX += velocityX * dtSeconds;
    _resolveHorizontalCollisions(previousX);

    playerY += velocityY * dtSeconds;
    final bool landed = _resolveVerticalCollisions(previousY);
    final bool standingOnFloor = _isStandingOnFloor();
    if ((landed || standingOnFloor) && velocityY >= 0) {
      velocityY = 0;
      onGround = true;
    } else {
      onGround = false;
    }

    _collectTouchedGems();
    _handleDragonInteractions();
    if (!gameOver && _isTouchingDeathZone()) {
      _triggerGameOver();
    }

    _updatePlayerAnimationSelection();
    syncPlayerToSpriteRuntime();
  }

  void _classifyZones() {
    floorZoneIndices.clear();
    solidZoneIndices.clear();
    deathZoneIndices.clear();

    for (int i = 0; i < levelData.zones.size; i++) {
      final LevelZone zone = levelData.zones.get(i);
      final String type = normalize(zone.type);
      final String name = normalize(zone.name);
      if (containsAny(type, <String>['death']) ||
          containsAny(name, <String>['death'])) {
        deathZoneIndices.add(i);
        continue;
      }

      final bool isFloor =
          containsAny(type, <String>['floor', 'platform']) ||
          containsAny(name, <String>['floor', 'platform']);
      final bool isSolid =
          containsAny(type, <String>[
            'wall',
            'mur',
            'solid',
            'bloc',
            'block',
          ]) ||
          containsAny(name, <String>['wall', 'mur', 'solid', 'bloc', 'block']);
      final bool isWallLikeFloor =
          isFloor && zone.height > zone.width * FLOOR_WALL_LIKE_RATIO;

      if (isFloor) {
        floorZoneIndices.add(i);
      }
      if (isSolid || isWallLikeFloor) {
        solidZoneIndices.add(i);
      }
    }
  }

  void _resolveHorizontalCollisions(double previousX) {
    if (solidZoneIndices.size <= 0 || (playerX - previousX).abs() <= 0.0001) {
      return;
    }

    final Rectangle playerRectBounds = playerRect(this.rectCacheA);
    final Rectangle previousRect = playerRectAt(
      previousX,
      playerY,
      previousPlayerRectCache,
    );
    final double leftOffset = playerX - playerRectBounds.x;
    final double rightOffset =
        playerRectBounds.x + playerRectBounds.width - playerX;

    double bestCrossDistance = double.infinity;
    double bestResolvedX = playerX;
    bool collided = false;
    final bool movingRight = velocityX > 0;

    for (final int zoneIndex in solidZoneIndices.iterable()) {
      final Rectangle zoneRect = zoneRectAtIndex(zoneIndex, rectCacheB);
      if (!_overlapsVerticallyForSweep(
        previousRect,
        playerRectBounds,
        zoneRect,
      )) {
        continue;
      }

      if (movingRight) {
        final double previousRight = previousRect.x + previousRect.width;
        final double currentRight = playerRectBounds.x + playerRectBounds.width;
        final double zoneLeft = zoneRect.x;
        if (previousRight <= zoneLeft + COLLISION_EPSILON &&
            currentRight >= zoneLeft - COLLISION_EPSILON) {
          final double crossDistance = zoneLeft - previousRight;
          if (crossDistance < bestCrossDistance) {
            bestCrossDistance = crossDistance;
            bestResolvedX = zoneLeft - rightOffset;
            collided = true;
          }
        }
      } else {
        final double previousLeft = previousRect.x;
        final double currentLeft = playerRectBounds.x;
        final double zoneRight = zoneRect.x + zoneRect.width;
        if (previousLeft >= zoneRight - COLLISION_EPSILON &&
            currentLeft <= zoneRight + COLLISION_EPSILON) {
          final double crossDistance = previousLeft - zoneRight;
          if (crossDistance < bestCrossDistance) {
            bestCrossDistance = crossDistance;
            bestResolvedX = zoneRight + leftOffset;
            collided = true;
          }
        }
      }
    }

    if (collided) {
      playerX = bestResolvedX;
      velocityX = 0;
    }
  }

  bool _resolveVerticalCollisions(double previousY) {
    if (floorZoneIndices.size <= 0) {
      return false;
    }

    final Rectangle playerRectBounds = playerRect(rectCacheA);
    final Rectangle previousRect = playerRectAt(
      playerX,
      previousY,
      previousPlayerRectCache,
    );

    if (velocityY <= 0) {
      return false;
    }

    final double previousBottom = previousRect.y + previousRect.height;
    final double currentBottom = playerRectBounds.y + playerRectBounds.height;
    final double playerBottomOffset = currentBottom - playerY;
    double bestCrossDistance = double.infinity;
    double bestLandingTop = double.nan;

    for (final int zoneIndex in floorZoneIndices.iterable()) {
      final Rectangle zoneRect = zoneRectAtIndex(zoneIndex, rectCacheB);
      final double zoneTop = zoneRect.y;

      if (!_overlapsHorizontallyForSweep(
        previousRect,
        playerRectBounds,
        zoneRect,
      )) {
        continue;
      }
      if (!_crossedZoneTop(previousBottom, currentBottom, zoneTop)) {
        continue;
      }

      final double crossDistance = zoneTop - previousBottom;
      if (crossDistance < bestCrossDistance) {
        bestCrossDistance = crossDistance;
        bestLandingTop = zoneTop;
      }
    }

    if (bestLandingTop.isFinite) {
      playerY = bestLandingTop - playerBottomOffset;
      velocityY = 0;
      return true;
    }

    double correctedY = playerY;
    bool landed = false;
    for (int i = 0; i < 4; i++) {
      final Rectangle correctedRect = playerRectAt(
        playerX,
        correctedY,
        rectCacheA,
      );
      double maxPenetration = 0;
      for (final int zoneIndex in floorZoneIndices.iterable()) {
        final Rectangle zoneRect = zoneRectAtIndex(zoneIndex, rectCacheB);
        if (!_overlapsHorizontallyForSweep(
          correctedRect,
          correctedRect,
          zoneRect,
        )) {
          continue;
        }
        final double zoneTop = zoneRect.y;
        final bool crossedTop =
            correctedRect.y + correctedRect.height > zoneTop &&
            correctedRect.y < zoneTop + 4;
        if (!crossedTop) {
          continue;
        }
        final double penetration =
            correctedRect.y + correctedRect.height - zoneTop;
        if (penetration > maxPenetration) {
          maxPenetration = penetration;
        }
      }
      if (maxPenetration <= 0) {
        break;
      }
      correctedY -= maxPenetration + 0.01;
      landed = true;
    }

    if (landed) {
      playerY = correctedY;
      velocityY = 0;
      return true;
    }
    return false;
  }

  bool _isStandingOnFloor() {
    if (floorZoneIndices.size <= 0) {
      return false;
    }

    final Rectangle playerRectBounds = playerRect(rectCacheA);
    final double testBottom =
        playerRectBounds.y + playerRectBounds.height + 0.5;
    final double testLeft = playerRectBounds.x;
    final double testRight = playerRectBounds.x + playerRectBounds.width;

    for (final int zoneIndex in floorZoneIndices.iterable()) {
      final Rectangle zoneRect = zoneRectAtIndex(zoneIndex, rectCacheB);
      final bool overlapsHorizontally =
          testRight > zoneRect.x && testLeft < zoneRect.x + zoneRect.width;
      if (!overlapsHorizontally) {
        continue;
      }
      final double bottomDelta = (testBottom - zoneRect.y).abs();
      if (bottomDelta <= FLOOR_SUPPORT_DELTA) {
        return true;
      }
    }

    return false;
  }

  bool _isTouchingDeathZone() {
    if (deathZoneIndices.size <= 0) {
      return false;
    }
    return spriteOverlapsAnyZoneByHitBoxes(
      playerSpriteIndex,
      playerX,
      playerY,
      deathZoneIndices,
    );
  }

  void _collectTouchedGems() {
    if (gemSpriteIndices.size <= 0) {
      return;
    }

    for (final int spriteIndex in gemSpriteIndices.iterable()) {
      if (collectedGemSpriteIndices.contains(spriteIndex)) {
        continue;
      }
      if (spriteIndex < 0 || spriteIndex >= spriteRuntimeStates.size) {
        continue;
      }
      final SpriteRuntimeState runtime = spriteRuntimeStates.get(spriteIndex);
      if (!runtime.visible) {
        continue;
      }
      if (spritesOverlapByHitBoxes(
        playerSpriteIndex,
        playerX,
        playerY,
        spriteIndex,
        runtime.worldX,
        runtime.worldY,
      )) {
        collectedGemSpriteIndices.add(spriteIndex);
        setSpriteVisible(spriteIndex, false);
      }
    }

    if (gemSpriteIndices.size > 0 &&
        collectedGemSpriteIndices.size >= gemSpriteIndices.size) {
      _triggerWin();
    }
  }

  void _handleDragonInteractions() {
    if (gameOver || dragonSpriteIndices.size <= 0) {
      return;
    }

    final bool foxyIsFalling =
        !onGround && velocityY > DRAGON_STOMP_MIN_FALL_SPEED;
    touchingDragonNowCache.clear();

    for (final int spriteIndex in dragonSpriteIndices.iterable()) {
      if (removedDragonSpriteIndices.contains(spriteIndex) ||
          dragonDeathStartSecondsBySprite.containsKey(spriteIndex)) {
        continue;
      }
      if (spriteIndex < 0 || spriteIndex >= spriteRuntimeStates.size) {
        continue;
      }
      final SpriteRuntimeState dragonRuntime = spriteRuntimeStates.get(
        spriteIndex,
      );
      if (!dragonRuntime.visible) {
        continue;
      }
      if (!spritesOverlapByHitBoxes(
        playerSpriteIndex,
        playerX,
        playerY,
        spriteIndex,
        dragonRuntime.worldX,
        dragonRuntime.worldY,
      )) {
        continue;
      }

      if (foxyIsFalling) {
        _startDragonDeath(spriteIndex);
        velocityY = -JUMP_IMPULSE_PER_SECOND * 0.38;
        onGround = false;
        continue;
      }

      touchingDragonNowCache.add(spriteIndex);
      final double nextDamageSeconds = nextDragonDamageSecondsBySprite.get(
        spriteIndex,
        -double.infinity,
      );
      if (simulationTimeSeconds >= nextDamageSeconds) {
        _applyDragonDamage();
        nextDragonDamageSecondsBySprite.put(
          spriteIndex,
          simulationTimeSeconds + DRAGON_TOUCH_DAMAGE_INTERVAL_SECONDS,
        );
        if (gameOver) {
          break;
        }
      }
    }

    touchingDragonSpriteIndices.clear();
    for (final int spriteIndex in touchingDragonNowCache.iterable()) {
      touchingDragonSpriteIndices.add(spriteIndex);
    }

    expiredDragonDamageSpriteIndices.clear();
    for (final int spriteIndex in nextDragonDamageSecondsBySprite.keys()) {
      if (!touchingDragonNowCache.contains(spriteIndex)) {
        expiredDragonDamageSpriteIndices.add(spriteIndex);
      }
    }
    for (final int spriteIndex in expiredDragonDamageSpriteIndices.iterable()) {
      nextDragonDamageSecondsBySprite.remove(spriteIndex, -1);
    }
    expiredDragonDamageSpriteIndices.clear();
  }

  void _startDragonDeath(int spriteIndex) {
    if (spriteIndex < 0 || spriteIndex >= spriteRuntimeStates.size) {
      return;
    }
    if (dragonDeathStartSecondsBySprite.containsKey(spriteIndex)) {
      return;
    }
    dragonDeathStartSecondsBySprite.put(spriteIndex, simulationTimeSeconds);
    touchingDragonSpriteIndices.remove(spriteIndex);
    nextDragonDamageSecondsBySprite.remove(spriteIndex, -1);
    setAnimationOverrideByName(spriteIndex, DRAGON_DEATH_ANIMATION_NAME);
  }

  void _pruneCompletedDragonDeaths() {
    if (dragonDeathStartSecondsBySprite.size <= 0) {
      return;
    }

    completedDragonDeathSpriteIndices.clear();
    for (final int spriteIndex in dragonDeathStartSecondsBySprite.keys()) {
      final double startSeconds = dragonDeathStartSecondsBySprite.get(
        spriteIndex,
        simulationTimeSeconds,
      );
      final double elapsedSeconds = simulationTimeSeconds - startSeconds;
      if (elapsedSeconds >= dragonDeathDurationSeconds) {
        completedDragonDeathSpriteIndices.add(spriteIndex);
      }
    }

    for (final int spriteIndex
        in completedDragonDeathSpriteIndices.iterable()) {
      dragonDeathStartSecondsBySprite.remove(spriteIndex, -1);
      removedDragonSpriteIndices.add(spriteIndex);
      setAnimationOverrideByName(spriteIndex, null);
      setSpriteVisible(spriteIndex, false);
    }
    completedDragonDeathSpriteIndices.clear();
  }

  double _resolveDragonDeathDurationSeconds() {
    final String? animationId = findAnimationIdByName(
      DRAGON_DEATH_ANIMATION_NAME,
    );
    if (animationId == null || animationId.isEmpty) {
      return DRAGON_DEATH_FALLBACK_DURATION_SECONDS;
    }
    final AnimationClip? clip = levelData.animationClips.get(animationId);
    if (clip == null) {
      return DRAGON_DEATH_FALLBACK_DURATION_SECONDS;
    }

    final int spanFrames = math.max(1, clip.endFrame - clip.startFrame + 1);
    final double fps = clip.fps.isFinite && clip.fps > 0
        ? clip.fps
        : DEFAULT_ANIMATION_FPS;
    final double durationSeconds = spanFrames / fps;
    if (!durationSeconds.isFinite || durationSeconds <= 0) {
      return DRAGON_DEATH_FALLBACK_DURATION_SECONDS;
    }
    return durationSeconds;
  }

  void _applyDragonDamage() {
    lifePercent -= DRAGON_DAMAGE_PERCENT;
    if (lifePercent <= 0) {
      lifePercent = 0;
      _triggerGameOver();
    }
  }

  void _triggerGameOver() {
    gameOver = true;
    win = false;
    velocityX = 0;
    velocityY = 0;
    onGround = false;
    jumpQueued = false;
  }

  void _triggerWin() {
    win = true;
    gameOver = false;
    velocityX = 0;
    velocityY = 0;
    onGround = false;
    jumpQueued = false;
  }

  void _applyMovingFloorCarry() {
    if (floorZoneIndices.size <= 0 ||
        zoneRuntimeStates.size <= 0 ||
        zonePreviousRuntimeStates.size <= 0) {
      return;
    }

    final Rectangle playerRectBounds = playerRect(rectCacheA);
    double bestCarryMagnitudeSq = 0;
    double carryX = 0;
    double carryY = 0;

    for (final int zoneIndex in floorZoneIndices.iterable()) {
      if (zoneIndex < 0 ||
          zoneIndex >= zoneRuntimeStates.size ||
          zoneIndex >= zonePreviousRuntimeStates.size) {
        continue;
      }
      final RuntimeTransform current = zoneRuntimeStates.get(zoneIndex);
      final RuntimeTransform previous = zonePreviousRuntimeStates.get(
        zoneIndex,
      );
      final double deltaX = current.x - previous.x;
      final double deltaY = current.y - previous.y;
      if (deltaX.abs() <= 0.0001 && deltaY.abs() <= 0.0001) {
        continue;
      }

      final Rectangle previousZoneRect = zoneRectAtPreviousIndex(
        zoneIndex,
        rectCacheB,
      );
      if (!_isStandingOnFloorRect(playerRectBounds, previousZoneRect)) {
        continue;
      }

      final double magnitudeSq = deltaX * deltaX + deltaY * deltaY;
      if (magnitudeSq > bestCarryMagnitudeSq) {
        bestCarryMagnitudeSq = magnitudeSq;
        carryX = deltaX;
        carryY = deltaY;
      }
    }

    if (bestCarryMagnitudeSq > 0) {
      playerX += carryX;
      playerY += carryY;
    }
  }

  bool _overlapsHorizontallyForSweep(
    Rectangle previousRect,
    Rectangle currentRect,
    Rectangle zoneRect,
  ) {
    final double sweepLeft = math.min(previousRect.x, currentRect.x);
    final double sweepRight = math.max(
      previousRect.x + previousRect.width,
      currentRect.x + currentRect.width,
    );
    return sweepRight > zoneRect.x + COLLISION_EPSILON &&
        sweepLeft < zoneRect.x + zoneRect.width - COLLISION_EPSILON;
  }

  bool _overlapsVerticallyForSweep(
    Rectangle previousRect,
    Rectangle currentRect,
    Rectangle zoneRect,
  ) {
    final double sweepTop = math.min(previousRect.y, currentRect.y);
    final double sweepBottom = math.max(
      previousRect.y + previousRect.height,
      currentRect.y + currentRect.height,
    );
    return sweepBottom > zoneRect.y + COLLISION_EPSILON &&
        sweepTop < zoneRect.y + zoneRect.height - COLLISION_EPSILON;
  }

  bool _crossedZoneTop(
    double previousBottom,
    double currentBottom,
    double zoneTop,
  ) {
    return previousBottom <= zoneTop + COLLISION_EPSILON &&
        currentBottom >= zoneTop - COLLISION_EPSILON;
  }

  bool _isStandingOnFloorRect(Rectangle playerRect, Rectangle floorRect) {
    final double playerBottom = playerRect.y + playerRect.height + 0.5;
    final bool overlapsHorizontally =
        playerRect.x + playerRect.width > floorRect.x &&
        playerRect.x < floorRect.x + floorRect.width;
    if (!overlapsHorizontally) {
      return false;
    }
    final double bottomDelta = (playerBottom - floorRect.y).abs();
    return bottomDelta <= FLOOR_SUPPORT_DELTA;
  }

  void _updatePlayerAnimationSelection() {
    if (playerSpriteIndex < 0) {
      return;
    }

    const double verticalThreshold = 5;
    const double moveThreshold = 2;
    String animationName = 'Foxy Idle';
    if (!onGround) {
      if (velocityY < -verticalThreshold) {
        animationName = 'Foxy Jump Up';
      } else {
        animationName = 'Foxy Jump Fall';
      }
    } else if (velocityX.abs() > moveThreshold) {
      animationName = 'Foxy Walk';
    }

    setPlayerFlip(!facingRight, false);
    setPlayerAnimationOverrideByName(animationName);
  }
}
