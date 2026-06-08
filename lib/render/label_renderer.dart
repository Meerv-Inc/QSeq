import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../models/combined_label.dart';
import '../sizing/dpi.dart';
import 'raster_renderer.dart';

/// Composites a [CombinedLabel] (1D + 2D) into a single pixel-exact image.
class LabelRenderer {
  LabelRenderer._();

  static Future<ui.Image> render(CombinedLabel label, {ui.Image? logo}) async {
    final oneD = await RasterRenderer.render(label.oneD);
    final twoD = await RasterRenderer.render(label.twoD, logo: logo);
    final dpi = label.oneD.dpi;
    final padPx = (Dpi.mmToInch(label.paddingMm) * dpi).round().toDouble();
    final gapPx = (Dpi.mmToInch(label.gapMm) * dpi).round().toDouble();
    final out = label.outer;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
        Rect.fromLTWH(0, 0, out.widthPx.toDouble(), out.heightPx.toDouble()),
        Paint()..color = const Color(0xFFFFFFFF));

    void drawCentered(ui.Image img, double left, double top, double boxW,
        double boxH) {
      final dx = left + (boxW - img.width) / 2;
      final dy = top + (boxH - img.height) / 2;
      canvas.drawImage(img, Offset(dx, dy), Paint());
    }

    if (label.arrangement == LabelArrangement.stacked) {
      final contentW = out.widthPx - 2 * padPx;
      drawCentered(twoD, padPx, padPx, contentW, twoD.height.toDouble());
      drawCentered(oneD, padPx, padPx + twoD.height + gapPx, contentW,
          oneD.height.toDouble());
    } else {
      final contentH = out.heightPx - 2 * padPx;
      drawCentered(twoD, padPx, padPx, twoD.width.toDouble(), contentH);
      drawCentered(oneD, padPx + twoD.width + gapPx, padPx,
          oneD.width.toDouble(), contentH);
    }

    final picture = recorder.endRecording();
    return picture.toImage(out.widthPx, out.heightPx);
  }
}
