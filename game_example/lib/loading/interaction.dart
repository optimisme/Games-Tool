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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        CupertinoPageRoute<void>(
          builder: (_) {
            if (widget.levelIndex == 1) {
              return Level1(levelIndex: widget.levelIndex);
            }
            return const Level0(levelIndex: 0);
          },
        ),
      );
    });
  }
}
