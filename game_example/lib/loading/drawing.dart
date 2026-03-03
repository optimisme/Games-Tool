part of 'main.dart';

/// Painter for the loading screen retro-style title, progress bar, and status text.
class _LoadingPainter extends CustomPainter {
  /// Creates a painter for current loading progress and messages.
  const _LoadingPainter({
    required this.levelIndex,
    required this.progress,
    required this.label,
    required this.showRetryHint,
  });

  final int levelIndex;
  final double progress;
  final String label;
  final bool showRetryHint;

  static const Color _bg = Color(0xFF040404);
  static const Color _primary = Color(0xFF35FF74);
  static const Color _bgBar = Color(0xFF0B0B0B);
  static const Color _secondary = Color(0xFFB9F9CA);

  /// Paints title, progress bar, status label, and retry hint.
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _bg);

    final double clampedProgress = progress.clamp(0.0, 1.0);
    final String title = 'LEVEL $levelIndex';
    final String percentText = '${(clampedProgress * 100).toInt()}%';
    final double barWidth = math.min(size.width * 0.7, 420.0);
    const double barHeight = 22;

    final TextPainter titlePainter = buildTextPainter(
      title,
      const TextStyle(
        color: _primary,
        fontSize: 34,
        fontWeight: FontWeight.w800,
        letterSpacing: 3,
      ),
      textAlign: TextAlign.center,
    );
    final TextPainter percentPainter = buildTextPainter(
      percentText,
      const TextStyle(
        color: _secondary,
        fontSize: 16,
        fontFamily: 'monospace',
      ),
      textAlign: TextAlign.center,
    );
    final TextPainter labelPainter = buildTextPainter(
      label,
      const TextStyle(
        color: _secondary,
        fontSize: 14,
        fontFamily: 'monospace',
      ),
      textAlign: TextAlign.center,
    );
    final TextPainter hintPainter = buildTextPainter(
      'ENTER/TAP: Retry    ESC: Menu',
      const TextStyle(
        color: _secondary,
        fontSize: 12,
        fontFamily: 'monospace',
      ),
      textAlign: TextAlign.center,
    );

    const double gapTitleToBar = 28;
    const double gapBarToPercent = 14;
    const double gapPercentToLabel = 10;
    const double gapLabelToHint = 10;
    final double totalHeight = titlePainter.height +
        gapTitleToBar +
        barHeight +
        gapBarToPercent +
        percentPainter.height +
        gapPercentToLabel +
        labelPainter.height +
        (showRetryHint ? gapLabelToHint + hintPainter.height : 0);

    double y = (size.height - totalHeight) / 2;

    titlePainter.paint(
        canvas, Offset((size.width - titlePainter.width) / 2, y));
    y += titlePainter.height + gapTitleToBar;

    final Rect barRect =
        Rect.fromLTWH((size.width - barWidth) / 2, y, barWidth, barHeight);
    canvas.drawRect(barRect, Paint()..color = _bgBar);
    final Rect fillRect = Rect.fromLTWH(
      barRect.left,
      barRect.top,
      barRect.width * clampedProgress,
      barRect.height,
    );
    if (fillRect.width > 0) {
      canvas.drawRect(fillRect, Paint()..color = _primary);
    }
    canvas.drawRect(
      barRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _primary,
    );
    y += barHeight + gapBarToPercent;

    percentPainter.paint(
      canvas,
      Offset((size.width - percentPainter.width) / 2, y),
    );
    y += percentPainter.height + gapPercentToLabel;

    labelPainter.paint(
      canvas,
      Offset((size.width - labelPainter.width) / 2, y),
    );
    if (!showRetryHint) {
      return;
    }
    y += labelPainter.height + gapLabelToHint;
    hintPainter.paint(
      canvas,
      Offset((size.width - hintPainter.width) / 2, y),
    );
  }

  /// Repaints whenever loading visual state changes.
  @override
  bool shouldRepaint(covariant _LoadingPainter oldDelegate) {
    return oldDelegate.levelIndex != levelIndex ||
        oldDelegate.progress != progress ||
        oldDelegate.label != label ||
        oldDelegate.showRetryHint != showRetryHint;
  }
}
