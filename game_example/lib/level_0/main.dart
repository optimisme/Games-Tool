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

const Set<String> _level0BlockedZoneTypes = <String>{
  'Mur',
  'Aigua',
};
const String _level0DecoracionsLayerName = 'Decoracions';
const String _level0PontAmagatLayerName = 'Pont Amagat';
const String _level0FuturPontGameplayData = 'Futur Pont';
const String _level0BackIconAssetPath = 'other/enrrere.png';
const String _level0BackLabel = 'Tornar';
const String _level0PlayerSpriteName = 'Heroi';
const String _level0ArbreZoneName = 'Arbre';
const String _level0PlayerTransformId = 'level0/player';
const String _level0CameraTransformId = 'level0/camera';
const double _level0EndStateInputDelaySeconds = 1.0;
const HudBackButtonLayout _level0BackHudLayout = HudBackButtonLayout(
  hudX: 20 * kHudSpacingScaleX,
  hudY: 5 * kHudSpacingScaleY,
  iconWidth: 8 * kHudScale,
  iconHeight: 8 * kHudScale,
  iconGap: 3 * kHudSpacingScaleX,
);

String _level0TileKey(int x, int y) => '$x:$y';

bool _isLevel0PlayerSprite(Map<String, dynamic> sprite) {
  final String target = _level0PlayerSpriteName.toLowerCase();
  final String spriteName = ((sprite['name'] as String?) ?? '').trim();
  final String spriteType = ((sprite['type'] as String?) ?? '').trim();
  return spriteName.toLowerCase() == target ||
      spriteType.toLowerCase() == target;
}

