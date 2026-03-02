part of '../menu.dart';

extension _MenuInteraction on _MenuState {
  void _startLevel(BuildContext context, AppData appData, int levelIndex) {
    Navigator.of(context).pushReplacement(
      CupertinoPageRoute<void>(
        builder: (_) => Loading(levelIndex: levelIndex),
      ),
    );
  }

  void _selectAndStart(BuildContext context, AppData appData, int index) {
    final int clamped = index.clamp(0, _menuOptions.length - 1);
    if (clamped != _selectedIndex) {
      _refreshMenu(() {
        _selectedIndex = clamped;
      });
    }
    _startLevel(context, appData, clamped);
  }

  void _moveSelection(int delta) {
    _refreshMenu(() {
      _selectedIndex = (_selectedIndex + delta) % _menuOptions.length;
      if (_selectedIndex < 0) {
        _selectedIndex += _menuOptions.length;
      }
      _cursorVisible = true;
    });
  }

  KeyEventResult _onKeyEvent(
    BuildContext context,
    KeyEvent event,
    AppData appData,
  ) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.handled;
    }

    final LogicalKeyboardKey key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyW) {
      _moveSelection(-1);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.keyS) {
      _moveSelection(1);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      _startLevel(context, appData, _selectedIndex);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _onTapDown(
    TapDownDetails details,
    BuildContext context,
    AppData appData,
  ) {
    final Offset point = details.localPosition;

    for (int i = 0; i < _optionRects.length; i++) {
      if (_optionRects[i].contains(point)) {
        _selectAndStart(context, appData, i);
        return;
      }
    }
  }
}
