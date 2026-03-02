import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_data.dart';
import '../shared/camera.dart';
import '../shared/utils_level.dart';
import '../shared/utils_painter.dart';
import '../utils_gamestool/utils_gamestool.dart';

part 'drawing.dart';
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
const String _level0ArbreZoneName = 'Arbre';
const double _level0EndStateInputDelaySeconds = 1.0;
const HudBackButtonLayout _level0BackHudLayout = HudBackButtonLayout(
  hudX: 20,
  hudY: 5,
  iconWidth: 8,
  iconHeight: 8,
  iconGap: 3,
);

String _level0TileKey(int x, int y) => '$x:$y';

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
  int? _decoracionsLayerIndex;
  int? _pontAmagatLayerIndex;
  Level0UpdateState? _updateState;
  ui.Image? _backIconImage;
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

  void _refreshLevel0([VoidCallback? update]) {
    if (!mounted) {
      return;
    }
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

/// HUD helpers that map virtual viewport coordinates back to screen space.
extension _Level0Hud on _Level0State {
  Rect _backLabelScreenRect({
    required AppData appData,
    required Size canvasSize,
  }) {
    final RuntimeLevelViewport viewport =
        GamesToolRuntimeRenderer.levelViewport(
      gamesTool: appData.gamesTool,
      level: _level,
    );
    return resolveBackLabelScreenRect(
      viewport: viewport,
      canvasSize: canvasSize,
      label: _level0BackLabel,
      layout: _level0BackHudLayout,
      textStyle: kHudTextStyle,
    );
  }
}
