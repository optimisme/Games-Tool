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
      drawHudText(canvas, 'Loading level 0...', const Offset(20, 20));
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
        final Rect hudRect = resolveHudRectInVirtualViewport(
          viewport: viewport,
          virtualViewportSize: viewportSize,
        );
        final RuntimeCamera2D effectiveCamera = RuntimeCamera2D(
          x: runtimeCamera.x,
          y: runtimeCamera.y,
          // Rendering works in virtual viewport space, so focal follows viewport width.
          focal: viewportSize.width,
        );
        final List<Map<String, dynamic>> layerPainterOrder =
            appData.gamesTool.listLevelLayers(
          level!,
          visibleOnly: true,
          painterOrder: true,
        );
        final List<Map<String, dynamic>> levelSprites =
            ((level!['sprites'] as List<dynamic>?) ?? const <dynamic>[])
                .whereType<Map<String, dynamic>>()
                .toList(growable: false);
        final Map<String, dynamic>? playerSprite =
            appData.gamesTool.findSpriteByType(level!, 'Heroi') ??
                appData.gamesTool.findFirstSprite(level!);
        final List<double> depthOrder =
            GamesToolRuntimeRenderer.resolveDepthPainterOrder(
          gamesTool: appData.gamesTool,
          layerPainterOrder: layerPainterOrder,
          sprites: levelSprites,
          includeSprite: (int _, Map<String, dynamic> sprite) {
            return playerSprite != null && identical(sprite, playerSprite);
          },
        );

        canvas.drawRect(
          Rect.fromLTWH(0, 0, viewportSize.width, viewportSize.height),
          Paint()..color = levelBackground,
        );
        for (final double depth in depthOrder) {
          GamesToolRuntimeRenderer.drawLevelTileLayers(
            canvas: canvas,
            painterSize: viewportSize,
            level: level!,
            gamesTool: appData.gamesTool,
            imagesCache: appData.imagesCache,
            camera: effectiveCamera,
            backgroundColor: levelBackground,
            depthSensitivity: depthSensitivity,
            drawBackground: false,
            onlyDepth: depth,
          );
          _drawSpritesAtDepth(
            canvas: canvas,
            size: viewportSize,
            runtimeCamera: effectiveCamera,
            depthSensitivity: depthSensitivity,
            depth: depth,
            playerSprite: playerSprite,
          );
        }
        if (playerSprite == null) {
          _drawFallbackPlayer(canvas, viewportSize, effectiveCamera);
        }

        drawBackToMenuHud(
          canvas: canvas,
          hudRect: hudRect,
          iconImage: backIconImage,
          label: _level0BackLabel,
          layout: _level0BackHudLayout,
        );
        drawHudText(
          canvas,
          'LEVEL 0: TOP-DOWN  |  MOVE: ARROWS/WASD',
          Offset(hudRect.left + 20, hudRect.top + 170),
        );
        if (renderState!.isOnPont) {
          drawHudText(
            canvas,
            'Caminant pel pont',
            Offset(hudRect.left + 20, hudRect.top + 20),
          );
        }
        drawTopRightHudText(
          canvas: canvas,
          hudRect: hudRect,
          text: 'Arbres: ${renderState!.arbresRemovedCount}',
          top: 5,
        );
      },
    );
  }

  void _drawSpritesAtDepth({
    required Canvas canvas,
    required Size size,
    required RuntimeCamera2D runtimeCamera,
    required double depthSensitivity,
    required double depth,
    required Map<String, dynamic>? playerSprite,
  }) {
    if (playerSprite == null) {
      return;
    }
    final double playerDepth = appData.gamesTool.spriteDepth(playerSprite);
    if (!GamesToolRuntimeRenderer.sameDepth(playerDepth, depth)) {
      return;
    }
    _drawAnimatedPlayer(
      canvas,
      size,
      runtimeCamera,
      playerSprite: playerSprite,
      depthSensitivity: depthSensitivity,
    );
  }

  void _drawAnimatedPlayer(
    Canvas canvas,
    Size size,
    RuntimeCamera2D runtimeCamera, {
    required Map<String, dynamic>? playerSprite,
    required double depthSensitivity,
  }) {
    final Level0RenderState state = renderState!;
    if (level == null) {
      _drawFallbackPlayer(canvas, size, runtimeCamera);
      return;
    }

    final _AnimationSelection animation = _resolveAnimationFor(state);
    if (playerSprite == null) {
      _drawFallbackPlayer(canvas, size, runtimeCamera);
      return;
    }
    final bool drewSprite = GamesToolRuntimeRenderer.drawAnimatedSprite(
      canvas: canvas,
      painterSize: size,
      gameData: gameData ?? appData.gameData,
      gamesTool: appData.gamesTool,
      imagesCache: appData.imagesCache,
      sprite: playerSprite,
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
