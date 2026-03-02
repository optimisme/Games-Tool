part of 'main.dart';

/// Renderer for level 1 world layers, animated actors, and HUD/end overlays.
class Level1Painter extends CustomPainter {
  const Level1Painter({
    required this.appData,
    required this.level,
    required this.camera,
    required this.backIconImage,
    required this.renderState,
  });

  final AppData appData;
  final Map<String, dynamic>? level;
  final Camera camera;
  final ui.Image? backIconImage;
  final Level1RenderState? renderState;

  @override
  void paint(Canvas canvas, Size size) {
    if (level == null || renderState == null) {
      final Paint background = Paint()..color = const Color(0xFF0A0D1A);
      canvas.drawRect(Offset.zero & size, background);
      drawHudText(canvas, 'Loading level 1...', const Offset(20, 20));
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
      fallback: const Color(0xFF0A0D1A),
    );
    final Rect screenHudRect = resolveScreenHudRect(
      canvasSize: size,
    );

    GamesToolRuntimeRenderer.withViewport(
      canvas: canvas,
      painterSize: size,
      viewport: viewport,
      outerBackgroundColor: levelBackground,
      drawInViewport: (Size viewportSize) {
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
            _resolveLevel1PlayerSprite(level);
        final List<double> depthOrder =
            GamesToolRuntimeRenderer.resolveDepthPainterOrder(
          gamesTool: appData.gamesTool,
          layerPainterOrder: layerPainterOrder,
          sprites: levelSprites,
          includeSprite: (int spriteIndex, Map<String, dynamic> sprite) {
            return !_shouldSkipSprite(
              spriteIndex: spriteIndex,
              sprite: sprite,
              playerSprite: playerSprite,
              state: renderState!,
            );
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
            viewportSize: viewportSize,
            camera: effectiveCamera,
            depthSensitivity: depthSensitivity,
            depth: depth,
            sprites: levelSprites,
            playerSprite: playerSprite,
            state: renderState!,
          );
        }
      },
    );
    drawBackToMenuHud(
      canvas: canvas,
      hudRect: screenHudRect,
      iconImage: backIconImage,
      label: _level1BackLabel,
      layout: _level1BackHudLayout,
    );
    drawHudText(
      canvas,
      'LEVEL 1: PLATFORMER  |  MOVE: A/D OR ARROWS  |  JUMP: SPACE/W/UP',
      Offset(
        screenHudRect.left + hudSpacingX(20),
        screenHudRect.bottom - hudSpacingY(14),
      ),
      maxWidth: screenHudRect.width - hudSpacingX(40),
    );
    drawTopRightHudText(
      canvas: canvas,
      hudRect: screenHudRect,
      text: 'Gems: ${renderState!.gemsCount}',
      top: hudSpacingY(5),
    );
    final double hudRowTop = hudSpacingY(31);
    final String lifeText = 'Life: ${renderState!.lifePercent}%';
    final TextPainter lifePainter = buildTextPainter(lifeText, kHudTextStyle);
    final double lifeLeft = screenHudRect.left + _level1BackHudLayout.hudX;
    final double lifeTop = screenHudRect.top + hudRowTop;
    final double lifeBarLeft = lifeLeft + lifePainter.width + hudSpacingX(10);
    final double lifeBarTop = lifeTop + (lifePainter.height - hudUnits(6)) / 2;
    drawHudText(
      canvas,
      lifeText,
      Offset(lifeLeft, lifeTop),
    );
    _drawHudProgressBarAt(
      canvas,
      left: lifeBarLeft,
      top: lifeBarTop,
      progress: renderState!.lifePercent / 100.0,
    );
    drawTopRightHudText(
      canvas: canvas,
      hudRect: screenHudRect,
      text: 'FPS: ${renderState!.fps.toStringAsFixed(1)}',
      top: hudRowTop,
    );
    if (renderState!.isGameOver) {
      _drawGameOverOverlay(
        canvas,
        size,
        showPressAnyKey: renderState!.canExitEndState,
      );
    } else if (renderState!.isWin) {
      _drawYouWinOverlay(
        canvas,
        size,
        showPressAnyKey: renderState!.canExitEndState,
      );
    }
  }

