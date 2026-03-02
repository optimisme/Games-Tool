import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';

import '../utils_gamestool/utils_gamestool.dart';

const TextStyle kHudTextStyle = TextStyle(
  color: Color(0xFFE0F2FF),
  fontSize: 6.5,
  fontWeight: FontWeight.w600,
);

class HudBackButtonLayout {
  const HudBackButtonLayout({
    required this.hudX,
    required this.hudY,
    required this.iconWidth,
    required this.iconHeight,
    required this.iconGap,
    this.hitPadding = const EdgeInsets.fromLTRB(6, 4, 6, 4),
  });

  final double hudX;
  final double hudY;
  final double iconWidth;
  final double iconHeight;
  final double iconGap;
  final EdgeInsets hitPadding;

  double get textX => hudX + iconWidth + iconGap;
}

Rect resolveHudRectInVirtualViewport({
  required RuntimeLevelViewport viewport,
  required Size virtualViewportSize,
}) {
  final String adaptation = viewport.adaptation.trim().toLowerCase();
  if (adaptation != 'expand') {
    return Rect.fromLTWH(
      0,
      0,
      virtualViewportSize.width,
      virtualViewportSize.height,
    );
  }

  final double baseWidth =
      viewport.width > 0 ? viewport.width : virtualViewportSize.width;
  final double baseHeight =
      viewport.height > 0 ? viewport.height : virtualViewportSize.height;
  final double left = (virtualViewportSize.width - baseWidth) / 2;
  final double top = (virtualViewportSize.height - baseHeight) / 2;
  return Rect.fromLTWH(left, top, baseWidth, baseHeight);
}

Rect resolveBackLabelScreenRect({
  required RuntimeLevelViewport viewport,
  required Size canvasSize,
  required String label,
  required HudBackButtonLayout layout,
  TextStyle textStyle = kHudTextStyle,
}) {
  final RuntimeViewportLayout viewportLayout =
      GamesToolRuntimeRenderer.resolveViewportLayout(
    painterSize: canvasSize,
    viewport: viewport,
  );
  if (!viewportLayout.hasVisibleArea ||
      viewportLayout.scaleX == 0 ||
      viewportLayout.scaleY == 0) {
    return Rect.zero;
  }
  final Rect hudVirtualRect = resolveHudRectInVirtualViewport(
    viewport: viewport,
    virtualViewportSize: viewportLayout.virtualSize,
  );
  final TextPainter labelPainter = buildTextPainter(label, textStyle);

  final double labelLeft = viewportLayout.destinationRect.left +
      ((hudVirtualRect.left + layout.hudX) * viewportLayout.scaleX);
  final double labelTop = viewportLayout.destinationRect.top +
      ((hudVirtualRect.top + layout.hudY) * viewportLayout.scaleY);
  final double labelWidth =
      (layout.iconWidth + layout.iconGap + labelPainter.width) *
          viewportLayout.scaleX;
  final double labelHeight = (layout.iconHeight > labelPainter.height
          ? layout.iconHeight
          : labelPainter.height) *
      viewportLayout.scaleY;

  return Rect.fromLTWH(
    labelLeft - layout.hitPadding.left,
    labelTop - layout.hitPadding.top,
    labelWidth + layout.hitPadding.left + layout.hitPadding.right,
    labelHeight + layout.hitPadding.top + layout.hitPadding.bottom,
  );
}

void drawBackToMenuHud({
  required Canvas canvas,
  required Rect hudRect,
  required ui.Image? iconImage,
  required String label,
  required HudBackButtonLayout layout,
  TextStyle textStyle = kHudTextStyle,
}) {
  if (iconImage != null) {
    final Rect srcRect = Rect.fromLTWH(
      0,
      0,
      iconImage.width.toDouble(),
      iconImage.height.toDouble(),
    );
    final Rect dstRect = Rect.fromLTWH(
      hudRect.left + layout.hudX,
      hudRect.top + layout.hudY,
      layout.iconWidth,
      layout.iconHeight,
    );
    canvas.drawImageRect(iconImage, srcRect, dstRect, Paint());
  }
  drawHudText(
    canvas,
    label,
    Offset(hudRect.left + layout.textX, hudRect.top + layout.hudY),
    style: textStyle,
  );
}

void drawTopRightHudText({
  required Canvas canvas,
  required Rect hudRect,
  required String text,
  required double top,
  TextStyle style = kHudTextStyle,
  double rightPadding = 20,
}) {
  final TextPainter painter = buildTextPainter(text, style);
  painter.paint(
    canvas,
    Offset(hudRect.right - painter.width - rightPadding, hudRect.top + top),
  );
}

void drawHudText(
  Canvas canvas,
  String text,
  Offset offset, {
  TextStyle style = kHudTextStyle,
  double? maxWidth,
}) {
  final TextPainter painter = buildTextPainter(
    text,
    style,
    maxWidth: maxWidth,
  );
  painter.paint(canvas, offset);
}

TextPainter buildTextPainter(
  String text,
  TextStyle style, {
  TextAlign textAlign = TextAlign.left,
  double? maxWidth,
}) {
  final TextPainter painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textAlign: textAlign,
  )..layout(maxWidth: maxWidth ?? double.infinity);
  return painter;
}

void drawCenteredText({
  required Canvas canvas,
  required double canvasWidth,
  required String text,
  required double y,
  required TextStyle style,
  double? maxWidth,
}) {
  final TextPainter painter = buildTextPainter(
    text,
    style,
    textAlign: TextAlign.center,
    maxWidth: maxWidth,
  );
  painter.paint(
    canvas,
    Offset(
      (canvasWidth - painter.width) / 2,
      y,
    ),
  );
}
