import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app_data.dart';
import 'camera.dart';
import 'utils_gamestool/utils_gamestool.dart';

class Level0 extends StatefulWidget {
  const Level0({super.key, required this.levelIndex});

  final int levelIndex;

  @override
  State<Level0> createState() => _Level0State();
}

class _Level0State extends State<Level0> with SingleTickerProviderStateMixin {
  final FocusNode _focusNode = FocusNode();
  final Set<LogicalKeyboardKey> _pressedKeys = <LogicalKeyboardKey>{};
  final Camera _camera = Camera();

  Ticker? _ticker;
  Duration? _lastTickTimestamp;
  bool _initialized = false;
  Map<String, dynamic>? _level;
  Level0UpdateState? _updateState;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_initialized) {
      return;
    }

    final AppData appData = context.read<AppData>();
    if (!appData.isReady) {
      return;
    }

    _initialized = true;
    _initializeLevel(appData);
    _startLoop();
  }

  void _initializeLevel(AppData appData) {
    _level = appData.getLevelByIndex(widget.levelIndex);
    final Map<String, dynamic>? spawn =
        appData.firstSpriteForLevel(widget.levelIndex);

    _updateState = Level0UpdateState(
      playerX: (spawn?['x'] as num?)?.toDouble() ?? 100,
      playerY: (spawn?['y'] as num?)?.toDouble() ?? 100,
      playerWidth: (spawn?['width'] as num?)?.toDouble() ?? 20,
      playerHeight: (spawn?['height'] as num?)?.toDouble() ?? 20,
      speedPerSecond: 95,
    );

    _camera
      ..x = _updateState!.playerX
      ..y = _updateState!.playerY
      ..focal = 500;
  }

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

    setState(() {});
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

    final bool isMoving = inputX != 0 || inputY != 0;
    state.isMoving = isMoving;
    if (isMoving) {
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
    state.playerX += dx;
    state.playerY += dy;
    state.animationTimeSeconds += dt;
    state.tickCounter = (state.animationTimeSeconds * 60).floor();
  }

  KeyEventResult _onKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      _pressedKeys.add(event.logicalKey);
    } else if (event is KeyUpEvent) {
      _pressedKeys.remove(event.logicalKey);
    }
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppData appData = context.watch<AppData>();
    final Level0UpdateState? state = _updateState;

    return CupertinoPageScaffold(
      child: SafeArea(
        child: Focus(
          autofocus: true,
          focusNode: _focusNode,
          onKeyEvent: (FocusNode node, KeyEvent event) => _onKeyEvent(event),
          child: CustomPaint(
            painter: Level0Painter(
              appData: appData,
              level: _level,
              camera: _camera,
              renderState: state == null ? null : Level0RenderState.from(state),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class Level0UpdateState {
  Level0UpdateState({
    required this.playerX,
    required this.playerY,
    required this.playerWidth,
    required this.playerHeight,
    required this.speedPerSecond,
  });

  double playerX;
  double playerY;
  double playerWidth;
  double playerHeight;
  String direction = 'down';
  bool isMoving = false;
  int tickCounter = 0;
  double animationTimeSeconds = 0;
  final double speedPerSecond;
}

class Level0RenderState {
  const Level0RenderState({
    required this.playerX,
    required this.playerY,
    required this.playerWidth,
    required this.playerHeight,
    required this.direction,
    required this.isMoving,
    required this.animationTimeSeconds,
    required this.tickCounter,
  });

  factory Level0RenderState.from(Level0UpdateState state) {
    return Level0RenderState(
      playerX: state.playerX,
      playerY: state.playerY,
      playerWidth: state.playerWidth,
      playerHeight: state.playerHeight,
      direction: state.direction,
      isMoving: state.isMoving,
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
  final double animationTimeSeconds;
  final int tickCounter;
}

class Level0Painter extends CustomPainter {
  const Level0Painter({
    required this.appData,
    required this.level,
    required this.camera,
    required this.renderState,
  });

  final AppData appData;
  final Map<String, dynamic>? level;
  final Camera camera;
  final Level0RenderState? renderState;

  @override
  void paint(Canvas canvas, Size size) {
    if (level == null || renderState == null) {
      final Paint background = Paint()..color = const Color(0xFF0B1014);
      canvas.drawRect(Offset.zero & size, background);
      _drawText(canvas, 'Loading level 0...', const Offset(20, 20));
      return;
    }

    final RuntimeCamera2D runtimeCamera = camera.toRuntimeCamera2D();
    final double parallaxSensitivity =
        GamesToolRuntimeRenderer.levelParallaxSensitivity(
      gamesTool: appData.gamesTool,
      level: level,
    );

    GamesToolRuntimeRenderer.drawLevelTileLayers(
      canvas: canvas,
      painterSize: size,
      level: level!,
      gamesTool: appData.gamesTool,
      imagesCache: appData.imagesCache,
      camera: runtimeCamera,
      backgroundColor: const Color(0xFF0B1014),
      parallaxSensitivity: parallaxSensitivity,
    );

    GamesToolRuntimeRenderer.drawAnimatedSpriteByType(
      canvas: canvas,
      painterSize: size,
      gameData: appData.gameData,
      level: level!,
      gamesTool: appData.gamesTool,
      imagesCache: appData.imagesCache,
      camera: runtimeCamera,
      spriteType: 'flag',
      elapsedSeconds: renderState!.tickCounter / 60.0,
      parallaxSensitivity: parallaxSensitivity,
    );

    _drawAnimatedPlayer(canvas, size);

    _drawText(
      canvas,
      'LEVEL 0: TOP-DOWN  |  MOVE: ARROWS/WASD',
      const Offset(20, 20),
    );

    GamesToolRuntimeRenderer.drawConnectionIndicator(
      canvas,
      size,
      appData.isConnected,
    );
  }

  void _drawText(Canvas canvas, String text, Offset offset) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFFE0F2FF),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  void _drawAnimatedPlayer(Canvas canvas, Size size) {
    final Level0RenderState state = renderState!;
    if (level == null) {
      _drawFallbackPlayer(canvas, size);
      return;
    }

    final Map<String, dynamic>? sprite = appData.gamesTool.findFirstSprite(
      level!,
    );
    final _AnimationSelection animation = _resolveAnimationFor(state);
    if (sprite == null) {
      _drawFallbackPlayer(canvas, size);
      return;
    }

    final double parallaxSensitivity =
        GamesToolRuntimeRenderer.levelParallaxSensitivity(
      gamesTool: appData.gamesTool,
      level: level,
    );
    final bool drewSprite = GamesToolRuntimeRenderer.drawAnimatedSprite(
      canvas: canvas,
      painterSize: size,
      gameData: appData.gameData,
      gamesTool: appData.gamesTool,
      imagesCache: appData.imagesCache,
      sprite: sprite,
      camera: camera.toRuntimeCamera2D(),
      elapsedSeconds: state.animationTimeSeconds,
      animationName: animation.animationName,
      worldX: state.playerX,
      worldY: state.playerY,
      flipX: animation.mirrorX,
      drawWidthWorld: state.playerWidth,
      drawHeightWorld: state.playerHeight,
      parallaxSensitivity: parallaxSensitivity,
      fallbackFps: 8,
    );
    if (!drewSprite) {
      _drawFallbackPlayer(canvas, size);
    }
  }

  void _drawFallbackPlayer(Canvas canvas, Size size) {
    final Level0RenderState state = renderState!;
    final RuntimeCamera2D runtimeCamera = camera.toRuntimeCamera2D();
    final double cameraScale = RuntimeCameraMath.cameraScaleForViewport(
      viewportSize: size,
      focal: runtimeCamera.focal,
    );
    final double parallaxSensitivity =
        GamesToolRuntimeRenderer.levelParallaxSensitivity(
      gamesTool: appData.gamesTool,
      level: level,
    );
    final Offset screenPos = RuntimeCameraMath.worldToScreen(
      worldX: state.playerX,
      worldY: state.playerY,
      viewportSize: size,
      camera: runtimeCamera,
      parallaxSensitivity: parallaxSensitivity,
    );
    final Rect playerRect = Rect.fromLTWH(
      screenPos.dx,
      screenPos.dy,
      state.playerWidth * cameraScale,
      state.playerHeight * cameraScale,
    );
    final Paint playerPaint = Paint()..color = const Color(0xFF4DA3FF);
    canvas.drawRect(playerRect, playerPaint);
  }

  _AnimationSelection _resolveAnimationFor(Level0RenderState state) {
    final String prefix = state.isMoving ? 'Heroi Camina ' : 'Heroi Aturat ';
    switch (state.direction) {
      case 'upLeft':
        return _AnimationSelection(
          animationName: '${prefix}Amunt-Dreta',
          mirrorX: true,
        );
      case 'up':
        return _AnimationSelection(animationName: '${prefix}Amunt');
      case 'upRight':
        return _AnimationSelection(animationName: '${prefix}Amunt-Dreta');
      case 'left':
        return _AnimationSelection(
          animationName: '${prefix}Dreta',
          mirrorX: true,
        );
      case 'right':
        return _AnimationSelection(animationName: '${prefix}Dreta');
      case 'downLeft':
        return _AnimationSelection(
          animationName: '${prefix}Avall-Dreta',
          mirrorX: true,
        );
      case 'downRight':
        return _AnimationSelection(animationName: '${prefix}Avall-Dreta');
      case 'down':
      default:
        return _AnimationSelection(animationName: '${prefix}Avall');
    }
  }

  @override
  bool shouldRepaint(covariant Level0Painter oldDelegate) {
    return oldDelegate.renderState?.tickCounter != renderState?.tickCounter ||
        oldDelegate.level != level;
  }
}

class _AnimationSelection {
  const _AnimationSelection({
    required this.animationName,
    this.mirrorX = false,
  });

  final String animationName;
  final bool mirrorX;
}
