import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../app_data.dart';
import '../level_0/main.dart';
import '../level_1/main.dart';
import '../shared/utils_level.dart';
import '../shared/utils_painter.dart';

part 'lifecycle.dart';
part 'interaction.dart';
part 'layout.dart';
part 'drawing.dart';

/// Transitional screen that waits for both data readiness and minimum UX timing.
class Loading extends StatefulWidget {
  const Loading({super.key, required this.levelIndex});

  final int levelIndex;

  @override
  State<Loading> createState() => _LoadingState();
}

class _LoadingState extends State<Loading> with SingleTickerProviderStateMixin {
  // Prevents a flash transition when assets are already warm in memory.
  static const Duration _minimumLoadingTime = Duration(milliseconds: 1100);

  late final AnimationController _controller;
  bool _didNavigate = false;

  @override
  void initState() {
    super.initState();
    _scheduleInitialLoad();
    _startProgressAnimation();
  }

  @override
  void dispose() {
    _disposeProgressAnimation();
    super.dispose();
  }

  void _refreshLoading() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

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
        child: CustomPaint(
          painter: _LoadingPainter(
            levelIndex: widget.levelIndex,
            progress: progress,
            label: label,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}
