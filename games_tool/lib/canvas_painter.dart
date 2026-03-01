import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import 'app_data.dart';
import 'game_animation.dart';
import 'game_animation_hit_box.dart';
import 'game_level.dart';
import 'layout_utils.dart';

class CanvasPainter extends CustomPainter {
  final ui.Image layerImage;
  final AppData appData;
  final Set<int> selectedLayerIndices;

  CanvasPainter(
    this.layerImage,
    this.appData, {
    Set<int>? selectedLayerIndices,
  }) : selectedLayerIndices = selectedLayerIndices ?? const <int>{};

  @override
  void paint(Canvas canvas, Size size) {
    if (appData.selectedSection == 'levels' ||
        appData.selectedSection == 'layers' ||
        appData.selectedSection == 'tilemap' ||
        appData.selectedSection == 'zones' ||
        appData.selectedSection == 'sprites' ||
        appData.selectedSection == 'viewport') {
      _paintWorldViewport(
        canvas,
        size,
        renderingTilemap: appData.selectedSection == 'tilemap',
        renderingSprites: appData.selectedSection == 'sprites' ||
            appData.selectedSection == 'layers' ||
            appData.selectedSection == 'levels' ||
            appData.selectedSection == 'viewport',
        renderingLayersPreview: appData.selectedSection == 'layers' ||
            appData.selectedSection == 'levels' ||
            appData.selectedSection == 'viewport',
        renderingViewport: appData.selectedSection == 'viewport',
      );
    } else {
      _paintDefault(canvas, size);
    }
  }

  // ─── Default (fit-to-canvas) rendering used by all sections except layers ──

  void _paintDefault(Canvas canvas, Size size) {
    final double imageWidth = layerImage.width.toDouble();
    final double imageHeight = layerImage.height.toDouble();
    final double availableWidth = size.width * 0.95;
    final double availableHeight = size.height * 0.95;

    final double scaleX = availableWidth / imageWidth;
    final double scaleY = availableHeight / imageHeight;
    final double scale = scaleX < scaleY ? scaleX : scaleY;

    final double scaledWidth = imageWidth * scale;
    final double scaledHeight = imageHeight * scale;
    final double dx = (size.width - scaledWidth) / 2;
    final double dy = (size.height - scaledHeight) / 2;

    appData.scaleFactor = scale;
    appData.imageOffset = Offset(dx, dy);

    canvas.drawImageRect(
      layerImage,
      Rect.fromLTWH(0, 0, imageWidth, imageHeight),
      Rect.fromLTWH(dx, dy, scaledWidth, scaledHeight),
      Paint(),
    );

    if (appData.selectedSection == 'animation_rigs') {
      _paintAnimationRigOverlay(
        canvas,
        dx: dx,
        dy: dy,
        scaledWidth: scaledWidth,
        scaledHeight: scaledHeight,
      );
    }

    // Dragging tile ghost (tilemap section)
    if (appData.selectedSection == 'tilemap' &&
        appData.draggingTileIndex != -1 &&
        appData.selectedLevel != -1 &&
        appData.selectedLayer != -1) {
      final level = appData.gameData.levels[appData.selectedLevel];
      final layer = level.layers[appData.selectedLayer];
      final tilesSheetFile = layer.tilesSheetFile;

      if (appData.imagesCache.containsKey(tilesSheetFile)) {
        final ui.Image tilesetImage = appData.imagesCache[tilesSheetFile]!;
        final double tileWidth = layer.tilesWidth.toDouble();
        final double tileHeight = layer.tilesHeight.toDouble();
        final int tilesetColumns = (tilesetImage.width / tileWidth).floor();
        final int tileIndex = appData.draggingTileIndex;
        final int tileRow = (tileIndex / tilesetColumns).floor();
        final int tileCol = tileIndex % tilesetColumns;

        canvas.drawImageRect(
          tilesetImage,
          Rect.fromLTWH(
              tileCol * tileWidth, tileRow * tileHeight, tileWidth, tileHeight),
          Rect.fromLTWH(
            appData.draggingOffset.dx - tileWidth / 2,
            appData.draggingOffset.dy - tileHeight / 2,
            tileWidth,
            tileHeight,
          ),
          Paint(),
        );
      }
    }
  }

