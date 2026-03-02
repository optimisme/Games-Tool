part of '../loading.dart';

extension _LoadingInitialize on _LoadingState {
  void _scheduleInitialLoad() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<AppData>().ensureLoadedForLevel(widget.levelIndex);
    });
  }

  void _startProgressAnimation() {
    _controller = AnimationController(
      vsync: this,
      duration: _LoadingState._minimumLoadingTime,
    )..addListener(_refreshLoading);

    _controller.forward();
  }

  void _disposeProgressAnimation() {
    _controller
      ..removeListener(_refreshLoading)
      ..dispose();
  }
}
