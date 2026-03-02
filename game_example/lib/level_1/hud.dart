part of 'main.dart';

extension _Level1Hud on _Level1State {
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
    final Rect hudVirtualRect = _resolveLevel1HudRectInVirtualViewport(
      viewport: viewport,
      virtualViewportSize: layout.virtualSize,
    );

    const TextStyle hudTextStyle = TextStyle(
      color: Color(0xFFE0F2FF),
      fontSize: 6.5,
      fontWeight: FontWeight.w600,
    );
    final TextPainter painter = TextPainter(
      text: const TextSpan(
        text: _level1BackLabel,
        style: hudTextStyle,
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final double labelLeft = layout.destinationRect.left +
        ((hudVirtualRect.left + _level1BackHudX) * layout.scaleX);
    final double labelTop = layout.destinationRect.top +
        ((hudVirtualRect.top + _level1BackHudY) * layout.scaleY);
    final double labelWidth =
        (_level1BackIconWidth + _level1BackIconGap + painter.width) *
            layout.scaleX;
    final double labelHeight = (_level1BackIconHeight > painter.height
            ? _level1BackIconHeight
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
