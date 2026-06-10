// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macos_ui/macos_ui.dart';

import '../models/size_result.dart';
import '../sizing/dpi.dart';
import '../state/app_controller.dart';

class SizeReadout extends ConsumerWidget {
  const SizeReadout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appControllerProvider);
    final theme = MacosTheme.of(context);

    PhysicalSize? outer;
    String geometry = '—';
    int? bytesReq;
    int? bytesCap;
    LogoLine? logo;
    final warnings = <String>[];

    if (s.mode.isSerialized) {
      final batch = ref.watch(batchProvider);
      final sample = batch?.sampleSize;
      if (batch != null && batch.items.isNotEmpty && sample != null) {
        final dpi = s.safeDpi;
        // Use the orientation-adjusted width and the *finite* page height
        // (pageHeightMm is the content length a continuous web actually
        // occupies — batch.page.heightMm is double.infinity for a flexo web,
        // and .round() on infinity throws, crashing the whole readout).
        final pageWmm = batch.effectiveWidthMm;
        final pageHmm = batch.pageHeightMm;
        outer = PhysicalSize(
          widthMm: pageWmm,
          heightMm: pageHmm,
          widthPx: (Dpi.mmToInch(pageWmm) * dpi).round(),
          heightPx: (Dpi.mmToInch(pageHmm) * dpi).round(),
          dpi: dpi,
        );
        final per = batch.hasOneD && batch.hasTwoD
            ? '2D ${batch.twoDSize!.geometryLabel} + 1D ${batch.oneDSize!.geometryLabel}'
            : sample.geometryLabel;
        geometry =
            'Per cell: $per\nGrid ${batch.columns} × ${batch.rows} = ${batch.perPage}/page · ${batch.pageCount} page(s) · ${batch.items.length} codes';
        if (batch.twoDSize != null) warnings.addAll(batch.twoDSize!.warnings);
        if (batch.oneDSize != null) warnings.addAll(batch.oneDSize!.warnings);
        if (!sample.fits) {
          warnings.insert(0, 'Data does not fit the chosen symbol.');
        }
      }
    } else if (s.mode.isCombo) {
      final label = ref.watch(combinedLabelProvider);
      if (label != null) {
        outer = label.outer;
        geometry =
            '2D ${label.twoDSize.geometryLabel} · 1D ${label.oneDSize.geometryLabel}';
        bytesReq = label.twoDSize.bytesRequested;
        bytesCap = label.twoDSize.bytesCapacity;
        logo = _logoLine(label.twoDSize);
        warnings.addAll(label.warnings);
      }
    } else {
      final r = ref.watch(singleSizeProvider);
      if (r != null) {
        outer = r.outer;
        geometry = r.geometryLabel;
        bytesReq = r.bytesRequested;
        bytesCap = r.bytesCapacity;
        logo = _logoLine(r);
        warnings.addAll(r.warnings);
        if (!r.fits) warnings.insert(0, 'Data does not fit this symbol.');
      }
    }

    return Container(
      height: 168,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: theme.canvasColor,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Outer perimeter',
                    style: theme.typography.caption1
                        .copyWith(color: MacosColors.systemGrayColor)),
                const SizedBox(height: 4),
                Text(outer?.mm ?? '—',
                    style: theme.typography.largeTitle
                        .copyWith(fontWeight: FontWeight.w600)),
                Text(
                    outer == null
                        ? ''
                        : '${outer.inch}   ·   ${outer.px} @ ${outer.dpi.round()} DPI',
                    style: theme.typography.body
                        .copyWith(color: MacosColors.systemGrayColor)),
                const SizedBox(height: 8),
                Text(geometry, style: theme.typography.body),
                if (bytesReq != null)
                  Text(
                    bytesCap == null
                        ? '$bytesReq bytes'
                        : '$bytesReq / $bytesCap bytes used',
                    style: theme.typography.body,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (logo != null) _logoWidget(context, logo),
                const SizedBox(height: 6),
                Expanded(
                  child: ListView(
                    children: [
                      for (final w in warnings)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('⚠  $w',
                              style: theme.typography.caption1.copyWith(
                                  color: MacosColors.systemOrangeColor)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  LogoLine? _logoLine(SizeResult r) {
    final b = r.logoBudget;
    if (b == null) return null;
    return LogoLine(
      fits: b.fits,
      text:
          'Logo ${(b.logoAreaFraction * 100).toStringAsFixed(1)}% of ${(b.budgetFraction * 100).toStringAsFixed(1)}% budget · max ≈ ${b.maxSafeLogoMm.toStringAsFixed(1)} mm',
    );
  }

  Widget _logoWidget(BuildContext context, LogoLine l) {
    final color =
        l.fits ? MacosColors.systemGreenColor : MacosColors.systemRedColor;
    return Row(
      children: [
        Icon(l.fits ? CupertinoIcons.check_mark_circled : CupertinoIcons.xmark_circle,
            size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(l.text,
              style: MacosTheme.of(context)
                  .typography
                  .caption1
                  .copyWith(color: color)),
        ),
      ],
    );
  }
}

class LogoLine {
  final bool fits;
  final String text;
  const LogoLine({required this.fits, required this.text});
}
