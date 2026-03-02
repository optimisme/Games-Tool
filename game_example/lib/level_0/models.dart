part of 'main.dart';

/// Mutable simulation state advanced by update.dart every frame.
class Level0UpdateState {
  Level0UpdateState({
    required this.playerX,
    required this.playerY,
    required this.playerWidth,
    required this.playerHeight,
    required this.speedPerSecond,
    required this.totalArbres,
  });

  double playerX;
  double playerY;
  double playerWidth;
  double playerHeight;
  String direction = 'down';
  bool isMoving = false;
  bool isOnPont = false;
  bool wasInsideFuturPontGameplayZone = false;
  int arbresRemovedCount = 0;
  final int totalArbres;
  bool isWin = false;
  double endStateElapsedSeconds = 0;
  int tickCounter = 0;
  double animationTimeSeconds = 0;
  final double speedPerSecond;

  bool get canExitEndState =>
      endStateElapsedSeconds >= _level0EndStateInputDelaySeconds;
}

class Level0RenderState {
  const Level0RenderState({
    required this.playerX,
    required this.playerY,
    required this.playerWidth,
    required this.playerHeight,
    required this.direction,
    required this.isMoving,
    required this.isOnPont,
    required this.arbresRemovedCount,
    required this.totalArbres,
    required this.isWin,
    required this.canExitEndState,
    required this.animationTimeSeconds,
    required this.tickCounter,
  });

  factory Level0RenderState.from(Level0UpdateState state) {
    // Snapshot mutable update state into an immutable render payload.
    return Level0RenderState(
      playerX: state.playerX,
      playerY: state.playerY,
      playerWidth: state.playerWidth,
      playerHeight: state.playerHeight,
      direction: state.direction,
      isMoving: state.isMoving,
      isOnPont: state.isOnPont,
      arbresRemovedCount: state.arbresRemovedCount,
      totalArbres: state.totalArbres,
      isWin: state.isWin,
      canExitEndState: state.canExitEndState,
      animationTimeSeconds: state.animationTimeSeconds,
      tickCounter: state.tickCounter,
    );
  }

  final double playerX;
  final double playerY;
  final double playerWidth;
  final double playerHeight;
  final String direction;
  final bool isMoving;
  final bool isOnPont;
  final int arbresRemovedCount;
  final int totalArbres;
  final bool isWin;
  final bool canExitEndState;
  final double animationTimeSeconds;
  final int tickCounter;
}