Map<String, dynamic>? _resolveLevel0PlayerSprite(Map<String, dynamic>? level) {
  if (level == null) {
    return null;
  }
  final List<Map<String, dynamic>> sprites =
      ((level['sprites'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
  for (final Map<String, dynamic> sprite in sprites) {
    if (_isLevel0PlayerSprite(sprite)) {
      return sprite;
    }
  }
  if (sprites.isEmpty) {
    return null;
  }
  return sprites.first;
}

LevelSpriteRenderSelection _resolveLevel0PlayerRenderSelection(
  Level0RenderState state,
) {
  final String prefix = state.isMoving ? 'Heroi Camina ' : 'Heroi Aturat ';
  switch (state.direction) {
    case 'upLeft':
      return LevelSpriteRenderSelection(
        animationName: '${prefix}Amunt-Dreta',
        flipX: true,
        fallbackFps: 8,
      );
    case 'up':
      return LevelSpriteRenderSelection(
        animationName: '${prefix}Amunt',
        fallbackFps: 8,
      );
    case 'upRight':
      return LevelSpriteRenderSelection(
        animationName: '${prefix}Amunt-Dreta',
        fallbackFps: 8,
      );
    case 'left':
      return LevelSpriteRenderSelection(
        animationName: '${prefix}Dreta',
        flipX: true,
        fallbackFps: 8,
      );
    case 'right':
      return LevelSpriteRenderSelection(
        animationName: '${prefix}Dreta',
        fallbackFps: 8,
      );
    case 'downLeft':
      return LevelSpriteRenderSelection(
        animationName: '${prefix}Avall-Dreta',
        flipX: true,
        fallbackFps: 8,
      );
    case 'downRight':
      return LevelSpriteRenderSelection(
        animationName: '${prefix}Avall-Dreta',
        fallbackFps: 8,
      );
    case 'down':
    default:
      return LevelSpriteRenderSelection(
        animationName: '${prefix}Avall',
        fallbackFps: 8,
      );
  }
}

Set<String> _collectLevel0ArbreTileKeys({
  required GamesToolApi gamesTool,
  required Map<String, dynamic>? level,
  required int? decoracionsLayerIndex,
}) {
  if (level == null || decoracionsLayerIndex == null) {
    return <String>{};
  }

  final List<Map<String, dynamic>> layers =
      ((level['layers'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
  if (decoracionsLayerIndex < 0 || decoracionsLayerIndex >= layers.length) {
    return <String>{};
  }
  final Map<String, dynamic> decoracionsLayer = layers[decoracionsLayerIndex];
  final List<List<dynamic>> tileRows = gamesTool.layerTileMapRows(
    decoracionsLayer,
  );
  if (tileRows.isEmpty) {
    return <String>{};
  }

  final double tileWidth = gamesTool.layerTilesWidth(decoracionsLayer);
  final double tileHeight = gamesTool.layerTilesHeight(decoracionsLayer);
  if (tileWidth <= 0 || tileHeight <= 0) {
    return <String>{};
  }
  final double layerX = gamesTool.layerX(decoracionsLayer);
  final double layerY = gamesTool.layerY(decoracionsLayer);

  final List<Map<String, dynamic>> zones =
      ((level['zones'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
  final String arbreTarget = _level0ArbreZoneName.toLowerCase();
  final List<Rect> arbreZoneRects = <Rect>[];
  for (final Map<String, dynamic> zone in zones) {
    final String zoneType = ((zone['type'] as String?) ?? '').trim();
    final String zoneName = ((zone['name'] as String?) ?? '').trim();
    if (zoneType.toLowerCase() != arbreTarget &&
        zoneName.toLowerCase() != arbreTarget) {
      continue;
    }
    final double zoneX = (zone['x'] as num?)?.toDouble() ?? 0;
    final double zoneY = (zone['y'] as num?)?.toDouble() ?? 0;
    final double zoneWidth = (zone['width'] as num?)?.toDouble() ?? 0;
    final double zoneHeight = (zone['height'] as num?)?.toDouble() ?? 0;
    if (zoneWidth <= 0 || zoneHeight <= 0) {
      continue;
    }
    arbreZoneRects.add(Rect.fromLTWH(zoneX, zoneY, zoneWidth, zoneHeight));
  }
  if (arbreZoneRects.isEmpty) {
    return <String>{};
  }

  final Set<String> collectibleKeys = <String>{};
  for (int tileY = 0; tileY < tileRows.length; tileY++) {
    final List<dynamic> row = tileRows[tileY];
    for (int tileX = 0; tileX < row.length; tileX++) {
      final int tileId = (row[tileX] as num?)?.toInt() ?? -1;
      if (tileId < 0) {
        continue;
      }
      final Rect tileRect = Rect.fromLTWH(
        layerX + tileX * tileWidth,
        layerY + tileY * tileHeight,
        tileWidth,
        tileHeight,
      );
      final bool insideAnyArbreZone = arbreZoneRects.any(tileRect.overlaps);
      if (!insideAnyArbreZone) {
        continue;
      }
      collectibleKeys.add(_level0TileKey(tileX, tileY));
    }
  }
  return collectibleKeys;
}

/// Top-down exploration level with tile interaction and zone-driven triggers.
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
  final GameDataRuntimeApi _runtimeApi = GameDataRuntimeApi();

  Ticker? _ticker;
  Duration? _lastTickTimestamp;
  bool _initialized = false;
  Map<String, dynamic>? _runtimeGameData;
  Map<String, dynamic>? _level;
  int? _heroSpriteIndex;
  double _cameraFollowOffsetX = 0;
  double _cameraFollowOffsetY = 0;
  int? _decoracionsLayerIndex;
  int? _pontAmagatLayerIndex;
  Level0UpdateState? _updateState;
  // Render interpolation alpha for the current vsync frame: [0, 1].
  double _renderAlpha = 1.0;
  bool _isLeavingLevel = false;

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

  @override
  void dispose() {
    _ticker?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _refreshLevel0([VoidCallback? update, double alpha = 1.0]) {
    if (!mounted) {
      return;
    }
    _renderAlpha = alpha;
    setState(update ?? () {});
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
              canvasSize: canvasSize,
            );
            final Level0RenderState? renderState = state == null
                ? null
                : Level0RenderState.from(
                    state,
                    runtimeApi: _runtimeApi,
                    alpha: _renderAlpha,
                  );
            final List<LayerRenderCommand> layerCommands =
                _buildLayerRenderCommands(appData: appData);
            final List<RenderImageCommand> imageCommands =
                _buildImageRenderCommands(canvasSize: canvasSize);
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
                  painter: LevelPainter<Level0RenderState>(
                    appData: appData,
                    gameData: _runtimeGameData ?? appData.gameData,
                    level: _level,
                    renderState: renderState,
                    layerCommands: layerCommands,
                    spriteCommands: spriteCommands,
                    hudCommands: hudCommands,
                    overlayCommands: overlayCommands,
                    imageCommands: imageCommands,
                    resolveRuntimeCamera: (Level0RenderState state) {
                      return RuntimeCamera2D(
                        x: state.cameraX,
                        y: state.cameraY,
                        focal: _camera.focal,
                      );
                    },
                    loadingLabel: 'Loading level 0...',
                    backLabel: _level0BackLabel,
                    backLayout: _level0BackHudLayout,
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
extension _Level0Hud on _Level0State {
  List<LevelSpriteRenderCommand> _buildSpriteRenderCommands({
    required AppData appData,
    required Level0RenderState? renderState,
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
        _resolveLevel0PlayerSprite(level);
    final LevelSpriteRenderSelection playerSelection =
        _resolveLevel0PlayerRenderSelection(renderState);

    return buildLevelSpriteRenderCommands(
      sprites: sprites,
      playerSprite: playerSprite,
      buildPlayerCommand: (int _, Map<String, dynamic> sprite) {
        return LevelSpriteRenderCommand(
          sprite: sprite,
          depth: appData.gamesTool.spriteDepth(sprite),
          animationName: playerSelection.animationName,
          elapsedSeconds: renderState.animationTimeSeconds +
              playerSelection.elapsedSecondsOffset,
          worldX: renderState.playerX,
          worldY: renderState.playerY,
          flipX: playerSelection.flipX,
          flipY: playerSelection.flipY,
          drawWidthWorld: renderState.playerWidth,
          drawHeightWorld: renderState.playerHeight,
          fallbackFps:
              playerSelection.fallbackFps ?? GamesToolApi.defaultAnimationFps,
        );
      },
      buildSpriteCommand: (int _, Map<String, dynamic> sprite) {
        return LevelSpriteRenderCommand(
          sprite: sprite,
          depth: appData.gamesTool.spriteDepth(sprite),
          elapsedSeconds: renderState.animationTimeSeconds,
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
    return visibleLayers.map((Map<String, dynamic> layer) {
      return LayerRenderCommand(
        layer: layer,
        depth: appData.gamesTool.layerDepth(layer),
      );
    }).toList(growable: false);
  }

  List<HudRenderCommand> _buildHudRenderCommands({
    required Level0RenderState? renderState,
    required double hudRectWidth,
  }) {
    if (renderState == null) {
      return const <HudRenderCommand>[];
    }
    final List<HudRenderCommand> commands = <HudRenderCommand>[
      HudRenderCommand.bottomLeftText(
        text: 'LEVEL 0: TOP-DOWN  |  MOVE: ARROWS/WASD',
        leftInHud: kHudFooterLeft,
        bottomInHud: kHudFooterBottom,
        maxWidth: resolveHudFooterMaxWidth(hudRectWidth),
      ),
      HudRenderCommand.topRightText(
        text:
            'Arbres: ${renderState.arbresRemovedCount}/${renderState.totalArbres}',
        top: kHudRowTopPrimary,
      ),
      HudRenderCommand.topRightText(
        text: 'FPS: ${renderState.fps.toStringAsFixed(1)}',
        top: kHudRowTopSecondary,
      ),
    ];
    if (renderState.isOnPont) {
      commands.insert(
        0,
        HudRenderCommand.text(
          text: 'Caminant pel pont',
          offsetInHud: Offset(hudSpacingX(20), kHudRowTopSecondary),
        ),
      );
    }
    return commands;
  }

  List<OverlayRenderCommand> _buildOverlayRenderCommands({
    required Level0RenderState? renderState,
  }) {
    if (renderState == null || !renderState.isWin) {
      return const <OverlayRenderCommand>[];
    }
    return <OverlayRenderCommand>[
      OverlayRenderCommand.centeredEndOverlay(
        title: 'TU GUANYES',
        showHint: renderState.canExitEndState,
        hintText: 'Prem qualsevol tecla',
        hintStyle: const TextStyle(
          color: Color(0xFFE8F3FF),
          fontSize: 10 * kHudScale,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.8 * kHudScale,
        ),
        titleCenterYOffset: -20 * kHudSpacingScaleY,
        hintCenterYOffset: 6 * kHudSpacingScaleY,
      ),
    ];
  }

  List<RenderImageCommand> _buildImageRenderCommands({
    required Size canvasSize,
  }) {
    final Rect hudRect = resolveScreenHudRect(
      canvasSize: canvasSize,
    );
    final Rect iconRect = Rect.fromLTWH(
      hudRect.left + _level0BackHudLayout.hudX,
      hudRect.top + _level0BackHudLayout.hudY,
      _level0BackHudLayout.iconWidth,
      _level0BackHudLayout.iconHeight,
    );
    return <RenderImageCommand>[
      RenderImageCommand.hud(
        assetKey: _level0BackIconAssetPath,
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
      label: _level0BackLabel,
      layout: _level0BackHudLayout,
      textStyle: kHudTextStyle,
    );
  }
}
