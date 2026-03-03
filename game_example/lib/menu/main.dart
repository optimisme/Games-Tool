import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app_data.dart';
import '../loading/main.dart';
import '../shared/utils_level.dart';
import '../shared/utils_painter.dart';

part 'drawing.dart';
part 'lifecycle.dart';
part 'interaction.dart';

const List<String> _menuOptions = <String>['LEVEL 0', 'LEVEL 1'];

/// Main level-selection screen.
class Menu extends StatefulWidget {
  /// Creates the menu screen widget.
  const Menu({super.key});

  /// Creates mutable state for the menu screen.
  @override
  State<Menu> createState() => _MenuState();
}

/// Holds menu input, selection, and blink animation state.
class _MenuState extends State<Menu> {
  final FocusNode _focusNode = FocusNode();
  int _selectedIndex = 0;
  bool _cursorVisible = true;
  Timer? _blinkTimer;
  List<Rect> _optionRects = const <Rect>[];

  /// Starts cursor blinking after the first frame is ready.
  @override
  void initState() {
    super.initState();
    _startCursorBlinkTimer();
  }

  /// Cleans up timer and focus resources.
  @override
  void dispose() {
    _stopCursorBlinkTimer();
    _focusNode.dispose();
    super.dispose();
  }

  /// Safely triggers setState while mounted.
  void _refreshMenu(VoidCallback update) {
    if (!mounted) {
      return;
    }
    setState(update);
  }

  /// Computes the interactive rectangles for each menu option.
  List<Rect> _buildOptionRects(Size size) {
    final double width = math.min(math.max(size.width * 0.46, 220), 420);
    final double buttonHeight = 60;
    final double spacing = 18;
    final double startY = size.height * 0.45;
    final double centerX = size.width / 2;

    return List<Rect>.generate(_menuOptions.length, (int index) {
      final double y = startY + index * (buttonHeight + spacing);
      return Rect.fromCenter(
        center: Offset(centerX, y),
        width: width,
        height: buttonHeight,
      );
    });
  }

  /// Builds the interactive menu UI.
  @override
  Widget build(BuildContext context) {
    final AppData appData = context.watch<AppData>();

    return CupertinoPageScaffold(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final Size size = Size(constraints.maxWidth, constraints.maxHeight);
            _optionRects = _buildOptionRects(size);

            return Focus(
              focusNode: _focusNode,
              autofocus: true,
              onKeyEvent: (FocusNode node, KeyEvent event) {
                return _onKeyEvent(context, event, appData);
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (TapDownDetails details) {
                  _focusNode.requestFocus();
                  _onTapDown(details, context, appData);
                },
                child: CustomPaint(
                  painter: _MenuPainter(
                    selectedIndex: _selectedIndex,
                    cursorVisible: _cursorVisible,
                    optionLabels: _menuOptions,
                    optionRects: _optionRects,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
