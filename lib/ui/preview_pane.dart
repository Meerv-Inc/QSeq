// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'dart:io';

import 'package:barcode_widget/barcode_widget.dart' as bw;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macos_ui/macos_ui.dart';

import '../models/caption.dart';
import '../models/combined_label.dart';
import '../models/encode_config.dart';
import '../models/size_result.dart';
import '../render/barcode_factory.dart';
import '../state/app_controller.dart';
import 'ruler_strip.dart';

class PreviewPane extends ConsumerWidget {
  const PreviewPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appControllerProvider);
    return Container(
      color: const Color(0xFFF2F2F4),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: s.mode.isSerialized
          ? _batch(context, ref, s)
          : s.mode.isCombo
              ? _combined(context, ref, s)
              : _single(context, ref, s),
    );
  }

  Widget _batch(BuildContext context, WidgetRef ref, AppSettings s) {
    final batch = ref.watch(batchProvider);
    if (batch == null || batch.items.isEmpty) {
      return _message(context, 'Set a valid data source and count');
    }
    final shown = batch.items.take(batch.perPage.clamp(1, 60)).toList();
    final cellW = batch.hasOneD ? 150.0 : 110.0;
    final twoW = batch.hasOneD ? 100.0 : cellW;
    // Scale reference: maps a displayed cell back to its physical mm.
    final refSize = batch.twoDSize ?? batch.oneDSize;
    final refDispW = batch.hasTwoD ? twoW : cellW;
    final refMm = refSize?.outer.widthMm ?? 0;
    final refPpm = refMm > 0 ? refDispW / refMm : 0.0;
    return _card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 940, maxHeight: 700),
              child: SingleChildScrollView(
                child: Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final it in shown)
                SizedBox(
                  width: cellW,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (batch.hasTwoD && it.twoDData != null) ...[
                        bw.BarcodeWidget(
                          barcode: batch.twoDSample!.symbology.supportsEcLevel
                              ? BarcodeFactory.build(
                                  batch.twoDSample!.symbology,
                                  ecLevel: batch.twoDSample!.ecLevel)
                              : BarcodeFactory.build(
                                  batch.twoDSample!.symbology),
                          data: it.twoDData!,
                          width: twoW,
                          height: twoW,
                          drawText: false,
                          errorBuilder: (c, e) => _inlineError(e),
                        ),
                        const SizedBox(height: 6),
                        _hri(
                            context,
                            LabelCaption.hri(it.twoDData!,
                                boldTail: it.counter),
                            cellW),
                      ],
                      if (batch.hasOneD && it.oneDData != null) ...[
                        const SizedBox(height: 12),
                        bw.BarcodeWidget(
                          barcode:
                              BarcodeFactory.build(batch.oneDSample!.symbology),
                          data: it.oneDData!,
                          width: cellW,
                          height: 48,
                          drawText: false,
                          errorBuilder: (c, e) => _inlineError(e),
                        ),
                        const SizedBox(height: 6),
                        _hri(
                            context,
                            LabelCaption.hri(it.oneDData!,
                                boldTail: it.counter),
                            cellW),
                      ],
                    ],
                  ),
                ),
                ],
              ),
            ),
          ),
          ),
          if (refPpm > 0)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Scale  ',
                      style: MacosTheme.of(context).typography.caption2),
                  RulerStrip(
                      pxPerMm: refPpm,
                      lengthPx: (60 * refPpm).clamp(140, 360).toDouble()),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Full human-readable interpretation under a code — the entire encoded
  /// string, wrapped, with the incrementing serial in bold.
  Widget _hri(BuildContext context, LabelCaption cap, double maxWidth) {
    final base = MacosTheme.of(context)
        .typography
        .caption2
        .copyWith(fontFamily: 'monospace', height: 1.3);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: cap.prefix, style: base),
          if (cap.bold.isNotEmpty)
            TextSpan(
                text: cap.bold,
                style: base.copyWith(fontWeight: FontWeight.bold)),
        ]),
        textAlign: TextAlign.center,
        softWrap: true,
      ),
    );
  }


  Widget _single(BuildContext context, WidgetRef ref, AppSettings s) {
    final resolved = s.resolved;
    if (resolved.data == null) {
      return _message(context, resolved.error ?? 'Enter data to encode');
    }
    final cfg = s.singleConfig;
    final size = ref.watch(singleSizeProvider);
    final frac =
        (cfg.logoSideMm > 0 && size != null) ? _fracFor(cfg.logoSideMm, size) : 0.0;
    final is2D = cfg.symbology.is2D;
    final dispW = is2D ? 240.0 : 320.0;
    final dispH = is2D ? 240.0 : 120.0;
    final wmm = size?.outer.widthMm ?? 0;
    final hmm = size?.outer.heightMm ?? 0;
    final ppmH = wmm > 0 ? dispW / wmm : 0.0;
    final ppmV = hmm > 0 ? dispH / hmm : 0.0;
    final symbol = _symbol(cfg, logoFraction: frac, logoPath: s.logoImagePath);
    final hri = LabelCaption.hri(cfg.data);

    return _card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ppmH > 0 && ppmV > 0)
            Row(mainAxisSize: MainAxisSize.min, children: [
              symbol,
              const SizedBox(width: 16),
              RulerStrip(pxPerMm: ppmV, lengthPx: dispH, horizontal: false),
            ])
          else
            symbol,
          if (ppmH > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: RulerStrip(pxPerMm: ppmH, lengthPx: dispW),
            ),
          if (hri.isNotEmpty) ...[
            const SizedBox(height: 14),
            _hri(context, hri, dispW + 40),
          ],
        ],
      ),
    );
  }

  Widget _combined(BuildContext context, WidgetRef ref, AppSettings s) {
    final label = ref.watch(combinedLabelProvider);
    if (label == null) {
      return _message(context, 'Enter a valid GTIN and serial');
    }
    Widget block(EncodeConfig cfg, Widget symbol) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            symbol,
            const SizedBox(height: 6),
            _hri(context, LabelCaption.hri(cfg.data), 260),
          ],
        );
    final twoD = block(
        label.twoD,
        _symbol(label.twoD,
            logoFraction: _fracFor(s.safeLogoSideMm, label.twoDSize),
            logoPath: s.logoImagePath));
    final oneD = block(label.oneD, _symbol(label.oneD));
    const gap = SizedBox(width: 20, height: 18);
    return _card(
      child: label.arrangement == LabelArrangement.stacked
          ? Column(mainAxisSize: MainAxisSize.min, children: [twoD, gap, oneD])
          : Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [twoD, gap, oneD]),
    );
  }

  /// One symbol with optional centre logo dead-space overlay.
  Widget _symbol(EncodeConfig cfg,
      {double logoFraction = 0, String? logoPath}) {
    final is2D = cfg.symbology.is2D;
    final barcode = cfg.symbology.supportsEcLevel
        ? BarcodeFactory.build(cfg.symbology, ecLevel: cfg.ecLevel)
        : BarcodeFactory.build(cfg.symbology);
    final side = is2D ? 240.0 : 320.0;
    final widget = bw.BarcodeWidget(
      barcode: barcode,
      data: cfg.data,
      width: side,
      height: is2D ? side : 120,
      drawText: !is2D,
      errorBuilder: (context, error) => _inlineError(error),
    );
    if (!is2D || logoFraction <= 0) return widget;

    final logoSide = side * logoFraction.clamp(0.0, 0.5);
    return Stack(
      alignment: Alignment.center,
      children: [
        widget,
        Container(
          width: logoSide + 6,
          height: logoSide + 6,
          color: const Color(0xFFFFFFFF),
          alignment: Alignment.center,
          child: (logoPath != null && File(logoPath).existsSync())
              ? Image.file(File(logoPath),
                  width: logoSide, height: logoSide, fit: BoxFit.contain)
              : null,
        ),
      ],
    );
  }

  double _fracFor(double logoMm, SizeResult size) {
    final side = size.outer.widthMm;
    return side <= 0 ? 0 : logoMm / side;
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 12, spreadRadius: 1),
        ],
      ),
      child: child,
    );
  }

  Widget _message(BuildContext context, String text) {
    return Text(text,
        style: MacosTheme.of(context)
            .typography
            .title3
            .copyWith(color: MacosColors.systemGrayColor));
  }

  Widget _inlineError(String error) => SizedBox(
        width: 240,
        child: Text(error,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFCC0000), fontSize: 12)),
      );
}
