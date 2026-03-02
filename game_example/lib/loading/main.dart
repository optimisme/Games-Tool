import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

import '../app_data.dart';
import '../level_0/main.dart';
import '../level_1.dart';

part 'initialize.dart';
part 'interaction.dart';
part 'layout.dart';

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
    _maybeNavigate(appData);

    final bool levelReady = appData.isReadyForLevel(widget.levelIndex);
    final double progress =
        _buildProgress(appData: appData, levelReady: levelReady);
    final String label =
        _buildLoadingLabel(appData: appData, levelReady: levelReady);

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