  void _paintAnimationRigOverlay(
    Canvas canvas, {
    required double dx,
    required double dy,
    required double scaledWidth,
    required double scaledHeight,
  }) {
    if (appData.selectedAnimation < 0 ||
        appData.selectedAnimation >= appData.gameData.animations.length) {
      return;
    }
    if (scaledWidth <= 0 || scaledHeight <= 0) {
      return;
    }
    final GameAnimation animation =
        appData.gameData.animations[appData.selectedAnimation];
    final int activeFrame = appData.animationRigActiveFrame >= 0
        ? appData.animationRigActiveFrame
        : animation.startFrame;
    final GameAnimationFrameRig rig = animation.rigForFrame(activeFrame);

    _paintAnimationRigPixelGrid(
      canvas,
      dx: dx,
      dy: dy,
      scaledWidth: scaledWidth,
      scaledHeight: scaledHeight,
    );

    final int selectedIndex = appData.selectedAnimationHitBox;
    for (int i = 0; i < rig.hitBoxes.length; i++) {
      final GameAnimationHitBox hitBox = rig.hitBoxes[i];
      final Rect rect = Rect.fromLTWH(
        dx + scaledWidth * hitBox.x.clamp(0.0, 1.0),
        dy + scaledHeight * hitBox.y.clamp(0.0, 1.0),
        scaledWidth * hitBox.width.clamp(0.0, 1.0),
        scaledHeight * hitBox.height.clamp(0.0, 1.0),
      );
      if (rect.width <= 0 || rect.height <= 0) {
        continue;
      }
      final Color color = LayoutUtils.getColorFromName(hitBox.color);
      canvas.drawRect(
        rect,
        Paint()
          ..color = color.withValues(alpha: 0.18)
          ..style = PaintingStyle.fill,
      );
      canvas.drawRect(
        rect,
        Paint()
          ..color = color
          ..strokeWidth = i == selectedIndex ? 2.2 : 1.4
          ..style = PaintingStyle.stroke,
      );

      if (i == selectedIndex) {
        final double handleSize =
            (14.0).clamp(0, math.min(rect.width, rect.height));
        if (handleSize > 0) {
          final Path handlePath = Path()
            ..moveTo(rect.right, rect.bottom)
            ..lineTo(rect.right - handleSize, rect.bottom)
            ..lineTo(rect.right, rect.bottom - handleSize)
            ..close();
          canvas.drawPath(
            handlePath,
            Paint()
              ..color = color
              ..style = PaintingStyle.fill,
          );
        }
      }

      _drawLabel(
        canvas,
        hitBox.name.trim().isEmpty ? 'Hit Box ${i + 1}' : hitBox.name,
        Offset(rect.left + 4, rect.top + 4),
        TextStyle(
          color: color,
          fontSize: 9.0,
          fontFamily: 'monospace',
          fontWeight: FontWeight.w600,
        ),
      );
    }

    // Draw anchor last so it remains visible/draggable above overlapping hit boxes.
    final double anchorX = rig.anchorX.clamp(0.0, 1.0);
    final double anchorY = rig.anchorY.clamp(0.0, 1.0);
    final Offset anchorCenter = Offset(
      dx + scaledWidth * anchorX,
      dy + scaledHeight * anchorY,
    );
    final Color anchorColor = LayoutUtils.getColorFromName(rig.anchorColor);
    const double anchorRadius = 6.0;
    canvas.drawCircle(
      anchorCenter,
      anchorRadius + 1.0,
      Paint()
        ..color = const Color(0xB3FFFFFF)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      anchorCenter,
      anchorRadius,
      Paint()
        ..color = anchorColor
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      anchorCenter,
      anchorRadius,
      Paint()
        ..color = const Color(0xB3000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  void _paintAnimationRigPixelGrid(
    Canvas canvas, {
    required double dx,
    required double dy,
    required double scaledWidth,
    required double scaledHeight,
  }) {
    final double sourceWidth = layerImage.width.toDouble();
    final double sourceHeight = layerImage.height.toDouble();
    if (sourceWidth <= 0 || sourceHeight <= 0) {
      return;
    }
    final double stepX = scaledWidth / sourceWidth;
    final double stepY = scaledHeight / sourceHeight;
    if (stepX < 3.0 || stepY < 3.0) {
      return;
    }

    final Paint gridPaint = Paint()
      ..color = const Color(0x55000000)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (int x = 0; x <= sourceWidth.toInt(); x++) {
      final double lineX = dx + x * stepX;
      canvas.drawLine(
        Offset(lineX, dy),
        Offset(lineX, dy + scaledHeight),
        gridPaint,
      );
    }
    for (int y = 0; y <= sourceHeight.toInt(); y++) {
      final double lineY = dy + y * stepY;
      canvas.drawLine(
        Offset(dx, lineY),
        Offset(dx + scaledWidth, lineY),
        gridPaint,
      );
    }
  }

  // ─── World viewport: zoom + pan + axis ─────────────────────────────────────

  void _paintWorldViewport(
    Canvas canvas,
    Size size, {
    required bool renderingTilemap,
    required bool renderingSprites,
    bool renderingLayersPreview = false,
    bool renderingViewport = false,
  }) {
    final double vScale = appData.layersViewScale;
    final Offset vOffset = appData.layersViewOffset;

    // Store for hit-testing in layout_utils (compatible with translateCoords)
    appData.scaleFactor = vScale;
    appData.imageOffset = vOffset;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Apply viewport transform: world → screen
    canvas.translate(vOffset.dx, vOffset.dy);
    canvas.scale(vScale);

    // Draw each layer directly in world space from the image cache
    if (appData.selectedLevel != -1) {
      final level = appData.gameData.levels[appData.selectedLevel];
      final double levelParallaxSensitivity = level.parallaxSensitivity;

      for (int li = level.layers.length - 1; li >= 0; li--) {
        final layer = level.layers[li];
        if (layer.visible == false) continue;
        if (!appData.imagesCache.containsKey(layer.tilesSheetFile)) continue;

        final ui.Image tilesetImg = appData.imagesCache[layer.tilesSheetFile]!;
        final double tw = layer.tilesWidth.toDouble();
        final double th = layer.tilesHeight.toDouble();
        final int tsetCols = (tilesetImg.width / tw).floor();
        if (tsetCols == 0) continue;

        final int rows = layer.tileMap.length;
        final int cols = layer.tileMap.isNotEmpty ? layer.tileMap[0].length : 0;
        final double lx = layer.x.toDouble();
        final double ly = layer.y.toDouble();
        final double parallax = LayoutUtils.parallaxFactorForDepth(
          layer.depth,
          sensitivity: levelParallaxSensitivity,
        );
        final double parallaxDx = (vOffset.dx * (parallax - 1.0)) / vScale;
        final double parallaxDy = (vOffset.dy * (parallax - 1.0)) / vScale;
        final double drawLx = lx + parallaxDx;
        final double drawLy = ly + parallaxDy;
        final double lw = cols * tw;
        final double lh = rows * th;

        final double opacity =
            renderingTilemap && li != appData.selectedLayer ? 0.5 : 1.0;
        final int alpha = (255 * opacity).round().clamp(0, 255);
        final Paint tilePaint = Paint()
          ..color = Color.fromARGB(alpha, 255, 255, 255);

        for (int row = 0; row < rows; row++) {
          for (int col = 0; col < cols; col++) {
            final int tileIndex = layer.tileMap[row][col];
            if (tileIndex < 0) continue;

            final int tileRow = (tileIndex / tsetCols).floor();
            final int tileCol = tileIndex % tsetCols;

            canvas.drawImageRect(
              tilesetImg,
              Rect.fromLTWH(tileCol * tw, tileRow * th, tw, th),
              Rect.fromLTWH(
                drawLx + col * tw,
                drawLy + row * th,
                tw,
                th,
              ),
              tilePaint,
            );
          }
        }

        // Draw grid lines over the layer
        final Paint gridPaint = Paint()
          ..color =
              Color.fromARGB((51 * opacity).round().clamp(0, 255), 0, 0, 0)
          ..strokeWidth = 0.5
          ..style = PaintingStyle.stroke;
        for (int r = 0; r <= rows; r++) {
          canvas.drawLine(
            Offset(drawLx, drawLy + r * th),
            Offset(drawLx + lw, drawLy + r * th),
            gridPaint,
          );
        }
        for (int c = 0; c <= cols; c++) {
          canvas.drawLine(
            Offset(drawLx + c * tw, drawLy),
            Offset(drawLx + c * tw, drawLy + lh),
            gridPaint,
          );
        }

        final bool isSelectedInLayersView = renderingLayersPreview &&
            appData.selectedSection == 'layers' &&
            selectedLayerIndices.contains(li);
        final bool isSelectedInTilemapView = !renderingLayersPreview &&
            appData.selectedSection == 'tilemap' &&
            li == appData.selectedLayer;
        if (isSelectedInLayersView || isSelectedInTilemapView) {
          final Color selectedColor = isSelectedInTilemapView
              ? appData.tilesetSelectionColorForFile(layer.tilesSheetFile)
              : const Color(0xFF2196F3);
          final Paint selPaint = Paint()
            ..color = selectedColor
            ..strokeWidth = 2.0 / vScale
            ..style = PaintingStyle.stroke;
          canvas.drawRect(
            Rect.fromLTWH(drawLx + 1, drawLy + 1, lw - 2, lh - 2),
            selPaint,
          );
        }
      }

      if (appData.selectedSection == 'zones') {
        final Set<int> selectedZoneIndices = appData.selectedZoneIndices
            .where((index) => index >= 0 && index < level.zones.length)
            .toSet();
        if (appData.selectedZone >= 0 &&
            appData.selectedZone < level.zones.length) {
          selectedZoneIndices.add(appData.selectedZone);
        }
        for (int i = 0; i < level.zones.length; i++) {
          final zone = level.zones[i];
          final Rect zoneRect = Rect.fromLTWH(
            zone.x.toDouble(),
            zone.y.toDouble(),
            zone.width.toDouble(),
            zone.height.toDouble(),
          );
          final Color zoneColor = LayoutUtils.getColorFromName(zone.color);
          final Paint fillPaint = Paint()
            ..color = zoneColor.withValues(alpha: 0.5)
            ..style = PaintingStyle.fill;
          canvas.drawRect(zoneRect, fillPaint);

          if (selectedZoneIndices.contains(i)) {
            final Paint selectedPaint = Paint()
              ..color = zoneColor
              ..strokeWidth = 2.0 / vScale
              ..style = PaintingStyle.stroke;
            canvas.drawRect(zoneRect, selectedPaint);

            if (i == appData.selectedZone) {
              final double maxHandleSize = zone.width <= 0 || zone.height <= 0
                  ? 0
                  : zone.width < zone.height
                      ? zone.width.toDouble()
                      : zone.height.toDouble();
              final double handleSize = maxHandleSize <= 0
                  ? 0
                  : LayoutUtils.zoneResizeHandleSizeWorld(appData)
                      .clamp(0, maxHandleSize);
              if (handleSize > 0) {
                final double right = zoneRect.right;
                final double bottom = zoneRect.bottom;
                final Path handlePath = Path()
                  ..moveTo(right, bottom)
                  ..lineTo(right - handleSize, bottom)
                  ..lineTo(right, bottom - handleSize)
                  ..close();
                final Paint handlePaint = Paint()
                  ..color = zoneColor
                  ..style = PaintingStyle.fill;
                canvas.drawPath(handlePath, handlePaint);
              }
            }
          }
        }
      }

      if (renderingSprites) {
        final Set<int> selectedSpriteIndices = appData.selectedSpriteIndices
            .where((index) => index >= 0 && index < level.sprites.length)
            .toSet();
        if (appData.selectedSprite >= 0 &&
            appData.selectedSprite < level.sprites.length) {
          selectedSpriteIndices.add(appData.selectedSprite);
        }
        for (int i = 0; i < level.sprites.length; i++) {
          final sprite = level.sprites[i];
          final String imageFile = LayoutUtils.spriteImageFile(appData, sprite);
          if (imageFile.isEmpty ||
              !appData.imagesCache.containsKey(imageFile)) {
            continue;
          }
          final ui.Image spriteImage = appData.imagesCache[imageFile]!;
          final Size frameSize = LayoutUtils.spriteFrameSize(appData, sprite);
          final double spriteWidth = frameSize.width;
          final double spriteHeight = frameSize.height;
          if (spriteWidth <= 0 || spriteHeight <= 0) {
            continue;
          }
          final int frames =
              math.max(1, (spriteImage.width / spriteWidth).floor());
          final int frameIndex = LayoutUtils.spriteFrameIndex(
            appData: appData,
            sprite: sprite,
            totalFrames: frames,
          );
          final double spriteFrameX = frameIndex * spriteWidth;
          final double spriteParallax = LayoutUtils.parallaxFactorForDepth(
            sprite.depth,
            sensitivity: levelParallaxSensitivity,
          );
          final Rect spriteRectWorld = LayoutUtils.spriteWorldRect(
            appData,
            sprite,
            frameSize: frameSize,
          ).shift(
            Offset(
              (vOffset.dx * (spriteParallax - 1.0)) / vScale,
              (vOffset.dy * (spriteParallax - 1.0)) / vScale,
            ),
          );
          final double spriteX = spriteRectWorld.left;
          final double spriteY = spriteRectWorld.top;

          final Rect srcRect =
              Rect.fromLTWH(spriteFrameX, 0, spriteWidth, spriteHeight);
          final Rect dstRect =
              Rect.fromLTWH(spriteX, spriteY, spriteWidth, spriteHeight);
          if (sprite.flipX || sprite.flipY) {
            final double centerX = dstRect.center.dx;
            final double centerY = dstRect.center.dy;
            canvas.save();
            canvas.translate(centerX, centerY);
            canvas.scale(sprite.flipX ? -1.0 : 1.0, sprite.flipY ? -1.0 : 1.0);
            canvas.translate(-centerX, -centerY);
            canvas.drawImageRect(spriteImage, srcRect, dstRect, Paint());
            canvas.restore();
          } else {
            canvas.drawImageRect(spriteImage, srcRect, dstRect, Paint());
          }

          if (!renderingLayersPreview && selectedSpriteIndices.contains(i)) {
            final Paint selectedPaint = Paint()
              ..color = const Color(0xFF2196F3)
              ..strokeWidth = 2.0 / vScale
              ..style = PaintingStyle.stroke;
            canvas.drawRect(
              Rect.fromLTWH(spriteX, spriteY, spriteWidth, spriteHeight),
              selectedPaint,
            );
          }
        }
      }
    }

    canvas.restore();

    // Draw viewport rectangle overlay (in screen space, on top of the world)
    if (renderingViewport &&
        appData.selectedLevel != -1 &&
        appData.selectedLevel < appData.gameData.levels.length) {
      _paintViewportOverlay(canvas, size, vScale, vOffset);
    }

    // Draw axes on top (in screen space)
    _paintAxes(canvas, size, vScale, vOffset);
  }

  void _paintViewportOverlay(
      Canvas canvas, Size size, double vScale, Offset vOffset) {
    final level = appData.gameData.levels[appData.selectedLevel];
    final double vw = level.viewportWidth.toDouble();
    final double vh = level.viewportHeight.toDouble();
    final String initialColorName = _normalizedViewportColorName(
      level.viewportInitialColor,
      GameLevel.defaultViewportInitialColor,
    );
    final String previewColorName = _normalizedViewportColorName(
      level.viewportPreviewColor,
      GameLevel.defaultViewportPreviewColor,
    );
    final Color initialColor = LayoutUtils.getColorFromName(initialColorName);
    final Color previewColor = LayoutUtils.getColorFromName(previewColorName);

    // Initial position overlay (not draggable).
    _paintViewportRect(
      canvas,
      vScale,
      vOffset,
      wx: level.viewportX.toDouble(),
      wy: level.viewportY.toDouble(),
      ww: vw,
      wh: vh,
      fillColor: initialColor.withValues(alpha: 0.08),
      borderColor: initialColor,
      label: 'Initial: ${level.viewportX}, ${level.viewportY}',
      labelColor: initialColor,
      showResizeHandle: false,
    );

    // Preview position overlay (draggable).
    _paintViewportRect(
      canvas,
      vScale,
      vOffset,
      wx: appData.viewportPreviewX.toDouble(),
      wy: appData.viewportPreviewY.toDouble(),
      ww: appData.viewportPreviewWidth.toDouble(),
      wh: appData.viewportPreviewHeight.toDouble(),
      fillColor: previewColor.withValues(alpha: 0.1),
      borderColor: previewColor,
      label:
          'Preview: ${appData.viewportPreviewX}, ${appData.viewportPreviewY} | ${appData.viewportPreviewWidth}x${appData.viewportPreviewHeight}',
      labelColor: previewColor,
      showResizeHandle: true,
    );
  }

  String _normalizedViewportColorName(String colorName, String fallback) {
    final String normalized = colorName.trim();
    if (GameLevel.viewportColorPalette.contains(normalized)) {
      return normalized;
    }
    return fallback;
  }

  void _paintViewportRect(
    Canvas canvas,
    double vScale,
    Offset vOffset, {
    required double wx,
    required double wy,
    required double ww,
    required double wh,
    required Color fillColor,
    required Color borderColor,
    required String label,
    required Color labelColor,
    required bool showResizeHandle,
  }) {
    final double sx = vOffset.dx + wx * vScale;
    final double sy = vOffset.dy + wy * vScale;
    final double sw = ww * vScale;
    final double sh = wh * vScale;
    final Rect screenRect = Rect.fromLTWH(sx, sy, sw, sh);

    canvas.drawRect(
        screenRect,
        Paint()
          ..color = fillColor
          ..style = PaintingStyle.fill);
    canvas.drawRect(
        screenRect,
        Paint()
          ..color = borderColor
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke);

    if (showResizeHandle) {
      final double handleSize =
          (LayoutUtils.viewportResizeHandleSizeWorld(appData) * vScale)
              .clamp(0, sw < sh ? sw : sh);
      if (handleSize > 0) {
        final double right = sx + sw;
        final double bottom = sy + sh;
        final Path handlePath = Path()
          ..moveTo(right, bottom)
          ..lineTo(right - handleSize, bottom)
          ..lineTo(right, bottom - handleSize)
          ..close();
        final Paint handlePaint = Paint()
          ..color = borderColor
          ..style = PaintingStyle.fill;
        canvas.drawPath(handlePath, handlePaint);
      }
    }

    _drawLabel(
      canvas,
      label,
      Offset(sx + 4, sy + 4),
      TextStyle(color: labelColor, fontSize: 9.0, fontFamily: 'monospace'),
    );
  }

  void _paintAxes(Canvas canvas, Size size, double vScale, Offset vOffset) {
    // World origin in screen space
    final double ox = vOffset.dx;
    final double oy = vOffset.dy;

    const double axisThickness = 1.5;
    const double tickLen = 5.0;
    const double labelFontSize = 9.0;
    const double minTickSpacingPx = 40.0;

    // Choose a world-space tick interval that gives reasonable screen spacing
    double worldTickInterval = 32.0;
    while (worldTickInterval * vScale < minTickSpacingPx) {
      worldTickInterval *= 2;
    }
    while (worldTickInterval * vScale > minTickSpacingPx * 4) {
      worldTickInterval /= 2;
    }

    final Paint axisPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.55)
      ..strokeWidth = axisThickness
      ..style = PaintingStyle.stroke;

    final Paint tickPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.45)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final textStyle = TextStyle(
      color: Colors.grey.shade500,
      fontSize: labelFontSize,
      fontFamily: 'monospace',
    );

    // ── X axis ──────────────────────────────────────────────────────────────
    // Clamp axis line to visible area
    final double axisY = oy.clamp(0.0, size.height);
    canvas.drawLine(Offset(0, axisY), Offset(size.width, axisY), axisPaint);

    // Ticks and labels along X
    final double firstWorldX =
        ((-ox / vScale) / worldTickInterval).ceil() * worldTickInterval;
    double worldX = firstWorldX;
    while (true) {
      final double screenX = ox + worldX * vScale;
      if (screenX > size.width + 1) break;
      if (screenX >= -1) {
        canvas.drawLine(
          Offset(screenX, axisY - tickLen),
          Offset(screenX, axisY + tickLen),
          tickPaint,
        );
        if (worldX != 0) {
          _drawLabel(
            canvas,
            worldX.toInt().toString(),
            Offset(screenX + 2, axisY + tickLen + 1),
            textStyle,
          );
        }
      }
      worldX += worldTickInterval;
    }

    // ── Y axis ──────────────────────────────────────────────────────────────
    final double axisX = ox.clamp(0.0, size.width);
    canvas.drawLine(Offset(axisX, 0), Offset(axisX, size.height), axisPaint);

    // Ticks and labels along Y
    final double firstWorldY =
        ((-oy / vScale) / worldTickInterval).ceil() * worldTickInterval;
    double worldY = firstWorldY;
    while (true) {
      final double screenY = oy + worldY * vScale;
      if (screenY > size.height + 1) break;
      if (screenY >= -1) {
        canvas.drawLine(
          Offset(axisX - tickLen, screenY),
          Offset(axisX + tickLen, screenY),
          tickPaint,
        );
        if (worldY != 0) {
          _drawLabel(
            canvas,
            worldY.toInt().toString(),
            Offset(axisX + tickLen + 2, screenY - labelFontSize - 1),
            textStyle,
          );
        }
      }
      worldY += worldTickInterval;
    }

    // ── Origin label ────────────────────────────────────────────────────────
    _drawLabel(
      canvas,
      '0',
      Offset(axisX + 3, axisY + 3),
      textStyle,
    );
  }

  void _drawLabel(
      Canvas canvas, String text, Offset position, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, position);
  }

  @override
  bool shouldRepaint(covariant CanvasPainter oldDelegate) {
    return true;
  }
}
