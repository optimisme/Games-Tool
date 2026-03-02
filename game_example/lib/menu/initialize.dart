part of '../menu.dart';

extension _MenuInitialize on _MenuState {
  void _startCursorBlinkTimer() {
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 420), (_) {
      if (!mounted) {
        return;
      }
      _refreshMenu(() {
        _cursorVisible = !_cursorVisible;
      });
    });
  }

  void _stopCursorBlinkTimer() {
    _blinkTimer?.cancel();
    _blinkTimer = null;
  }
}
