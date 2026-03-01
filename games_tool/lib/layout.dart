import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/services.dart'
    show
        HardwareKeyboard,
        KeyDownEvent,
        KeyEvent,
        KeyRepeatEvent,
        KeyUpEvent,
        LogicalKeyboardKey;
import 'package:flutter_cupertino_desktop_kit/flutter_cupertino_desktop_kit.dart';
import 'package:provider/provider.dart';
import 'app_data.dart';
import 'canvas_painter.dart';
import 'game_animation.dart';
import 'game_animation_hit_box.dart';
import 'game_layer.dart';
import 'game_level.dart';
import 'game_sprite.dart';
import 'game_zone.dart';
import 'layout_animation_rigs.dart';
import 'layout_animations.dart';
import 'layout_sprites.dart';
import 'layout_layers.dart';
import 'layout_levels.dart';
import 'layout_media.dart';
import 'layout_projects.dart';
import 'layout_projects_main.dart';
import 'layout_tilemaps.dart';
import 'layout_zones.dart';
import 'layout_viewport.dart';
import 'layout_utils.dart';

part 'layout_painters.dart';
part 'layout_part_navigation.dart';
part 'layout_part_animation_rig_helpers.dart';
part 'layout_part_layer_selection.dart';
part 'layout_part_zone_selection.dart';
part 'layout_part_sprite_selection.dart';
part 'layout_part_viewport_tools.dart';
part 'layout_part_animation_rig_ui.dart';
part 'layout_part_gestures.dart';

class Layout extends StatefulWidget {
  const Layout({super.key, required this.title});

  final String title;

  @override
  State<Layout> createState() => _LayoutState();
}

enum _LayersCanvasTool { arrow, hand }

class _LayoutState extends State<Layout> {
  static const double _animationRigFrameStripReservedHeight = 74.0;

  // Clau del layout escollit
  final GlobalKey<LayoutSpritesState> layoutSpritesKey =
      GlobalKey<LayoutSpritesState>();
  final GlobalKey<LayoutZonesState> layoutZonesKey =
      GlobalKey<LayoutZonesState>();
  final GlobalKey<LayoutViewportState> layoutViewportKey =
      GlobalKey<LayoutViewportState>();
  final GlobalKey<LayoutAnimationRigsState> layoutAnimationRigsKey =
      GlobalKey<LayoutAnimationRigsState>();
  final GlobalKey _animationRigFrameStripRowKey = GlobalKey();

