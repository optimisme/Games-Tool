part of 'main.dart';

extension _Level1Interaction on _Level1State {
  void _goBackToMenu() {
    if (!mounted || _isLeavingLevel) {
      return;
    }
    _isLeavingLevel = true;
    _ticker?.stop();
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

  KeyEventResult _onKeyEvent(KeyEvent event) {
    final LogicalKeyboardKey key = event.logicalKey;
    final Level1UpdateState? state = _updateState;

    if (state != null && state.isGameOver) {
      if (event is KeyDownEvent) {
        _goBackToMenu();
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.escape) {
      if (event is KeyDownEvent) {
        _goBackToMenu();
      }
      return KeyEventResult.handled;
    }

    if (event is KeyDownEvent) {
      _pressedKeys.add(key);
      if (key == LogicalKeyboardKey.space ||
          key == LogicalKeyboardKey.arrowUp ||
          key == LogicalKeyboardKey.keyW) {
        _jumpQueued = true;
      }
    } else if (event is KeyUpEvent) {
      _pressedKeys.remove(key);
    }

    return KeyEventResult.handled;
  }
}
