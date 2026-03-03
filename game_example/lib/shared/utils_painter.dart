import 'package:flutter/cupertino.dart';

const double kHudScale = 4.0;
const double kHudSpacingScaleX = 1.0;
const double kHudSpacingScaleY = 2.0;

double hudUnits(double value) => value * kHudScale;
double hudSpacingX(double value) => value * kHudSpacingScaleX;
double hudSpacingY(double value) => value * kHudSpacingScaleY;

const TextStyle kHudTextStyle = TextStyle(
  color: Color(0xFFE0F2FF),
  fontSize: 6.5 * kHudScale,
  fontWeight: FontWeight.w600,
);

class HudBackButtonLayout {
  const HudBackButtonLayout({
    required this.hudX,
    required this.hudY,
    required this.iconWidth,
    required this.iconHeight,
    required this.iconGap,
    this.hitPadding = const EdgeInsets.fromLTRB(
      6 * kHudSpacingScaleX,
      4 * kHudSpacingScaleY,
      6 * kHudSpacingScaleX,
      4 * kHudSpacingScaleY,
    ),
  });

  final double hudX;
  final double hudY;
  final double iconWidth;
  final double iconHeight;
  final double iconGap;
  final EdgeInsets hitPadding;

  double get textX => hudX + iconWidth + iconGap;
}

Rect resolveScreenHudRect({
  required Size canvasSize,
  EdgeInsets padding = const EdgeInsets.fromLTRB(
    12 * kHudSpacingScaleX,
    8 * kHudSpacingScaleY,
    12 * kHudSpacingScaleX,
    8 * kHudSpacingScaleY,
  ),
}) {
  final double width = canvasSize.width - padding.left - padding.right;
  final double height = canvasSize.height - padding.top - padding.bottom;
  if (width <= 0 || height <= 0) {
    return Rect.zero;
  }
  return Rect.fromLTWH(
    padding.left,
    padding.top,
    width,
    height,
  );
}

Rect resolveBackLabelRectInHud({
  required Rect hudRect,
  required String label,
  required HudBackButtonLayout layout,
  TextStyle textStyle = kHudTextStyle,
}) {
  if (hudRect.width <= 0 || hudRect.height <= 0) {
    return Rect.zero;
  }
  final TextPainter labelPainter = buildTextPainter(label, textStyle);
  final double labelLeft = hudRect.left + layout.hudX;
  final double labelTop = hudRect.top + layout.hudY;
  final double labelWidth =
      layout.iconWidth + layout.iconGap + labelPainter.width;
  final double labelHeight = layout.iconHeight > labelPainter.height
      ? layout.iconHeight
      : labelPainter.height;

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
  required String label,
  required HudBackButtonLayout layout,
  TextStyle textStyle = kHudTextStyle,
}) {
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
  double rightPadding = 20 * kHudSpacingScaleX,
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

void drawCenteredEndOverlay({
  required Canvas canvas,
  required Size viewportSize,
  required String title,
  required bool showHint,
  required String hintText,
  TextStyle titleStyle = const TextStyle(
    color: Color(0xFFFFFFFF),
    fontSize: 20 * kHudScale,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.5 * kHudScale,
  ),
  TextStyle hintStyle = const TextStyle(
    color: Color(0xFFE0F2FF),
    fontSize: 8.5 * kHudScale,
    fontWeight: FontWeight.w600,
  ),
  double titleCenterYOffset = -12 * kHudSpacingScaleY,
  double hintCenterYOffset = 16 * kHudSpacingScaleY,
  Color scrimColor = const Color(0xB3000000),
}) {
  canvas.drawRect(
    Rect.fromLTWH(0, 0, viewportSize.width, viewportSize.height),
    Paint()..color = scrimColor,
  );

  final TextPainter titlePainter = TextPainter(
    text: TextSpan(
      text: title,
      style: titleStyle,
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  titlePainter.paint(
    canvas,
    Offset(
      (viewportSize.width - titlePainter.width) / 2,
      (viewportSize.height - titlePainter.height) / 2 + titleCenterYOffset,
    ),
  );

  if (!showHint) {
    return;
  }

  final TextPainter hintPainter = TextPainter(
    text: TextSpan(
      text: hintText,
      style: hintStyle,
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  hintPainter.paint(
    canvas,
    Offset(
      (viewportSize.width - hintPainter.width) / 2,
      (viewportSize.height - hintPainter.height) / 2 + hintCenterYOffset,
    ),
  );
}
