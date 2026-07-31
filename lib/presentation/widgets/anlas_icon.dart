import 'package:flutter/material.dart';

/// Official Anlas amber used by the NovelAI web client for both the crystal
/// icon and the balance number (rgb 245 243 194 / #F5F3C2).
const Color kAnlasColor = Color(0xFFF5F3C2);

/// Renders the official NovelAI Anlas crystal icon.
///
/// The vector geometry is transcribed verbatim from the SVG asset used by the
/// NovelAI web client (viewBox 0 0 10 9), so it scales crisply at any size.
class AnlasIcon extends StatelessWidget {
  const AnlasIcon({super.key, this.size = 14, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? kAnlasColor;
    // Source viewBox is 10x9; preserve the aspect ratio so the crystal does
    // not stretch into a square.
    final height = size * 9 / 10;
    return SizedBox(
      width: size,
      height: height,
      child: CustomPaint(painter: _AnlasCrystalPainter(iconColor)),
    );
  }
}

class _AnlasCrystalPainter extends CustomPainter {
  _AnlasCrystalPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Source coordinates live in a 10x9 grid; scale to the paint area.
    final sx = size.width / 10;
    final sy = size.height / 9;

    final path = Path()
      // M4.48874 0
      ..moveTo(4.48874 * sx, 0)
      // H5.51107
      ..lineTo(5.51107 * sx, 0)
      // L7.14867 1.60183
      ..lineTo(7.14867 * sx, 1.60183 * sy)
      // L5.45731 8.99994
      ..lineTo(5.45731 * sx, 8.99994 * sy)
      // H4.54284
      ..lineTo(4.54284 * sx, 8.99994 * sy)
      // L2.85142 1.60156
      ..lineTo(2.85142 * sx, 1.60156 * sy)
      // Z
      ..close()
      // M7.47144 9
      ..moveTo(7.47144 * sx, 9 * sy)
      // L10 5.04294
      ..lineTo(10 * sx, 5.04294 * sy)
      // V4.39087
      ..lineTo(10 * sx, 4.39087 * sy)
      // L8.65736 3.07756
      ..lineTo(8.65736 * sx, 3.07756 * sy)
      // L8.24906 3.18423
      ..lineTo(8.24906 * sx, 3.18423 * sy)
      // L6.91946 9
      ..lineTo(6.91946 * sx, 9 * sy)
      // Z
      ..close()
      // M3.08069 9
      ..moveTo(3.08069 * sx, 9 * sy)
      // L1.7543 3.19828
      ..lineTo(1.7543 * sx, 3.19828 * sy)
      // L1.33187 3.08792
      ..lineTo(1.33187 * sx, 3.08792 * sy)
      // L0 4.39069
      ..lineTo(0, 4.39069 * sy)
      // V5.04271
      ..lineTo(0, 5.04271 * sy)
      // L2.52871 9
      ..lineTo(2.52871 * sx, 9 * sy)
      // Z
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _AnlasCrystalPainter oldDelegate) =>
      oldDelegate.color != color;
}
