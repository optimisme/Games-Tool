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
part 'hud.dart';
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
const HudBackButtonLayout _level0BackHudLayout = HudBackButtonLayout(
  hudX: 20,
  hudY: 5,
  iconWidth: 8,
  iconHeight: 8,
  iconGap: 3,
);

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
