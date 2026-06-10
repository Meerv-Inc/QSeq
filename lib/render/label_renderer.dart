// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'dart:math' as math;
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
    final padPx = (Dpi.mmToInch(label.paddingMm) * dpi).round();
    final gapPx = (Dpi.mmToInch(label.gapMm) * dpi).round();

    // Size the canvas from the ACTUAL rendered symbols, not the sizing-engine
    // estimate (CombinedLabel.outer). A 1D width is an estimate that the encoder
    // can exceed by a few modules; sizing the boxes from the estimate made the
    // centring offset go negative, so the wider symbol overran its neighbour and
    // was hard-clipped at the canvas edge. Laying out from the real pixel sizes
    // guarantees both symbols fit whole.
    final stacked = label.arrangement == LabelArrangement.stacked;
    final int outW;
    final int outH;
    if (stacked) {
      outW = math.max(oneD.width, twoD.width) + 2 * padPx;
      outH = oneD.height + twoD.height + gapPx + 2 * padPx;
    } else {
      outW = oneD.width + twoD.width + gapPx + 2 * padPx;
      outH = math.max(oneD.height, twoD.height) + 2 * padPx;
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
        Paint()..color = const Color(0xFFFFFFFF));

    void drawCentered(ui.Image img, double left, double top, double boxW,
        double boxH) {
      final dx = left + (boxW - img.width) / 2;
      final dy = top + (boxH - img.height) / 2;
      canvas.drawImage(img, Offset(dx, dy), Paint());
    }

    final pad = padPx.toDouble();
    if (stacked) {
      final contentW = (outW - 2 * padPx).toDouble();
      drawCentered(twoD, pad, pad, contentW, twoD.height.toDouble());
      drawCentered(oneD, pad, (padPx + twoD.height + gapPx).toDouble(),
          contentW, oneD.height.toDouble());
    } else {
      final contentH = (outH - 2 * padPx).toDouble();
      drawCentered(twoD, pad, pad, twoD.width.toDouble(), contentH);
      drawCentered(oneD, (padPx + twoD.width + gapPx).toDouble(), pad,
          oneD.width.toDouble(), contentH);
    }

    final picture = recorder.endRecording();
    return picture.toImage(outW, outH);
  }
}
