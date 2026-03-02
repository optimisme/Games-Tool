part of 'main.dart';

/// Input handling and scene transitions for level 0.
extension _Level0Interaction on _Level0State {
  KeyEventResult _onKeyEvent(KeyEvent event) {
    final LogicalKeyboardKey key = event.logicalKey;

    if (key == LogicalKeyboardKey.escape) {
      if (event is KeyDownEvent) {
        _goBackToMenu();
      }
      return KeyEventResult.handled;
    }

    if (event is KeyDownEvent) {
      // Keep pressed keys as the single source of truth for movement polling.
      _pressedKeys.add(key);
    } else if (event is KeyUpEvent) {
      _pressedKeys.remove(key);
    }
    return KeyEventResult.handled;
  }

  void _clearLevel0RuntimeState() {
    _pressedKeys.clear();
    _lastTickTimestamp = null;
    _runtimeApi.resetFrameState();
    _runtimeGameData = null;
    _level = null;
    _heroSpriteIndex = null;
    _decoracionsLayerIndex = null;
    _pontAmagatLayerIndex = null;
    _updateState = null;
    _backIconImage = null;
  }

  Future<void> _ensureBackIconLoaded(AppData appData) async {
    if (_backIconImage != null) {
      return;
    }
    try {
      final ui.Image iconImage =
          await appData.getImage(_level0BackIconAssetPath);
      if (!mounted) {
        return;
      }
      _refreshLevel0(() {
        _backIconImage = iconImage;
      });
    } catch (_) {
      // Keep text-only fallback if asset load fails.
    }
  }

  void _goBackToMenu() {
    // One-way guard to avoid duplicate pushReplacement transitions.
    if (!mounted || _isLeavingLevel) {
      return;
    }
    _isLeavingLevel = true;
    _ticker?.stop();
    _clearLevel0RuntimeState();
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
}
