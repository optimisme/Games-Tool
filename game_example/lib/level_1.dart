import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app_data.dart';
import 'camera.dart';
import 'menu/main.dart';
import 'utils_gamestool/utils_gamestool.dart';

const String _level1BackIconAssetPath = 'other/enrrere.png';
const String _level1BackLabel = 'Tornar';
const String _level1PlayerSpriteName = 'Foxy';
const String _level1FloorZoneName = 'Floor';
const String _level1DeathZoneName = 'Foxy Death';
const String _level1GemSpriteName = 'Gem';
const String _level1AnimFoxyIdle = 'Foxy Idle';
const String _level1AnimFoxyWalk = 'Foxy Walk';
const String _level1AnimFoxyJumpUp = 'Foxy Jump Up';
const String _level1AnimFoxyJumpFall = 'Foxy Jump Fall';
const double _level1BackHudX = 20;
const double _level1BackHudY = 5;
const double _level1BackIconWidth = 8;
const double _level1BackIconHeight = 8;
const double _level1BackIconGap = 3;
const double _level1BackTextX =
    _level1BackHudX + _level1BackIconWidth + _level1BackIconGap;

Rect _resolveLevel1HudRectInVirtualViewport({
  required RuntimeLevelViewport viewport,
  required Size virtualViewportSize,
}) {
  final String adaptation = viewport.adaptation.trim().toLowerCase();
  if (adaptation != 'expand') {
    return Rect.fromLTWH(
      0,
      0,
      virtualViewportSize.width,
      virtualViewportSize.height,
    );
  }

  final double baseWidth =
      viewport.width > 0 ? viewport.width : virtualViewportSize.width;
  final double baseHeight =
      viewport.height > 0 ? viewport.height : virtualViewportSize.height;
  final double left = (virtualViewportSize.width - baseWidth) / 2;
  final double top = (virtualViewportSize.height - baseHeight) / 2;
  return Rect.fromLTWH(left, top, baseWidth, baseHeight);
}

bool _isLevel1PlayerSprite(Map<String, dynamic> sprite) {
  final String target = _level1PlayerSpriteName.toLowerCase();
  final String spriteName = ((sprite['name'] as String?) ?? '').trim();
  return spriteName.toLowerCase() == target;
}

bool _isLevel1GemSprite(Map<String, dynamic> sprite) {
  final String target = _level1GemSpriteName.toLowerCase();
  final String spriteName = ((sprite['name'] as String?) ?? '').trim();
  final String spriteType = ((sprite['type'] as String?) ?? '').trim();
  return spriteName.toLowerCase() == target ||
      spriteType.toLowerCase() == target;
}

