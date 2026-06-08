import 'package:flutter/widgets.dart';

/// An on-screen mm + inch ruler (with fine/vernier ticks) drawn at a given
/// display scale [pxPerMm], so the preview shows the design's true physical
/// scale. Horizontal or vertical.
class RulerStrip extends StatelessWidget {
  final double pxPerMm;
  final double lengthPx;
  final bool horizontal;
  final double band;

  const RulerStrip({
    super.key,
    required this.pxPerMm,
    required this.lengthPx,
    this.horizontal = true,
    this.band = 30,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: horizontal ? Size(lengthPx, band) : Size(band, lengthPx),
      painter: _RulerPainter(pxPerMm, horizontal, band),
    );
  }
}

class _RulerPainter extends CustomPainter {
  final double pxPerMm;
  final bool horizontal;
  final double band;
  _RulerPainter(this.pxPerMm, this.horizontal, this.band);

  static const _ink = Color(0xFF111111);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFFFFFF));
    final thin = Paint()
      ..color = _ink
      ..strokeWidth = 0.7;
    final thick = Paint()
      ..color = _ink
      ..strokeWidth = 1.2;
    final lenPx = horizontal ? size.width : size.height;

    void tick(double pos, double len, bool major, bool fromFar) {
      final p = major ? thick : thin;
      if (horizontal) {
        final y0 = fromFar ? band - len : 0.0;
        final y1 = fromFar ? band : len;
        canvas.drawLine(Offset(pos, y0), Offset(pos, y1), p);
      } else {
        final x0 = fromFar ? band - len : 0.0;
        final x1 = fromFar ? band : len;
        canvas.drawLine(Offset(x0, pos), Offset(x1, pos), p);
      }
    }

    void label(String s, double pos, bool fromFar) {
      final tp = TextPainter(
        text: TextSpan(
            text: s,
            style: const TextStyle(
                color: _ink, fontSize: 8, fontFamily: 'monospace')),
        textDirection: TextDirection.ltr,
      )..layout();
      if (horizontal) {
        tp.paint(canvas, Offset(pos + 1, fromFar ? band - 13 : 11));
      } else {
        tp.paint(canvas, Offset(fromFar ? band - 16 : 9, pos + 1));
      }
    }

    // Millimetre scale (near edge).
    final mmN = (lenPx / pxPerMm).floor();
    for (var i = 0; i <= mmN; i++) {
      final pos = i * pxPerMm;
      final major = i % 10 == 0, med = i % 5 == 0;
      tick(pos, major ? 11 : (med ? 7 : 4), major, false);
      if (major && i > 0) label('$i', pos, false);
    }

    // Inch scale (far edge), 1/16".
    final unit = pxPerMm * 25.4 / 16;
    final sN = (lenPx / unit).floor();
    for (var j = 0; j <= sN; j++) {
      final pos = j * unit;
      final major = j % 16 == 0, half = j % 8 == 0, q = j % 4 == 0;
      tick(pos, major ? 11 : (half ? 8 : (q ? 5 : 3)), major, true);
      if (major && j > 0) label('${j ~/ 16}"', pos, true);
    }
  }

  @override
  bool shouldRepaint(covariant _RulerPainter old) =>
      old.pxPerMm != pxPerMm || old.horizontal != horizontal;
}
