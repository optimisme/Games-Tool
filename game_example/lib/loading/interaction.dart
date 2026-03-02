part of 'main.dart';

/// Navigation logic for leaving loading and entering the selected level.
extension _LoadingInteraction on _LoadingState {
  void _maybeNavigate(AppData appData) {
    if (_didNavigate) {
      return;
    }
    // Invariant: do not navigate until both timing and data readiness gates pass.
    if (!_controller.isCompleted ||
        !appData.isReadyForLevel(widget.levelIndex)) {
      return;
    }

    _didNavigate = true;
    pushReplacementCupertinoPage(
      context: context,
      postFrame: true,
      isMounted: () => mounted,
      builder: (_) => selectByLevelIndex<Widget>(
        levelIndex: widget.levelIndex,
        level0: const Level0(levelIndex: 0),
        level1: Level1(levelIndex: widget.levelIndex),
      ),
    );
  }
}
