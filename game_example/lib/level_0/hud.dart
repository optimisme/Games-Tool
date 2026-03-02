part of 'main.dart';

/// HUD helpers that map virtual viewport coordinates back to screen space.
extension _Level0Hud on _Level0State {
  Rect _backLabelScreenRect({
    required AppData appData,
    required Size canvasSize,
  }) {
    final RuntimeLevelViewport viewport =
        GamesToolRuntimeRenderer.levelViewport(
      gamesTool: appData.gamesTool,
      level: _level,
    );
    return resolveBackLabelScreenRect(
      viewport: viewport,
      canvasSize: canvasSize,
      label: _level0BackLabel,
      layout: _level0BackHudLayout,
      textStyle: kHudTextStyle,
    );
  }
}
