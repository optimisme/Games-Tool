part of 'main.dart';

/// Menu lifecycle helpers.
extension _MenuInitialize on _MenuState {
  /// Starts a periodic blink timer for the selected-option cursor.
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

  /// Stops and clears the cursor blink timer.
  void _stopCursorBlinkTimer() {
    _blinkTimer?.cancel();
    _blinkTimer = null;
  }
}
