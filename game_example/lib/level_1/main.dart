import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_data.dart';
import '../shared/camera.dart';
import '../shared/level_rendering.dart';
import '../shared/utils_level.dart';
import '../shared/utils_painter.dart';
import '../utils_gamestool/utils_gamestool.dart';

part 'drawing.dart';
part 'lifecycle.dart';
part 'interaction.dart';
part 'models.dart';
part 'update.dart';

const String _level1BackIconAssetPath = 'other/enrrere.png';
const String _level1BackLabel = 'Tornar';
const String _level1PlayerSpriteName = 'Foxy';
const String _level1FloorZoneName = 'Floor';
const String _level1DeathZoneName = 'Foxy Death';
const String _level1GemSpriteName = 'Gem';
const String _level1DragonSpriteName = 'Dragon';
const String _level1AnimFoxyIdle = 'Foxy Idle';
const String _level1AnimFoxyWalk = 'Foxy Walk';
const String _level1AnimFoxyJumpUp = 'Foxy Jump Up';
const String _level1AnimFoxyJumpFall = 'Foxy Jump Fall';
const String _level1AnimDragonDeath = 'Dragon Death';
const String _level1MovingPlatformLayerName = 'Platform';
const String _level1MovingPlatformFloorGameplayData = 'Platform Floor';
const String _level1PlayerTransformId = 'level1/player';
const String _level1CameraTransformId = 'level1/camera';
const String _level1MovingPlatformTransformId = 'level1/platform';
const int _level1InitialLifePercent = 100;
const int _level1DragonDamagePercent = 25;
const double _level1EndStateInputDelaySeconds = 1.0;
const double _level1MovingPlatformLoopSeconds = 5;
const double _level1MovingPlatformFloorYOffset = 5;
const List<Offset> _level1MovingPlatformPath = <Offset>[
  Offset(590, 440),
  Offset(745, 470),
  Offset(740, 340),
];
const HudBackButtonLayout _level1BackHudLayout = HudBackButtonLayout(
  hudX: 20 * kHudSpacingScaleX,
  hudY: 5 * kHudSpacingScaleY,
  iconWidth: 8 * kHudScale,
  iconHeight: 8 * kHudScale,
  iconGap: 3 * kHudSpacingScaleX,
);

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

