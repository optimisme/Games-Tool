part of '../menu.dart';

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
