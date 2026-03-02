import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../app_data.dart';
import '../shared/camera.dart';
import '../menu/main.dart';
import '../utils_gamestool/utils_gamestool.dart';

class LevelViewportBootstrap {
  const LevelViewportBootstrap({
    required this.viewportWidth,
    required this.viewportCenterX,
    required this.viewportCenterY,
    required this.spawnX,
    required this.spawnY,
  });

  final double viewportWidth;
  final double viewportCenterX;
  final double viewportCenterY;
  final double spawnX;
  final double spawnY;
}

void syncPressedKeys({
  required Set<LogicalKeyboardKey> pressedKeys,
  required KeyEvent event,
}) {
  if (event is KeyDownEvent) {
    pressedKeys.add(event.logicalKey);
  } else if (event is KeyUpEvent) {
    pressedKeys.remove(event.logicalKey);
  }
}

void navigateToMenuWithSlide(BuildContext context) {
  Navigator.of(context).pushReplacement(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) => const Menu(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final Animation<Offset> slideAnimation = Tween<Offset>(
          begin: const Offset(-1, 0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
        );
        return SlideTransition(
          position: slideAnimation,
          child: child,
        );
      },
    ),
  );
}

void pushReplacementCupertinoPage({
  required BuildContext context,
  required WidgetBuilder builder,
  bool postFrame = false,
  bool Function()? isMounted,
}) {
  void navigate() {
    Navigator.of(context).pushReplacement(
      CupertinoPageRoute<void>(builder: builder),
    );
  }

  if (!postFrame) {
    navigate();
    return;
  }

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (isMounted != null && !isMounted()) {
      return;
    }
    navigate();
  });
}

T selectByLevelIndex<T>({
  required int levelIndex,
  required T level0,
  required T level1,
}) {
  if (levelIndex == 1) {
    return level1;
  }
  return level0;
}

Ticker restartGameLoopTicker({
  required TickerProvider tickerProvider,
  required Ticker? ticker,
  required Duration? Function() getLastTickTimestamp,
  required void Function(Duration? value) setLastTickTimestamp,
  required void Function(double dt) onTick,
  void Function(double frameDt)? onFrame,
  double initialDtSeconds = 1 / 60,
  double fixedDtSeconds = 1 / 60,
  double maxDtSeconds = 0.05,
  int maxSubsteps = 5,
}) {
  ticker?.dispose();
  setLastTickTimestamp(null);
  final double safeFixedDt =
      fixedDtSeconds.isFinite && fixedDtSeconds > 0 ? fixedDtSeconds : 1 / 60;
  final int safeMaxSubsteps = maxSubsteps < 1 ? 1 : maxSubsteps;
  double accumulatorSeconds = 0;
  final Ticker nextTicker = tickerProvider.createTicker((Duration elapsed) {
    final Duration? previous = getLastTickTimestamp();
    setLastTickTimestamp(elapsed);
    final double frameDt = previous == null
        ? initialDtSeconds
        : (elapsed - previous).inMicroseconds / 1000000;
    final double clampedFrameDt = frameDt.clamp(0.0, maxDtSeconds);
    onFrame?.call(clampedFrameDt);

    accumulatorSeconds += clampedFrameDt;
    int substeps = 0;
    while (accumulatorSeconds >= safeFixedDt && substeps < safeMaxSubsteps) {
      onTick(safeFixedDt);
      accumulatorSeconds -= safeFixedDt;
      substeps += 1;
    }

    // Drop excess backlog to avoid spiral-of-death under sustained slowdown.
    if (substeps >= safeMaxSubsteps && accumulatorSeconds > safeFixedDt) {
      accumulatorSeconds = safeFixedDt;
    }
  });
  nextTicker.start();
  return nextTicker;
}

