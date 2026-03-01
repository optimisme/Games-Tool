import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'app_data.dart';
import 'camera.dart';
import 'utils_gamestool.dart';

class CameraScale {
  const CameraScale({required this.camera, required this.scale});

  final Camera camera;
  final double scale;
}

class CommonRenderer {
  const CommonRenderer._();
  static const double _minParallaxFactor = 0.25;
  static const double _maxParallaxFactor = 4.0;

  static CameraScale getCameraScale(Size painterSize, Camera camera) {
    final double scale = painterSize.width / camera.focal;
    return CameraScale(camera: camera, scale: scale);
  }

  // Mirror games_tool behaviour:
  // negative depth => closer (moves faster), positive depth => farther.
  static double parallaxFactorForDepth(
    double depth, {
    double sensitivity = GamesToolApi.defaultParallaxSensitivity,
  }) {
    final double safeSensitivity = sensitivity.isFinite && sensitivity >= 0
        ? sensitivity
        : GamesToolApi.defaultParallaxSensitivity;
    final double factor = math.exp(-depth * safeSensitivity);
    return factor.clamp(_minParallaxFactor, _maxParallaxFactor).toDouble();
  }

  static Offset worldToScreen(
    double worldX,
    double worldY,
    Size painterSize,
    Camera camera, {
    double depth = 0,
    double parallaxSensitivity = GamesToolApi.defaultParallaxSensitivity,
  }) {
    final CameraScale camData = getCameraScale(painterSize, camera);
    final double parallax = parallaxFactorForDepth(
      depth,
      sensitivity: parallaxSensitivity,
    );
    final double camX = camData.camera.x * parallax;
    final double camY = camData.camera.y * parallax;

    return Offset(
      (worldX - camX) * camData.scale + painterSize.width / 2,
      (worldY - camY) * camData.scale + painterSize.height / 2,
    );
  }

