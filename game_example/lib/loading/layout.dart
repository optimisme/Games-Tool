part of 'main.dart';

extension _LoadingLayout on _LoadingState {
  double _buildProgress({
    required AppData appData,
    required bool levelReady,
  }) {
    final double rawProgress = _controller.value;
    final double dataProgress =
        levelReady ? 1 : appData.loadingProgress.clamp(0.0, 0.95);
    return levelReady
        ? rawProgress
        : math.min(0.95, math.max(rawProgress * 0.35, dataProgress));
  }

  String _buildLoadingLabel({
    required AppData appData,
    required bool levelReady,
  }) {
    if (appData.loadingError != null) {
      return 'Asset loading failed';
    }
    if (!_controller.isCompleted) {
      return 'Preparing level ${widget.levelIndex}...';
    }
    if (appData.isLoadingData) {
      return 'Loading assets...';
    }
    if (!levelReady) {
      return 'Waiting for assets...';
    }
    return 'Launching level ${widget.levelIndex}...';
  }
}
