part of 'main.dart';

/// Renderer for level 0 world, player animation, and HUD overlays.
class Level0Painter extends CustomPainter {
  const Level0Painter({
    required this.appData,
    required this.gameData,
    required this.level,
    required this.camera,
    required this.renderState,
    required this.layerCommands,
    required this.spriteCommands,
    required this.imageCommands,
  });

  final AppData appData;
  final Map<String, dynamic> gameData;
  final Map<String, dynamic>? level;
  final Camera camera;
  final Level0RenderState? renderState;
  final List<LayerRenderCommand> layerCommands;
  final List<LevelSpriteRenderCommand> spriteCommands;
  final List<RenderImageCommand> imageCommands;

  @override
  void paint(Canvas canvas, Size size) {
    final Map<String, dynamic>? levelData = level;
    final Level0RenderState? state = renderState;
    if (levelData == null || state == null) {
      drawLevelLoadingPlaceholder(
        canvas: canvas,
        size: size,
        label: 'Loading level 0...',
        backgroundColor: const Color(0xFF0B1014),
      );
      return;
    }

    final LevelRenderFrameContext<Level0RenderState> frame =
        LevelRenderFrameContext<Level0RenderState>(
      appData: appData,
      gameData: gameData,
      level: levelData,
      renderState: state,
      runtimeCamera: RuntimeCamera2D(
        x: state.cameraX,
        y: state.cameraY,
        focal: camera.focal,
      ),
    );
    drawLevelWorldWithCommands<Level0RenderState>(
      canvas: canvas,
      canvasSize: size,
      frame: frame,
      layerCommands: layerCommands,
      spriteCommands: spriteCommands,
      imageCommands: imageCommands,
      backgroundFallback: const Color(0xFF0B1014),
    );

    final Rect screenHudRect = resolveScreenHudRect(
      canvasSize: size,
    );
    final List<HudRenderCommand> hudCommands = _buildHudRenderCommands(
      state: state,
      hudRectWidth: screenHudRect.width,
    );
    drawCommonLevelHud(
      canvas: canvas,
      hudRect: screenHudRect,
      backLabel: _level0BackLabel,
      backLayout: _level0BackHudLayout,
      commands: hudCommands,
    );

    if (state.isWin) {
      _drawYouWinOverlay(
        canvas,
        size,
        showPressAnyKey: state.canExitEndState,
      );
    }
  }

  List<HudRenderCommand> _buildHudRenderCommands({
    required Level0RenderState state,
    required double hudRectWidth,
  }) {
    final List<HudRenderCommand> commands = <HudRenderCommand>[
      HudRenderCommand.bottomLeftText(
        text: 'LEVEL 0: TOP-DOWN  |  MOVE: ARROWS/WASD',
        leftInHud: kHudFooterLeft,
        bottomInHud: kHudFooterBottom,
        maxWidth: resolveHudFooterMaxWidth(hudRectWidth),
      ),
      HudRenderCommand.topRightText(
        text: 'Arbres: ${state.arbresRemovedCount}/${state.totalArbres}',
        top: kHudRowTopPrimary,
      ),
      HudRenderCommand.topRightText(
        text: 'FPS: ${state.fps.toStringAsFixed(1)}',
        top: kHudRowTopSecondary,
      ),
    ];
    if (state.isOnPont) {
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

  void _drawYouWinOverlay(
    Canvas canvas,
    Size viewportSize, {
    required bool showPressAnyKey,
  }) {
    drawCenteredEndOverlay(
      canvas: canvas,
      viewportSize: viewportSize,
      title: 'TU GUANYES',
      showHint: showPressAnyKey,
      hintText: 'Prem qualsevol tecla',
      hintStyle: const TextStyle(
        color: Color(0xFFE8F3FF),
        fontSize: 10 * kHudScale,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.8 * kHudScale,
      ),
      titleCenterYOffset: -20 * kHudSpacingScaleY,
      hintCenterYOffset: 6 * kHudSpacingScaleY,
    );
  }

  @override
  bool shouldRepaint(covariant Level0Painter oldDelegate) {
    return oldDelegate.renderState?.renderRevision !=
            renderState?.renderRevision ||
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
