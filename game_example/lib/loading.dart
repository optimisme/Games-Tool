import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import 'app_data.dart';
import 'level_0.dart';
import 'level_1.dart';

class Loading extends StatefulWidget {
  const Loading({super.key, required this.levelIndex});

  final int levelIndex;

  @override
  State<Loading> createState() => _LoadingState();
}

class _LoadingState extends State<Loading> with SingleTickerProviderStateMixin {
  static const Duration _minimumLoadingTime = Duration(milliseconds: 1100);

  late final AnimationController _controller;
  bool _didNavigate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<AppData>().ensureLoaded();
    });

    _controller = AnimationController(
      vsync: this,
      duration: _minimumLoadingTime,
    )..addListener(() {
        if (mounted) {
          setState(() {});
        }
      });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _maybeNavigate(AppData appData) {
    if (_didNavigate) {
      return;
    }
    if (!_controller.isCompleted || !appData.isReady) {
      return;
    }

    _didNavigate = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      appData.startGame(widget.levelIndex);
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

  @override
  Widget build(BuildContext context) {
    final AppData appData = context.watch<AppData>();
    _maybeNavigate(appData);

    final double rawProgress = _controller.value;
    final double dataProgress =
        appData.isReady ? 1 : appData.loadingProgress.clamp(0.0, 0.95);
    final double progress = appData.isReady
        ? rawProgress
        : math.min(0.95, math.max(rawProgress * 0.35, dataProgress));

    final String label;
    if (appData.loadingError != null) {
      label = 'Asset loading failed';
    } else if (!_controller.isCompleted) {
      label = 'Preparing level ${widget.levelIndex}...';
    } else if (appData.isLoadingData) {
      label = 'Loading assets...';
    } else if (!appData.isReady) {
      label = 'Waiting for assets...';
    } else {
      label = 'Launching level ${widget.levelIndex}...';
    }

    return CupertinoPageScaffold(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double barWidth = math.min(constraints.maxWidth * 0.7, 420);

            return Container(
              color: const Color(0xFF040404),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'LEVEL ${widget.levelIndex}',
                      style: const TextStyle(
                        color: Color(0xFF35FF74),
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      width: barWidth,
                      height: 22,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFF35FF74),
                          width: 2,
                        ),
                        color: const Color(0xFF0B0B0B),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: barWidth * progress,
                          color: const Color(0xFF35FF74),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(
                        color: Color(0xFFB9F9CA),
                        fontSize: 16,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFFB9F9CA),
                        fontSize: 14,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
