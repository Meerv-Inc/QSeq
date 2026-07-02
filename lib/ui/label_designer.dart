// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

// The interactive label designer (ported from the web app): a sized label on
// which the workspace's code(s), a title and ONE shared human-readable line
// have free mm-positions — click to select, drag to move, drag the corner
// handle to resize, with edge/centre snapping.
import 'dart:io';
import 'dart:math' as math;

import 'package:barcode_widget/barcode_widget.dart' as bw;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macos_ui/macos_ui.dart';

import '../models/label_spec.dart';
import '../models/symbology.dart';
import '../render/barcode_factory.dart';
import '../state/app_controller.dart';

class LabelDesigner extends ConsumerStatefulWidget {
  const LabelDesigner({super.key});

  @override
  ConsumerState<LabelDesigner> createState() => _LabelDesignerState();
}

class _LabelDesignerState extends ConsumerState<LabelDesigner> {
  String? _dragKey;
  bool _dragResize = false;
  double _grabDx = 0, _grabDy = 0;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appControllerProvider);
    final spec = ref.watch(labelSpecProvider);
    final selected = ref.watch(labelSelectionProvider);
    final t = labelTexts(s.data);

    final show2D = s.mode.use2D && spec.twoDOn;
    final show1D = s.mode.use1D && spec.oneDOn;
    final n2 = show2D
        ? naturalLabelSymbolSize(
            symbology: s.twoDSymbology,
            data: t.d2,
            ecLevel: s.ecLevel,
            pdf417EcLevel: s.pdf417EcLevel,
            dpi: s.safeDpi,
            xDimensionMm: s.safeXDimensionMm,
            barHeightMm: s.safeBarHeightMm)
        : null;
    final n1 = show1D
        ? naturalLabelSymbolSize(
            symbology: s.oneDSymbology,
            data: t.d1,
            ecLevel: s.ecLevel,
            dpi: s.safeDpi,
            xDimensionMm: s.safeXDimensionMm,
            barHeightMm: s.safeBarHeightMm)
        : null;
    if ((show2D && n2 == null) || (show1D && n1 == null)) {
      return Center(
          child: Text('Data does not fit — adjust the inputs',
              style: MacosTheme.of(context).typography.body));
    }

    // PDF417 is too wide to sit side by side with a 1D code, so the label
    // designer forces it above the 1D code the same way the static combined
    // label and serialized sheets already do.
    final needsStacked2D =
        show2D && show1D && s.twoDSymbology == Symbology.pdf417;

    // Arrange missing elements; push the arrangement into state after the
    // frame so drags operate on the same rects we painted.
    var arranged = spec;
    final missing = labelElementKeys.any((k) =>
        _enabled(k, spec, show2D, show1D) && !spec.rects.containsKey(k));
    final stackingMismatch =
        needsStacked2D && labelLayoutIsSideBySide(spec);
    if (missing || stackingMismatch) {
      arranged = spec.clone();
      autoArrangeLabel(arranged, n2, n1, stacked2D: needsStacked2D);
      final push = arranged;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(labelSpecProvider.notifier).set(push);
      });
    }
    // Symbols keep their true aspect: height follows width.
    final r2 = arranged.rects['twoD'];
    if (r2 != null && n2 != null) r2.h = r2.w * n2.h / n2.w;
    final r1 = arranged.rects['oneD'];
    if (r1 != null && n1 != null) r1.h = r1.w * n1.h / n1.w;

    return LayoutBuilder(builder: (context, box) {
      final maxW = box.maxWidth.isFinite ? box.maxWidth - 60 : 560.0;
      final maxH = box.maxHeight.isFinite ? box.maxHeight - 60 : 420.0;
      final k = math
          .min(maxW / arranged.wMm, maxH / arranged.hMm)
          .clamp(1.0, 14.0)
          .toDouble();
      return Center(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (d) => _down(d.localPosition, arranged, k, show2D, show1D),
          onPanUpdate: (d) => _move(d.localPosition, k),
          onPanEnd: (_) => _dragKey = null,
          onPanCancel: () => _dragKey = null,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: SizedBox(
              width: arranged.wMm * k,
              height: arranged.hMm * k,
              child: Stack(children: [
                Positioned.fill(
                    child: Container(color: const Color(0xFFFFFFFF))),
                if (arranged.bgImagePath != null)
                  Positioned.fill(
                    child: Image.file(File(arranged.bgImagePath!),
                        fit: BoxFit.fill,
                        errorBuilder: (_, _, _) => const SizedBox()),
                  ),
                if (show2D && r2 != null)
                  _positioned(
                      r2,
                      k,
                      _symbol(s, s.twoDSymbology, t.d2, r2.w * k, r2.h * k,
                          logo: true)),
                if (show1D && r1 != null)
                  _positioned(
                      r1,
                      k,
                      _symbol(s, s.oneDSymbology, t.d1, r1.w * k, r1.h * k)),
                if (arranged.titleOn && arranged.title.isNotEmpty)
                  _title(arranged, k),
                if (arranged.hriOn) _hri(arranged, t.hri, k),
                if (arranged.frameShown)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                          painter: _DashedRectPainter(
                              const Color(0xFF39C1FF),
                              math.max(1.0, arranged.wMm * 0.002 * k))),
                    ),
                  ),
                if (selected != null &&
                    _enabled(selected, arranged, show2D, show1D) &&
                    arranged.rects[selected] != null)
                  _selection(arranged.rects[selected]!, k),
              ]),
            ),
          ),
        ),
      );
    });
  }

  bool _enabled(String key, LabelSpec spec, bool show2D, bool show1D) =>
      switch (key) {
        'twoD' => show2D,
        'oneD' => show1D,
        'title' => spec.titleOn,
        'hri' => spec.hriOn,
        _ => false,
      };

  Widget _positioned(ElRect r, double k, Widget child) => Positioned(
      left: r.x * k, top: r.y * k, width: r.w * k, height: r.h * k,
      child: IgnorePointer(child: child));

  Widget _symbol(AppSettings s, dynamic symbology, String data, double w,
      double h,
      {bool logo = false}) {
    final code = bw.BarcodeWidget(
      barcode: BarcodeFactory.build(
        symbology,
        ecLevel: symbology.supportsEcLevel ? s.ecLevel : null,
        pdf417EcLevel: symbology.supportsPdf417EcLevel ? s.pdf417EcLevel : null,
      ),
      data: data,
      width: w,
      height: h,
      drawText: false,
      color: const Color(0xFF000000),
      errorBuilder: (_, _) => const SizedBox(),
    );
    if (!logo || s.logoSideMm <= 0 || !symbology.supportsLogo) return code;
    // Centre dead-space (and the picked logo image) at the same fraction the
    // exports print.
    final n = naturalLabelSymbolSize(
        symbology: s.twoDSymbology,
        data: data,
        ecLevel: s.ecLevel,
        dpi: s.safeDpi,
        xDimensionMm: s.safeXDimensionMm,
        barHeightMm: s.safeBarHeightMm);
    final frac = (n == null || n.w <= 0)
        ? 0.0
        : (s.logoSideMm / n.w).clamp(0.0, 0.9);
    if (frac <= 0) return code;
    return Stack(alignment: Alignment.center, children: [
      code,
      Container(
        width: w * frac,
        height: w * frac,
        color: const Color(0xFFFFFFFF),
        child: s.logoImagePath != null
            ? Image.file(File(s.logoImagePath!),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox())
            : null,
      ),
    ]);
  }

  Widget _title(LabelSpec spec, double k) {
    final r = spec.rects['title']!;
    final font = math.max(1.5, r.h / 1.4) * k;
    return Positioned(
      left: r.x * k,
      top: r.y * k,
      width: r.w * k,
      height: r.h * k,
      child: IgnorePointer(
        child: Text(spec.title,
            textAlign: TextAlign.center,
            overflow: TextOverflow.clip,
            style: TextStyle(
                fontSize: font,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF000000))),
      ),
    );
  }

  Widget _hri(LabelSpec spec, String text, double k) {
    final r = spec.rects['hri'];
    if (r == null) return const SizedBox();
    final fontMm = spec.hriFontMm > 0
        ? spec.hriFontMm.clamp(0.8, 30.0)
        : math.max(1.2, math.min(3.2, r.h / 2.6));
    return Positioned(
      left: r.x * k,
      top: r.y * k,
      width: r.w * k,
      child: IgnorePointer(
        child: Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: fontMm * k,
                fontFamily: 'monospace',
                color: const Color(0xFF000000))),
      ),
    );
  }

  Widget _selection(ElRect r, double k) {
    const hs = 9.0; // handle px
    return Positioned(
      left: r.x * k,
      top: r.y * k,
      width: r.w * k,
      height: r.h * k,
      child: IgnorePointer(
        child: Stack(children: [
          Positioned.fill(
              child: CustomPaint(
                  painter: _DashedRectPainter(const Color(0xFF2AA6FF), 1.2))),
          const Positioned(
              right: 0,
              bottom: 0,
              child: SizedBox(
                  width: hs,
                  height: hs,
                  child: ColoredBox(color: Color(0xFF2AA6FF)))),
        ]),
      ),
    );
  }

  // ---- drag (mm space) ----
  void _down(Offset local, LabelSpec spec, double k, bool show2D, bool show1D) {
    final mx = local.dx / k, my = local.dy / k;
    String? hit;
    for (final key in const ['title', 'hri', 'twoD', 'oneD']) {
      if (!_enabled(key, spec, show2D, show1D)) continue;
      final r = spec.rects[key];
      if (r == null) continue;
      if (mx >= r.x && mx <= r.x + r.w && my >= r.y && my <= r.y + r.h) {
        hit = key;
        break;
      }
    }
    _dragKey = hit;
    _dragResize = false;
    if (hit != null) {
      final r = spec.rects[hit]!;
      final tol = math.max(2.5, 14 / k);
      _dragResize = (mx - (r.x + r.w)).abs() <= tol &&
          (my - (r.y + r.h)).abs() <= tol;
      _grabDx = mx - r.x;
      _grabDy = my - r.y;
    }
    ref.read(labelSelectionProvider.notifier).set(hit);
  }

  void _move(Offset local, double k) {
    final key = _dragKey;
    if (key == null) return;
    final mx = local.dx / k, my = local.dy / k;
    ref.read(labelSpecProvider.notifier).mutate((spec) {
      final r = spec.rects[key];
      if (r == null) return;
      if (_dragResize) {
        var nw = math.max(3.0, mx - r.x);
        if (spec.snap) nw = nw.roundToDouble();
        r.w = math.min(nw, spec.wMm - r.x);
      } else {
        var nx = mx - _grabDx;
        var ny = my - _grabDy;
        if (spec.snap) {
          nx = nx.roundToDouble();
          ny = ny.roundToDouble();
        }
        const sn = 1.6;
        if (nx.abs() < sn) nx = 0;
        if ((nx + r.w - spec.wMm).abs() < sn) nx = spec.wMm - r.w;
        if ((nx + r.w / 2 - spec.wMm / 2).abs() < sn) {
          nx = spec.wMm / 2 - r.w / 2;
        }
        if (ny.abs() < sn) ny = 0;
        if ((ny + r.h - spec.hMm).abs() < sn) ny = spec.hMm - r.h;
        r.x = nx.clamp(0, math.max(0, spec.wMm - r.w));
        r.y = ny.clamp(0, math.max(0, spec.hMm - r.h));
      }
    });
  }
}

class _DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  const _DashedRectPainter(this.color, this.strokeWidth);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    const dash = 6.0, gapLen = 4.5;
    final path = Path()
      ..addRect(Rect.fromLTWH(strokeWidth / 2, strokeWidth / 2,
          size.width - strokeWidth, size.height - strokeWidth));
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(
            metric.extractPath(d, math.min(d + dash, metric.length)), paint);
        d += dash + gapLen;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRectPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}