  static void drawLevelTileLayers({
    required Canvas canvas,
    required Size painterSize,
    required Map<String, dynamic> level,
    required AppData appData,
    required Camera camera,
    Color backgroundColor = Colors.black,
    double parallaxSensitivity = GamesToolApi.defaultParallaxSensitivity,
  }) {
    final Paint paint = Paint()..color = backgroundColor;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, painterSize.width, painterSize.height),
      paint,
    );

    final CameraScale camData = getCameraScale(painterSize, camera);
    final List<Map<String, dynamic>> layers = appData.gamesTool.listLevelLayers(
      level,
      visibleOnly: true,
      painterOrder: true,
    );

    for (final Map<String, dynamic> layer in layers) {
      final double depth = appData.gamesTool.layerDepth(layer);
      final double parallax = parallaxFactorForDepth(
        depth,
        sensitivity: parallaxSensitivity,
      );
      final double camX = camData.camera.x * parallax;
      final double camY = camData.camera.y * parallax;
      final double layerX = appData.gamesTool.layerX(layer);
      final double layerY = appData.gamesTool.layerY(layer);
      final List<List<dynamic>> tileMap = appData.gamesTool.layerTileMapRows(
        layer,
      );
      if (tileMap.isEmpty) {
        continue;
      }

      final double tileW = appData.gamesTool.layerTilesWidth(layer);
      final double tileH = appData.gamesTool.layerTilesHeight(layer);

      final String? tilesSheetFile = appData.gamesTool.layerTilesSheetFile(
        layer,
      );
      if (tilesSheetFile == null) {
        continue;
      }

      final String tileSheetPath = appData.gamesTool.toRelativeAssetKey(
        tilesSheetFile,
      );

      if (!appData.imagesCache.containsKey(tileSheetPath)) {
        continue;
      }

      final ui.Image tileSheet = appData.imagesCache[tileSheetPath]!;
      final int tileSheetCols = (tileSheet.width / tileW).floor();

      for (int row = 0; row < tileMap.length; row++) {
        final List<dynamic> rowData = tileMap[row];
        for (int col = 0; col < rowData.length; col++) {
          final int tileIndex = (rowData[col] as num?)?.toInt() ?? -1;
          if (tileIndex < 0) {
            continue;
          }

          final double worldX = layerX + col * tileW;
          final double worldY = layerY + row * tileH;
          final double screenX =
              (worldX - camX) * camData.scale + painterSize.width / 2;
          final double screenY =
              (worldY - camY) * camData.scale + painterSize.height / 2;
          final double destWidth = tileW * camData.scale;
          final double destHeight = tileH * camData.scale;

          final int srcCol = tileIndex % tileSheetCols;
          final int srcRow = tileIndex ~/ tileSheetCols;
          final double srcX = srcCol * tileW;
          final double srcY = srcRow * tileH;

          canvas.drawImageRect(
            tileSheet,
            Rect.fromLTWH(srcX, srcY, tileW, tileH),
            Rect.fromLTWH(
              screenX - 1,
              screenY - 1,
              destWidth + 1,
              destHeight + 1,
            ),
            Paint(),
          );
        }
      }
    }
  }

  static void drawAnimatedFlag({
    required Canvas canvas,
    required Size painterSize,
    required Map<String, dynamic> level,
    required AppData appData,
    required Camera camera,
    required int tickCounter,
    double parallaxSensitivity = GamesToolApi.defaultParallaxSensitivity,
  }) {
    final Map<String, dynamic>? flagSprite = appData.gamesTool.findSpriteByType(
      level,
      'flag',
    );
    if (flagSprite == null) {
      return;
    }

    final Map<String, dynamic>? animationData =
        appData.gamesTool.findAnimationForSprite(appData.gameData, flagSprite);
    final String? imageFile = animationData == null
        ? appData.gamesTool.spriteImageFile(flagSprite)
        : (animationData['mediaFile'] as String?);
    if (imageFile == null || imageFile.isEmpty) {
      return;
    }

    final String spritePath = appData.gamesTool.toRelativeAssetKey(imageFile);
    if (!appData.imagesCache.containsKey(spritePath)) {
      return;
    }

    final ui.Image spriteImg = appData.imagesCache[spritePath]!;
    final Map<String, dynamic>? mediaAsset =
        appData.gamesTool.findMediaAssetByFile(
      appData.gameData,
      imageFile,
    );
    final double spriteWidth = mediaAsset == null
        ? appData.gamesTool.spriteWidth(flagSprite)
        : appData.gamesTool.mediaTileWidth(
            mediaAsset,
            fallback: appData.gamesTool.spriteWidth(flagSprite),
          );
    final double spriteHeight = mediaAsset == null
        ? appData.gamesTool.spriteHeight(flagSprite)
        : appData.gamesTool.mediaTileHeight(
            mediaAsset,
            fallback: appData.gamesTool.spriteHeight(flagSprite),
          );
    if (spriteWidth <= 0 || spriteHeight <= 0) {
      return;
    }

    final int columns = (spriteImg.width / spriteWidth).floor();
    if (columns <= 0) {
      return;
    }
    final int rows = (spriteImg.height / spriteHeight).floor();
    if (rows <= 0) {
      return;
    }
    final int totalFrames = columns * rows;

    final int rawFrameIndex = animationData == null
        ? tickCounter
        : appData.gamesTool.animationFrameIndexAtTime(
            playback: appData.gamesTool.animationPlaybackConfig(animationData),
            elapsedSeconds: tickCounter / 60.0,
          );
    final int frameIndex = rawFrameIndex % totalFrames;
    final int srcCol = frameIndex % columns;
    final int srcRow = frameIndex ~/ columns;
    final Rect srcRect = Rect.fromLTWH(
      srcCol * spriteWidth,
      srcRow * spriteHeight,
      spriteWidth,
      spriteHeight,
    );

    final double anchorX = animationData == null
        ? GamesToolApi.defaultAnchorX
        : appData.gamesTool.animationAnchorXForFrame(
            animationData,
            frameIndex: frameIndex,
          );
    final double anchorY = animationData == null
        ? GamesToolApi.defaultAnchorY
        : appData.gamesTool.animationAnchorYForFrame(
            animationData,
            frameIndex: frameIndex,
          );
    final bool flipX = flagSprite['flipX'] == true;
    final bool flipY = flagSprite['flipY'] == true;

    final Offset screenPos = worldToScreen(
      appData.gamesTool.spriteX(flagSprite),
      appData.gamesTool.spriteY(flagSprite),
      painterSize,
      camera,
      parallaxSensitivity: parallaxSensitivity,
    );

    final CameraScale camData = getCameraScale(painterSize, camera);
    final double destWidth = spriteWidth * camData.scale;
    final double destHeight = spriteHeight * camData.scale;
    final Paint paint = Paint()..filterQuality = FilterQuality.none;

    canvas.save();
    canvas.translate(screenPos.dx, screenPos.dy);
    canvas.scale(flipX ? -1.0 : 1.0, flipY ? -1.0 : 1.0);
    canvas.drawImageRect(
      spriteImg,
      srcRect,
      Rect.fromLTWH(
        -destWidth * anchorX,
        -destHeight * anchorY,
        destWidth,
        destHeight,
      ),
      paint,
    );
    canvas.restore();
  }

  static void drawSpriteFromSheet(
    Canvas canvas,
    ui.Image spriteSheet,
    Rect srcRect,
    Offset destPos,
    Size destSize,
  ) {
    canvas.drawImageRect(
      spriteSheet,
      srcRect,
      Rect.fromLTWH(destPos.dx, destPos.dy, destSize.width, destSize.height),
      Paint(),
    );
  }

  static Offset arrowTile(String direction) {
    switch (direction) {
      case 'left':
        return const Offset(64, 0);
      case 'upLeft':
        return const Offset(128, 0);
      case 'up':
        return const Offset(192, 0);
      case 'upRight':
        return const Offset(256, 0);
      case 'right':
        return const Offset(320, 0);
      case 'downRight':
        return const Offset(384, 0);
      case 'down':
        return const Offset(448, 0);
      case 'downLeft':
        return const Offset(512, 0);
      default:
        return Offset.zero;
    }
  }

  static Color colorFromString(String color) {
    switch (color.toLowerCase()) {
      case 'gray':
        return Colors.grey;
      case 'green':
        return const Color.fromARGB(255, 0, 121, 4);
      case 'blue':
        return Colors.blue;
      case 'orange':
        return Colors.orange;
      case 'red':
        return Colors.red;
      case 'purple':
        return Colors.purple;
      case 'black':
        return Colors.black;
      default:
        return Colors.black;
    }
  }

  static void drawConnectionIndicator(
    Canvas canvas,
    Size painterSize,
    bool isConnected,
  ) {
    final Paint paint = Paint()
      ..color = isConnected ? Colors.green : Colors.red;
    canvas.drawCircle(Offset(painterSize.width - 10, 10), 5, paint);
  }
}
