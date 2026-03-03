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
const String _level1PlayerTransformId = 'level1/player';
const String _level1CameraTransformId = 'level1/camera';
const int _level1InitialLifePercent = 100;
const int _level1DragonDamagePercent = 25;
const double _level1EndStateInputDelaySeconds = 1.0;
const String _level1PathTargetTypeLayer = 'layer';
const String _level1PathTargetTypeZone = 'zone';
const String _level1PathTargetTypeSprite = 'sprite';
const String _level1PathBehaviorRestart = 'restart';
const String _level1PathBehaviorPingPong = 'ping_pong';
const String _level1PathBehaviorOnce = 'once';
const int _level1PathDefaultDurationMs = 2000;
const HudBackButtonLayout _level1BackHudLayout = HudBackButtonLayout(
  hudX: 20 * kHudSpacingScaleX,
  hudY: 5 * kHudSpacingScaleY,
  iconWidth: 8 * kHudScale,
  iconHeight: 8 * kHudScale,
  iconGap: 3 * kHudSpacingScaleX,
);

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
  Map<String, dynamic>? _runtimeGameData;
  Map<String, dynamic>? _level;
  int? _playerSpriteIndex;
  Level1UpdateState? _updateState;
  // Render interpolation alpha for the current vsync frame: [0, 1].
  double _renderAlpha = 1.0;
  bool _isLeavingLevel = false;
  double _cameraFollowOffsetX = 0;
  double _cameraFollowOffsetY = 0;
  final List<_Level1PathBindingRuntime> _pathBindings =
      <_Level1PathBindingRuntime>[];

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
            );
            final List<LevelSpriteRenderCommand> spriteCommands =
                _buildSpriteRenderCommands(
              appData: appData,
              renderState: renderState,
            );
            final List<HudRenderCommand> hudCommands = _buildHudRenderCommands(
              renderState: renderState,
              hudRectWidth: resolveScreenHudRect(canvasSize: canvasSize).width,
            );
            final List<OverlayRenderCommand> overlayCommands =
                _buildOverlayRenderCommands(
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
                  handleBackHudTap(
                    screenPosition: details.localPosition,
                    canvasSize: canvasSize,
                    commands: hudCommands,
                    onBackTap: _goBackToMenu,
                  );
                },
                child: CustomPaint(
                  painter: LevelPainter<Level1RenderState>(
                    appData: appData,
                    gameData: _runtimeGameData ?? appData.gameData,
                    level: _level,
                    renderState: renderState,
                    layerCommands: layerCommands,
                    spriteCommands: spriteCommands,
                    hudCommands: hudCommands,
                    overlayCommands: overlayCommands,
                    imageCommands: imageCommands,
                    resolveRuntimeCamera: (Level1RenderState state) {
                      return RuntimeCamera2D(
                        x: state.cameraX,
                        y: state.cameraY,
                        focal: _camera.focal,
                      );
                    },
                    renderRevision: renderState?.renderRevision,
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
        appData.gamesTool.findSpriteByName(level, _level1PlayerSpriteName);
    final Set<int> dragonSpriteIndices = appData.gamesTool
        .findSpriteIndicesByTypeOrName(level, _level1DragonSpriteName)
        .toSet();
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
            dragonSpriteIndices.contains(spriteIndex);
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
  }) {
    final Map<String, dynamic>? level = _level;
    if (level == null) {
      return const <LayerRenderCommand>[];
    }
    final List<Map<String, dynamic>> visibleLayers = appData.gamesTool
        .listLevelLayers(level, visibleOnly: true, painterOrder: true);
    return visibleLayers
        .map(
          (Map<String, dynamic> layer) => LayerRenderCommand(
            layer: layer,
            depth: appData.gamesTool.layerDepth(layer),
          ),
        )
        .toList(growable: false);
  }

  List<HudRenderCommand> _buildHudRenderCommands({
    required Level1RenderState? renderState,
    required double hudRectWidth,
  }) {
    final List<HudRenderCommand> commands = <HudRenderCommand>[
      HudRenderCommand.text(
        text: _level1BackLabel,
        offsetInHud: Offset(
          _level1BackHudLayout.textX,
          _level1BackHudLayout.hudY,
        ),
        interactionId: kHudInteractionBack,
        interactionBoundsInHud: resolveBackLabelRectInHudLocal(
          label: _level1BackLabel,
          layout: _level1BackHudLayout,
          textStyle: kHudTextStyle,
        ),
      ),
    ];
    if (renderState == null) {
      return commands;
    }
    final double hudRowTop = kHudRowTopSecondary;
    final String lifeText = 'Life: ${renderState.lifePercent}%';
    final TextPainter lifePainter = buildTextPainter(lifeText, kHudTextStyle);
    final double lifeLeftInHud = _level1BackHudLayout.hudX;
    final double lifeBarLeftInHud =
        lifeLeftInHud + lifePainter.width + hudSpacingX(10);
    final double lifeBarTopInHud =
        hudRowTop + (lifePainter.height - hudUnits(6)) / 2;

    commands.addAll(<HudRenderCommand>[
      HudRenderCommand.bottomLeftText(
        text:
            'LEVEL 1: PLATFORMER  |  MOVE: A/D OR ARROWS  |  JUMP: SPACE/W/UP',
        leftInHud: kHudFooterLeft,
        bottomInHud: kHudFooterBottom,
        maxWidth: resolveHudFooterMaxWidth(hudRectWidth),
      ),
      HudRenderCommand.topRightText(
        text: 'Gems: ${renderState.gemsCount}',
        top: kHudRowTopPrimary,
      ),
      HudRenderCommand.text(
        text: lifeText,
        offsetInHud: Offset(lifeLeftInHud, hudRowTop),
      ),
      HudRenderCommand.progressBar(
        leftInHud: lifeBarLeftInHud,
        topInHud: lifeBarTopInHud,
        barWidth: hudUnits(62),
        barHeight: hudUnits(6),
        progress: renderState.lifePercent / 100.0,
      ),
      HudRenderCommand.topRightText(
        text: 'FPS: ${renderState.fps.toStringAsFixed(1)}',
        top: kHudRowTopSecondary,
      ),
    ]);
    return commands;
  }

  List<OverlayRenderCommand> _buildOverlayRenderCommands({
    required Level1RenderState? renderState,
  }) {
    if (renderState == null) {
      return const <OverlayRenderCommand>[];
    }
    if (renderState.isGameOver) {
      return <OverlayRenderCommand>[
        OverlayRenderCommand.centeredEndOverlay(
          title: 'GAME OVER',
          showHint: renderState.canExitEndState,
          hintText: 'Press any key to return to menu',
        ),
      ];
    }
    if (renderState.isWin) {
      return <OverlayRenderCommand>[
        OverlayRenderCommand.centeredEndOverlay(
          title: 'YOU WIN',
          showHint: renderState.canExitEndState,
          hintText: 'Press any key to return to menu',
        ),
      ];
    }
    return const <OverlayRenderCommand>[];
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
}
