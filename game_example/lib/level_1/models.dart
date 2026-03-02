part of 'main.dart';

class Level1UpdateState {
  Level1UpdateState({
    required this.playerX,
    required this.playerY,
    required this.playerWidth,
    required this.playerHeight,
    required this.gemsCount,
    this.lifePercent = _level1InitialLifePercent,
  });

  double playerX;
  double playerY;
  double playerWidth;
  double playerHeight;

  double velocityX = 0;
  double velocityY = 0;
  bool onGround = false;
  bool isInJumpArc = false;
  bool facingRight = true;
  bool isGameOver = false;
  int tickCounter = 0;
  double animationTimeSeconds = 0;
  double platformMotionTimeSeconds = 0;
  final Set<int> collectedGemSpriteIndices = <int>{};
  final Set<int> removedDragonSpriteIndices = <int>{};
  final Map<int, double> dragonDeathStartSeconds = <int, double>{};

  int gemsCount;
  int lifePercent;
  final double gravityPerSecondSq = 2088;
  final double moveSpeedPerSecond = 204;
  final double jumpImpulsePerSecond = 708;
  final double maxFallSpeedPerSecond = 840;
  final Set<int> touchingDragonSpriteIndices = <int>{};
}

class Level1RenderState {
  const Level1RenderState({
    required this.playerX,
    required this.playerY,
    required this.playerWidth,
    required this.playerHeight,
    required this.velocityX,
    required this.velocityY,
    required this.onGround,
    required this.isGameOver,
    required this.facingRight,
    required this.tickCounter,
    required this.animationTimeSeconds,
    required this.gemsCount,
    required this.lifePercent,
    required this.collectedGemSpriteIndices,
    required this.removedDragonSpriteIndices,
    required this.dragonDeathStartSeconds,
  });

  factory Level1RenderState.from(Level1UpdateState state) {
    return Level1RenderState(
      playerX: state.playerX,
      playerY: state.playerY,
      playerWidth: state.playerWidth,
      playerHeight: state.playerHeight,
      velocityX: state.velocityX,
      velocityY: state.velocityY,
      onGround: state.onGround,
      isGameOver: state.isGameOver,
      facingRight: state.facingRight,
      tickCounter: state.tickCounter,
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
  final double playerWidth;
  final double playerHeight;
  final double velocityX;
  final double velocityY;
  final bool onGround;
  final bool isGameOver;
  final bool facingRight;
  final int tickCounter;
  final double animationTimeSeconds;
  final int gemsCount;
  final int lifePercent;
  final Set<int> collectedGemSpriteIndices;
  final Set<int> removedDragonSpriteIndices;
  final Map<int, double> dragonDeathStartSeconds;
}
