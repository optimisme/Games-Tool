import 'dart:math' as math;
import 'dart:ui';

import 'project_data_api.dart';
import 'runtime_models.dart';

class RuntimeCameraMath {
  const RuntimeCameraMath._();

  static const double minDepthProjectionFactor = 0.25;
  static const double maxDepthProjectionFactor = 4.0;

  // Shared interpolation primitive used by level render states.
  static double lerpDouble(
    double previous,
    double current, {
    double alpha = 1.0,
  }) {
    final double t = alpha.clamp(0.0, 1.0).toDouble();
    return previous + (current - previous) * t;
  }

  static Offset lerpOffset({
    required double previousX,
    required double previousY,
    required double currentX,
    required double currentY,
    double alpha = 1.0,
  }) {
    return Offset(
      lerpDouble(previousX, currentX, alpha: alpha),
      lerpDouble(previousY, currentY, alpha: alpha),
    );
  }

  static double depthProjectionFactorForDepth(
    double depth, {
    double sensitivity = GamesToolApi.defaultDepthSensitivity,
  }) {
    final double safeSensitivity = sensitivity.isFinite && sensitivity >= 0
        ? sensitivity
        : GamesToolApi.defaultDepthSensitivity;
    final double factor = math.exp(-depth * safeSensitivity);
    return factor
        .clamp(minDepthProjectionFactor, maxDepthProjectionFactor)
        .toDouble();
  }

  static double depthScaleForDepth(
    double depth, {
    double sensitivity = GamesToolApi.defaultDepthSensitivity,
  }) {
    return depthProjectionFactorForDepth(
      depth,
      sensitivity: sensitivity,
    );
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
    double depthSensitivity = GamesToolApi.defaultDepthSensitivity,
  }) {
    final double scale = cameraScaleForViewport(
      viewportSize: viewportSize,
      focal: camera.focal,
    );
    final double depthProjection = depthProjectionFactorForDepth(
      depth,
      sensitivity: depthSensitivity,
    );
    final double camX = camera.x * depthProjection;
    final double camY = camera.y * depthProjection;
    final double projectedWorldX = worldX * depthProjection;
    final double projectedWorldY = worldY * depthProjection;

    return Offset(
      (projectedWorldX - camX) * scale + viewportSize.width / 2,
      (projectedWorldY - camY) * scale + viewportSize.height / 2,
    );
  }

  static Offset? screenToWorld({
    required double screenX,
    required double screenY,
    required RuntimeCamera2D camera,
    required Size viewportSize,
    double depth = 0,
    double depthSensitivity = GamesToolApi.defaultDepthSensitivity,
  }) {
    final double scale = cameraScaleForViewport(
      viewportSize: viewportSize,
      focal: camera.focal,
    );
    if (scale == 0) {
      return null;
    }
    final double depthProjection = depthProjectionFactorForDepth(
      depth,
      sensitivity: depthSensitivity,
    );
    if (depthProjection == 0) {
      return null;
    }

    return Offset(
      ((screenX - viewportSize.width / 2) / scale +
              camera.x * depthProjection) /
          depthProjection,
      ((screenY - viewportSize.height / 2) / scale +
              camera.y * depthProjection) /
          depthProjection,
    );
  }

  static Rect? worldViewportRect({
    required RuntimeCamera2D camera,
    required Size viewportSize,
    double depth = 0,
    double depthSensitivity = GamesToolApi.defaultDepthSensitivity,
    double paddingWorld = 0,
  }) {
    final Offset? topLeft = screenToWorld(
      screenX: 0,
      screenY: 0,
      camera: camera,
      viewportSize: viewportSize,
      depth: depth,
      depthSensitivity: depthSensitivity,
    );
    final Offset? bottomRight = screenToWorld(
      screenX: viewportSize.width,
      screenY: viewportSize.height,
      camera: camera,
      viewportSize: viewportSize,
      depth: depth,
      depthSensitivity: depthSensitivity,
    );
    if (topLeft == null || bottomRight == null) {
      return null;
    }

    final double left = math.min(topLeft.dx, bottomRight.dx) - paddingWorld;
    final double top = math.min(topLeft.dy, bottomRight.dy) - paddingWorld;
    final double right = math.max(topLeft.dx, bottomRight.dx) + paddingWorld;
    final double bottom = math.max(topLeft.dy, bottomRight.dy) + paddingWorld;
    if (right <= left || bottom <= top) {
      return null;
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }
}
