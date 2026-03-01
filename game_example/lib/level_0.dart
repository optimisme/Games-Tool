import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app_data.dart';
import 'camera.dart';
import 'rendering.dart';
import 'utils_gamestool.dart';

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
    final Paint background = Paint()..color = const Color(0xFF0B1014);
    canvas.drawRect(Offset.zero & size, background);

    if (level == null || renderState == null) {
      _drawText(canvas, 'Loading level 0...', const Offset(20, 20));
      return;
    }

    final double parallaxSensitivity = _levelParallaxSensitivity();

    CommonRenderer.drawLevelTileLayers(
      canvas: canvas,
      painterSize: size,
      level: level!,
      appData: appData,
      camera: camera,
      backgroundColor: const Color(0xFF0B1014),
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

    _drawAnimatedPlayer(canvas, size);

    _drawText(
      canvas,
      'LEVEL 0: TOP-DOWN  |  MOVE: ARROWS/WASD',
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
    final Map<String, dynamic>? animationData =
        appData.gamesTool.findAnimationByName(
      appData.gameData,
      animation.animationName,
    );

    if (sprite == null || animationData == null) {
      _drawFallbackPlayer(canvas, size);
      return;
    }

    final Object? mediaFile = animationData['mediaFile'];
    if (mediaFile is! String || mediaFile.isEmpty) {
      _drawFallbackPlayer(canvas, size);
      return;
    }

    final String sheetPath = appData.gamesTool.toRelativeAssetKey(mediaFile);
    final ui.Image? sheet = appData.imagesCache[sheetPath];
    if (sheet == null) {
      _drawFallbackPlayer(canvas, size);
      return;
    }

    final Map<String, dynamic>? mediaAsset =
        appData.gamesTool.findMediaAssetByFile(
      appData.gameData,
      mediaFile,
    );
    final double frameWidth = mediaAsset == null
        ? appData.gamesTool.spriteWidth(sprite, fallback: state.playerWidth)
        : appData.gamesTool.mediaTileWidth(
            mediaAsset,
            fallback: appData.gamesTool.spriteWidth(
              sprite,
              fallback: state.playerWidth,
            ),
          );
    final double frameHeight = mediaAsset == null
        ? appData.gamesTool.spriteHeight(sprite, fallback: state.playerHeight)
        : appData.gamesTool.mediaTileHeight(
            mediaAsset,
            fallback: appData.gamesTool.spriteHeight(
              sprite,
              fallback: state.playerHeight,
            ),
          );

    final int columns = (sheet.width / frameWidth).floor();
    if (columns <= 0) {
      _drawFallbackPlayer(canvas, size);
      return;
    }

    final AnimationPlaybackConfig playback =
        appData.gamesTool.animationPlaybackConfig(
      animationData,
      fallbackFps: 8,
    );
    final int frameIndex = appData.gamesTool.animationFrameIndexAtTime(
      playback: playback,
      elapsedSeconds: state.animationTimeSeconds,
    );
    final int srcCol = frameIndex % columns;
    final int srcRow = frameIndex ~/ columns;
    final Rect srcRect = Rect.fromLTWH(
      srcCol * frameWidth,
      srcRow * frameHeight,
      frameWidth,
      frameHeight,
    );

    final CameraScale cameraScale = CommonRenderer.getCameraScale(size, camera);
    final double parallaxSensitivity = _levelParallaxSensitivity();
    final Offset screenPos = CommonRenderer.worldToScreen(
      state.playerX,
      state.playerY,
      size,
      camera,
      parallaxSensitivity: parallaxSensitivity,
    );
    final Rect destRect = Rect.fromLTWH(
      screenPos.dx,
      screenPos.dy,
      state.playerWidth * cameraScale.scale,
      state.playerHeight * cameraScale.scale,
    );

    final Paint paint = Paint()..filterQuality = FilterQuality.none;
    if (!animation.mirrorX) {
      canvas.drawImageRect(sheet, srcRect, destRect, paint);
      return;
    }

    canvas.save();
    canvas.translate(destRect.left + destRect.width, destRect.top);
    canvas.scale(-1, 1);
    canvas.drawImageRect(
      sheet,
      srcRect,
      Rect.fromLTWH(0, 0, destRect.width, destRect.height),
      paint,
    );
    canvas.restore();
  }

  void _drawFallbackPlayer(Canvas canvas, Size size) {
    final Level0RenderState state = renderState!;
    final CameraScale cameraScale = CommonRenderer.getCameraScale(size, camera);
    final double parallaxSensitivity = _levelParallaxSensitivity();
    final Offset screenPos = CommonRenderer.worldToScreen(
      state.playerX,
      state.playerY,
      size,
      camera,
      parallaxSensitivity: parallaxSensitivity,
    );
    final Rect playerRect = Rect.fromLTWH(
      screenPos.dx,
      screenPos.dy,
      state.playerWidth * cameraScale.scale,
      state.playerHeight * cameraScale.scale,
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

  double _levelParallaxSensitivity() {
    final Map<String, dynamic>? currentLevel = level;
    if (currentLevel == null) {
      return GamesToolApi.defaultParallaxSensitivity;
    }
    return appData.gamesTool.levelParallaxSensitivity(currentLevel);
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
