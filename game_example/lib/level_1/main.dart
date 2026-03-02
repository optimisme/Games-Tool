import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_data.dart';
import '../camera.dart';
import '../menu/main.dart';
import '../utils_gamestool/utils_gamestool.dart';

part 'drawing.dart';
part 'hud.dart';
part 'initialize.dart';
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
const int _level1InitialLifePercent = 100;
const int _level1DragonDamagePercent = 25;
const double _level1EndStateInputDelaySeconds = 2.0;
const double _level1MovingPlatformLoopSeconds = 5;
const double _level1MovingPlatformFloorYOffset = 5;
const List<Offset> _level1MovingPlatformPath = <Offset>[
  Offset(590, 440),
  Offset(745, 470),
  Offset(740, 340),
];
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

int? _resolveLevel1LayerIndexByName(
  Map<String, dynamic>? level,
  String layerName,
) {
  if (level == null) {
    return null;
  }
  final List<Map<String, dynamic>> layers =
      ((level['layers'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
  final String target = layerName.trim().toLowerCase();
  for (int i = 0; i < layers.length; i++) {
    final String name = ((layers[i]['name'] as String?) ?? '').trim();
    if (name.toLowerCase() == target) {
      return i;
    }
  }
  return null;
}

int? _resolveLevel1ZoneIndexByGameplayData(
  Map<String, dynamic>? level,
  String gameplayData,
) {
  if (level == null) {
    return null;
  }
  final List<Map<String, dynamic>> zones =
      ((level['zones'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
  final String target = gameplayData.trim().toLowerCase();
  for (int i = 0; i < zones.length; i++) {
    final String zoneGameplayData =
        ((zones[i]['gameplayData'] as String?) ?? '').trim();
    if (zoneGameplayData.toLowerCase() == target) {
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
  double _cameraFollowOffsetX = 0;
  double _cameraFollowOffsetY = -80;
  int? _movingPlatformLayerIndex;
  int? _movingPlatformFloorZoneIndex;

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

  void _refreshLevel1([VoidCallback? update]) {
    if (!mounted) {
      return;
    }
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
