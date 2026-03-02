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
    required this.collectibleArbreTileKeys,
  })  : previousPlayerX = playerX,
        previousPlayerY = playerY,
        previousCameraX = playerX,
        previousCameraY = playerY,
        cameraX = playerX,
        cameraY = playerY;

  double playerX;
  double playerY;
  // Previous-tick positions used by the painter for render interpolation.
  // Both player and camera must be lerped together or tiles vibrate relative
  // to the sprite.
  double previousPlayerX;
  double previousPlayerY;
  double cameraX;
  double cameraY;
  double previousCameraX;
  double previousCameraY;
  double playerWidth;
  double playerHeight;
  String direction = 'down';
  bool isMoving = false;
  bool isOnPont = false;
  bool wasInsideFuturPontGameplayZone = false;
  int arbresRemovedCount = 0;
  final int totalArbres;
  final Set<String> collectibleArbreTileKeys;
  final Set<String> collectedArbreTileKeys = <String>{};
  bool isWin = false;
  double endStateElapsedSeconds = 0;
  double fps = 60;
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
    required this.cameraX,
    required this.cameraY,
    required this.playerWidth,
    required this.playerHeight,
    required this.direction,
    required this.isMoving,
    required this.isOnPont,
    required this.arbresRemovedCount,
    required this.totalArbres,
    required this.isWin,
    required this.canExitEndState,
    required this.fps,
    required this.animationTimeSeconds,
    required this.tickCounter,
  });

  factory Level0RenderState.from(Level0UpdateState state, {double alpha = 1.0}) {
    // Lerp both player and camera between the previous and current physics tick.
    // They must move together — interpolating only the player causes the sprite
    // to shift relative to the tiles every frame (visible vibration).
    final double renderX =
        state.previousPlayerX + (state.playerX - state.previousPlayerX) * alpha;
    final double renderY =
        state.previousPlayerY + (state.playerY - state.previousPlayerY) * alpha;
    final double renderCamX =
        state.previousCameraX + (state.cameraX - state.previousCameraX) * alpha;
    final double renderCamY =
        state.previousCameraY + (state.cameraY - state.previousCameraY) * alpha;
    return Level0RenderState(
      playerX: renderX,
      playerY: renderY,
      cameraX: renderCamX,
      cameraY: renderCamY,
      playerWidth: state.playerWidth,
      playerHeight: state.playerHeight,
      direction: state.direction,
      isMoving: state.isMoving,
      isOnPont: state.isOnPont,
      arbresRemovedCount: state.arbresRemovedCount,
      totalArbres: state.totalArbres,
      isWin: state.isWin,
      canExitEndState: state.canExitEndState,
      fps: state.fps,
      animationTimeSeconds: state.animationTimeSeconds,
      tickCounter: state.tickCounter,
    );
  }

  final double playerX;
  final double playerY;
  final double cameraX;
  final double cameraY;
  final double playerWidth;
  final double playerHeight;
  final String direction;
  final bool isMoving;
  final bool isOnPont;
  final int arbresRemovedCount;
  final int totalArbres;
  final bool isWin;
  final bool canExitEndState;
  final double fps;
  final double animationTimeSeconds;
  final int tickCounter;
}
