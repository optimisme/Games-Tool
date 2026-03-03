part of 'main.dart';

/// Navigation logic for leaving loading and entering the selected level.
extension _LoadingInteraction on _LoadingState {
  void _goBackToMenu() {
    if (_didNavigate) {
      return;
    }
    _didNavigate = true;
    navigateToMenuWithSlide(context);
  }

  void _requestLoad() {
    if (!mounted) {
      return;
    }
    final AppData appData = context.read<AppData>();
    if (appData.isLoadingData) {
      return;
    }
    _didNavigate = false;
    unawaited(
      appData.ensureLoadedForLevel(widget.levelIndex).catchError((_) {
        // Error state is exposed via AppData.loadingError for UI recovery.
      }),
    );
  }

  void _onTap(AppData appData) {
    if (appData.loadingError != null) {
      _requestLoad();
    }
  }

  KeyEventResult _onKeyEvent(KeyEvent event, AppData appData) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.handled;
    }

    if (appData.loadingError == null) {
      return KeyEventResult.ignored;
    }

    final LogicalKeyboardKey key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      _goBackToMenu();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.keyR) {
      _requestLoad();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _maybeNavigate(AppData appData) {
    if (_didNavigate) {
      return;
    }
    // Invariant: do not navigate until both timing and data readiness gates pass.
    if (appData.loadingError != null ||
        !_controller.isCompleted ||
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
