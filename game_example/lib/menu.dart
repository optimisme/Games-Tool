import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app_data.dart';
import 'loading.dart';

part 'menu/drawing.dart';
part 'menu/initialize.dart';
part 'menu/interaction.dart';
part 'menu/layout.dart';

const List<String> _menuOptions = <String>['LEVEL 0', 'LEVEL 1'];

class Menu extends StatefulWidget {
  const Menu({super.key});

  @override
  State<Menu> createState() => _MenuState();
}

class _MenuState extends State<Menu> {
  final FocusNode _focusNode = FocusNode();
  int _selectedIndex = 0;
  bool _cursorVisible = true;
  Timer? _blinkTimer;
  List<Rect> _optionRects = const <Rect>[];

  @override
  void initState() {
    super.initState();
    _startCursorBlinkTimer();
  }

  @override
  void dispose() {
    _stopCursorBlinkTimer();
    _focusNode.dispose();
    super.dispose();
  }

  void _refreshMenu(VoidCallback update) {
    if (!mounted) {
      return;
    }
    setState(update);
  }

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