LevelViewportBootstrap buildLevelViewportBootstrap({
  required GamesToolApi gamesTool,
  required Map<String, dynamic>? level,
  required Map<String, dynamic>? spawn,
  double fallbackCenterX = 100,
  double fallbackCenterY = 100,
}) {
  final double viewportWidth = level == null
      ? GamesToolApi.defaultViewportWidth
      : gamesTool.levelViewportWidth(
          level,
          fallback: GamesToolApi.defaultViewportWidth,
        );
  final double viewportCenterX = level == null
      ? fallbackCenterX
      : gamesTool.levelViewportCenterX(
          level,
          fallbackWidth: GamesToolApi.defaultViewportWidth,
          fallbackX: 0,
        );
  final double viewportCenterY = level == null
      ? fallbackCenterY
      : gamesTool.levelViewportCenterY(
          level,
          fallbackHeight: GamesToolApi.defaultViewportHeight,
          fallbackY: 0,
        );
  return LevelViewportBootstrap(
    viewportWidth: viewportWidth,
    viewportCenterX: viewportCenterX,
    viewportCenterY: viewportCenterY,
    spawnX: (spawn?['x'] as num?)?.toDouble() ?? viewportCenterX,
    spawnY: (spawn?['y'] as num?)?.toDouble() ?? viewportCenterY,
  );
}

void applyBootstrapCamera({
  required Camera camera,
  required LevelViewportBootstrap bootstrap,
}) {
  camera
    ..x = bootstrap.viewportCenterX
    ..y = bootstrap.viewportCenterY
    ..focal = bootstrap.viewportWidth;
}

Future<void> ensureImageLoaded({
  required AppData appData,
  required String assetPath,
  required ui.Image? currentImage,
  required bool Function() isMounted,
  required void Function(ui.Image image) onLoaded,
}) async {
  if (currentImage != null) {
    return;
  }
  try {
    final ui.Image loaded = await appData.getImage(assetPath);
    if (!isMounted()) {
      return;
    }
    onLoaded(loaded);
  } catch (_) {
    // Keep text-only fallback if asset load fails.
  }
}

Future<void> ensureStateImageLoaded({
  required AppData appData,
  required String assetPath,
  required ui.Image? currentImage,
  required bool Function() isMounted,
  required void Function(VoidCallback update) refresh,
  required void Function(ui.Image image) assignImage,
}) async {
  await ensureImageLoaded(
    appData: appData,
    assetPath: assetPath,
    currentImage: currentImage,
    isMounted: isMounted,
    onLoaded: (ui.Image image) {
      refresh(() {
        assignImage(image);
      });
    },
  );
}

KeyEventResult handleGameplayKeyEvent({
  required KeyEvent event,
  required Set<LogicalKeyboardKey> pressedKeys,
  required VoidCallback onBackToMenu,
  bool inEndState = false,
  bool canExitEndState = false,
  VoidCallback? onJumpQueued,
}) {
  final LogicalKeyboardKey key = event.logicalKey;
  if (inEndState) {
    if (event is KeyDownEvent && canExitEndState) {
      onBackToMenu();
    }
    return KeyEventResult.handled;
  }

  if (key == LogicalKeyboardKey.escape) {
    if (event is KeyDownEvent) {
      onBackToMenu();
    }
    return KeyEventResult.handled;
  }

  syncPressedKeys(pressedKeys: pressedKeys, event: event);
  if (event is KeyDownEvent &&
      onJumpQueued != null &&
      (key == LogicalKeyboardKey.space ||
          key == LogicalKeyboardKey.arrowUp ||
          key == LogicalKeyboardKey.keyW)) {
    onJumpQueued();
  }
  return KeyEventResult.handled;
}

void goBackToMenu({
  required BuildContext context,
  required bool isMounted,
  required bool isLeavingLevel,
  required void Function(bool value) setIsLeavingLevel,
  Ticker? ticker,
  VoidCallback? beforeNavigate,
}) {
  if (!isMounted || isLeavingLevel) {
    return;
  }
  setIsLeavingLevel(true);
  ticker?.stop();
  beforeNavigate?.call();
  navigateToMenuWithSlide(context);
}
