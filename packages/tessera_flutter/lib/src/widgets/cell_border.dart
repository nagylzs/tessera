import 'package:flutter/rendering.dart';

/// The hairlines of one grid cell: a 1 px right and bottom border, each
/// optionally starting part-way along its edge so that a merged header
/// label and the blank leg beside it (the "rotated L") show no line
/// between them; plus the 2 px inset [outline] of the current cell.
/// Internal to `CubeView`.
final class CellBorder extends CustomPainter {
  const CellBorder({
    required this.color,
    this.rightFrom = 0,
    this.rightUntil = double.infinity,
    this.bottomFrom = 0,
    this.bottomUntil = double.infinity,
    this.outline,
  });

  final Color color;

  /// Drawn just inside the cell when set.
  final Color? outline;

  /// Where the right border starts and ends, measured from the top.
  final double rightFrom;
  final double rightUntil;

  /// Where the bottom border starts and ends, measured from the left.
  final double bottomFrom;
  final double bottomUntil;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final rightEnd = rightUntil < size.height ? rightUntil : size.height;
    if (rightFrom < rightEnd) {
      canvas.drawRect(
        Rect.fromLTRB(size.width - 1, rightFrom, size.width, rightEnd),
        paint,
      );
    }
    final bottomEnd = bottomUntil < size.width ? bottomUntil : size.width;
    if (bottomFrom < bottomEnd) {
      canvas.drawRect(
        Rect.fromLTRB(bottomFrom, size.height - 1, bottomEnd, size.height),
        paint,
      );
    }
    final outline = this.outline;
    if (outline != null) {
      canvas.drawRect(
        (Offset.zero & size).deflate(1),
        Paint()
          ..color = outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(CellBorder old) =>
      old.color != color ||
      old.rightFrom != rightFrom ||
      old.rightUntil != rightUntil ||
      old.bottomFrom != bottomFrom ||
      old.bottomUntil != bottomUntil ||
      old.outline != outline;
}
