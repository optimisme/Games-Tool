import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app_data.dart';
import 'camera.dart';
import 'rendering.dart';
import 'utils_gamestool.dart';

class Level1 extends StatefulWidget {
  const Level1({super.key, required this.levelIndex});

  final int levelIndex;

  @override
  State<Level1> createState() => _Level1State();
}

class _Level1State extends State<Level1> with SingleTickerProviderStateMixin {
  final FocusNode _focusNode = FocusNode();
  final Set<LogicalKeyboardKey> _pressedKeys = <LogicalKeyboardKey>{};
  final Camera _camera = Camera();

  Ticker? _ticker;
  Duration? _lastTickTimestamp;
  bool _initialized = false;
  bool _jumpQueued = false;
  Map<String, dynamic>? _level;
  Level1UpdateState? _updateState;

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

    final double spawnX = (spawn?['x'] as num?)?.toDouble() ?? 100;
    final double spawnY = (spawn?['y'] as num?)?.toDouble() ?? 120;

    _updateState = Level1UpdateState(
      playerX: spawnX,
      playerY: spawnY,
      playerWidth: (spawn?['width'] as num?)?.toDouble() ?? 22,
      playerHeight: (spawn?['height'] as num?)?.toDouble() ?? 30,
      groundY: spawnY + 110,
    );

    _camera
      ..x = spawnX
      ..y = spawnY - 80
      ..focal = 560;
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
    final Level1UpdateState? state = _updateState;
    if (!mounted || state == null) {
      return;
    }

    _updatePhysics(state, dt);
    _camera
      ..x = state.playerX
      ..y = state.playerY - 80;

