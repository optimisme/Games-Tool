import 'dart:math' as math;
import 'dart:ui' as ui;

import 'project_data_api.dart';
import 'runtime_math.dart';
import 'runtime_models.dart';

class GamesToolRuntimeRenderer {
  const GamesToolRuntimeRenderer._();

  static double levelParallaxSensitivity({
    required GamesToolApi gamesTool,
    Map<String, dynamic>? level,
    double fallback = GamesToolApi.defaultParallaxSensitivity,
  }) {
    if (level == null) {
      return fallback;
    }
    return gamesTool.levelParallaxSensitivity(level, fallback: fallback);
  }

  static double cameraScale({
    required ui.Size viewportSize,
    required RuntimeCamera2D camera,
  }) {
    return RuntimeCameraMath.cameraScaleForViewport(
      viewportSize: viewportSize,
      focal: camera.focal,
    );
  }

  static ui.Offset worldToScreen({
    required double worldX,
    required double worldY,
    required ui.Size viewportSize,
    required RuntimeCamera2D camera,
    double depth = 0,
    double parallaxSensitivity = GamesToolApi.defaultParallaxSensitivity,
  }) {
    return RuntimeCameraMath.worldToScreen(
      worldX: worldX,
      worldY: worldY,
      camera: camera,
      viewportSize: viewportSize,
      depth: depth,
      parallaxSensitivity: parallaxSensitivity,
    );
  }

  static RuntimeLevelViewport levelViewport({
    required GamesToolApi gamesTool,
    required Map<String, dynamic>? level,
    double fallbackWidth = GamesToolApi.defaultViewportWidth,
    double fallbackHeight = GamesToolApi.defaultViewportHeight,
    String fallbackAdaptation = GamesToolApi.defaultViewportAdaptation,
  }) {
    if (level == null) {
      return RuntimeLevelViewport(
        width: fallbackWidth,
        height: fallbackHeight,
        x: 0,
        y: 0,
        adaptation: fallbackAdaptation,
      );
    }
    return RuntimeLevelViewport(
      width: gamesTool.levelViewportWidth(level, fallback: fallbackWidth),
      height: gamesTool.levelViewportHeight(level, fallback: fallbackHeight),
      x: gamesTool.levelViewportX(level),
      y: gamesTool.levelViewportY(level),
      adaptation: gamesTool.levelViewportAdaptation(level,
          fallback: fallbackAdaptation),
      initialColorName: gamesTool.levelViewportInitialColorName(level),
      previewColorName: gamesTool.levelViewportPreviewColorName(level),
    );
  }

  static RuntimeViewportLayout resolveViewportLayout({
    required ui.Size painterSize,
    required RuntimeLevelViewport viewport,
  }) {
    final double viewportWidth = viewport.width > 0 ? viewport.width : 1;
    final double viewportHeight = viewport.height > 0 ? viewport.height : 1;
    if (painterSize.width <= 0 || painterSize.height <= 0) {
      return RuntimeViewportLayout(
        virtualSize: ui.Size(viewportWidth, viewportHeight),
        destinationRect: ui.Rect.zero,
        scaleX: 0,
        scaleY: 0,
      );
    }

    final String adaptation = _normalizeViewportAdaptation(viewport.adaptation);
    ui.Size virtualSize = ui.Size(viewportWidth, viewportHeight);
    ui.Rect destinationRect = ui.Rect.fromLTWH(
      0,
      0,
      painterSize.width,
      painterSize.height,
    );

    if (adaptation == 'letterbox') {
      final double screenAspect = painterSize.width / painterSize.height;
      final double viewportAspect = viewportWidth / viewportHeight;
      if (viewportAspect > screenAspect) {
        final double outputHeight = painterSize.width / viewportAspect;
        destinationRect = ui.Rect.fromLTWH(
          0,
          (painterSize.height - outputHeight) / 2,
          painterSize.width,
          outputHeight,
        );
      } else {
        final double outputWidth = painterSize.height * viewportAspect;
        destinationRect = ui.Rect.fromLTWH(
          (painterSize.width - outputWidth) / 2,
          0,
          outputWidth,
          painterSize.height,
        );
      }
    } else if (adaptation == 'expand') {
      final double screenAspect = painterSize.width / painterSize.height;
      final double viewportAspect = viewportWidth / viewportHeight;
      if (screenAspect > viewportAspect) {
        virtualSize = ui.Size(viewportHeight * screenAspect, viewportHeight);
      } else {
        virtualSize = ui.Size(viewportWidth, viewportWidth / screenAspect);
      }
    }

    final double scaleX = destinationRect.width / virtualSize.width;
    final double scaleY = destinationRect.height / virtualSize.height;

    return RuntimeViewportLayout(
      virtualSize: virtualSize,
      destinationRect: destinationRect,
      scaleX: scaleX,
      scaleY: scaleY,
    );
  }

