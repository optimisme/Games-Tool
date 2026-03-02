part of 'main.dart';

/// Renderer for level 0 world, player animation, and HUD overlays.
class Level0Painter extends CustomPainter {
  const Level0Painter({
    required this.appData,
    required this.gameData,
    required this.level,
    required this.camera,
    required this.backIconImage,
    required this.renderState,
  });

  final AppData appData;
  final Map<String, dynamic>? gameData;
  final Map<String, dynamic>? level;
  final Camera camera;
  final ui.Image? backIconImage;
  final Level0RenderState? renderState;

  @override
  void paint(Canvas canvas, Size size) {
    if (level == null || renderState == null) {
      final Paint background = Paint()..color = const Color(0xFF0B1014);
      canvas.drawRect(Offset.zero & size, background);
      _drawText(canvas, 'Loading level 0...', const Offset(20, 20));
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
      fallback: const Color(0xFF0B1014),
    );

    GamesToolRuntimeRenderer.withViewport(
      canvas: canvas,
      painterSize: size,
      viewport: viewport,
      outerBackgroundColor: levelBackground,
      drawInViewport: (Size viewportSize) {
        final Rect hudRect = _resolveLevel0HudRectInVirtualViewport(
          viewport: viewport,
          virtualViewportSize: viewportSize,
        );
        final RuntimeCamera2D effectiveCamera = RuntimeCamera2D(
          x: runtimeCamera.x,
          y: runtimeCamera.y,
          // Rendering works in virtual viewport space, so focal follows viewport width.
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

        _drawAnimatedPlayer(canvas, viewportSize, effectiveCamera);

        _drawBackToMenuHud(canvas, hudRect);
        _drawText(
          canvas,
          'LEVEL 0: TOP-DOWN  |  MOVE: ARROWS/WASD',
          Offset(hudRect.left + 20, hudRect.top + 170),
        );
        if (renderState!.isOnPont) {
          _drawText(
            canvas,
            'Caminant pel pont',
            Offset(hudRect.left + 20, hudRect.top + 20),
          );
        }
        _drawTopRightText(
          canvas,
          hudRect,
          'Arbres: ${renderState!.arbresRemovedCount}',
          5,
        );
      },
    );
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
        hudRect.left + _level0BackHudX,
        hudRect.top + _level0BackHudY,
        _level0BackIconWidth,
        _level0BackIconHeight,
      );
      canvas.drawImageRect(iconImage, srcRect, dstRect, Paint());
    }
    _drawText(
      canvas,
      _level0BackLabel,
      Offset(hudRect.left + _level0BackTextX, hudRect.top + _level0BackHudY),
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
    )..layout();
    painter.paint(canvas, offset);
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

  void _drawAnimatedPlayer(
    Canvas canvas,
    Size size,
    RuntimeCamera2D runtimeCamera,
  ) {
    final Level0RenderState state = renderState!;
    if (level == null) {
      _drawFallbackPlayer(canvas, size, runtimeCamera);
      return;
    }

    final Map<String, dynamic>? sprite =
        appData.gamesTool.findSpriteByType(level!, 'Heroi') ??
            appData.gamesTool.findFirstSprite(level!);
    final _AnimationSelection animation = _resolveAnimationFor(state);
    if (sprite == null) {
      _drawFallbackPlayer(canvas, size, runtimeCamera);
      return;
    }

    final double depthSensitivity =
        GamesToolRuntimeRenderer.levelDepthSensitivity(
      gamesTool: appData.gamesTool,
      level: level,
    );
    final bool drewSprite = GamesToolRuntimeRenderer.drawAnimatedSprite(
      canvas: canvas,
      painterSize: size,
      gameData: gameData ?? appData.gameData,
      gamesTool: appData.gamesTool,
      imagesCache: appData.imagesCache,
      sprite: sprite,
      camera: runtimeCamera,
      elapsedSeconds: state.animationTimeSeconds,
      animationName: animation.animationName,
      worldX: state.playerX,
      worldY: state.playerY,
      flipX: animation.mirrorX,
      drawWidthWorld: state.playerWidth,
      drawHeightWorld: state.playerHeight,
      depthSensitivity: depthSensitivity,
      fallbackFps: 8,
    );
    if (!drewSprite) {
      _drawFallbackPlayer(canvas, size, runtimeCamera);
    }
  }

  void _drawFallbackPlayer(
    Canvas canvas,
    Size size,
    RuntimeCamera2D runtimeCamera,
  ) {
    final Level0RenderState state = renderState!;
    final double cameraScale = RuntimeCameraMath.cameraScaleForViewport(
      viewportSize: size,
      focal: runtimeCamera.focal,
    );
    final double depthSensitivity =
        GamesToolRuntimeRenderer.levelDepthSensitivity(
      gamesTool: appData.gamesTool,
      level: level,
    );
    final Offset screenPos = RuntimeCameraMath.worldToScreen(
      worldX: state.playerX,
      worldY: state.playerY,
      viewportSize: size,
      camera: runtimeCamera,
      depthSensitivity: depthSensitivity,
    );
    final Rect playerRect = Rect.fromLTWH(
      screenPos.dx,
      screenPos.dy,
      state.playerWidth * cameraScale,
      state.playerHeight * cameraScale,
    );
    final Paint playerPaint = Paint()..color = const Color(0xFF4DA3FF);
    canvas.drawRect(playerRect, playerPaint);
  }

  _AnimationSelection _resolveAnimationFor(Level0RenderState state) {
    final String prefix = state.isMoving ? 'Heroi Camina ' : 'Heroi Aturat ';
    switch (state.direction) {
      case 'upLeft':
        return _AnimationSelection(
          animationName: '${prefix}Amunt-Dreta',
          mirrorX: true,
        );
      case 'up':
        return _AnimationSelection(animationName: '${prefix}Amunt');
      case 'upRight':
        return _AnimationSelection(animationName: '${prefix}Amunt-Dreta');
      case 'left':
        return _AnimationSelection(
          animationName: '${prefix}Dreta',
          mirrorX: true,
        );
      case 'right':
        return _AnimationSelection(animationName: '${prefix}Dreta');
      case 'downLeft':
        return _AnimationSelection(
          animationName: '${prefix}Avall-Dreta',
          mirrorX: true,
        );
      case 'downRight':
        return _AnimationSelection(animationName: '${prefix}Avall-Dreta');
      case 'down':
      default:
        return _AnimationSelection(animationName: '${prefix}Avall');
    }
  }

  @override
  bool shouldRepaint(covariant Level0Painter oldDelegate) {
    // Tick counter is the repaint clock; level identity change also invalidates frame.
    return oldDelegate.renderState?.tickCounter != renderState?.tickCounter ||
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
