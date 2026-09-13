import 'package:flutter/rendering.dart';

/// The hairlines of one grid cell: a 1 px right and bottom border, each
/// optionally starting part-way along its edge so that a merged header
/// label and the blank leg beside it (the "rotated L") show no line
/// between them. Internal to `CubeView`.
final class CellBorder extends CustomPainter {
  const CellBorder({
    required this.color,
    this.rightFrom = 0,
    this.bottomFrom = 0,
  });

  final Color color;

  /// Where the right border starts, measured from the top.
  final double rightFrom;

  /// Where the bottom border starts, measured from the left.
  final double bottomFrom;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    if (rightFrom < size.height) {
      canvas.drawRect(
        Rect.fromLTRB(size.width - 1, rightFrom, size.width, size.height),
        paint,
      );
    }
    if (bottomFrom < size.width) {
      canvas.drawRect(
        Rect.fromLTRB(bottomFrom, size.height - 1, size.width, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CellBorder old) =>
      old.color != color ||
      old.rightFrom != rightFrom ||
      old.bottomFrom != bottomFrom;
}