  static RuntimeViewportLayout withViewport({
    required ui.Canvas canvas,
    required ui.Size painterSize,
    required RuntimeLevelViewport viewport,
    required void Function(ui.Size viewportSize) drawInViewport,
    ui.Color outerBackgroundColor = const ui.Color(0xFF000000),
    bool clearOuterBackground = true,
    bool clipToViewport = true,
  }) {
    final RuntimeViewportLayout layout = resolveViewportLayout(
      painterSize: painterSize,
      viewport: viewport,
    );
    if (clearOuterBackground) {
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, painterSize.width, painterSize.height),
        ui.Paint()..color = outerBackgroundColor,
      );
    }
    if (!layout.hasVisibleArea || layout.scaleX == 0 || layout.scaleY == 0) {
      return layout;
    }

    canvas.save();
    if (clipToViewport) {
      canvas.clipRect(layout.destinationRect);
    }
    canvas.translate(layout.destinationRect.left, layout.destinationRect.top);
    canvas.scale(layout.scaleX, layout.scaleY);
    drawInViewport(layout.virtualSize);
    canvas.restore();
    return layout;
  }

  static ui.Color colorFromName(
    String? colorName, {
    ui.Color fallback = const ui.Color(0xFF000000),
  }) {
    final String normalized = colorName?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty) {
      return fallback;
    }
    if (normalized.startsWith('#')) {
      final String hex = normalized.substring(1);
      if (hex.length == 6) {
        final int? value = int.tryParse(hex, radix: 16);
        if (value != null) {
          return ui.Color(0xFF000000 | value);
        }
      } else if (hex.length == 8) {
        final int? value = int.tryParse(hex, radix: 16);
        if (value != null) {
          return ui.Color(value);
        }
      }
    }

    switch (normalized) {
      case 'black':
        return const ui.Color(0xFF000000);
      case 'white':
        return const ui.Color(0xFFFFFFFF);
      case 'red':
        return const ui.Color(0xFFD80000);
      case 'green':
        return const ui.Color(0xFF00B600);
      case 'blue':
        return const ui.Color(0xFF007AFF);
      case 'yellow':
        return const ui.Color(0xFFFFCC00);
      case 'amber':
        return const ui.Color(0xFFFFB300);
      case 'orange':
        return const ui.Color(0xFFFF9500);
      case 'pink':
        return const ui.Color(0xFFFF2D55);
      case 'purple':
        return const ui.Color(0xFFAF52DE);
      case 'teal':
        return const ui.Color(0xFF30B0C7);
      case 'cyan':
        return const ui.Color(0xFF32ADE6);
      case 'indigo':
        return const ui.Color(0xFF5856D6);
      case 'brown':
        return const ui.Color(0xFFA2845E);
      case 'gray':
      case 'grey':
        return const ui.Color(0xFF8E8E93);
      default:
        return fallback;
    }
  }

  static ui.Color levelBackgroundColor({
    required GamesToolApi gamesTool,
    required Map<String, dynamic>? level,
    ui.Color fallback = const ui.Color(0xFF000000),
  }) {
    if (level == null) {
      return fallback;
    }
    final String hex = gamesTool.levelBackgroundColorHex(level);
    return colorFromName(hex, fallback: fallback);
  }

  static void drawLevelTileLayers({
    required ui.Canvas canvas,
    required ui.Size painterSize,
    required Map<String, dynamic> level,
    required GamesToolApi gamesTool,
    required Map<String, ui.Image> imagesCache,
    required RuntimeCamera2D camera,
    ui.Color backgroundColor = const ui.Color(0xFF000000),
    double parallaxSensitivity = GamesToolApi.defaultParallaxSensitivity,
  }) {
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, painterSize.width, painterSize.height),
      ui.Paint()..color = backgroundColor,
    );

    final double scale = cameraScale(viewportSize: painterSize, camera: camera);
    if (scale == 0) {
      return;
    }

    final List<Map<String, dynamic>> layers = gamesTool.listLevelLayers(
      level,
      visibleOnly: true,
      painterOrder: true,
    );

    for (final Map<String, dynamic> layer in layers) {
      final List<List<dynamic>> tileMap = gamesTool.layerTileMapRows(layer);
      if (tileMap.isEmpty) {
        continue;
      }

      final String? tilesSheetFile = gamesTool.layerTilesSheetFile(layer);
      if (tilesSheetFile == null) {
        continue;
      }

      final String tileSheetPath = gamesTool.toRelativeAssetKey(tilesSheetFile);
      final ui.Image? tileSheet = imagesCache[tileSheetPath];
      if (tileSheet == null) {
        continue;
      }

      final double tileW = gamesTool.layerTilesWidth(layer);
      final double tileH = gamesTool.layerTilesHeight(layer);
      if (tileW <= 0 || tileH <= 0) {
        continue;
      }
      final int tileSheetCols = (tileSheet.width / tileW).floor();
      if (tileSheetCols <= 0) {
        continue;
      }

      final double layerDepth = gamesTool.layerDepth(layer);
      final double parallax = RuntimeCameraMath.parallaxFactorForDepth(
        layerDepth,
        sensitivity: parallaxSensitivity,
      );
      final double camX = camera.x * parallax;
      final double camY = camera.y * parallax;
      final double layerX = gamesTool.layerX(layer);
      final double layerY = gamesTool.layerY(layer);
      final ui.Rect? viewportWorldRect = RuntimeCameraMath.worldViewportRect(
        camera: camera,
        viewportSize: painterSize,
        depth: layerDepth,
        parallaxSensitivity: parallaxSensitivity,
        paddingWorld: math.max(tileW, tileH),
      );
      if (viewportWorldRect == null) {
        continue;
      }
      final int rawRowStart =
          ((viewportWorldRect.top - layerY) / tileH).floor() - 1;
      final int rawRowEnd =
          ((viewportWorldRect.bottom - layerY) / tileH).ceil();
      final int rowStart = rawRowStart.clamp(0, tileMap.length - 1).toInt();
      final int rowEnd = rawRowEnd.clamp(0, tileMap.length - 1).toInt();
      if (rowEnd < rowStart) {
        continue;
      }
      final int rawColStart =
          ((viewportWorldRect.left - layerX) / tileW).floor() - 1;
      final int rawColEnd = ((viewportWorldRect.right - layerX) / tileW).ceil();

      for (int row = rowStart; row <= rowEnd; row++) {
        final List<dynamic> rowData = tileMap[row];
        if (rowData.isEmpty) {
          continue;
        }
        final int colStart = rawColStart.clamp(0, rowData.length - 1).toInt();
        final int colEnd = rawColEnd.clamp(0, rowData.length - 1).toInt();
        if (colEnd < colStart) {
          continue;
        }
        for (int col = colStart; col <= colEnd; col++) {
          final int tileIndex = (rowData[col] as num?)?.toInt() ?? -1;
          if (tileIndex < 0) {
            continue;
          }

          final double worldX = layerX + col * tileW;
          final double worldY = layerY + row * tileH;
          final double screenX =
              (worldX - camX) * scale + painterSize.width / 2;
          final double screenY =
              (worldY - camY) * scale + painterSize.height / 2;
          final double destWidth = tileW * scale;
          final double destHeight = tileH * scale;

          final int srcCol = tileIndex % tileSheetCols;
          final int srcRow = tileIndex ~/ tileSheetCols;
          final double srcX = srcCol * tileW;
          final double srcY = srcRow * tileH;

          canvas.drawImageRect(
            tileSheet,
            ui.Rect.fromLTWH(srcX, srcY, tileW, tileH),
            ui.Rect.fromLTWH(
              screenX - 1,
              screenY - 1,
              destWidth + 1,
              destHeight + 1,
            ),
            ui.Paint(),
          );
        }
      }
    }
  }

  static bool drawAnimatedSpriteByType({
    required ui.Canvas canvas,
    required ui.Size painterSize,
    required Map<String, dynamic> gameData,
    required Map<String, dynamic> level,
    required GamesToolApi gamesTool,
    required Map<String, ui.Image> imagesCache,
    required RuntimeCamera2D camera,
    required String spriteType,
    required double elapsedSeconds,
    double? depth,
    double? parallaxSensitivity,
    bool cullWhenOffscreen = true,
    int? frameIndex,
    double fallbackFps = GamesToolApi.defaultAnimationFps,
  }) {
    final Map<String, dynamic>? sprite = gamesTool.findSpriteByType(
      level,
      spriteType,
    );
    if (sprite == null) {
      return false;
    }
    final double resolvedParallaxSensitivity = parallaxSensitivity ??
        gamesTool.levelParallaxSensitivity(
          level,
          fallback: GamesToolApi.defaultParallaxSensitivity,
        );
    return drawAnimatedSprite(
      canvas: canvas,
      painterSize: painterSize,
      gameData: gameData,
      gamesTool: gamesTool,
      imagesCache: imagesCache,
      sprite: sprite,
      camera: camera,
      elapsedSeconds: elapsedSeconds,
      depth: depth,
      parallaxSensitivity: resolvedParallaxSensitivity,
      cullWhenOffscreen: cullWhenOffscreen,
      frameIndex: frameIndex,
      fallbackFps: fallbackFps,
    );
  }

  static bool drawAnimatedSprite({
    required ui.Canvas canvas,
    required ui.Size painterSize,
    required Map<String, dynamic> gameData,
    required GamesToolApi gamesTool,
    required Map<String, ui.Image> imagesCache,
    required Map<String, dynamic> sprite,
    required RuntimeCamera2D camera,
    required double elapsedSeconds,
    String? animationName,
    double? worldX,
    double? worldY,
    bool? flipX,
    bool? flipY,
    double? drawWidthWorld,
    double? drawHeightWorld,
    double? depth,
    double parallaxSensitivity = GamesToolApi.defaultParallaxSensitivity,
    bool cullWhenOffscreen = true,
    int? frameIndex,
    double fallbackFps = GamesToolApi.defaultAnimationFps,
  }) {
    final Map<String, dynamic>? animationData =
        (animationName != null && animationName.isNotEmpty)
            ? gamesTool.findAnimationByName(gameData, animationName)
            : gamesTool.findAnimationForSprite(gameData, sprite);
    if (animationName != null &&
        animationName.isNotEmpty &&
        animationData == null) {
      return false;
    }

    final String? imageFile = animationData == null
        ? gamesTool.spriteImageFile(sprite)
        : (animationData['mediaFile'] as String?);
    if (imageFile == null || imageFile.isEmpty) {
      return false;
    }

    final String spritePath = gamesTool.toRelativeAssetKey(imageFile);
    final ui.Image? spriteImg = imagesCache[spritePath];
    if (spriteImg == null) {
      return false;
    }

    final Map<String, dynamic>? mediaAsset = gamesTool.findMediaAssetByFile(
      gameData,
      imageFile,
    );
    final double frameWidth = mediaAsset == null
        ? gamesTool.spriteWidth(sprite)
        : gamesTool.mediaTileWidth(
            mediaAsset,
            fallback: gamesTool.spriteWidth(sprite),
          );
    final double frameHeight = mediaAsset == null
        ? gamesTool.spriteHeight(sprite)
        : gamesTool.mediaTileHeight(
            mediaAsset,
            fallback: gamesTool.spriteHeight(sprite),
          );
    if (frameWidth <= 0 || frameHeight <= 0) {
      return false;
    }

    final int columns = (spriteImg.width / frameWidth).floor();
    final int rows = (spriteImg.height / frameHeight).floor();
    if (columns <= 0 || rows <= 0) {
      return false;
    }
    final int totalFrames = columns * rows;

    final int rawFrameIndex = frameIndex ??
        (animationData == null
            ? (elapsedSeconds * fallbackFps).floor()
            : gamesTool.animationFrameIndexAtTime(
                playback: gamesTool.animationPlaybackConfig(animationData),
                elapsedSeconds: elapsedSeconds,
              ));
    final int resolvedFrameIndex = rawFrameIndex % totalFrames;
    final int srcCol = resolvedFrameIndex % columns;
    final int srcRow = resolvedFrameIndex ~/ columns;
    final ui.Rect srcRect = ui.Rect.fromLTWH(
      srcCol * frameWidth,
      srcRow * frameHeight,
      frameWidth,
      frameHeight,
    );

    final double anchorX = animationData == null
        ? GamesToolApi.defaultAnchorX
        : gamesTool.animationAnchorXForFrame(
            animationData,
            frameIndex: resolvedFrameIndex,
          );
    final double anchorY = animationData == null
        ? GamesToolApi.defaultAnchorY
        : gamesTool.animationAnchorYForFrame(
            animationData,
            frameIndex: resolvedFrameIndex,
          );
    final bool resolvedFlipX = flipX ?? (sprite['flipX'] == true);
    final bool resolvedFlipY = flipY ?? (sprite['flipY'] == true);
    final double resolvedDepth = depth ?? gamesTool.spriteDepth(sprite);
    final double resolvedWorldX = worldX ?? gamesTool.spriteX(sprite);
    final double resolvedWorldY = worldY ?? gamesTool.spriteY(sprite);
    final double resolvedDrawWidthWorld = drawWidthWorld ?? frameWidth;
    final double resolvedDrawHeightWorld = drawHeightWorld ?? frameHeight;
    if (resolvedDrawWidthWorld <= 0 || resolvedDrawHeightWorld <= 0) {
      return false;
    }

    if (cullWhenOffscreen) {
      final ui.Rect? worldViewportRect = RuntimeCameraMath.worldViewportRect(
        camera: camera,
        viewportSize: painterSize,
        depth: resolvedDepth,
        parallaxSensitivity: parallaxSensitivity,
        paddingWorld: math.max(
          resolvedDrawWidthWorld,
          resolvedDrawHeightWorld,
        ),
      );
      if (worldViewportRect == null) {
        return false;
      }
      final ui.Rect spriteWorldRect = ui.Rect.fromLTWH(
        resolvedWorldX - resolvedDrawWidthWorld * anchorX,
        resolvedWorldY - resolvedDrawHeightWorld * anchorY,
        resolvedDrawWidthWorld,
        resolvedDrawHeightWorld,
      );
      if (!_rectsIntersect(spriteWorldRect, worldViewportRect)) {
        return true;
      }
    }

    final ui.Offset screenPos = worldToScreen(
      worldX: resolvedWorldX,
      worldY: resolvedWorldY,
      viewportSize: painterSize,
      camera: camera,
      depth: resolvedDepth,
      parallaxSensitivity: parallaxSensitivity,
    );
    final double scale = cameraScale(viewportSize: painterSize, camera: camera);
    if (scale == 0) {
      return false;
    }
    final double destWidth = resolvedDrawWidthWorld * scale;
    final double destHeight = resolvedDrawHeightWorld * scale;

    canvas.save();
    canvas.translate(screenPos.dx, screenPos.dy);
    canvas.scale(resolvedFlipX ? -1.0 : 1.0, resolvedFlipY ? -1.0 : 1.0);
    canvas.drawImageRect(
      spriteImg,
      srcRect,
      ui.Rect.fromLTWH(
        -destWidth * anchorX,
        -destHeight * anchorY,
        destWidth,
        destHeight,
      ),
      ui.Paint()..filterQuality = ui.FilterQuality.none,
    );
    canvas.restore();
    return true;
  }

  static bool _rectsIntersect(ui.Rect a, ui.Rect b) {
    return a.left < b.right &&
        a.right > b.left &&
        a.top < b.bottom &&
        a.bottom > b.top;
  }

  static String _normalizeViewportAdaptation(String adaptation) {
    final String normalized = adaptation.trim().toLowerCase();
    switch (normalized) {
      case 'fit':
      case 'contain':
      case 'letterbox':
        return 'letterbox';
      case 'expand':
        return 'expand';
      case 'stretch':
      case 'strech':
        return 'stretch';
      default:
        return GamesToolApi.defaultViewportAdaptation;
    }
  }
}
