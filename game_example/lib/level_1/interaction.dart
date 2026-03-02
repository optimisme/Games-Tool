part of 'main.dart';

/// Input and navigation rules for active gameplay and end states.
extension _Level1Interaction on _Level1State {
  void _goBackToMenu() {
    goBackToMenu(
      context: context,
      isMounted: mounted,
      isLeavingLevel: _isLeavingLevel,
      setIsLeavingLevel: (bool value) {
        _isLeavingLevel = value;
      },
      ticker: _ticker,
    );
  }

  KeyEventResult _onKeyEvent(KeyEvent event) {
    final Level1UpdateState? state = _updateState;
    return handleGameplayKeyEvent(
      event: event,
      pressedKeys: _pressedKeys,
      onBackToMenu: _goBackToMenu,
      inEndState: state != null && (state.isGameOver || state.isWin),
      canExitEndState: state?.canExitEndState ?? false,
      onJumpQueued: () {
        _jumpQueued = true;
      },
    );
  }
}
