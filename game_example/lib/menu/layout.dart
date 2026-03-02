part of '../menu.dart';

extension _MenuLayout on _MenuState {
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
}
