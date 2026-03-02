part of 'main.dart';

const String _level0BackIconAssetPath = 'other/enrrere.png';
const String _level0BackLabel = 'Tornar';
const double _level0BackHudX = 20;
const double _level0BackHudY = 5;
const double _level0BackIconWidth = 8;
const double _level0BackIconHeight = 8;
const double _level0BackIconGap = 3;
const double _level0BackTextX =
    _level0BackHudX + _level0BackIconWidth + _level0BackIconGap;

Rect _resolveLevel0HudRectInVirtualViewport({
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

/// HUD helpers that map virtual viewport coordinates back to screen space.
extension _Level0Hud on _Level0State {
  TextStyle get _hudTextStyle => const TextStyle(
        color: Color(0xFFE0F2FF),
        fontSize: 6.5,
        fontWeight: FontWeight.w600,
      );

  Rect _backLabelScreenRect({
    required AppData appData,
    required Size canvasSize,
  }) {
    final RuntimeLevelViewport viewport =
        GamesToolRuntimeRenderer.levelViewport(
      gamesTool: appData.gamesTool,
      level: _level,
    );
    final RuntimeViewportLayout layout =
        GamesToolRuntimeRenderer.resolveViewportLayout(
      painterSize: canvasSize,
      viewport: viewport,
    );
    if (!layout.hasVisibleArea || layout.scaleX == 0 || layout.scaleY == 0) {
      return Rect.zero;
    }
    final Rect hudVirtualRect = _resolveLevel0HudRectInVirtualViewport(
      viewport: viewport,
      virtualViewportSize: layout.virtualSize,
    );

    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: _level0BackLabel,
        style: _hudTextStyle,
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final double labelLeft = layout.destinationRect.left +
        ((hudVirtualRect.left + _level0BackHudX) * layout.scaleX);
    final double labelTop = layout.destinationRect.top +
        ((hudVirtualRect.top + _level0BackHudY) * layout.scaleY);
    final double labelWidth =
        (_level0BackIconWidth + _level0BackIconGap + painter.width) *
            layout.scaleX;
    final double labelHeight = (_level0BackIconHeight > painter.height
            ? _level0BackIconHeight
            : painter.height) *
        layout.scaleY;

    return Rect.fromLTWH(
      labelLeft - 6,
      labelTop - 4,
      labelWidth + 12,
      labelHeight + 8,
    );
  }
}