  void _drawSpritesAtDepth({
    required Canvas canvas,
    required Size viewportSize,
    required RuntimeCamera2D camera,
    required double depthSensitivity,
    required double depth,
    required List<Map<String, dynamic>> sprites,
    required Map<String, dynamic>? playerSprite,
    required Level1RenderState state,
  }) {
    for (int spriteIndex = 0; spriteIndex < sprites.length; spriteIndex++) {
      final Map<String, dynamic> sprite = sprites[spriteIndex];
      if (_shouldSkipSprite(
        spriteIndex: spriteIndex,
        sprite: sprite,
        playerSprite: playerSprite,
        state: state,
      )) {
        continue;
      }
      final double spriteDepth = appData.gamesTool.spriteDepth(sprite);
      if (!GamesToolRuntimeRenderer.sameDepth(spriteDepth, depth)) {
        continue;
      }

      final bool isPlayer =
          playerSprite != null && identical(sprite, playerSprite);
      if (isPlayer) {
        final String playerAnimationName = _resolvePlayerAnimationName(state);
        GamesToolRuntimeRenderer.drawAnimatedSprite(
          canvas: canvas,
          painterSize: viewportSize,
          gameData: appData.gameData,
          gamesTool: appData.gamesTool,
          imagesCache: appData.imagesCache,
          sprite: sprite,
          camera: camera,
          animationName: playerAnimationName,
          elapsedSeconds: state.animationTimeSeconds,
          worldX: state.playerX,
          worldY: state.playerY,
          drawWidthWorld: state.playerWidth,
          drawHeightWorld: state.playerHeight,
          flipX: !state.facingRight,
          depthSensitivity: depthSensitivity,
        );
        continue;
      }

      final bool dragonDying =
          state.dragonDeathStartSeconds.containsKey(spriteIndex);
      final double? dragonDeathStart =
          state.dragonDeathStartSeconds[spriteIndex];
      final bool drawDragonDeath = dragonDying &&
          dragonDeathStart != null &&
          _isLevel1DragonSprite(sprite);
      GamesToolRuntimeRenderer.drawAnimatedSprite(
        canvas: canvas,
        painterSize: viewportSize,
        gameData: appData.gameData,
        gamesTool: appData.gamesTool,
        imagesCache: appData.imagesCache,
        sprite: sprite,
        camera: camera,
        animationName: drawDragonDeath ? _level1AnimDragonDeath : null,
        elapsedSeconds: drawDragonDeath
            ? (state.animationTimeSeconds - dragonDeathStart)
                .clamp(0.0, double.infinity)
            : state.animationTimeSeconds,
        depthSensitivity: depthSensitivity,
      );
    }
  }

  bool _shouldSkipSprite({
    required int spriteIndex,
    required Map<String, dynamic> sprite,
    required Map<String, dynamic>? playerSprite,
    required Level1RenderState state,
  }) {
    final bool isPlayer =
        playerSprite != null && identical(sprite, playerSprite);
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

  String _resolvePlayerAnimationName(Level1RenderState state) {
    const double verticalThreshold = 5.0;
    const double moveThreshold = 2.0;
    if (!state.onGround) {
      if (state.velocityY < -verticalThreshold) {
        return _level1AnimFoxyJumpUp;
      }
      return _level1AnimFoxyJumpFall;
    }
    if (state.velocityX.abs() > moveThreshold) {
      return _level1AnimFoxyWalk;
    }
    return _level1AnimFoxyIdle;
  }

  void _drawHudProgressBarAt(
    Canvas canvas, {
    required double left,
    required double top,
    required double progress,
  }) {
    final double barWidth = hudUnits(62);
    final double barHeight = hudUnits(6);
    final double clampedProgress = progress.clamp(0.0, 1.0);
    final Rect barRect = Rect.fromLTWH(left, top, barWidth, barHeight);
    final Rect fillRect = Rect.fromLTWH(
      left,
      top,
      barWidth * clampedProgress,
      barHeight,
    );
    final Color fillColor = Color.lerp(
          const Color(0xFFD14040),
          const Color(0xFF3BCB77),
          clampedProgress,
        ) ??
        const Color(0xFF3BCB77);

    canvas.drawRect(barRect, Paint()..color = const Color(0xFF26313B));
    if (fillRect.width > 0) {
      canvas.drawRect(fillRect, Paint()..color = fillColor);
    }
    canvas.drawRect(
      barRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = hudUnits(1)
        ..color = const Color(0xFFB9D8E8),
    );
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
    return oldDelegate.renderState?.tickCounter != renderState?.tickCounter ||
        oldDelegate.renderState?.gemsCount != renderState?.gemsCount ||
        oldDelegate.renderState?.lifePercent != renderState?.lifePercent ||
        oldDelegate.renderState?.isGameOver != renderState?.isGameOver ||
        oldDelegate.renderState?.isWin != renderState?.isWin ||
        oldDelegate.renderState?.canExitEndState !=
            renderState?.canExitEndState ||
        oldDelegate.backIconImage != backIconImage ||
        oldDelegate.level != level;
  }
}
