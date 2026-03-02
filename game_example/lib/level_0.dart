import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app_data.dart';
import 'camera.dart';
import 'menu.dart';
import 'utils_gamestool/utils_gamestool.dart';

const String _level0BackIconAssetPath = 'other/enrrere.png';
const String _level0BackLabel = 'Tornar';
const double _level0BackHudX = 20;
const double _level0BackHudY = 5;
const double _level0BackIconWidth = 8;
const double _level0BackIconHeight = 8;
const double _level0BackIconGap = 3;
const double _level0BackTextX =
    _level0BackHudX + _level0BackIconWidth + _level0BackIconGap;

Rect _resolveLevel0HudRectInVirtualViewport({
  required RuntimeLevelViewport viewport,
  required Size virtualViewportSize,
}) {
  final String adaptation = viewport.adaptation.trim().toLowerCase();
  if (adaptation != 'expand') {
    return Rect.fromLTWH(
        0, 0, virtualViewportSize.width, virtualViewportSize.height);
  }

  final double baseWidth =
      viewport.width > 0 ? viewport.width : virtualViewportSize.width;
  final double baseHeight =
      viewport.height > 0 ? viewport.height : virtualViewportSize.height;
  final double left = (virtualViewportSize.width - baseWidth) / 2;
  final double top = (virtualViewportSize.height - baseHeight) / 2;
  return Rect.fromLTWH(left, top, baseWidth, baseHeight);
}

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
  static const String _pontAmagatLayerName = 'Pont Amagat';
  static const String _futurPontGameplayData = 'Futur Pont';

  final FocusNode _focusNode = FocusNode();
  final Set<LogicalKeyboardKey> _pressedKeys = <LogicalKeyboardKey>{};
  final Camera _camera = Camera();
  final GameDataRuntimeApi _runtimeApi = GameDataRuntimeApi();

  Ticker? _ticker;
  Duration? _lastTickTimestamp;
  bool _initialized = false;
  Map<String, dynamic>? _runtimeGameData;
  Map<String, dynamic>? _level;
  int? _heroSpriteIndex;
  int? _decoracionsLayerIndex;
  int? _pontAmagatLayerIndex;
  Level0UpdateState? _updateState;
  ui.Image? _backIconImage;
  bool _isLeavingLevel = false;

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
    _runtimeGameData = _cloneGameData(appData.gameData);
    _level = _runtimeGameData == null
        ? null
        : appData.gamesTool
            .findLevelByIndex(_runtimeGameData!, widget.levelIndex);
    if (_runtimeGameData != null) {
      _runtimeApi.useLoadedGameData(_runtimeGameData!,
          gamesTool: appData.gamesTool);
    }
    _heroSpriteIndex = _resolveHeroSpriteIndex(_level);
    _decoracionsLayerIndex =
        _resolveLayerIndexByName(_level, _decoracionsLayerName);
    _pontAmagatLayerIndex =
        _resolveLayerIndexByName(_level, _pontAmagatLayerName);
    unawaited(_ensureBackIconLoaded(appData));

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

  Map<String, dynamic>? _cloneGameData(Map<String, dynamic> source) {
    if (source.isEmpty) {
      return null;
    }
    final dynamic clone = jsonDecode(jsonEncode(source));
    if (clone is Map<String, dynamic>) {
      return clone;
    }
    return null;
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
    _revealPontAmagatLayerIfEnteringFuturPontZone(state);
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

  bool _isInsideZoneWithGameplayData(
    Level0UpdateState state,
    String gameplayDataValue,
  ) {
    final int? spriteIndex = _heroSpriteIndex;
    if (spriteIndex == null) {
      return false;
    }
    final List<ZoneContact> zoneContacts = _runtimeApi.collideSpriteWithZones(
      levelIndex: widget.levelIndex,
      spriteIndex: spriteIndex,
      spritePose: RuntimeSpritePose(
        levelIndex: widget.levelIndex,
        spriteIndex: spriteIndex,
        x: state.playerX,
        y: state.playerY,
        elapsedSeconds: state.animationTimeSeconds,
      ),
      elapsedSeconds: state.animationTimeSeconds,
    );
    final Set<int> checkedZoneIndices = <int>{};
    final String targetGameplayData = gameplayDataValue.trim();
    for (final ZoneContact contact in zoneContacts) {
      if (!checkedZoneIndices.add(contact.zoneIndex)) {
        continue;
      }
      final String zoneGameplayData = (_runtimeApi.gameDataGetAs<String>(
                <Object>[
                  'levels',
                  widget.levelIndex,
                  'zones',
                  contact.zoneIndex,
                  'gameplayData',
                ],
              ) ??
              '')
          .trim();
      if (zoneGameplayData == targetGameplayData) {
        return true;
      }
    }
    return false;
  }

  void _revealLayerIfHidden(int layerIndex) {
    final bool isVisible = _runtimeApi.gameDataGetAs<bool>(
          <Object>[
            'levels',
            widget.levelIndex,
            'layers',
            layerIndex,
            'visible'
          ],
        ) ??
        false;
    if (isVisible) {
      return;
    }
    _runtimeApi.gameDataSet(
      <Object>['levels', widget.levelIndex, 'layers', layerIndex, 'visible'],
      true,
    );
  }

  void _revealPontAmagatLayerIfEnteringFuturPontZone(Level0UpdateState state) {
    final int? layerIndex = _pontAmagatLayerIndex;
    if (layerIndex == null) {
      return;
    }
    final bool isInsideFuturPontZone =
        _isInsideZoneWithGameplayData(state, _futurPontGameplayData);
    final bool enteredFuturPontZone =
        isInsideFuturPontZone && !state.wasInsideFuturPontGameplayZone;
    if (enteredFuturPontZone) {
      _revealLayerIfHidden(layerIndex);
    }
    state.wasInsideFuturPontGameplayZone = isInsideFuturPontZone;
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
    final LogicalKeyboardKey key = event.logicalKey;

    if (key == LogicalKeyboardKey.escape) {
      if (event is KeyDownEvent) {
        _goBackToMenu();
      }
      return KeyEventResult.handled;
    }

    if (event is KeyDownEvent) {
      _pressedKeys.add(key);
    } else if (event is KeyUpEvent) {
      _pressedKeys.remove(key);
    }
    return KeyEventResult.handled;
  }

  TextStyle get _hudTextStyle => const TextStyle(
        color: Color(0xFFE0F2FF),
        fontSize: 6.5,
        fontWeight: FontWeight.w600,
      );

  Rect _backLabelScreenRect({
    required AppData appData,
    required Size canvasSize,
  }) {
    final RuntimeLevelViewport viewport =
        GamesToolRuntimeRenderer.levelViewport(
      gamesTool: appData.gamesTool,
      level: _level,
    );
    final RuntimeViewportLayout layout =
        GamesToolRuntimeRenderer.resolveViewportLayout(
      painterSize: canvasSize,
      viewport: viewport,
    );
    if (!layout.hasVisibleArea || layout.scaleX == 0 || layout.scaleY == 0) {
      return Rect.zero;
    }
    final Rect hudVirtualRect = _resolveLevel0HudRectInVirtualViewport(
      viewport: viewport,
      virtualViewportSize: layout.virtualSize,
    );

    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: _level0BackLabel,
        style: _hudTextStyle,
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final double labelLeft = layout.destinationRect.left +
        ((hudVirtualRect.left + _level0BackHudX) * layout.scaleX);
    final double labelTop = layout.destinationRect.top +
        ((hudVirtualRect.top + _level0BackHudY) * layout.scaleY);
    final double labelWidth =
        (_level0BackIconWidth + _level0BackIconGap + painter.width) *
            layout.scaleX;
    final double labelHeight = (_level0BackIconHeight > painter.height
            ? _level0BackIconHeight
            : painter.height) *
        layout.scaleY;

    return Rect.fromLTWH(
      labelLeft - 6,
      labelTop - 4,
      labelWidth + 12,
      labelHeight + 8,
    );
  }

  void _clearLevel0RuntimeState() {
    _pressedKeys.clear();
    _lastTickTimestamp = null;
    _runtimeApi.resetFrameState();
    _runtimeGameData = null;
    _level = null;
    _heroSpriteIndex = null;
    _decoracionsLayerIndex = null;
    _pontAmagatLayerIndex = null;
    _updateState = null;
    _backIconImage = null;
  }

  Future<void> _ensureBackIconLoaded(AppData appData) async {
    if (_backIconImage != null) {
      return;
    }
    try {
      final ui.Image iconImage =
          await appData.getImage(_level0BackIconAssetPath);
      if (!mounted) {
        return;
      }
      setState(() {
        _backIconImage = iconImage;
      });
    } catch (_) {
      // Keep text-only fallback if asset load fails.
    }
  }

  void _goBackToMenu() {
    if (!mounted || _isLeavingLevel) {
      return;
    }
    _isLeavingLevel = true;
    _ticker?.stop();
    _clearLevel0RuntimeState();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) => const Menu(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final Animation<Offset> slideAnimation = Tween<Offset>(
            begin: const Offset(-1, 0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
          );
          return SlideTransition(
            position: slideAnimation,
            child: child,
          );
        },
      ),
    );
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
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final Size canvasSize =
                Size(constraints.maxWidth, constraints.maxHeight);
            final Rect backLabelRect = _backLabelScreenRect(
              appData: appData,
              canvasSize: canvasSize,
            );

            return Focus(
              autofocus: true,
              focusNode: _focusNode,
              onKeyEvent: (FocusNode node, KeyEvent event) =>
                  _onKeyEvent(event),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (TapDownDetails details) {
                  _focusNode.requestFocus();
                  if (backLabelRect.contains(details.localPosition)) {
                    _goBackToMenu();
                  }
                },
                child: CustomPaint(
                  painter: Level0Painter(
                    appData: appData,
                    gameData: _runtimeGameData,
                    level: _level,
                    camera: _camera,
                    backIconImage: _backIconImage,
                    renderState:
                        state == null ? null : Level0RenderState.from(state),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            );
          },
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
  bool wasInsideFuturPontGameplayZone = false;
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
    required this.gameData,
    required this.level,
    required this.camera,
    required this.backIconImage,
    required this.renderState,
  });

  final AppData appData;
  final Map<String, dynamic>? gameData;
  final Map<String, dynamic>? level;
  final Camera camera;
  final ui.Image? backIconImage;
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
        final Rect hudRect = _resolveLevel0HudRectInVirtualViewport(
          viewport: viewport,
          virtualViewportSize: viewportSize,
        );
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

        _drawBackToMenuHud(canvas, hudRect);
        _drawText(
          canvas,
          'LEVEL 0: TOP-DOWN  |  MOVE: ARROWS/WASD',
          Offset(hudRect.left + 20, hudRect.top + 170),
        );
        if (renderState!.isOnPont) {
          _drawText(
            canvas,
            'Caminant pel pont',
            Offset(hudRect.left + 20, hudRect.top + 20),
          );
        }
        _drawTopRightText(
          canvas,
          hudRect,
          'Arbres: ${renderState!.arbresRemovedCount}',
          5,
        );
      },
    );
  }

  void _drawBackToMenuHud(Canvas canvas, Rect hudRect) {
    final ui.Image? iconImage = backIconImage;
    if (iconImage != null) {
      final Rect srcRect = Rect.fromLTWH(
        0,
        0,
        iconImage.width.toDouble(),
        iconImage.height.toDouble(),
      );
      final Rect dstRect = Rect.fromLTWH(
        hudRect.left + _level0BackHudX,
        hudRect.top + _level0BackHudY,
        _level0BackIconWidth,
        _level0BackIconHeight,
      );
      canvas.drawImageRect(iconImage, srcRect, dstRect, Paint());
    }
    _drawText(
      canvas,
      _level0BackLabel,
      Offset(hudRect.left + _level0BackTextX, hudRect.top + _level0BackHudY),
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

  void _drawTopRightText(Canvas canvas, Rect hudRect, String text, double top) {
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
    painter.paint(
      canvas,
      Offset(hudRect.right - painter.width - 20, hudRect.top + top),
    );
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
      gameData: gameData ?? appData.gameData,
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
