part of 'main.dart';

/// Input handling and scene transitions for level 0.
extension _Level0Interaction on _Level0State {
  KeyEventResult _onKeyEvent(KeyEvent event) {
    final Level0UpdateState? state = _updateState;
    return handleGameplayKeyEvent(
      event: event,
      pressedKeys: _pressedKeys,
      onBackToMenu: _goBackToMenu,
      inEndState: state != null && state.isWin,
      canExitEndState: state?.canExitEndState ?? false,
    );
  }

  void _clearRuntimeState() {
    _pressedKeys.clear();
    _lastTickTimestamp = null;
    _runtimeApi.resetFrameState();
    _runtimeGameData = null;
    _level = null;
    _heroSpriteIndex = null;
    _cameraFollowOffsetX = 0;
    _cameraFollowOffsetY = 0;
    _decoracionsLayerIndex = null;
    _pontAmagatLayerIndex = null;
    _updateState = null;
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
}