Map<String, dynamic>? _resolveLevel1PlayerSprite(Map<String, dynamic>? level) {
  if (level == null) {
    return null;
  }
  final List<Map<String, dynamic>> sprites =
      ((level['sprites'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
  for (final Map<String, dynamic> sprite in sprites) {
    if (_isLevel1PlayerSprite(sprite)) {
      return sprite;
    }
  }
  return null;
}

int? _resolveLevel1PlayerSpriteIndex(Map<String, dynamic>? level) {
  if (level == null) {
    return null;
  }
  final List<Map<String, dynamic>> sprites =
      ((level['sprites'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
  for (int i = 0; i < sprites.length; i++) {
    if (_isLevel1PlayerSprite(sprites[i])) {
      return i;
    }
  }
  return null;
}

List<Rect> _resolveLevel1FloorZones(Map<String, dynamic>? level) {
  return _resolveLevel1ZonesByTypeOrName(level, _level1FloorZoneName);
}

List<Rect> _resolveLevel1DeathZones(Map<String, dynamic>? level) {
  return _resolveLevel1ZonesByTypeOrName(level, _level1DeathZoneName);
}

List<Rect> _resolveLevel1ZonesByTypeOrName(
  Map<String, dynamic>? level,
  String zoneTypeOrName,
) {
  if (level == null) {
    return const <Rect>[];
  }
  final List<Map<String, dynamic>> zones =
      ((level['zones'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
  final String target = zoneTypeOrName.toLowerCase();
  final List<Rect> floors = <Rect>[];
  for (final Map<String, dynamic> zone in zones) {
    final String zoneType = ((zone['type'] as String?) ?? '').trim();
    final String zoneName = ((zone['name'] as String?) ?? '').trim();
    if (zoneType.toLowerCase() != target && zoneName.toLowerCase() != target) {
      continue;
    }
    final double x = (zone['x'] as num?)?.toDouble() ?? 0;
    final double y = (zone['y'] as num?)?.toDouble() ?? 0;
    final double width = (zone['width'] as num?)?.toDouble() ?? 0;
    final double height = (zone['height'] as num?)?.toDouble() ?? 0;
    if (width <= 0 || height <= 0) {
      continue;
    }
    floors.add(Rect.fromLTWH(x, y, width, height));
  }
  return floors;
}

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
  final GameDataRuntimeApi _runtimeApi = GameDataRuntimeApi();

  Ticker? _ticker;
  Duration? _lastTickTimestamp;
  bool _initialized = false;
  bool _jumpQueued = false;
  Map<String, dynamic>? _level;
  Map<String, dynamic>? _playerSprite;
  int? _playerSpriteIndex;
  Level1UpdateState? _updateState;
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
    _runtimeApi.useLoadedGameData(
      appData.gameData,
      gamesTool: appData.gamesTool,
    );
    _level = appData.getLevelByIndex(widget.levelIndex);
    _playerSprite = _resolveLevel1PlayerSprite(_level);
    _playerSpriteIndex = _resolveLevel1PlayerSpriteIndex(_level);
    unawaited(_ensureBackIconLoaded(appData));
    final Map<String, dynamic>? spawn = _playerSprite;
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
        ? 120
        : appData.gamesTool.levelViewportCenterY(
            _level!,
            fallbackHeight: GamesToolApi.defaultViewportHeight,
            fallbackY: 0,
          );

    final double spawnX =
        (spawn?['x'] as num?)?.toDouble() ?? levelViewportCenterX;
    final double spawnY =
        (spawn?['y'] as num?)?.toDouble() ?? levelViewportCenterY;

    _updateState = Level1UpdateState(
      playerX: spawnX,
      playerY: spawnY,
      playerWidth: (spawn?['width'] as num?)?.toDouble() ?? 22,
      playerHeight: (spawn?['height'] as num?)?.toDouble() ?? 30,
      gemsCount: 0,
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
    final Level1UpdateState? state = _updateState;
    if (!mounted || state == null) {
      return;
    }

    if (!state.isGameOver) {
      _updatePhysics(state, dt);
      _camera
        ..x = state.playerX
        ..y = state.playerY - 80;
    }

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

    final bool hasSupport = _isStandingOnFloor(state);
    if (hasSupport && state.velocityY >= 0) {
      state.velocityY = 0;
      state.onGround = true;
    } else if (!hasSupport) {
      state.onGround = false;
    }

    if (_jumpQueued && state.onGround) {
      state.velocityY = -state.jumpImpulsePerSecond;
      state.onGround = false;
    }
    _jumpQueued = false;

    if (!state.onGround || state.velocityY < 0) {
      state.velocityY += state.gravityPerSecondSq * dt;
      if (state.velocityY > state.maxFallSpeedPerSecond) {
        state.velocityY = state.maxFallSpeedPerSecond;
      }
    }

    state.playerX += state.velocityX * dt;
    state.playerY += state.velocityY * dt;
    final bool landed = _resolveFloorPenetration(state);
    final bool standingOnFloor = _isStandingOnFloor(state);
    if ((landed || standingOnFloor) && state.velocityY >= 0) {
      state.velocityY = 0;
      state.onGround = true;
    } else {
      state.onGround = false;
    }
    _collectTouchedGems(state);

    if (_isTouchingDeathZone(state)) {
      state.isGameOver = true;
      state.velocityX = 0;
      state.velocityY = 0;
      state.onGround = false;
      _jumpQueued = false;
      _pressedKeys.clear();
      _ticker?.stop();
    }

    state.animationTimeSeconds += dt;
    state.tickCounter = (state.animationTimeSeconds * 60).floor();
  }

  bool _isTouchingDeathZone(Level1UpdateState state) {
    final List<Rect> deathZones = _resolveLevel1DeathZones(_level);
    if (deathZones.isEmpty) {
      return false;
    }
    final List<Rect> playerRects = _playerCollisionRectsForPose(
      state,
      y: state.playerY,
      elapsedSeconds: state.animationTimeSeconds,
    );
    for (final Rect playerRect in playerRects) {
      for (final Rect deathZone in deathZones) {
        if (playerRect.overlaps(deathZone)) {
          return true;
        }
      }
    }
    return false;
  }

  bool _isStandingOnFloor(Level1UpdateState state) {
    final List<Rect> floors = _resolveLevel1FloorZones(_level);
    if (floors.isEmpty) {
      return false;
    }
    final List<Rect> playerRects = _playerCollisionRectsForPose(
      state,
      y: state.playerY + 0.5,
      elapsedSeconds: state.animationTimeSeconds,
    );
    for (final Rect playerRect in playerRects) {
      for (final Rect floor in floors) {
        final bool overlapsHorizontally =
            playerRect.right > floor.left && playerRect.left < floor.right;
        if (!overlapsHorizontally) {
          continue;
        }
        final double bottomDelta = (playerRect.bottom - floor.top).abs();
        if (bottomDelta <= 1.0) {
          return true;
        }
      }
    }
    return false;
  }

  void _collectTouchedGems(Level1UpdateState state) {
    final List<int> candidateGemIndices = _gemSpriteIndices()
        .where((index) => !state.collectedGemSpriteIndices.contains(index))
        .toList(growable: false);
    if (candidateGemIndices.isEmpty) {
      return;
    }
    final List<Rect> playerRects = _playerCollisionRectsForPose(
      state,
      y: state.playerY,
      elapsedSeconds: state.animationTimeSeconds,
    );
    if (playerRects.isEmpty) {
      return;
    }

    final List<int> newlyCollected = <int>[];
    for (final int gemIndex in candidateGemIndices) {
      final List<Rect> gemRects = _spriteCollisionRectsForIndex(
        spriteIndex: gemIndex,
        elapsedSeconds: state.animationTimeSeconds,
      );
      bool collided = false;
      for (final Rect playerRect in playerRects) {
        for (final Rect gemRect in gemRects) {
          if (playerRect.overlaps(gemRect)) {
            collided = true;
            break;
          }
        }
        if (collided) {
          break;
        }
      }
      if (collided) {
        newlyCollected.add(gemIndex);
      }
    }
    if (newlyCollected.isEmpty) {
      return;
    }
    state.collectedGemSpriteIndices.addAll(newlyCollected);
    state.gemsCount += newlyCollected.length;
  }

  List<int> _gemSpriteIndices() {
    final Map<String, dynamic>? level = _level;
    if (level == null) {
      return const <int>[];
    }
    final List<Map<String, dynamic>> sprites =
        ((level['sprites'] as List<dynamic>?) ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);
    final List<int> indices = <int>[];
    for (int i = 0; i < sprites.length; i++) {
      if (_isLevel1GemSprite(sprites[i])) {
        indices.add(i);
      }
    }
    return indices;
  }

  List<Rect> _playerCollisionRectsForPose(
    Level1UpdateState state, {
    required double y,
    required double elapsedSeconds,
  }) {
    final int? playerSpriteIndex = _playerSpriteIndex;
    if (playerSpriteIndex == null || !_runtimeApi.isReady || _level == null) {
      return const <Rect>[];
    }
    return _spriteCollisionRectsForIndex(
      spriteIndex: playerSpriteIndex,
      elapsedSeconds: elapsedSeconds,
      levelIndex: widget.levelIndex,
      pose: RuntimeSpritePose(
        levelIndex: widget.levelIndex,
        spriteIndex: playerSpriteIndex,
        x: state.playerX,
        y: y,
        flipX: !state.facingRight,
        elapsedSeconds: elapsedSeconds,
      ),
    );
  }

  List<Rect> _spriteCollisionRectsForIndex({
    required int spriteIndex,
    required double elapsedSeconds,
    int? levelIndex,
    RuntimeSpritePose? pose,
  }) {
    final int resolvedLevelIndex = levelIndex ?? widget.levelIndex;
    if (!_runtimeApi.isReady || _level == null) {
      return const <Rect>[];
    }
    final List<WorldHitBox> hitBoxes = _runtimeApi.spriteHitBoxes(
      levelIndex: resolvedLevelIndex,
      spriteIndex: spriteIndex,
      pose: pose,
      elapsedSeconds: elapsedSeconds,
    );
    if (hitBoxes.isNotEmpty) {
      return hitBoxes.map((hitBox) => hitBox.rectWorld).toList(growable: false);
    }
    final Rect? anchoredRect = _spriteAnchoredRectForIndex(
      spriteIndex: spriteIndex,
      elapsedSeconds: elapsedSeconds,
      levelIndex: resolvedLevelIndex,
      pose: pose,
    );
    if (anchoredRect == null) {
      return const <Rect>[];
    }
    return <Rect>[anchoredRect];
  }

  Rect? _spriteAnchoredRectForIndex({
    required int spriteIndex,
    required double elapsedSeconds,
    int? levelIndex,
    RuntimeSpritePose? pose,
  }) {
    final int resolvedLevelIndex = levelIndex ?? widget.levelIndex;
    final Map<String, dynamic>? sprite = _runtimeApi.spriteByIndex(
      levelIndex: resolvedLevelIndex,
      spriteIndex: spriteIndex,
    );
    if (sprite == null) {
      return null;
    }
    final GamesToolApi gamesTool = _runtimeApi.gamesTool;
    final Map<String, dynamic> gameData = _runtimeApi.gameData;
    final Map<String, dynamic>? animation =
        gamesTool.findAnimationForSprite(gameData, sprite);
    final String? spriteImageFile = gamesTool.spriteImageFile(sprite);
    final String? animationMediaFile = animation?['mediaFile'] as String?;
    final String effectiveFile =
        (animationMediaFile != null && animationMediaFile.isNotEmpty)
            ? animationMediaFile
            : (spriteImageFile ?? '');
    final Map<String, dynamic>? mediaAsset = effectiveFile.isEmpty
        ? null
        : gamesTool.findMediaAssetByFile(gameData, effectiveFile);
    final double frameWidth = mediaAsset == null
        ? gamesTool.spriteWidth(sprite)
        : gamesTool.mediaTileWidth(mediaAsset,
            fallback: gamesTool.spriteWidth(sprite));
    final double frameHeight = mediaAsset == null
        ? gamesTool.spriteHeight(sprite)
        : gamesTool.mediaTileHeight(mediaAsset,
            fallback: gamesTool.spriteHeight(sprite));
    if (frameWidth <= 0 || frameHeight <= 0) {
      return null;
    }

    double anchorX = GamesToolApi.defaultAnchorX;
    double anchorY = GamesToolApi.defaultAnchorY;
    if (animation != null) {
      final AnimationPlaybackConfig playback =
          gamesTool.animationPlaybackConfig(animation);
      final int frameIndex = gamesTool.animationFrameIndexAtTime(
        playback: playback,
        elapsedSeconds: elapsedSeconds,
      );
      anchorX = gamesTool.animationAnchorXForFrame(
        animation,
        frameIndex: frameIndex,
      );
      anchorY = gamesTool.animationAnchorYForFrame(
        animation,
        frameIndex: frameIndex,
      );
    }

    final double worldX = pose?.x ?? gamesTool.spriteX(sprite);
    final double worldY = pose?.y ?? gamesTool.spriteY(sprite);
    final double left = worldX - frameWidth * anchorX;
    final double top = worldY - frameHeight * anchorY;
    return Rect.fromLTWH(left, top, frameWidth, frameHeight);
  }

  bool _resolveFloorPenetration(Level1UpdateState state) {
    if (state.velocityY < 0) {
      return false;
    }
    final List<Rect> floors = _resolveLevel1FloorZones(_level);
    if (floors.isEmpty) {
      return false;
    }
    double correctedY = state.playerY;
    bool landed = false;
    for (int i = 0; i < 6; i++) {
      final List<Rect> playerRects = _playerCollisionRectsForPose(
        state,
        y: correctedY,
        elapsedSeconds: state.animationTimeSeconds,
      );
      double maxPenetration = 0;
      for (final Rect playerRect in playerRects) {
        for (final Rect floor in floors) {
          final bool overlapsHorizontally =
              playerRect.right > floor.left && playerRect.left < floor.right;
          if (!overlapsHorizontally) {
            continue;
          }
          final bool crossedTop =
              playerRect.bottom > floor.top && playerRect.top < floor.top + 4;
          if (!crossedTop) {
            continue;
          }
          final double penetration = playerRect.bottom - floor.top;
          if (penetration > maxPenetration) {
            maxPenetration = penetration;
          }
        }
      }
      if (maxPenetration <= 0) {
        break;
      }
      correctedY -= maxPenetration + 0.01;
      landed = true;
    }
    state.playerY = correctedY;
    return landed;
  }

  void _refreshLevel1([VoidCallback? update]) {
    if (!mounted) {
      return;
    }
    setState(update ?? () {});
  }

  Future<void> _ensureBackIconLoaded(AppData appData) async {
    if (_backIconImage != null) {
      return;
    }
    try {
      final ui.Image iconImage =
          await appData.getImage(_level1BackIconAssetPath);
      if (!mounted) {
        return;
      }
      _refreshLevel1(() {
        _backIconImage = iconImage;
      });
    } catch (_) {
      // Keep text-only fallback if asset load fails.
    }
  }

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
    final Rect hudVirtualRect = _resolveLevel1HudRectInVirtualViewport(
      viewport: viewport,
      virtualViewportSize: layout.virtualSize,
    );

    const TextStyle hudTextStyle = TextStyle(
      color: Color(0xFFE0F2FF),
      fontSize: 6.5,
      fontWeight: FontWeight.w600,
    );
    final TextPainter painter = TextPainter(
      text: const TextSpan(
        text: _level1BackLabel,
        style: hudTextStyle,
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final double labelLeft = layout.destinationRect.left +
        ((hudVirtualRect.left + _level1BackHudX) * layout.scaleX);
    final double labelTop = layout.destinationRect.top +
        ((hudVirtualRect.top + _level1BackHudY) * layout.scaleY);
    final double labelWidth =
        (_level1BackIconWidth + _level1BackIconGap + painter.width) *
            layout.scaleX;
    final double labelHeight = (_level1BackIconHeight > painter.height
            ? _level1BackIconHeight
            : painter.height) *
        layout.scaleY;

    return Rect.fromLTWH(
      labelLeft - 6,
      labelTop - 4,
      labelWidth + 12,
      labelHeight + 8,
    );
  }

  void _goBackToMenu() {
    if (!mounted || _isLeavingLevel) {
      return;
    }
    _isLeavingLevel = true;
    _ticker?.stop();
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

  KeyEventResult _onKeyEvent(KeyEvent event) {
    final LogicalKeyboardKey key = event.logicalKey;
    final Level1UpdateState? state = _updateState;

    if (state != null && state.isGameOver) {
      if (event is KeyDownEvent) {
        _goBackToMenu();
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.escape) {
      if (event is KeyDownEvent) {
        _goBackToMenu();
      }
      return KeyEventResult.handled;
    }

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
                  painter: Level1Painter(
                    appData: appData,
                    level: _level,
                    camera: _camera,
                    backIconImage: _backIconImage,
                    renderState:
                        state == null ? null : Level1RenderState.from(state),
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

class Level1UpdateState {
  Level1UpdateState({
    required this.playerX,
    required this.playerY,
    required this.playerWidth,
    required this.playerHeight,
    required this.gemsCount,
  });

  double playerX;
  double playerY;
  double playerWidth;
  double playerHeight;

  double velocityX = 0;
  double velocityY = 0;
  bool onGround = false;
  bool facingRight = true;
  bool isGameOver = false;
  int tickCounter = 0;
  double animationTimeSeconds = 0;
  final Set<int> collectedGemSpriteIndices = <int>{};

  int gemsCount;
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
    required this.velocityX,
    required this.velocityY,
    required this.onGround,
    required this.isGameOver,
    required this.facingRight,
    required this.tickCounter,
    required this.animationTimeSeconds,
    required this.gemsCount,
    required this.collectedGemSpriteIndices,
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
      collectedGemSpriteIndices: Set<int>.from(state.collectedGemSpriteIndices),
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
  final Set<int> collectedGemSpriteIndices;
}

class Level1Painter extends CustomPainter {
  const Level1Painter({
    required this.appData,
    required this.level,
    required this.camera,
    required this.backIconImage,
    required this.renderState,
  });

  final AppData appData;
  final Map<String, dynamic>? level;
  final Camera camera;
  final ui.Image? backIconImage;
  final Level1RenderState? renderState;

  @override
  void paint(Canvas canvas, Size size) {
    if (level == null || renderState == null) {
      final Paint background = Paint()..color = const Color(0xFF0A0D1A);
      canvas.drawRect(Offset.zero & size, background);
      _drawText(canvas, 'Loading level 1...', const Offset(20, 20));
      return;
    }

    final RuntimeCamera2D runtimeCamera = camera.toRuntimeCamera2D();
    final double depthSensitivity =
        GamesToolRuntimeRenderer.levelDepthSensitivity(
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
      fallback: const Color(0xFF0A0D1A),
    );

    GamesToolRuntimeRenderer.withViewport(
      canvas: canvas,
      painterSize: size,
      viewport: viewport,
      outerBackgroundColor: levelBackground,
      drawInViewport: (Size viewportSize) {
        final Rect hudRect = _resolveLevel1HudRectInVirtualViewport(
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
          depthSensitivity: depthSensitivity,
        );
        final List<Map<String, dynamic>> levelSprites =
            ((level!['sprites'] as List<dynamic>?) ?? const <dynamic>[])
                .whereType<Map<String, dynamic>>()
                .toList(growable: false);
        final Map<String, dynamic>? playerSprite =
            _resolveLevel1PlayerSprite(level);
        for (int spriteIndex = 0;
            spriteIndex < levelSprites.length;
            spriteIndex++) {
          final Map<String, dynamic> sprite = levelSprites[spriteIndex];
          if (playerSprite != null && identical(sprite, playerSprite)) {
            continue;
          }
          if (renderState!.collectedGemSpriteIndices.contains(spriteIndex)) {
            continue;
          }
          GamesToolRuntimeRenderer.drawAnimatedSprite(
            canvas: canvas,
            painterSize: viewportSize,
            gameData: appData.gameData,
            gamesTool: appData.gamesTool,
            imagesCache: appData.imagesCache,
            sprite: sprite,
            camera: effectiveCamera,
            elapsedSeconds: renderState!.animationTimeSeconds,
            depthSensitivity: depthSensitivity,
          );
        }

        if (playerSprite != null) {
          final String playerAnimationName =
              _resolvePlayerAnimationName(renderState!);
          GamesToolRuntimeRenderer.drawAnimatedSprite(
            canvas: canvas,
            painterSize: viewportSize,
            gameData: appData.gameData,
            gamesTool: appData.gamesTool,
            imagesCache: appData.imagesCache,
            sprite: playerSprite,
            camera: effectiveCamera,
            animationName: playerAnimationName,
            elapsedSeconds: renderState!.animationTimeSeconds,
            worldX: renderState!.playerX,
            worldY: renderState!.playerY,
            drawWidthWorld: renderState!.playerWidth,
            drawHeightWorld: renderState!.playerHeight,
            flipX: !renderState!.facingRight,
            depthSensitivity: depthSensitivity,
          );
        }

        _drawBackToMenuHud(canvas, hudRect);
        _drawText(
          canvas,
          'LEVEL 1: PLATFORMER  |  MOVE: A/D OR ARROWS  |  JUMP: SPACE/W/UP',
          Offset(hudRect.left + 20, hudRect.bottom - 10),
        );
        _drawTopRightText(
          canvas,
          hudRect,
          'Gems: ${renderState!.gemsCount}',
          5,
        );
        if (renderState!.isGameOver) {
          _drawGameOverOverlay(canvas, viewportSize);
        }
      },
    );
  }

  String _resolvePlayerAnimationName(Level1RenderState state) {
    const double verticalThreshold = 5.0;
    const double moveThreshold = 2.0;
    if (!state.onGround) {
      if (state.velocityY < -verticalThreshold) {
        return _level1AnimFoxyJumpUp;
      }
      return _level1AnimFoxyJumpFall;
    }
    if (state.velocityX.abs() > moveThreshold) {
      return _level1AnimFoxyWalk;
    }
    return _level1AnimFoxyIdle;
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
        hudRect.left + _level1BackHudX,
        hudRect.top + _level1BackHudY,
        _level1BackIconWidth,
        _level1BackIconHeight,
      );
      canvas.drawImageRect(iconImage, srcRect, dstRect, Paint());
    }
    _drawText(
      canvas,
      _level1BackLabel,
      Offset(hudRect.left + _level1BackTextX, hudRect.top + _level1BackHudY),
    );
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

  void _drawGameOverOverlay(Canvas canvas, Size viewportSize) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, viewportSize.width, viewportSize.height),
      Paint()..color = const Color(0xB3000000),
    );
    final TextPainter titlePainter = TextPainter(
      text: const TextSpan(
        text: 'GAME OVER',
        style: TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    titlePainter.paint(
      canvas,
      Offset(
        (viewportSize.width - titlePainter.width) / 2,
        (viewportSize.height - titlePainter.height) / 2 - 12,
      ),
    );

    final TextPainter hintPainter = TextPainter(
      text: const TextSpan(
        text: 'Press any key to return to menu',
        style: TextStyle(
          color: Color(0xFFE0F2FF),
          fontSize: 8.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    hintPainter.paint(
      canvas,
      Offset(
        (viewportSize.width - hintPainter.width) / 2,
        (viewportSize.height - hintPainter.height) / 2 + 16,
      ),
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
    )..layout(maxWidth: 900);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant Level1Painter oldDelegate) {
    return oldDelegate.renderState?.tickCounter != renderState?.tickCounter ||
        oldDelegate.renderState?.gemsCount != renderState?.gemsCount ||
        oldDelegate.renderState?.isGameOver != renderState?.isGameOver ||
        oldDelegate.backIconImage != backIconImage ||
        oldDelegate.level != level;
  }
}
