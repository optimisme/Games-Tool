import 'dart:math' as math;
import 'dart:ui';

import 'project_data_api.dart';
import 'runtime_models.dart';

class RuntimeCameraMath {
  const RuntimeCameraMath._();

  static const double minParallaxFactor = 0.25;
  static const double maxParallaxFactor = 4.0;

  static double parallaxFactorForDepth(
    double depth, {
    double sensitivity = GamesToolApi.defaultParallaxSensitivity,
  }) {
    final double safeSensitivity = sensitivity.isFinite && sensitivity >= 0
        ? sensitivity
        : GamesToolApi.defaultParallaxSensitivity;
    final double factor = math.exp(-depth * safeSensitivity);
    return factor.clamp(minParallaxFactor, maxParallaxFactor).toDouble();
  }

  static double cameraScaleForViewport({
    required Size viewportSize,
    required double focal,
  }) {
    if (focal == 0 || !focal.isFinite || viewportSize.width == 0) {
      return 0;
    }
    return viewportSize.width / focal;
  }

  static Offset worldToScreen({
    required double worldX,
    required double worldY,
    required RuntimeCamera2D camera,
    required Size viewportSize,
    double depth = 0,
    double parallaxSensitivity = GamesToolApi.defaultParallaxSensitivity,
  }) {
    final double scale = cameraScaleForViewport(
      viewportSize: viewportSize,
      focal: camera.focal,
    );
    final double parallax = parallaxFactorForDepth(
      depth,
      sensitivity: parallaxSensitivity,
    );
    final double camX = camera.x * parallax;
    final double camY = camera.y * parallax;

    return Offset(
      (worldX - camX) * scale + viewportSize.width / 2,
      (worldY - camY) * scale + viewportSize.height / 2,
    );
  }

  static Offset? screenToWorld({
    required double screenX,
    required double screenY,
    required RuntimeCamera2D camera,
    required Size viewportSize,
    double depth = 0,
    double parallaxSensitivity = GamesToolApi.defaultParallaxSensitivity,
  }) {
    final double scale = cameraScaleForViewport(
      viewportSize: viewportSize,
      focal: camera.focal,
    );
    if (scale == 0) {
      return null;
    }
    final double parallax = parallaxFactorForDepth(
      depth,
      sensitivity: parallaxSensitivity,
    );

    return Offset(
      (screenX - viewportSize.width / 2) / scale + camera.x * parallax,
      (screenY - viewportSize.height / 2) / scale + camera.y * parallax,
    );
  }
}
