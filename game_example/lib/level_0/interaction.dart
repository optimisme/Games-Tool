part of 'main.dart';

/// Input handling and scene transitions for level 0.
extension _Level0Interaction on _Level0State {
  KeyEventResult _onKeyEvent(KeyEvent event) {
    return handleGameplayKeyEvent(
      event: event,
      pressedKeys: _pressedKeys,
      onBackToMenu: _goBackToMenu,
    );
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

  void _goBackToMenu() {
    goBackToMenu(
      context: context,
      isMounted: mounted,
      isLeavingLevel: _isLeavingLevel,
      setIsLeavingLevel: (bool value) {
        _isLeavingLevel = value;
      },
      ticker: _ticker,
      beforeNavigate: _clearLevel0RuntimeState,
    );
  }
}
