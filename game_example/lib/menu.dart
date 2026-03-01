import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app_data.dart';
import 'loading.dart';

class Menu extends StatefulWidget {
  const Menu({super.key});

  @override
  State<Menu> createState() => _MenuState();
}

class _MenuState extends State<Menu> {
  static const List<String> _options = <String>['LEVEL 0', 'LEVEL 1'];

  final FocusNode _focusNode = FocusNode();
  int _selectedIndex = 0;
  bool _cursorVisible = true;
  Timer? _blinkTimer;
  List<Rect> _optionRects = const <Rect>[];

  @override
  void initState() {
    super.initState();
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 420), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _cursorVisible = !_cursorVisible;
      });
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _startLevel(BuildContext context, AppData appData, int levelIndex) {
    Navigator.of(context).pushReplacement(
      CupertinoPageRoute<void>(
        builder: (_) => Loading(levelIndex: levelIndex),
      ),
    );
  }

  void _selectAndStart(BuildContext context, AppData appData, int index) {
    final int clamped = index.clamp(0, _options.length - 1);
    if (clamped != _selectedIndex) {
      setState(() {
        _selectedIndex = clamped;
      });
    }
    _startLevel(context, appData, clamped);
  }

  void _moveSelection(int delta) {
    setState(() {
      _selectedIndex = (_selectedIndex + delta) % _options.length;
      if (_selectedIndex < 0) {
        _selectedIndex += _options.length;
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

  List<Rect> _buildOptionRects(Size size) {
    final double width = math.min(math.max(size.width * 0.46, 220), 420);
    final double buttonHeight = 60;
    final double spacing = 18;
    final double startY = size.height * 0.45;
    final double centerX = size.width / 2;

    return List<Rect>.generate(_options.length, (int index) {
      final double y = startY + index * (buttonHeight + spacing);
      return Rect.fromCenter(
        center: Offset(centerX, y),
        width: width,
        height: buttonHeight,
      );
    });
  }

  void _onTapDown(
      TapDownDetails details, BuildContext context, AppData appData) {
    final Offset point = details.localPosition;

    for (int i = 0; i < _optionRects.length; i++) {
      if (_optionRects[i].contains(point)) {
        _selectAndStart(context, appData, i);
        return;
      }
    }
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
                    optionLabels: _options,
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

class _MenuPainter extends CustomPainter {
  _MenuPainter({
    required this.selectedIndex,
    required this.cursorVisible,
    required this.optionLabels,
    required this.optionRects,
  });

  final int selectedIndex;
  final bool cursorVisible;
  final List<String> optionLabels;
  final List<Rect> optionRects;

  static const Color _bg = Color(0xFF000000);
  static const Color _primary = Color(0xFF35FF74);
  static const Color _dim = Color(0xFF146F34);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint();

    paint.color = _bg;
    canvas.drawRect(Offset.zero & size, paint);

    // CRT-like scanlines for a retro look.
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x2217A840);
    for (double y = 0; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    _drawCenteredText(
      canvas: canvas,
      canvasWidth: size.width,
      text: 'Game Example',
      y: size.height * 0.18,
      color: _primary,
      fontSize: math.min(52, size.width * 0.11),
      weight: FontWeight.w900,
      letterSpacing: 4,
    );

    _drawCenteredText(
      canvas: canvas,
      canvasWidth: size.width,
      text: 'SELECT LEVEL',
      y: size.height * 0.30,
      color: _dim,
      fontSize: math.min(26, size.width * 0.056),
      weight: FontWeight.w700,
      letterSpacing: 3,
    );

    for (int i = 0; i < optionRects.length; i++) {
      final bool selected = i == selectedIndex;
      final Rect rect = optionRects[i];

      paint
        ..style = PaintingStyle.fill
        ..color = selected ? const Color(0xFF0E1E12) : const Color(0xFF060B08);
      canvas.drawRect(rect, paint);

      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 3 : 2
        ..color = selected ? _primary : _dim;
      canvas.drawRect(rect, paint);

      final String prefix = selected && cursorVisible ? '> ' : '  ';
      _drawCenteredText(
        canvas: canvas,
        canvasWidth: size.width,
        text: '$prefix${optionLabels[i]}',
        y: rect.center.dy - 12,
        color: selected ? _primary : const Color(0xFF23AA54),
        fontSize: 28,
        weight: FontWeight.w700,
        letterSpacing: 2,
      );
    }

    const String footer = 'ARROWS/W,S: MOVE   ENTER/SPACE: PLAY   MOUSE: CLICK';

    _drawCenteredText(
      canvas: canvas,
      canvasWidth: size.width,
      text: footer,
      y: size.height - 40,
      color: const Color(0xFF21964A),
      fontSize: math.min(18, size.width * 0.032),
      weight: FontWeight.w600,
      letterSpacing: 1.4,
    );
  }

  void _drawCenteredText({
    required Canvas canvas,
    required double canvasWidth,
    required String text,
    required double y,
    required Color color,
    required double fontSize,
    required FontWeight weight,
    double letterSpacing = 0,
  }) {
    final TextSpan span = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: weight,
        fontFamily: 'monospace',
        letterSpacing: letterSpacing,
      ),
    );

    final TextPainter painter = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    painter.paint(
      canvas,
      Offset(
        (canvasWidth - painter.width) / 2,
        y,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _MenuPainter oldDelegate) {
    return selectedIndex != oldDelegate.selectedIndex ||
        cursorVisible != oldDelegate.cursorVisible ||
        optionRects != oldDelegate.optionRects;
  }
}
