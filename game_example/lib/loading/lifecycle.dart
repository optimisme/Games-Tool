part of 'main.dart';

/// Startup/teardown responsibilities for loading progress and animation.
extension _LoadingInitialize on _LoadingState {
  /// Schedules the first load request after initial frame render.
  void _scheduleInitialLoad() {
    // Delay until first frame so Provider/context reads happen after initial build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _requestLoad();
    });
  }

  /// Starts the loading progress animation controller.
  void _startProgressAnimation() {
    _controller = AnimationController(
      vsync: this,
      // Keep progress animation aligned with minimum loading screen duration.
      duration: _LoadingState._minimumLoadingTime,
    )..addListener(_refreshLoading);

    _controller.forward();
  }

  /// Stops and disposes the progress animation controller.
  void _disposeProgressAnimation() {
    _controller
      ..removeListener(_refreshLoading)
      ..dispose();
  }
}