    setState(() {});
  }

  void _updatePhysics(Level1UpdateState state, double dt) {
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

    if (_jumpQueued && state.onGround) {
      state.velocityY = -state.jumpImpulsePerSecond;
      state.onGround = false;
    }
    _jumpQueued = false;

    state.velocityY += state.gravityPerSecondSq * dt;
    if (state.velocityY > state.maxFallSpeedPerSecond) {
      state.velocityY = state.maxFallSpeedPerSecond;
    }

    state.playerX += state.velocityX * dt;
    state.playerY += state.velocityY * dt;

    if (state.playerY >= state.groundY) {
      state.playerY = state.groundY;
      state.velocityY = 0;
      state.onGround = true;
    }

    state.animationTimeSeconds += dt;
    state.tickCounter = (state.animationTimeSeconds * 60).floor();
  }

  KeyEventResult _onKeyEvent(KeyEvent event) {
    final LogicalKeyboardKey key = event.logicalKey;

    if (event is KeyDownEvent) {
      _pressedKeys.add(key);
      if (key == LogicalKeyboardKey.space ||
          key == LogicalKeyboardKey.arrowUp ||
          key == LogicalKeyboardKey.keyW) {
        _jumpQueued = true;
      }
    } else if (event is KeyUpEvent) {
      _pressedKeys.remove(key);
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
    final Level1UpdateState? state = _updateState;

    return CupertinoPageScaffold(
      child: SafeArea(
        child: Focus(
          autofocus: true,
          focusNode: _focusNode,
          onKeyEvent: (FocusNode node, KeyEvent event) => _onKeyEvent(event),
          child: CustomPaint(
            painter: Level1Painter(
              appData: appData,
              level: _level,
              camera: _camera,
              renderState: state == null ? null : Level1RenderState.from(state),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class Level1UpdateState {
  Level1UpdateState({
    required this.playerX,
    required this.playerY,
    required this.playerWidth,
    required this.playerHeight,
    required this.groundY,
  });

  double playerX;
  double playerY;
  double playerWidth;
  double playerHeight;

  double velocityX = 0;
  double velocityY = 0;
  bool onGround = false;
  bool facingRight = true;
  int tickCounter = 0;
  double animationTimeSeconds = 0;

  final double groundY;
  final double gravityPerSecondSq = 2088;
  final double moveSpeedPerSecond = 204;
  final double jumpImpulsePerSecond = 708;
  final double maxFallSpeedPerSecond = 840;
}

class Level1RenderState {
  const Level1RenderState({
    required this.playerX,
    required this.playerY,
    required this.playerWidth,
    required this.playerHeight,
    required this.groundY,
    required this.facingRight,
    required this.tickCounter,
  });

  factory Level1RenderState.from(Level1UpdateState state) {
    return Level1RenderState(
      playerX: state.playerX,
      playerY: state.playerY,
      playerWidth: state.playerWidth,
      playerHeight: state.playerHeight,
      groundY: state.groundY,
      facingRight: state.facingRight,
      tickCounter: state.tickCounter,
    );
  }

  final double playerX;
  final double playerY;
  final double playerWidth;
  final double playerHeight;
  final double groundY;
  final bool facingRight;
  final int tickCounter;
}

class Level1Painter extends CustomPainter {
  const Level1Painter({
    required this.appData,
    required this.level,
    required this.camera,
    required this.renderState,
  });

  final AppData appData;
  final Map<String, dynamic>? level;
  final Camera camera;
  final Level1RenderState? renderState;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint background = Paint()..color = const Color(0xFF0A0D1A);
    canvas.drawRect(Offset.zero & size, background);

    if (level == null || renderState == null) {
      _drawText(canvas, 'Loading level 1...', const Offset(20, 20));
      return;
    }

    final double parallaxSensitivity = _levelParallaxSensitivity();

    CommonRenderer.drawLevelTileLayers(
      canvas: canvas,
      painterSize: size,
      level: level!,
      appData: appData,
      camera: camera,
      backgroundColor: const Color(0xFF0A0D1A),
      parallaxSensitivity: parallaxSensitivity,
    );

    CommonRenderer.drawAnimatedFlag(
      canvas: canvas,
      painterSize: size,
      level: level!,
      appData: appData,
      camera: camera,
      tickCounter: renderState!.tickCounter,
      parallaxSensitivity: parallaxSensitivity,
    );

    final Offset groundStart = CommonRenderer.worldToScreen(
      renderState!.playerX - 1200,
      renderState!.groundY + renderState!.playerHeight,
      size,
      camera,
      parallaxSensitivity: parallaxSensitivity,
    );
    final Offset groundEnd = CommonRenderer.worldToScreen(
      renderState!.playerX + 1200,
      renderState!.groundY + renderState!.playerHeight,
      size,
      camera,
      parallaxSensitivity: parallaxSensitivity,
    );
    final Paint groundPaint = Paint()
      ..color = const Color(0xFF32C96C)
      ..strokeWidth = 3;
    canvas.drawLine(groundStart, groundEnd, groundPaint);

    final CameraScale cameraScale = CommonRenderer.getCameraScale(size, camera);
    final Offset screenPos = CommonRenderer.worldToScreen(
      renderState!.playerX,
      renderState!.playerY,
      size,
      camera,
      parallaxSensitivity: parallaxSensitivity,
    );

    final Rect playerRect = Rect.fromLTWH(
      screenPos.dx,
      screenPos.dy,
      renderState!.playerWidth * cameraScale.scale,
      renderState!.playerHeight * cameraScale.scale,
    );

    final Paint bodyPaint = Paint()..color = const Color(0xFFFFB347);
    canvas.drawRect(playerRect, bodyPaint);

    final Paint eyePaint = Paint()..color = const Color(0xFF121212);
    final double eyeX = renderState!.facingRight
        ? playerRect.right - (playerRect.width * 0.25)
        : playerRect.left + (playerRect.width * 0.25);
    final Offset eyePos =
        Offset(eyeX, playerRect.top + (playerRect.height * 0.3));
    canvas.drawCircle(eyePos, (playerRect.width * 0.08).clamp(2, 6), eyePaint);

    _drawText(
      canvas,
      'LEVEL 1: PLATFORMER  |  MOVE: A/D OR ARROWS  |  JUMP: SPACE/W/UP',
      const Offset(20, 20),
    );

    CommonRenderer.drawConnectionIndicator(canvas, size, appData.isConnected);
  }

  void _drawText(Canvas canvas, String text, Offset offset) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFFE0F2FF),
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 900);
    painter.paint(canvas, offset);
  }

  double _levelParallaxSensitivity() {
    final Map<String, dynamic>? currentLevel = level;
    if (currentLevel == null) {
      return GamesToolApi.defaultParallaxSensitivity;
    }
    return appData.gamesTool.levelParallaxSensitivity(currentLevel);
  }

  @override
  bool shouldRepaint(covariant Level1Painter oldDelegate) {
    return oldDelegate.renderState?.tickCounter != renderState?.tickCounter ||
        oldDelegate.level != level;
  }
}