bool _isLevel1DragonSprite(Map<String, dynamic> sprite) {
  final String target = _level1DragonSpriteName.toLowerCase();
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

LevelSpriteRenderSelection _resolveLevel1PlayerRenderSelection(
  Level1RenderState state,
) {
  const double verticalThreshold = 5.0;
  const double moveThreshold = 2.0;
  String animationName = _level1AnimFoxyIdle;
  if (!state.onGround) {
    if (state.velocityY < -verticalThreshold) {
      animationName = _level1AnimFoxyJumpUp;
    } else {
      animationName = _level1AnimFoxyJumpFall;
    }
    return LevelSpriteRenderSelection(
      animationName: animationName,
      flipX: !state.facingRight,
    );
  }
  if (state.velocityX.abs() > moveThreshold) {
    animationName = _level1AnimFoxyWalk;
  }
  return LevelSpriteRenderSelection(
    animationName: animationName,
    flipX: !state.facingRight,
  );
}

bool _shouldSkipLevel1Sprite({
  required int spriteIndex,
  required bool isPlayer,
  required Level1RenderState state,
}) {
  if (isPlayer) {
    return false;
  }
  if (state.collectedGemSpriteIndices.contains(spriteIndex)) {
    return true;
  }
  if (state.removedDragonSpriteIndices.contains(spriteIndex)) {
    return true;
  }
  return false;
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

/// Platformer level with moving platforms, collectibles, and enemy interactions.
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
  // Render interpolation alpha for the current vsync frame: [0, 1].
  double _renderAlpha = 1.0;
  bool _isLeavingLevel = false;
  double _cameraFollowOffsetX = 0;
  double _cameraFollowOffsetY = 0;
  int? _movingPlatformLayerIndex;
  int? _movingPlatformFloorZoneIndex;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Invariant: initialize once, and only after shared assets are ready.
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

  void _refreshLevel1([VoidCallback? update, double alpha = 1.0]) {
    if (!mounted) {
      return;
    }
    _renderAlpha = alpha;
    setState(update ?? () {});
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
              canvasSize: canvasSize,
            );
            final Level1RenderState? renderState = state == null
                ? null
                : Level1RenderState.from(
                    state,
                    runtimeApi: _runtimeApi,
                    alpha: _renderAlpha,
                  );
            final List<LayerRenderCommand> layerCommands =
                _buildLayerRenderCommands(
              appData: appData,
              renderState: renderState,
            );
            final List<LevelSpriteRenderCommand> spriteCommands =
                _buildSpriteRenderCommands(
              appData: appData,
              renderState: renderState,
            );
            final List<RenderImageCommand> imageCommands =
                _buildImageRenderCommands(canvasSize: canvasSize);

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
                    gameData: appData.gameData,
                    level: _level,
                    camera: _camera,
                    renderState: renderState,
                    layerCommands: layerCommands,
                    spriteCommands: spriteCommands,
                    imageCommands: imageCommands,
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

/// HUD helpers for screen-space interaction geometry.
extension _Level1Hud on _Level1State {
  List<LevelSpriteRenderCommand> _buildSpriteRenderCommands({
    required AppData appData,
    required Level1RenderState? renderState,
  }) {
    final Map<String, dynamic>? level = _level;
    if (level == null || renderState == null) {
      return const <LevelSpriteRenderCommand>[];
    }
    final List<Map<String, dynamic>> sprites =
        ((level['sprites'] as List<dynamic>?) ?? const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);
    final Map<String, dynamic>? playerSprite =
        _resolveLevel1PlayerSprite(level);
    final LevelSpriteRenderSelection playerSelection =
        _resolveLevel1PlayerRenderSelection(renderState);

    return buildLevelSpriteRenderCommands(
      sprites: sprites,
      playerSprite: playerSprite,
      shouldSkip: (int spriteIndex, Map<String, dynamic> _, bool isPlayer) {
        return _shouldSkipLevel1Sprite(
          spriteIndex: spriteIndex,
          isPlayer: isPlayer,
          state: renderState,
        );
      },
      buildPlayerCommand: (int _, Map<String, dynamic> sprite) {
        return LevelSpriteRenderCommand(
          sprite: sprite,
          depth: appData.gamesTool.spriteDepth(sprite),
          animationName: playerSelection.animationName,
          elapsedSeconds: renderState.animationTimeSeconds +
              playerSelection.elapsedSecondsOffset,
          worldX: renderState.playerX,
          worldY: renderState.playerY,
          drawWidthWorld: renderState.playerWidth,
          drawHeightWorld: renderState.playerHeight,
          flipX: playerSelection.flipX,
          flipY: playerSelection.flipY,
          fallbackFps:
              playerSelection.fallbackFps ?? GamesToolApi.defaultAnimationFps,
        );
      },
      buildSpriteCommand: (int spriteIndex, Map<String, dynamic> sprite) {
        final bool dragonDying =
            renderState.dragonDeathStartSeconds.containsKey(spriteIndex);
        final double? dragonDeathStart =
            renderState.dragonDeathStartSeconds[spriteIndex];
        final bool drawDragonDeath = dragonDying &&
            dragonDeathStart != null &&
            _isLevel1DragonSprite(sprite);
        return LevelSpriteRenderCommand(
          sprite: sprite,
          depth: appData.gamesTool.spriteDepth(sprite),
          animationName: drawDragonDeath ? _level1AnimDragonDeath : null,
          elapsedSeconds: drawDragonDeath
              ? (renderState.animationTimeSeconds - dragonDeathStart)
                  .clamp(0.0, double.infinity)
              : renderState.animationTimeSeconds,
        );
      },
    );
  }

  List<LayerRenderCommand> _buildLayerRenderCommands({
    required AppData appData,
    required Level1RenderState? renderState,
  }) {
    final Map<String, dynamic>? level = _level;
    if (level == null) {
      return const <LayerRenderCommand>[];
    }
    final List<Map<String, dynamic>> visibleLayers = appData.gamesTool
        .listLevelLayers(level, visibleOnly: true, painterOrder: true);
    final List<Map<String, dynamic>> allLayers = appData.gamesTool
        .listLevelLayers(level, visibleOnly: false, painterOrder: false);
    final int? movingPlatformLayerIndex = _movingPlatformLayerIndex;
    final Map<String, dynamic>? movingPlatformLayer =
        movingPlatformLayerIndex != null &&
                movingPlatformLayerIndex >= 0 &&
                movingPlatformLayerIndex < allLayers.length
            ? allLayers[movingPlatformLayerIndex]
            : null;

    return visibleLayers.map((Map<String, dynamic> layer) {
      final bool isMovingPlatformLayer =
          movingPlatformLayer != null && identical(layer, movingPlatformLayer);
      return LayerRenderCommand(
        layer: layer,
        depth: appData.gamesTool.layerDepth(layer),
        worldOffset: isMovingPlatformLayer && renderState != null
            ? Offset(renderState.platformX, renderState.platformY)
            : null,
      );
    }).toList(growable: false);
  }

  List<RenderImageCommand> _buildImageRenderCommands({
    required Size canvasSize,
  }) {
    final Rect hudRect = resolveScreenHudRect(
      canvasSize: canvasSize,
    );
    final Rect iconRect = Rect.fromLTWH(
      hudRect.left + _level1BackHudLayout.hudX,
      hudRect.top + _level1BackHudLayout.hudY,
      _level1BackHudLayout.iconWidth,
      _level1BackHudLayout.iconHeight,
    );
    return <RenderImageCommand>[
      RenderImageCommand.hud(
        assetKey: _level1BackIconAssetPath,
        dstRectScreen: iconRect,
      ),
    ];
  }

  Rect _backLabelScreenRect({
    required Size canvasSize,
  }) {
    final Rect hudRect = resolveScreenHudRect(
      canvasSize: canvasSize,
    );
    return resolveBackLabelRectInHud(
      hudRect: hudRect,
      label: _level1BackLabel,
      layout: _level1BackHudLayout,
      textStyle: kHudTextStyle,
    );
  }
}
