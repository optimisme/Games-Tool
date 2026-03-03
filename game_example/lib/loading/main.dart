import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_data.dart';
import '../level_0/main.dart';
import '../level_1/main.dart';
import '../shared/utils_level.dart';
import '../shared/utils_painter.dart';

part 'lifecycle.dart';
part 'interaction.dart';
part 'drawing.dart';

/// Transitional screen that waits for both data readiness and minimum UX timing.
class Loading extends StatefulWidget {
  /// Creates a loading screen for a target level.
  const Loading({super.key, required this.levelIndex});

  final int levelIndex;

  /// Creates mutable loading state.
  @override
  State<Loading> createState() => _LoadingState();
}

/// Holds loading progress animation and navigation state.
class _LoadingState extends State<Loading> with SingleTickerProviderStateMixin {
  // Prevents a flash transition when assets are already warm in memory.
  static const Duration _minimumLoadingTime = Duration(milliseconds: 1100);

  late final AnimationController _controller;
  bool _didNavigate = false;

  /// Initializes loading request and progress animation.
  @override
  void initState() {
    super.initState();
    _scheduleInitialLoad();
    _startProgressAnimation();
  }

  /// Disposes animation resources.
  @override
  void dispose() {
    _disposeProgressAnimation();
    super.dispose();
  }

  /// Triggers a repaint when loading state changes.
  void _refreshLoading() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  /// Computes visual loading progress from data and animation state.
  double _buildProgress({
    required AppData appData,
    required bool levelReady,
  }) {
    final double rawProgress = _controller.value;
    final double dataProgress =
        levelReady ? 1 : appData.loadingProgress.clamp(0.0, 0.95);
    // Blend UI animation and real load progress; reserve final 5% for handoff.
    return levelReady
        ? rawProgress
        : math.min(0.95, math.max(rawProgress * 0.35, dataProgress));
  }

  /// Resolves the status label shown under the progress bar.
  String _buildLoadingLabel({
    required AppData appData,
    required bool levelReady,
  }) {
    if (appData.loadingError != null) {
      return 'Asset loading failed';
    }
    if (!_controller.isCompleted) {
      return 'Loading...';
    }
    if (appData.isLoadingData) {
      return 'Loading assets...';
    }
    if (!levelReady) {
      return 'Waiting for assets...';
    }
    return 'Launching level ${widget.levelIndex}...';
  }

  /// Builds the loading screen UI and painter.
  @override
  Widget build(BuildContext context) {
    final AppData appData = context.watch<AppData>();
    // Navigation is state-driven; keep this check in build to react immediately.
    _maybeNavigate(appData);

    final bool levelReady = appData.isReadyForLevel(widget.levelIndex);
    final double progress =
        _buildProgress(appData: appData, levelReady: levelReady);
    final String label =
        _buildLoadingLabel(appData: appData, levelReady: levelReady);

    return CupertinoPageScaffold(
      child: SafeArea(
        child: Focus(
          autofocus: true,
          onKeyEvent: (FocusNode _, KeyEvent event) {
            return _onKeyEvent(event, appData);
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _onTap(appData),
            child: CustomPaint(
              painter: _LoadingPainter(
                levelIndex: widget.levelIndex,
                progress: progress,
                label: label,
                showRetryHint: appData.loadingError != null,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}
