part of 'main.dart';

extension _LoadingInteraction on _LoadingState {
  void _maybeNavigate(AppData appData) {
    if (_didNavigate) {
      return;
    }
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
              return const Level1(levelIndex: 1);
            }
            return const Level0(levelIndex: 0);
          },
        ),
      );
    });
  }
}
