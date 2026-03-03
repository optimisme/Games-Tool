part of 'main.dart';

/// Startup/teardown responsibilities for loading progress and animation.
extension _LoadingInitialize on _LoadingState {
  void _scheduleInitialLoad() {
    // Delay until first frame so Provider/context reads happen after initial build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _requestLoad();
    });
  }

  void _startProgressAnimation() {
    _controller = AnimationController(
      vsync: this,
      // Keep progress animation aligned with minimum loading screen duration.
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
