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
    double parallaxSensitivity = GamesToolApi.defaultParallaxSensitivity,
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
    return drawAnimatedSprite(
      canvas: canvas,
      painterSize: painterSize,
      gameData: gameData,
      gamesTool: gamesTool,
      imagesCache: imagesCache,
      sprite: sprite,
      camera: camera,
      elapsedSeconds: elapsedSeconds,
      parallaxSensitivity: parallaxSensitivity,
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
    double depth = 0,
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
        depth: depth,
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
      depth: depth,
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
}
