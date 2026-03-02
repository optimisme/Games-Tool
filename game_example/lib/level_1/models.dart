part of 'main.dart';

/// Mutable simulation state advanced by update.dart every frame.
class Level1UpdateState {
  Level1UpdateState({
    required this.playerX,
    required this.playerY,
    required this.cameraX,
    required this.cameraY,
    required this.platformX,
    required this.platformY,
    required this.playerWidth,
    required this.playerHeight,
    required this.gemsCount,
    required this.totalGems,
    this.lifePercent = _level1InitialLifePercent,
  });

  double playerX;
  double playerY;
  double cameraX;
  double cameraY;
  double platformX;
  double platformY;
  double playerWidth;
  double playerHeight;

  double velocityX = 0;
  double velocityY = 0;
  bool onGround = false;
  bool isInJumpArc = false;
  bool facingRight = true;
  bool isGameOver = false;
  bool isWin = false;
  double endStateElapsedSeconds = 0;
  double fps = 60;
  int tickCounter = 0;
  double animationTimeSeconds = 0;
  double platformMotionTimeSeconds = 0;
  final Set<int> collectedGemSpriteIndices = <int>{};
  final Set<int> removedDragonSpriteIndices = <int>{};
  final Map<int, double> dragonDeathStartSeconds = <int, double>{};

  int gemsCount;
  final int totalGems;
  int lifePercent;
  final double gravityPerSecondSq = 2088;
  final double moveSpeedPerSecond = 204;
  final double jumpImpulsePerSecond = 708;
  final double maxFallSpeedPerSecond = 840;
  final Set<int> touchingDragonSpriteIndices = <int>{};

  // Input is ignored during end states until this cooldown has elapsed.
  bool get canExitEndState =>
      endStateElapsedSeconds >= _level1EndStateInputDelaySeconds;
}

class Level1RenderState {
  const Level1RenderState({
    required this.playerX,
    required this.playerY,
    required this.cameraX,
    required this.cameraY,
    required this.platformX,
    required this.platformY,
    required this.playerWidth,
    required this.playerHeight,
    required this.velocityX,
    required this.velocityY,
    required this.onGround,
    required this.isGameOver,
    required this.isWin,
    required this.canExitEndState,
    required this.facingRight,
    required this.tickCounter,
    required this.fps,
    required this.animationTimeSeconds,
    required this.gemsCount,
    required this.lifePercent,
    required this.collectedGemSpriteIndices,
    required this.removedDragonSpriteIndices,
    required this.dragonDeathStartSeconds,
  });

  factory Level1RenderState.from(
    Level1UpdateState state, {
    required GameDataRuntimeApi runtimeApi,
    double alpha = 1.0,
  }) {
    final Offset renderPlayer = runtimeApi.sampleTransform2D(
      _level1PlayerTransformId,
      alpha: alpha,
      fallbackX: state.playerX,
      fallbackY: state.playerY,
    );
    final Offset renderCamera = runtimeApi.sampleTransform2D(
      _level1CameraTransformId,
      alpha: alpha,
      fallbackX: state.cameraX,
      fallbackY: state.cameraY,
    );
    final Offset renderPlatform = runtimeApi.sampleTransform2D(
      _level1MovingPlatformTransformId,
      alpha: alpha,
      fallbackX: state.platformX,
      fallbackY: state.platformY,
    );
    return Level1RenderState(
      playerX: renderPlayer.dx,
      playerY: renderPlayer.dy,
      cameraX: renderCamera.dx,
      cameraY: renderCamera.dy,
      platformX: renderPlatform.dx,
      platformY: renderPlatform.dy,
      playerWidth: state.playerWidth,
      playerHeight: state.playerHeight,
      velocityX: state.velocityX,
      velocityY: state.velocityY,
      onGround: state.onGround,
      isGameOver: state.isGameOver,
      isWin: state.isWin,
      canExitEndState: state.canExitEndState,
      facingRight: state.facingRight,
      tickCounter: state.tickCounter,
      fps: state.fps,
      animationTimeSeconds: state.animationTimeSeconds,
      gemsCount: state.gemsCount,
      lifePercent: state.lifePercent,
      collectedGemSpriteIndices: Set<int>.from(state.collectedGemSpriteIndices),
      removedDragonSpriteIndices:
          Set<int>.from(state.removedDragonSpriteIndices),
      dragonDeathStartSeconds: Map<int, double>.from(
        state.dragonDeathStartSeconds,
      ),
    );
  }

  final double playerX;
  final double playerY;
  final double cameraX;
  final double cameraY;
  final double platformX;
  final double platformY;
  final double playerWidth;
  final double playerHeight;
  final double velocityX;
  final double velocityY;
  final bool onGround;
  final bool isGameOver;
  final bool isWin;
  final bool canExitEndState;
  final bool facingRight;
  final int tickCounter;
  final double fps;
  final double animationTimeSeconds;
  final int gemsCount;
  final int lifePercent;
  final Set<int> collectedGemSpriteIndices;
  final Set<int> removedDragonSpriteIndices;
  final Map<int, double> dragonDeathStartSeconds;
}