  // ignore: unused_field
  Timer? _timer;
  ui.Image? _layerImage;
  bool _isDraggingLayer = false;
  bool _isDraggingViewport = false;
  bool _isResizingViewport = false;
  bool _isDraggingZone = false;
  bool _isResizingZone = false;
  bool _isDraggingSprite = false;
  bool _isSelectingAnimationFrames = false;
  bool _isPaintingTilemap = false;
  bool _consumeTilemapTapUp = false;
  bool _didModifyZoneDuringGesture = false;
  bool _didModifySpriteDuringGesture = false;
  bool _didModifyLayerDuringGesture = false;
  bool _didModifyAnimationDuringGesture = false;
  bool _didModifyAnimationRigDuringGesture = false;
  bool _didModifyTilemapDuringGesture = false;
  int? _animationDragStartFrame;
  bool _isDraggingAnimationRigAnchor = false;
  bool _isDraggingAnimationRigHitBox = false;
  bool _isResizingAnimationRigHitBox = false;
  bool _isSelectingAnimationRigFramesFromStrip = false;
  bool _animationRigFrameStripDragAdditive = false;
  int? _animationRigFrameStripDragAnchorFrame;
  List<int> _animationRigFrameStripDragBaseSelection = <int>[];
  Offset _animationRigHitBoxDragOffset = Offset.zero;
  int _drawCanvasRequestId = 0;
  bool _isPointerDown = false;
  bool _isHoveringSelectedTilemapLayer = false;
  bool _isDragGestureActive = false;
  bool _pendingLayersViewportCenter = false;
  int? _pendingLevelsViewportFitLevelIndex;
  int? _lastAutoFramedLevelIndex;
  bool _selectionModifierShiftPressed = false;
  bool _selectionModifierAltPressed = false;
  bool _selectionModifierControlPressed = false;
  bool _selectionModifierMetaPressed = false;
  final Set<int> _selectedLayerIndices = <int>{};
  final Map<int, Offset> _layerDragOffsetsByIndex = <int, Offset>{};
  int _layerSelectionLevelIndex = -1;
  bool _isMarqueeSelectingLayers = false;
  bool _marqueeSelectionAdditive = false;
  Offset? _layersMarqueeStartLocal;
  Offset? _layersMarqueeCurrentLocal;
  Set<int> _marqueeBaseLayerSelection = <int>{};
  final Set<int> _selectedZoneIndices = <int>{};
  final Map<int, Offset> _zoneDragOffsetsByIndex = <int, Offset>{};
  int _zoneSelectionLevelIndex = -1;
  bool _isMarqueeSelectingZones = false;
  bool _zoneMarqueeSelectionAdditive = false;
  Offset? _zonesMarqueeStartLocal;
  Offset? _zonesMarqueeCurrentLocal;
  Set<int> _marqueeBaseZoneSelection = <int>{};
  final Set<int> _selectedSpriteIndices = <int>{};
  final Map<int, Offset> _spriteDragOffsetsByIndex = <int, Offset>{};
  int _spriteSelectionLevelIndex = -1;
  bool _isMarqueeSelectingSprites = false;
  bool _spriteMarqueeSelectionAdditive = false;
  Offset? _spritesMarqueeStartLocal;
  Offset? _spritesMarqueeCurrentLocal;
  Set<int> _marqueeBaseSpriteSelection = <int>{};
  final FocusNode _focusNode = FocusNode();
  _LayersCanvasTool _layersCanvasTool = _LayersCanvasTool.hand;
  List<String> sections = [
    'projects',
    'media',
    'animations',
    'animation_rigs',
    'levels',
    'layers',
    'tilemap',
    'zones',
    'sprites',
    'viewport',
  ];

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
    _refreshSelectionModifierState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appData = Provider.of<AppData>(context, listen: false);
      appData.selectedSection = 'projects';
      _focusNode.requestFocus();
    });

    _startFrameTimer();
  }

  void _startFrameTimer() {
    _timer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      final appData = Provider.of<AppData>(context, listen: false);
      appData.frame++;
      if (appData.frame > 4096) {
        appData.frame = 0;
      }
      appData.update();
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
    try {
      final appData = Provider.of<AppData>(context, listen: false);
      unawaited(appData.flushPendingAutosave());
    } catch (_) {}
    _timer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  bool _handleGlobalKeyEvent(KeyEvent event) {
    _updateSelectionModifierStateFromEvent(event);
    return false;
  }

  void _updateSelectionModifierStateFromEvent(KeyEvent event) {
    final bool? pressed = switch (event) {
      KeyDownEvent() => true,
      KeyRepeatEvent() => true,
      KeyUpEvent() => false,
      _ => null,
    };
    if (pressed == null) {
      return;
    }
    final LogicalKeyboardKey key = event.logicalKey;
    if (_isShiftModifierKey(key)) {
      _selectionModifierShiftPressed = pressed;
    }
    if (_isAltModifierKey(key)) {
      _selectionModifierAltPressed = pressed;
    }
    if (_isControlModifierKey(key)) {
      _selectionModifierControlPressed = pressed;
    }
    if (_isMetaModifierKey(key)) {
      _selectionModifierMetaPressed = pressed;
    }
  }

  bool _isShiftModifierKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.shift ||
        key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight;
  }

  bool _isAltModifierKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.alt ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight;
  }

  bool _isControlModifierKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.control ||
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight;
  }

  bool _isMetaModifierKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.meta ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight ||
        key == LogicalKeyboardKey.superKey;
  }

  void _refreshSelectionModifierState() {
    final HardwareKeyboard keyboard = HardwareKeyboard.instance;
    final Set<LogicalKeyboardKey> pressed = keyboard.logicalKeysPressed;
    _selectionModifierShiftPressed = keyboard.isShiftPressed ||
        pressed.contains(LogicalKeyboardKey.shift) ||
        pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight);
    _selectionModifierAltPressed = keyboard.isAltPressed ||
        pressed.contains(LogicalKeyboardKey.alt) ||
        pressed.contains(LogicalKeyboardKey.altLeft) ||
        pressed.contains(LogicalKeyboardKey.altRight);
    _selectionModifierControlPressed = keyboard.isControlPressed ||
        pressed.contains(LogicalKeyboardKey.control) ||
        pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight);
    _selectionModifierMetaPressed = keyboard.isMetaPressed ||
        pressed.contains(LogicalKeyboardKey.meta) ||
        pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight) ||
        pressed.contains(LogicalKeyboardKey.superKey);
  }

  Future<void> _drawCanvasImage(AppData appData) async {
    final int requestId = ++_drawCanvasRequestId;
    ui.Image image;
    switch (appData.selectedSection) {
      case 'projects':
        image = await LayoutUtils.drawCanvasImageEmpty(appData);
      case 'levels':
        // Levels section renders in world space via CanvasPainter.
        await LayoutUtils.preloadLayerImages(appData);
        await LayoutUtils.preloadSpriteImages(appData);
        image = await LayoutUtils.drawCanvasImageEmpty(appData);
      case 'layers':
        // Layers section renders directly in world space via CanvasPainter.
        // Preload tileset and sprite images for the preview.
        await LayoutUtils.preloadLayerImages(appData);
        await LayoutUtils.preloadSpriteImages(appData);
        image = await LayoutUtils.drawCanvasImageEmpty(appData);
      case 'tilemap':
        // Tilemap section now renders in world space via CanvasPainter.
        await LayoutUtils.preloadLayerImages(appData);
        image = await LayoutUtils.drawCanvasImageEmpty(appData);
      case 'zones':
        // Zones section reuses the world viewport rendering from layers.
        await LayoutUtils.preloadLayerImages(appData);
        image = await LayoutUtils.drawCanvasImageEmpty(appData);
      case 'sprites':
        await LayoutUtils.preloadLayerImages(appData);
        await LayoutUtils.preloadSpriteImages(appData);
        image = await LayoutUtils.drawCanvasImageEmpty(appData);
      case 'viewport':
        // Viewport section renders in world space via CanvasPainter.
        await LayoutUtils.preloadLayerImages(appData);
        await LayoutUtils.preloadSpriteImages(appData);
        LayoutUtils.ensureViewportPreviewInitialized(appData);
        image = await LayoutUtils.drawCanvasImageEmpty(appData);
      case 'animations':
        image = await LayoutUtils.drawCanvasImageAnimations(appData);
      case 'animation_rigs':
        image = await LayoutUtils.drawCanvasImageAnimationRig(appData);
      case 'media':
        image = await LayoutUtils.drawCanvasImageMedia(appData);
      default:
        image = await LayoutUtils.drawCanvasImageEmpty(appData);
    }

    if (!mounted || requestId != _drawCanvasRequestId) {
      return;
    }
    setState(() {
      _layerImage = image;
    });
  }

  void _applyLayersZoom(AppData appData, Offset cursor, double scrollDy) {
    if (scrollDy == 0) return;
    const double zoomSensitivity = 0.01;
    const double minScale = 0.05;
    const double maxScale = 20.0;
    final double oldScale = appData.layersViewScale;
    final double newScale = (oldScale * (1.0 - scrollDy * zoomSensitivity))
        .clamp(minScale, maxScale);
    appData.layersViewOffset =
        cursor + (appData.layersViewOffset - cursor) * (newScale / oldScale);
    appData.layersViewScale = newScale;
    appData.update();
  }

  Future<void> _autoSaveIfPossible(AppData appData) async {
    if (appData.selectedProject == null) {
      return;
    }
    appData.queueAutosave();
  }

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppData>(context);
    final cdkColors = CDKThemeNotifier.colorTokensOf(context);
    _syncLayerSelectionState(appData);
    _syncZoneSelectionState(appData);
    _syncSpriteSelectionState(appData);

    if (appData.selectedSection != 'projects') {
      _drawCanvasImage(appData);
    }

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: CDKPickerButtonsSegmented(
            selectedIndex: _selectedSectionIndex(appData.selectedSection),
            options: _buildSegmentedOptions(context),
            onSelected: (index) => unawaited(
              _onTabSelected(appData, sections[index]),
            ),
          ),
        ),
        trailing: appData.autosaveInlineMessage.isEmpty
            ? null
            : SizedBox(
                width: 220,
                child: CDKText(
                  appData.autosaveInlineMessage,
                  role: CDKTextRole.caption,
                  color: appData.autosaveHasError
                      ? CupertinoColors.systemRed
                      : cdkColors.colorTextSecondary,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
              ),
      ),
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          _updateSelectionModifierStateFromEvent(event);
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final AppData appData = Provider.of<AppData>(context, listen: false);
          final bool isDeleteKey =
              event.logicalKey == LogicalKeyboardKey.backspace ||
                  event.logicalKey == LogicalKeyboardKey.delete;
          if (isDeleteKey && appData.selectedSection == 'layers') {
            unawaited(_confirmAndDeleteSelectedLayers(appData));
            return KeyEventResult.handled;
          }
          final bool meta = HardwareKeyboard.instance.isMetaPressed;
          final bool ctrl = HardwareKeyboard.instance.isControlPressed;
          final bool shift = HardwareKeyboard.instance.isShiftPressed;
          final bool isZ = event.logicalKey == LogicalKeyboardKey.keyZ;
          if (!(meta || ctrl) || !isZ) return KeyEventResult.ignored;
          if (shift) {
            appData.redo();
          } else {
            appData.undo();
          }
          return KeyEventResult.handled;
        },
        child: SafeArea(
          child: Stack(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: appData.selectedSection == 'projects'
                        ? Container(
                            color: cdkColors.backgroundSecondary1,
                            child: const LayoutProjectsMain(),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final Size viewportSize = Size(
                                constraints.maxWidth,
                                constraints.maxHeight,
                              );
                              _queueSelectedLevelViewportFit(
                                appData,
                                viewportSize,
                              );
                              _queueInitialLayersViewportCenter(
                                appData,
                                viewportSize,
                              );
                              return Container(
                                color: cdkColors.backgroundSecondary1,
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      bottom: appData.selectedSection ==
                                              "animation_rigs"
                                          ? _animationRigFrameStripReservedHeight
                                          : 0,
                                      child: Listener(
                                        onPointerDown: (_) => {
                                          _isPointerDown = true,
                                          _focusNode.requestFocus(),
                                          _refreshSelectionModifierState(),
                                        },
                                        onPointerUp: (_) =>
                                            _isPointerDown = false,
                                        onPointerCancel: (_) =>
                                            _isPointerDown = false,
                                        // macOS trackpad: two-finger scroll → PointerScrollEvent
                                        onPointerSignal: (event) {
                                          if (event is! PointerScrollEvent) {
                                            return;
                                          }
                                          if (appData.selectedSection != "levels" &&
                                              appData.selectedSection !=
                                                  "layers" &&
                                              appData.selectedSection !=
                                                  "tilemap" &&
                                              appData.selectedSection !=
                                                  "zones" &&
                                              appData.selectedSection !=
                                                  "sprites" &&
                                              appData.selectedSection !=
                                                  "viewport") {
                                            return;
                                          }
                                          _applyLayersZoom(
                                              appData,
                                              event.localPosition,
                                              event.scrollDelta.dy);
                                        },
                                        // macOS trackpad: two-finger pan-zoom → PointerPanZoomUpdateEvent
                                        onPointerPanZoomUpdate: (event) {
                                          if (appData.selectedSection != "levels" &&
                                              appData.selectedSection !=
                                                  "layers" &&
                                              appData.selectedSection !=
                                                  "tilemap" &&
                                              appData.selectedSection !=
                                                  "zones" &&
                                              appData.selectedSection !=
                                                  "sprites" &&
                                              appData.selectedSection !=
                                                  "viewport") {
                                            return;
                                          }
                                          // pan delta from trackpad scroll
                                          final double dy = -event.panDelta.dy;
                                          if (dy == 0) return;
                                          _applyLayersZoom(
                                              appData, event.localPosition, dy);
                                        },
                                        child: MouseRegion(
                                          cursor: _tilemapCursor(appData),
                                          onHover: (event) {
                                            final bool hoveringTilemapLayer =
                                                appData.selectedSection ==
                                                        'tilemap' &&
                                                    LayoutUtils.getTilemapCoords(
                                                            appData,
                                                            event
                                                                .localPosition) !=
                                                        null;
                                            if (hoveringTilemapLayer !=
                                                _isHoveringSelectedTilemapLayer) {
                                              setState(() {
                                                _isHoveringSelectedTilemapLayer =
                                                    hoveringTilemapLayer;
                                              });
                                            }
                                          },
                                          onExit: (_) {
                                            if (_isHoveringSelectedTilemapLayer) {
                                              setState(() {
                                                _isHoveringSelectedTilemapLayer =
                                                    false;
                                              });
                                            }
                                          },
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onPanStart: (details) =>
                                                _handlePanStart(
                                                    appData, details),
                                            onPanUpdate: (details) =>
                                                _handlePanUpdate(
                                                    appData, details),
                                            onPanEnd: (details) =>
                                                _handlePanEnd(appData, details),
                                            onTapDown: (details) =>
                                                _handleTapDown(
                                                    appData, details),
                                            onTapUp: (details) =>
                                                _handleTapUp(appData, details),
                                            child: CustomPaint(
                                              painter: _layerImage != null
                                                  ? CanvasPainter(
                                                      _layerImage!,
                                                      appData,
                                                      selectedLayerIndices:
                                                          _selectedLayerIndices,
                                                    )
                                                  : null,
                                              child: Container(),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (appData.selectedSection == "layers")
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          child: CustomPaint(
                                            painter: _LayersMarqueePainter(
                                              rect: _layersMarqueeRect,
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (appData.selectedSection == "zones")
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          child: CustomPaint(
                                            painter: _LayersMarqueePainter(
                                              rect: _zonesMarqueeRect,
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (appData.selectedSection == "sprites")
                                      Positioned.fill(
                                        child: IgnorePointer(
                                          child: CustomPaint(
                                            painter: _LayersMarqueePainter(
                                              rect: _spritesMarqueeRect,
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (_usesWorldViewportSection(
                                          appData.selectedSection,
                                        ) ||
                                        appData.selectedSection == "layers" ||
                                        appData.selectedSection == "zones" ||
                                        appData.selectedSection == "tilemap" ||
                                        appData.selectedSection == "sprites")
                                      _buildWorldTopControlsOverlay(
                                        appData,
                                        viewportSize,
                                      ),
                                    if (appData.selectedSection ==
                                        "animation_rigs")
                                      _buildAnimationRigFrameStripOverlay(
                                        appData,
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: 350, minWidth: 350),
                    child: Container(
                      color: cdkColors.background,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
                            child: _buildBreadcrumb(appData, context),
                          ),
                          Expanded(
                            child: _getSelectedLayout(appData),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
