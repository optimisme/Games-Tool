import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../app_data.dart';
import '../menu/main.dart';

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
