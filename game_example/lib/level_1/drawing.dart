part of 'main.dart';

/// Renderer for level 1 world layers, animated actors, and HUD/end overlays.
class Level1Painter extends CustomPainter {
  const Level1Painter({
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
  final Level1RenderState? renderState;
  final List<LayerRenderCommand> layerCommands;
  final List<LevelSpriteRenderCommand> spriteCommands;
  final List<RenderImageCommand> imageCommands;

  @override
  void paint(Canvas canvas, Size size) {
    final Map<String, dynamic>? levelData = level;
    final Level1RenderState? state = renderState;
    if (levelData == null || state == null) {
      drawLevelLoadingPlaceholder(
        canvas: canvas,
        size: size,
        label: 'Loading level 1...',
        backgroundColor: const Color(0xFF000000),
      );
      return;
    }

    final LevelRenderFrameContext<Level1RenderState> frame =
        LevelRenderFrameContext<Level1RenderState>(
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
    drawLevelWorldWithCommands<Level1RenderState>(
      canvas: canvas,
      canvasSize: size,
      frame: frame,
      layerCommands: layerCommands,
      spriteCommands: spriteCommands,
      imageCommands: imageCommands,
      backgroundFallback: const Color(0xFF000000),
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
      backLabel: _level1BackLabel,
      backLayout: _level1BackHudLayout,
      commands: hudCommands,
    );

    if (state.isGameOver) {
      _drawGameOverOverlay(
        canvas,
        size,
        showPressAnyKey: state.canExitEndState,
      );
    } else if (state.isWin) {
      _drawYouWinOverlay(
        canvas,
        size,
        showPressAnyKey: state.canExitEndState,
      );
    }
  }

  List<HudRenderCommand> _buildHudRenderCommands({
    required Level1RenderState state,
    required double hudRectWidth,
  }) {
    final double hudRowTop = kHudRowTopSecondary;
    final String lifeText = 'Life: ${state.lifePercent}%';
    final TextPainter lifePainter = buildTextPainter(lifeText, kHudTextStyle);
    final double lifeLeftInHud = _level1BackHudLayout.hudX;
    final double lifeBarLeftInHud =
        lifeLeftInHud + lifePainter.width + hudSpacingX(10);
    final double lifeBarTopInHud =
        hudRowTop + (lifePainter.height - hudUnits(6)) / 2;

    return <HudRenderCommand>[
      HudRenderCommand.bottomLeftText(
        text:
            'LEVEL 1: PLATFORMER  |  MOVE: A/D OR ARROWS  |  JUMP: SPACE/W/UP',
        leftInHud: kHudFooterLeft,
        bottomInHud: kHudFooterBottom,
        maxWidth: resolveHudFooterMaxWidth(hudRectWidth),
      ),
      HudRenderCommand.topRightText(
        text: 'Gems: ${state.gemsCount}',
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
        progress: state.lifePercent / 100.0,
      ),
      HudRenderCommand.topRightText(
        text: 'FPS: ${state.fps.toStringAsFixed(1)}',
        top: kHudRowTopSecondary,
      ),
    ];
  }

  void _drawGameOverOverlay(
    Canvas canvas,
    Size viewportSize, {
    required bool showPressAnyKey,
  }) {
    drawCenteredEndOverlay(
      canvas: canvas,
      viewportSize: viewportSize,
      title: 'GAME OVER',
      showHint: showPressAnyKey,
      hintText: 'Press any key to return to menu',
    );
  }

  void _drawYouWinOverlay(
    Canvas canvas,
    Size viewportSize, {
    required bool showPressAnyKey,
  }) {
    drawCenteredEndOverlay(
      canvas: canvas,
      viewportSize: viewportSize,
      title: 'YOU WIN',
      showHint: showPressAnyKey,
      hintText: 'Press any key to return to menu',
    );
  }

  @override
  bool shouldRepaint(covariant Level1Painter oldDelegate) {
    return oldDelegate.renderState?.renderRevision !=
            renderState?.renderRevision ||
        oldDelegate.level != level;
  }
}
