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
  static const Set<String> _blockedZoneTypes = <String>{
    'Mur',
    'Aigua',
  };
  static const String _decoracionsLayerName = 'Decoracions';

  final FocusNode _focusNode = FocusNode();
  final Set<LogicalKeyboardKey> _pressedKeys = <LogicalKeyboardKey>{};
  final Camera _camera = Camera();
  final GameDataRuntimeApi _runtimeApi = GameDataRuntimeApi();

  Ticker? _ticker;
  Duration? _lastTickTimestamp;
  bool _initialized = false;
  Map<String, dynamic>? _level;
  int? _heroSpriteIndex;
  int? _decoracionsLayerIndex;
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
    _runtimeApi.useLoadedGameData(appData.gameData,
        gamesTool: appData.gamesTool);
    _heroSpriteIndex = _resolveHeroSpriteIndex(_level);
    _decoracionsLayerIndex =
        _resolveLayerIndexByName(_level, _decoracionsLayerName);

    final double levelViewportWidth = _level == null
        ? GamesToolApi.defaultViewportWidth
        : appData.gamesTool.levelViewportWidth(
            _level!,
            fallback: GamesToolApi.defaultViewportWidth,
          );
    final double levelViewportCenterX = _level == null
        ? 100
        : appData.gamesTool.levelViewportCenterX(
            _level!,
            fallbackWidth: GamesToolApi.defaultViewportWidth,
            fallbackX: 0,
          );
    final double levelViewportCenterY = _level == null
        ? 100
        : appData.gamesTool.levelViewportCenterY(
            _level!,
            fallbackHeight: GamesToolApi.defaultViewportHeight,
            fallbackY: 0,
          );

    final Map<String, dynamic>? spawn = _level == null
        ? null
        : appData.gamesTool.findSpriteByType(_level!, 'Heroi') ??
            appData.gamesTool.findFirstSprite(_level!);

    _updateState = Level0UpdateState(
      playerX: (spawn?['x'] as num?)?.toDouble() ?? levelViewportCenterX,
      playerY: (spawn?['y'] as num?)?.toDouble() ?? levelViewportCenterY,
      playerWidth: (spawn?['width'] as num?)?.toDouble() ?? 20,
      playerHeight: (spawn?['height'] as num?)?.toDouble() ?? 20,
      speedPerSecond: 95,
    );

    _camera
      ..x = levelViewportCenterX
      ..y = levelViewportCenterY
      ..focal = levelViewportWidth;
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

    final bool hasInput = inputX != 0 || inputY != 0;
    if (hasInput) {
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
    final double previousX = state.playerX;
    final double previousY = state.playerY;

    if (dx != 0) {
      final double nextX = state.playerX + dx;
      if (!_wouldCollideWithBlockedZone(
        state,
        nextX: nextX,
        nextY: state.playerY,
      )) {
        state.playerX = nextX;
      }
    }
    if (dy != 0) {
      final double nextY = state.playerY + dy;
      if (!_wouldCollideWithBlockedZone(
        state,
        nextX: state.playerX,
        nextY: nextY,
      )) {
        state.playerY = nextY;
      }
    }

    state.isMoving = state.playerX != previousX || state.playerY != previousY;
    _clearDecorationTileIfOnArbre(state);
    state.isOnPont = _isInsidePontZone(state);
    state.animationTimeSeconds += dt;
    state.tickCounter = (state.animationTimeSeconds * 60).floor();
  }

  bool _wouldCollideWithBlockedZone(
    Level0UpdateState state, {
    required double nextX,
    required double nextY,
  }) {
    final int? spriteIndex = _heroSpriteIndex;
    if (spriteIndex == null) {
      return false;
    }
    return _runtimeApi
        .collideSpriteWithZones(
          levelIndex: widget.levelIndex,
          spriteIndex: spriteIndex,
          spritePose: RuntimeSpritePose(
            levelIndex: widget.levelIndex,
            spriteIndex: spriteIndex,
            x: nextX,
            y: nextY,
            elapsedSeconds: state.animationTimeSeconds,
          ),
          zoneTypes: _blockedZoneTypes,
          elapsedSeconds: state.animationTimeSeconds,
        )
        .isNotEmpty;
  }

  bool _isInsidePontZone(Level0UpdateState state) {
    final int? spriteIndex = _heroSpriteIndex;
    if (spriteIndex == null) {
      return false;
    }
    return _runtimeApi
        .collideSpriteWithZones(
          levelIndex: widget.levelIndex,
          spriteIndex: spriteIndex,
          spritePose: RuntimeSpritePose(
            levelIndex: widget.levelIndex,
            spriteIndex: spriteIndex,
            x: state.playerX,
            y: state.playerY,
            elapsedSeconds: state.animationTimeSeconds,
          ),
          zoneTypes: const <String>{'Pont'},
          elapsedSeconds: state.animationTimeSeconds,
        )
        .isNotEmpty;
  }

  void _clearDecorationTileIfOnArbre(Level0UpdateState state) {
    final int? spriteIndex = _heroSpriteIndex;
    final int? layerIndex = _decoracionsLayerIndex;
    if (spriteIndex == null || layerIndex == null) {
      return;
    }
    final bool isInsideArbre = _runtimeApi
        .collideSpriteWithZones(
          levelIndex: widget.levelIndex,
          spriteIndex: spriteIndex,
          spritePose: RuntimeSpritePose(
            levelIndex: widget.levelIndex,
            spriteIndex: spriteIndex,
            x: state.playerX,
            y: state.playerY,
            elapsedSeconds: state.animationTimeSeconds,
          ),
          zoneTypes: const <String>{'Arbre'},
          elapsedSeconds: state.animationTimeSeconds,
        )
        .isNotEmpty;
    if (!isInsideArbre) {
      return;
    }

    final TileCoord? tile = _runtimeApi.worldToTile(
      levelIndex: widget.levelIndex,
      layerIndex: layerIndex,
      worldX: state.playerX,
      worldY: state.playerY,
    );
    if (tile == null) {
      return;
    }
    final int tileId = _runtimeApi.tileAt(
      levelIndex: widget.levelIndex,
      layerIndex: layerIndex,
      tileX: tile.x,
      tileY: tile.y,
    );
    if (tileId < 0) {
      return;
    }

    _runtimeApi.gameDataSet(
      <Object>[
        'levels',
        widget.levelIndex,
        'layers',
        layerIndex,
        'tileMap',
        tile.y,
        tile.x,
      ],
      -1,
    );
    state.arbresRemovedCount += 1;
  }

  int? _resolveHeroSpriteIndex(Map<String, dynamic>? level) {
    if (level == null) {
      return null;
    }
    final List<dynamic> sprites =
        (level['sprites'] as List<dynamic>?) ?? const <dynamic>[];
    for (int i = 0; i < sprites.length; i++) {
      final dynamic sprite = sprites[i];
      if (sprite is! Map<String, dynamic>) {
        continue;
      }
      final String type = (sprite['type'] as String?)?.trim() ?? '';
      final String name = (sprite['name'] as String?)?.trim() ?? '';
      if (type == 'Heroi' || name == 'Heroi') {
        return i;
      }
    }
    if (sprites.isEmpty) {
      return null;
    }
    return 0;
  }

  int? _resolveLayerIndexByName(Map<String, dynamic>? level, String layerName) {
    if (level == null) {
      return null;
    }
    final List<dynamic> layers =
        (level['layers'] as List<dynamic>?) ?? const <dynamic>[];
    for (int i = 0; i < layers.length; i++) {
      final dynamic layer = layers[i];
      if (layer is! Map<String, dynamic>) {
        continue;
      }
      final String name = (layer['name'] as String?)?.trim() ?? '';
      if (name == layerName) {
        return i;
      }
    }
    return null;
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
  bool isOnPont = false;
  int arbresRemovedCount = 0;
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
    required this.isOnPont,
    required this.arbresRemovedCount,
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
      isOnPont: state.isOnPont,
      arbresRemovedCount: state.arbresRemovedCount,
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
    final RuntimeLevelViewport viewport =
        GamesToolRuntimeRenderer.levelViewport(
      gamesTool: appData.gamesTool,
      level: level,
    );
    final Color levelBackground = GamesToolRuntimeRenderer.levelBackgroundColor(
      gamesTool: appData.gamesTool,
      level: level,
      fallback: const Color(0xFF0B1014),
    );

    GamesToolRuntimeRenderer.withViewport(
      canvas: canvas,
      painterSize: size,
      viewport: viewport,
      outerBackgroundColor: levelBackground,
      drawInViewport: (Size viewportSize) {
        final RuntimeCamera2D effectiveCamera = RuntimeCamera2D(
          x: runtimeCamera.x,
          y: runtimeCamera.y,
          focal: viewportSize.width,
        );
        GamesToolRuntimeRenderer.drawLevelTileLayers(
          canvas: canvas,
          painterSize: viewportSize,
          level: level!,
          gamesTool: appData.gamesTool,
          imagesCache: appData.imagesCache,
          camera: effectiveCamera,
          backgroundColor: levelBackground,
          parallaxSensitivity: parallaxSensitivity,
        );

        _drawAnimatedPlayer(canvas, viewportSize, effectiveCamera);

        _drawText(
          canvas,
          'LEVEL 0: TOP-DOWN  |  MOVE: ARROWS/WASD',
          const Offset(20, 20),
        );
        if (renderState!.isOnPont) {
          _drawText(canvas, 'Caminant pel pont', const Offset(20, 42));
        }
        _drawTopRightText(
          canvas,
          viewportSize,
          'Arbres: ${renderState!.arbresRemovedCount}',
          20,
        );
      },
    );
  }

  void _drawText(Canvas canvas, String text, Offset offset) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFFE0F2FF),
          fontSize: 6.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  void _drawTopRightText(Canvas canvas, Size size, String text, double top) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFFE0F2FF),
          fontSize: 6.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(size.width - painter.width - 20, top));
  }

  void _drawAnimatedPlayer(
    Canvas canvas,
    Size size,
    RuntimeCamera2D runtimeCamera,
  ) {
    final Level0RenderState state = renderState!;
    if (level == null) {
      _drawFallbackPlayer(canvas, size, runtimeCamera);
      return;
    }

    final Map<String, dynamic>? sprite =
        appData.gamesTool.findSpriteByType(level!, 'Heroi') ??
            appData.gamesTool.findFirstSprite(level!);
    final _AnimationSelection animation = _resolveAnimationFor(state);
    if (sprite == null) {
      _drawFallbackPlayer(canvas, size, runtimeCamera);
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
      camera: runtimeCamera,
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
      _drawFallbackPlayer(canvas, size, runtimeCamera);
    }
  }

  void _drawFallbackPlayer(
    Canvas canvas,
    Size size,
    RuntimeCamera2D runtimeCamera,
  ) {
    final Level0RenderState state = renderState!;
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
