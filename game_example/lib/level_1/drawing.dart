part of 'main.dart';

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
      _drawText(canvas, 'Loading level 1...', const Offset(20, 20));
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

    GamesToolRuntimeRenderer.withViewport(
      canvas: canvas,
      painterSize: size,
      viewport: viewport,
      outerBackgroundColor: levelBackground,
      drawInViewport: (Size viewportSize) {
        final Rect hudRect = _resolveLevel1HudRectInVirtualViewport(
          viewport: viewport,
          virtualViewportSize: viewportSize,
        );
        final RuntimeCamera2D effectiveCamera = RuntimeCamera2D(
          x: runtimeCamera.x,
          y: runtimeCamera.y,
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
        final List<Map<String, dynamic>> levelSprites =
            ((level!['sprites'] as List<dynamic>?) ?? const <dynamic>[])
                .whereType<Map<String, dynamic>>()
                .toList(growable: false);
        final Map<String, dynamic>? playerSprite =
            _resolveLevel1PlayerSprite(level);
        for (int spriteIndex = 0;
            spriteIndex < levelSprites.length;
            spriteIndex++) {
          final Map<String, dynamic> sprite = levelSprites[spriteIndex];
          if (playerSprite != null && identical(sprite, playerSprite)) {
            continue;
          }
          if (renderState!.collectedGemSpriteIndices.contains(spriteIndex)) {
            continue;
          }
          if (renderState!.removedDragonSpriteIndices.contains(spriteIndex)) {
            continue;
          }
          final bool dragonDying =
              renderState!.dragonDeathStartSeconds.containsKey(spriteIndex);
          final double? dragonDeathStart =
              renderState!.dragonDeathStartSeconds[spriteIndex];
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
            camera: effectiveCamera,
            animationName: drawDragonDeath ? _level1AnimDragonDeath : null,
            elapsedSeconds: drawDragonDeath
                ? (renderState!.animationTimeSeconds - dragonDeathStart)
                    .clamp(0.0, double.infinity)
                : renderState!.animationTimeSeconds,
            depthSensitivity: depthSensitivity,
          );
        }

        if (playerSprite != null) {
          final String playerAnimationName =
              _resolvePlayerAnimationName(renderState!);
          GamesToolRuntimeRenderer.drawAnimatedSprite(
            canvas: canvas,
            painterSize: viewportSize,
            gameData: appData.gameData,
            gamesTool: appData.gamesTool,
            imagesCache: appData.imagesCache,
            sprite: playerSprite,
            camera: effectiveCamera,
            animationName: playerAnimationName,
            elapsedSeconds: renderState!.animationTimeSeconds,
            worldX: renderState!.playerX,
            worldY: renderState!.playerY,
            drawWidthWorld: renderState!.playerWidth,
            drawHeightWorld: renderState!.playerHeight,
            flipX: !renderState!.facingRight,
            depthSensitivity: depthSensitivity,
          );
        }

        _drawBackToMenuHud(canvas, hudRect);
        _drawText(
          canvas,
          'LEVEL 1: PLATFORMER  |  MOVE: A/D OR ARROWS  |  JUMP: SPACE/W/UP',
          Offset(hudRect.left + 20, hudRect.bottom - 10),
        );
        _drawTopRightText(
          canvas,
          hudRect,
          'Gems: ${renderState!.gemsCount}',
          5,
        );
        _drawTopRightText(
          canvas,
          hudRect,
          'Life: ${renderState!.lifePercent}%',
          13,
        );
        _drawTopRightProgressBar(
          canvas,
          hudRect,
          top: 22,
          progress: renderState!.lifePercent / 100.0,
        );
        if (renderState!.isGameOver) {
          _drawGameOverOverlay(canvas, viewportSize);
        } else if (renderState!.isWin) {
          _drawYouWinOverlay(canvas, viewportSize);
        }
      },
    );
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
        hudRect.left + _level1BackHudX,
        hudRect.top + _level1BackHudY,
        _level1BackIconWidth,
        _level1BackIconHeight,
      );
      canvas.drawImageRect(iconImage, srcRect, dstRect, Paint());
    }
    _drawText(
      canvas,
      _level1BackLabel,
      Offset(hudRect.left + _level1BackTextX, hudRect.top + _level1BackHudY),
    );
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

  void _drawTopRightProgressBar(
    Canvas canvas,
    Rect hudRect, {
    required double top,
    required double progress,
  }) {
    const double barWidth = 62;
    const double barHeight = 6;
    final double clampedProgress = progress.clamp(0.0, 1.0);
    final double left = hudRect.right - barWidth - 20;
    final double y = hudRect.top + top;
    final Rect barRect = Rect.fromLTWH(left, y, barWidth, barHeight);
    final Rect fillRect = Rect.fromLTWH(
      left,
      y,
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
        ..strokeWidth = 1
        ..color = const Color(0xFFB9D8E8),
    );
  }

  void _drawGameOverOverlay(Canvas canvas, Size viewportSize) {
    _drawCenteredOverlay(
      canvas,
      viewportSize,
      title: 'GAME OVER',
    );
  }

  void _drawYouWinOverlay(Canvas canvas, Size viewportSize) {
    _drawCenteredOverlay(
      canvas,
      viewportSize,
      title: 'YOU WIN',
    );
  }

  void _drawCenteredOverlay(
    Canvas canvas,
    Size viewportSize, {
    required String title,
  }) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, viewportSize.width, viewportSize.height),
      Paint()..color = const Color(0xB3000000),
    );
    final TextPainter titlePainter = TextPainter(
      text: TextSpan(
        text: title,
        style: TextStyle(
          color: Color(0xFFFFFFFF),
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    titlePainter.paint(
      canvas,
      Offset(
        (viewportSize.width - titlePainter.width) / 2,
        (viewportSize.height - titlePainter.height) / 2 - 12,
      ),
    );

    final TextPainter hintPainter = TextPainter(
      text: const TextSpan(
        text: 'Press any key to return to menu',
        style: TextStyle(
          color: Color(0xFFE0F2FF),
          fontSize: 8.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    hintPainter.paint(
      canvas,
      Offset(
        (viewportSize.width - hintPainter.width) / 2,
        (viewportSize.height - hintPainter.height) / 2 + 16,
      ),
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
    )..layout(maxWidth: 900);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant Level1Painter oldDelegate) {
    return oldDelegate.renderState?.tickCounter != renderState?.tickCounter ||
        oldDelegate.renderState?.gemsCount != renderState?.gemsCount ||
        oldDelegate.renderState?.lifePercent != renderState?.lifePercent ||
        oldDelegate.renderState?.isGameOver != renderState?.isGameOver ||
        oldDelegate.renderState?.isWin != renderState?.isWin ||
        oldDelegate.backIconImage != backIconImage ||
        oldDelegate.level != level;
  }
}
