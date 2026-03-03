part of 'main.dart';

/// Input and navigation rules for active gameplay and end states.
extension _Level1Interaction on _Level1State {
  void _clearRuntimeState() {
    _pressedKeys.clear();
    _jumpQueued = false;
    _lastTickTimestamp = null;
    _runtimeApi.resetFrameState();
    _runtimeGameData = null;
    _level = null;
    _playerSpriteIndex = null;
    _updateState = null;
    _cameraFollowOffsetX = 0;
    _cameraFollowOffsetY = 0;
    _pathBindings.clear();
  }

  void _goBackToMenu() {
    goBackToMenu(
      context: context,
      isMounted: mounted,
      isLeavingLevel: _isLeavingLevel,
      setIsLeavingLevel: (bool value) {
        _isLeavingLevel = value;
      },
      ticker: _ticker,
      beforeNavigate: _clearRuntimeState,
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
