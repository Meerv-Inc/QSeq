// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:barcode_widget/barcode_widget.dart' as bw;
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macos_ui/macos_ui.dart';

import '../models/batch.dart';
import '../models/caption.dart';
import '../models/combined_label.dart';
import '../models/encode_config.dart';
import '../models/label_spec.dart';
import '../models/size_result.dart';
import '../render/barcode_factory.dart';
import '../render/label_export.dart';
import '../state/app_controller.dart';
import 'export_actions.dart';
import 'label_designer.dart';
import 'ruler_strip.dart';

class PreviewPane extends ConsumerWidget {
  const PreviewPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appControllerProvider);
    // The preview is always a light "paper" surface (light-grey stage, white
    // card). Pin it to the light theme so its text — the HRI under each code,
    // the scale label — stays dark and legible even when the app is following a
    // dark system theme (otherwise light theme text vanishes on white paper).
    return MacosTheme(
      data: MacosThemeData.light(),
      child: Builder(
        builder: (context) => Container(
          color: const Color(0xFFF2F2F4),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(24),
          // The label designer takes over single workspaces when the overlay is
          // on; label SHEETS now render WYSIWYG — a tiled sheet of the designed
          // label, one per serial, matching the exported PDF.
          child: s.labelOn && !s.mode.isSerialized
              ? const LabelDesigner()
              : s.labelOn && s.mode.isSerialized
              ? const _LabelSheetView()
              : s.mode.isSerialized
              ? _batch(context, ref, s)
              : s.mode.isCombo
              ? _combined(context, ref, s)
              : _single(context, ref, s),
        ),
      ),
    );
  }

  Widget _batch(BuildContext context, WidgetRef ref, AppSettings s) {
    final batch = ref.watch(batchProvider);
    if (batch == null || batch.items.isEmpty) {
      return _message(context, 'Set a valid data source and count');
    }
    // Page browser: slice the batch to the page being viewed, mirroring how the
    // PDF paginates onto the chosen page size. A continuous web is one page.
    final pageCount = batch.pageCount < 1 ? 1 : batch.pageCount;
    final pageIndex = ref.watch(batchPageProvider).clamp(0, pageCount - 1);
    final perPage = batch.perPage;
    // Cap the on-screen cells per page so a long continuous web stays responsive;
    // the exported PDF still emits every code.
    const previewCap = 120;
    final pageItems = batch.items
        .skip(pageIndex * perPage)
        .take(perPage)
        .toList();
    final shown = pageItems.take(previewCap).toList();
    final hiddenOnPage = pageItems.length - shown.length;
    final cols = batch.columns < 1 ? 1 : batch.columns;
    final zoom = ref.watch(batchZoomProvider);
    // Display scale (px per mm at 100%). Base it on the 2D code (or the 1D when
    // there is no 2D) — NOT the widest element — so a very wide GS1-128 in a
    // 1D+2D cell can't collapse the whole sheet to a few pixels. Every size
    // below (page, cells, gaps, rulers) derives from this one scale, then the
    // sheet is scaled by [zoom] to fit the stage.
    final refSize = batch.twoDSize ?? batch.oneDSize;
    final refMm = refSize?.outer.widthMm ?? 0;
    final refTargetPx = batch.hasTwoD ? 110.0 : 320.0;
    final trueScale = refMm > 0 ? refTargetPx / refMm : 8.0;
    final refPpm = trueScale;
    final gap = batch.cellGapMm * trueScale;
    final cellWpx = batch.cellWidthMm * trueScale;
    final twoWpx = (batch.twoDSize?.outer.widthMm ?? 0) * trueScale;
    final twoHpx = (batch.twoDSize?.outer.heightMm ?? 0) * trueScale;
    // Centre logo dead-space as a fraction of the 2D symbol's outer width, so the
    // serialized preview shows the same knockout (and picked logo image) that the
    // exported PDF prints — matching the single/combined previews.
    final twoOuterMm = batch.twoDSize?.outer.widthMm ?? 0;
    final twoLogoFrac =
        (batch.hasTwoD &&
            (batch.twoDSample?.symbology.supportsLogo ?? false) &&
            (batch.twoDSample?.logoSideMm ?? 0) > 0 &&
            twoOuterMm > 0)
        ? batch.twoDSample!.logoSideMm / twoOuterMm
        : 0.0;
    final oneWpx = (batch.oneDSize?.outer.widthMm ?? 0) * trueScale;
    final oneHpx = (batch.oneDSize?.outer.heightMm ?? 0) * trueScale;
    // One sheet cell: the 2D and/or 1D code with its HRI underneath, every
    // dimension at the same physical scale as the page.
    Widget cell(BatchItem it) => SizedBox(
      width: cellWpx,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (batch.hasTwoD && it.twoDData != null) ...[
            _logoOverlay(
              bw.BarcodeWidget(
                barcode: BarcodeFactory.build(
                  batch.twoDSample!.symbology,
                  ecLevel: batch.twoDSample!.ecLevel,
                  pdf417EcLevel: batch.twoDSample!.pdf417EcLevel,
                ),
                data: it.twoDData!,
                width: twoWpx,
                height: twoHpx,
                drawText: false,
                errorBuilder: (c, e) => _inlineError(e),
              ),
              twoWpx,
              twoLogoFrac,
              s.logoImagePath,
            ),
            const SizedBox(height: 6),
            _hri(
              context,
              LabelCaption.hri(it.twoDData!, boldTail: it.counter),
              cellWpx,
            ),
          ],
          if (batch.hasOneD && it.oneDData != null) ...[
            const SizedBox(height: 12),
            bw.BarcodeWidget(
              barcode: BarcodeFactory.build(batch.oneDSample!.symbology),
              data: it.oneDData!,
              width: oneWpx,
              height: oneHpx,
              drawText: false,
              errorBuilder: (c, e) => _inlineError(e),
            ),
            const SizedBox(height: 6),
            _hri(
              context,
              LabelCaption.hri(it.oneDData!, boldTail: it.counter),
              cellWpx,
            ),
          ],
        ],
      ),
    );

    // Lay the codes out as a fixed [cols]-wide grid (the page's real column
    // count) so the white "page" takes the page's portrait/landscape shape and
    // re-flows whenever the size or orientation changes.
    final gridRows = <Widget>[
      for (var i = 0; i < shown.length; i += cols)
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : gap),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var j = i; j < i + cols && j < shown.length; j++) ...[
                if (j > i) SizedBox(width: gap),
                cell(shown[j]),
              ],
            ],
          ),
        ),
    ];

    // The white page at true physical scale: its width/height carry the page's
    // portrait or landscape shape, with the codes filling the top-left content
    // area and the rest left as the printed margin.
    final pageWpx = batch.effectiveWidthMm * trueScale;
    final pageHpx = batch.pageHeightMm * trueScale;
    final marginPx = batch.marginMm * trueScale;
    final pageTrue = Container(
      width: pageWpx,
      height: pageHpx,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 12, spreadRadius: 1),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(marginPx),
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: 0,
          minHeight: 0,
          maxWidth: double.infinity,
          maxHeight: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: gridRows,
          ),
        ),
      ),
    );

    // Page + a vertical ruler down its right edge, all at true scale
    // (the ruler band is omitted entirely when screen rulers are off).
    const rulerBand = 30.0;
    final sheetTrue = !s.rulersOnScreen
        ? pageTrue
        : Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              pageTrue,
              const SizedBox(width: 6),
              RulerStrip(
                pxPerMm: trueScale,
                lengthPx: pageHpx,
                horizontal: false,
              ),
            ],
          );
    final sheetW = pageWpx + (s.rulersOnScreen ? 6 + rulerBand : 0);
    final sheetH = pageHpx;

    return LayoutBuilder(
      builder: (context, box) {
        // "Fit" zoom: shrink the whole sheet to sit inside the visible stage.
        final availW = box.maxWidth.isFinite ? box.maxWidth - 24 : sheetW;
        final availH = box.maxHeight.isFinite ? box.maxHeight - 120 : sheetH;
        final fitZoom = sheetW > 0 && sheetH > 0
            ? [
                availW / sheetW,
                availH / sheetH,
              ].reduce((a, b) => a < b ? a : b).clamp(0.1, 3.0).toDouble()
            : 1.0;
        // zoom == 0 means auto-fit; otherwise honour the explicit zoom.
        final z = zoom <= 0 ? fitZoom : zoom;
        // Scale the laid-out sheet uniformly. FittedBox measures the sheet at
        // its natural size and scales it to fill the zoomed box, so the inner
        // Row isn't squished (a constraining Transform would overflow it); the
        // outer SizedBox reports the scaled footprint so scrollbars track it.
        final sheet = SizedBox(
          width: sheetW * z,
          height: sheetH * z,
          child: FittedBox(
            fit: BoxFit.fill,
            child: SizedBox(width: sheetW, height: sheetH, child: sheetTrue),
          ),
        );
        return Column(
          children: [
            _zoomBar(context, ref, z),
            Expanded(
              child: _SheetScroll(
                child: Padding(padding: const EdgeInsets.all(8), child: sheet),
              ),
            ),
            if (refPpm > 0 && s.rulersOnScreen)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Scale  ',
                      style: MacosTheme.of(context).typography.caption2,
                    ),
                    RulerStrip(
                      pxPerMm: refPpm * z,
                      lengthPx: (60 * refPpm * z).clamp(120, 360).toDouble(),
                    ),
                  ],
                ),
              ),
            if (hiddenOnPage > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Showing first $previewCap of ${pageItems.length} on this page · all export to PDF',
                  style: MacosTheme.of(context).typography.caption2,
                ),
              ),
            _pageBrowser(
              context,
              ref,
              s.pageFormat,
              pageIndex,
              pageCount,
              batch.items.length,
              perPage,
            ),
          ],
        );
      },
    );
  }

  /// External zoom controls for the serialized sheet: fit-to-stage, zoom out/in,
  /// and reset to 100% (true physical scale).
  Widget _zoomBar(BuildContext context, WidgetRef ref, double zoom) {
    final type = MacosTheme.of(context).typography;
    void set(double z) => ref.read(batchZoomProvider.notifier).set(z);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          PushButton(
            controlSize: ControlSize.small,
            secondary: true,
            onPressed: () => set(0), // 0 = auto-fit
            child: const Text('Fit'),
          ),
          const SizedBox(width: 8),
          MacosIconButton(
            icon: const MacosIcon(CupertinoIcons.minus),
            onPressed: () => set(zoom / 1.25),
          ),
          SizedBox(
            width: 52,
            child: Text(
              '${(zoom * 100).round()}%',
              textAlign: TextAlign.center,
              style: type.caption1,
            ),
          ),
          MacosIconButton(
            icon: const MacosIcon(CupertinoIcons.plus),
            onPressed: () => set(zoom * 1.25),
          ),
          const SizedBox(width: 8),
          PushButton(
            controlSize: ControlSize.small,
            secondary: true,
            onPressed: () => set(1.0),
            child: const Text('100%'),
          ),
        ],
      ),
    );
  }

  /// Tabbed page browser pinned to the bottom of a serialized sheet, mirroring
  /// the web version: one tab per printed page, horizontally scrollable, the
  /// active tab highlighted. A continuous web reads as a single endless page.
  Widget _pageBrowser(
    BuildContext context,
    WidgetRef ref,
    PageFormat fmt,
    int pageIndex,
    int pageCount,
    int total,
    int perPage,
  ) {
    final type = MacosTheme.of(context).typography;
    if (fmt.isContinuous) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Text(
          '${fmt.label} · $total code${total == 1 ? '' : 's'} on one endless page',
          style: type.caption2.copyWith(color: MacosColors.systemGrayColor),
        ),
      );
    }
    return _PageTabs(
      info: '${fmt.label} · $pageCount page${pageCount == 1 ? '' : 's'}',
      pageIndex: pageIndex,
      pageCount: pageCount,
      onSelect: (p) => ref.read(batchPageProvider.notifier).set(p),
    );
  }

  /// Full human-readable interpretation under a code — the entire encoded
  /// string, wrapped, with the incrementing serial in bold.
  Widget _hri(BuildContext context, LabelCaption cap, double maxWidth) {
    final base = MacosTheme.of(
      context,
    ).typography.caption2.copyWith(fontFamily: 'monospace', height: 1.3);
    final bold = base.copyWith(fontWeight: FontWeight.bold);
    final full = cap.prefix + cap.bold;
    final boldLen = cap.bold.length;

    // For a URI, the domain (scheme + host) gets its own first line; the path
    // then wraps onto a second/third line, but only ever at a slash so the
    // numeric segments never split mid-run. The trailing serial stays bold.
    final scheme = full.indexOf('://');
    final List<InlineSpan> spans;
    if (scheme >= 0) {
      final pathStart = full.indexOf('/', scheme + 3);
      final domain = pathStart >= 0 ? full.substring(0, pathStart) : full;
      final path = pathStart >= 0 ? full.substring(pathStart) : '';
      // A zero-width space before each '/' is the only break opportunity, so the
      // line breaker can wrap at slashes and nowhere else.
      String slashBreak(String s) => s.replaceAll('/', '​/');
      final cut = boldLen <= path.length ? path.length - boldLen : path.length;
      spans = [
        TextSpan(text: '$domain\n', style: base),
        TextSpan(text: slashBreak(path.substring(0, cut)), style: base),
        if (cut < path.length)
          TextSpan(text: slashBreak(path.substring(cut)), style: bold),
      ];
    } else {
      spans = [
        TextSpan(text: cap.prefix, style: base),
        if (cap.bold.isNotEmpty) TextSpan(text: cap.bold, style: bold),
      ];
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Text.rich(
        TextSpan(children: spans),
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
    final frac = (cfg.symbology.supportsLogo && cfg.logoSideMm > 0 && size != null)
        ? _fracFor(cfg.logoSideMm, size)
        : 0.0;
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
          if (ppmH > 0 && ppmV > 0 && s.rulersOnScreen)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                symbol,
                const SizedBox(width: 16),
                RulerStrip(pxPerMm: ppmV, lengthPx: dispH, horizontal: false),
              ],
            )
          else
            symbol,
          if (ppmH > 0 && s.rulersOnScreen)
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
      _symbol(
        label.twoD,
        logoFraction: label.twoD.symbology.supportsLogo
            ? _fracFor(s.safeLogoSideMm, label.twoDSize)
            : 0.0,
        logoPath: s.logoImagePath,
      ),
    );
    final oneD = block(label.oneD, _symbol(label.oneD));
    const gap = SizedBox(width: 20, height: 18);
    return _card(
      child: label.arrangement == LabelArrangement.stacked
          ? Column(mainAxisSize: MainAxisSize.min, children: [twoD, gap, oneD])
          : Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [twoD, gap, oneD],
            ),
    );
  }

  /// One symbol with optional centre logo dead-space overlay.
  Widget _symbol(
    EncodeConfig cfg, {
    double logoFraction = 0,
    String? logoPath,
  }) {
    final is2D = cfg.symbology.is2D;
    final barcode = BarcodeFactory.build(
      cfg.symbology,
      ecLevel: cfg.ecLevel,
      pdf417EcLevel: cfg.pdf417EcLevel,
    );
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
    return _logoOverlay(widget, side, logoFraction, logoPath);
  }

  /// Overlays the centre logo dead-space on a 2D code: a white knockout square
  /// sized to [logoFraction] of [codePx], holding the picked logo image when
  /// one is set. Shared by the single, combined and serialized previews so all
  /// three match the exported PDF.
  Widget _logoOverlay(
    Widget code,
    double codePx,
    double logoFraction,
    String? logoPath,
  ) {
    if (logoFraction <= 0) return code;
    final logoSide = codePx * logoFraction.clamp(0.0, 0.5);
    return Stack(
      alignment: Alignment.center,
      children: [
        code,
        Container(
          width: logoSide + 6,
          height: logoSide + 6,
          color: const Color(0xFFFFFFFF),
          alignment: Alignment.center,
          child: (logoPath != null && File(logoPath).existsSync())
              ? Image.file(
                  File(logoPath),
                  width: logoSide,
                  height: logoSide,
                  fit: BoxFit.contain,
                )
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
    return Text(
      text,
      style: MacosTheme.of(
        context,
      ).typography.title3.copyWith(color: MacosColors.systemGrayColor),
    );
  }

  Widget _inlineError(String error) => SizedBox(
    width: 240,
    child: Text(
      error,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Color(0xFFCC0000), fontSize: 12),
    ),
  );
}

/// A vertically-scrolling area for the serialized sheet that keeps its
/// scrollbar in a dedicated right-hand gutter instead of overlaying the last
/// column of codes. Owns its controller so the bar and the view stay attached.
class _SheetScroll extends StatefulWidget {
  final Widget child;
  const _SheetScroll({required this.child});

  @override
  State<_SheetScroll> createState() => _SheetScrollState();
}

class _SheetScrollState extends State<_SheetScroll> {
  final _vController = ScrollController();
  final _hController = ScrollController();

  @override
  void dispose() {
    _vController.dispose();
    _hController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Vertical scroll (outer) with a right-hand gutter for its bar, plus a
    // horizontal scroll (inner) so a wide landscape sheet can be panned without
    // shrinking the codes below their true physical scale.
    return RawScrollbar(
      controller: _vController,
      thumbVisibility: true,
      interactive: true,
      thumbColor: const Color(0x88888888),
      radius: const Radius.circular(6),
      thickness: 10,
      child: SingleChildScrollView(
        controller: _vController,
        padding: const EdgeInsets.only(right: 18),
        child: RawScrollbar(
          controller: _hController,
          thumbVisibility: true,
          interactive: true,
          thumbColor: const Color(0x88888888),
          radius: const Radius.circular(6),
          thickness: 10,
          scrollbarOrientation: ScrollbarOrientation.bottom,
          child: SingleChildScrollView(
            controller: _hController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 14),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// The bottom page-tab strip for a serialized sheet — one tab per printed page,
/// horizontally scrollable, with the active page highlighted and scrolled into
/// view. Mirrors the web page browser; stateful only to hold the scroll
/// controller and reveal the active tab after each change.
class _PageTabs extends StatefulWidget {
  final String info;
  final int pageIndex;
  final int pageCount;
  final ValueChanged<int> onSelect;

  const _PageTabs({
    required this.info,
    required this.pageIndex,
    required this.pageCount,
    required this.onSelect,
  });

  @override
  State<_PageTabs> createState() => _PageTabsState();
}

class _PageTabsState extends State<_PageTabs> {
  final _scroll = ScrollController();
  final _activeKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
  }

  @override
  void didUpdateWidget(covariant _PageTabs old) {
    super.didUpdateWidget(old);
    if (old.pageIndex != widget.pageIndex ||
        old.pageCount != widget.pageCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // Keep the active page tab centred in the horizontally-scrolling strip.
  void _reveal() {
    final ctx = _activeKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: const Duration(milliseconds: 200),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = MacosTheme.of(context).typography;
    final atStart = widget.pageIndex <= 0;
    final atEnd = widget.pageIndex >= widget.pageCount - 1;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 940),
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Row(
          // Top-align so the prev/next arrows and the page tabs share the same
          // baseline. The tab strip is 10px taller than a tab (it reserves room
          // for its scrollbar), so centering would drop the 28px arrows below
          // the 28px tabs and make them look like a different height.
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 28,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.info,
                    style: type.caption2.copyWith(
                      color: MacosColors.systemGrayColor,
                    ),
                  ),
                ),
              ),
            ),
            _arrow(
              left: true,
              enabled: !atStart,
              onTap: () => widget.onSelect(widget.pageIndex - 1),
            ),
            const SizedBox(width: 6),
            // The tab strip scrolls horizontally (with a visible bar) between
            // the prev/next arrows when there are more pages than fit.
            Expanded(
              child: RawScrollbar(
                controller: _scroll,
                thumbVisibility: true,
                thickness: 6,
                radius: const Radius.circular(3),
                thumbColor: const Color(0x66888888),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SingleChildScrollView(
                    controller: _scroll,
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var p = 0; p < widget.pageCount; p++)
                          Padding(
                            key: p == widget.pageIndex ? _activeKey : null,
                            padding: const EdgeInsets.only(right: 6),
                            child: _tab(p),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            _arrow(
              left: false,
              enabled: !atEnd,
              onTap: () => widget.onSelect(widget.pageIndex + 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _arrow({
    required bool left,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFEDEDED),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFD6D6D6)),
          ),
          child: Icon(
            left ? CupertinoIcons.chevron_left : CupertinoIcons.chevron_right,
            size: 14,
            color: enabled ? const Color(0xFF333333) : const Color(0xFFBBBBBB),
          ),
        ),
      ),
    );
  }

  Widget _tab(int p) {
    final active = p == widget.pageIndex;
    const accent = Color(0xFF0A84FF);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => widget.onSelect(p),
        child: Container(
          constraints: const BoxConstraints(minWidth: 32),
          height: 28,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: active ? accent : const Color(0xFFEDEDED),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: active ? accent : const Color(0xFFD6D6D6),
            ),
          ),
          child: Text(
            '${p + 1}',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
              color: active ? const Color(0xFFFFFFFF) : const Color(0xFF333333),
            ),
          ),
        ),
      ),
    );
  }
}

/// WYSIWYG preview of a SHEET of designed labels — one rendered label per serial
/// (the exact same renderer the PDF uses), tiled and paginated like the code
/// sheet. Renders lazily and only re-renders when an input that affects the
/// labels changes, so it stays responsive.
class _LabelSheetView extends ConsumerStatefulWidget {
  const _LabelSheetView();

  @override
  ConsumerState<_LabelSheetView> createState() => _LabelSheetViewState();
}

class _LabelSheetViewState extends ConsumerState<_LabelSheetView> {
  static const int _cap = 90; // max labels rendered on screen per page
  static const double _previewDpi = 140; // raster res for the on-screen sheet
  String _sig = '';
  String _pendingSig = '';
  List<ui.Image> _imgs = const [];

  @override
  void dispose() {
    for (final im in _imgs) {
      im.dispose();
    }
    super.dispose();
  }

  // The label-sheet PDF tiles with a 10 mm page margin and a 3 mm cell gap;
  // mirror those exactly so the on-screen page matches the export.
  static const double _margin = 10;
  static const double _gap = 3;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appControllerProvider);
    final batch = ref.watch(batchProvider);
    final spec = ref.watch(labelSpecProvider);
    if (batch == null || batch.items.isEmpty) {
      return _centered('Set a valid data source and count');
    }

    // Arrange the label to get its true mm footprint, then compute the same
    // grid the PDF uses: columns by label width, rows by page height.
    final a = LabelExport.arrange(s, spec, serial: batch.items.first.serial);
    final pageWmm = batch.effectiveWidthMm;
    final cols = math.max(
      1,
      ((pageWmm - 2 * _margin + _gap) / (a.wMm + _gap)).floor(),
    );
    final continuous = batch.page.isContinuous;
    final total = batch.items.length;
    final rowsPerPage = continuous
        ? ((total + cols - 1) ~/ cols)
        : math.max(
            1,
            ((batch.effectiveHeightMm - 2 * _margin + _gap) / (a.hMm + _gap))
                .floor(),
          );
    final perPage = math.max(1, cols * rowsPerPage);
    final pageCount = math.max(1, (total + perPage - 1) ~/ perPage);
    final pageIndex = ref.watch(batchPageProvider).clamp(0, pageCount - 1);
    final pageItems = batch.items.skip(pageIndex * perPage).take(perPage);
    final shown = pageItems.take(_cap).toList();
    final hidden = pageItems.length - shown.length;
    final serials = [for (final it in shown) it.serial];

    // Page height to draw: fixed for a real format, content-fit for a web.
    final phMm = continuous
        ? 2 * _margin + ((shown.length + cols - 1) ~/ cols) * (a.hMm + _gap)
        : batch.effectiveHeightMm;

    // Fingerprint everything that changes the rendered labels (the spec is
    // clone-replaced on every edit, so its identity changes when it mutates).
    // The encoded payload of each shown item — rather than individual
    // DataSourceInput fields (gtin, serialize, format, domain, ...) — is
    // used here so this can't go stale when a field is added later (it
    // already missed `rawText`, so a free-text edit never invalidated the
    // cached raster); `oneDData`/`twoDData` reflect every input field by
    // construction.
    final payloads = shown
        .map((it) => '${it.oneDData}~${it.twoDData}')
        .join('␟');
    final sig = [
      identityHashCode(spec),
      pageIndex,
      payloads,
      s.twoDSymbology.name,
      s.oneDSymbology.name,
      s.ecLevel.name,
      s.safeXDimensionMm,
      s.safeBarHeightMm,
      s.safeLogoSideMm,
      s.logoImagePath ?? '',
      s.safeLogoEcBudget,
    ].join('|');
    if (sig != _sig) _renderLatest(sig, s, spec, serials);

    final fmtLabel =
        '${batch.page.label} · '
        '$pageCount page${pageCount == 1 ? '' : 's'} · '
        '$cols×$rowsPerPage labels/page';

    return Column(
      children: [
        Expanded(
          child: _imgs.isEmpty
              ? const Center(child: ProgressCircle())
              : LayoutBuilder(
                  builder: (context, c) {
                    const band = 30.0;
                    final rulers = s.rulersOnScreen;
                    final reserveW = rulers ? band + 6 : 0.0;
                    final reserveH = rulers ? band + 4 : 0.0;
                    final scale = math.min(
                      (c.maxWidth - 8 - reserveW) / pageWmm,
                      (c.maxHeight - 8 - reserveH) / phMm,
                    );
                    final pageWpx = pageWmm * scale, pageHpx = phMm * scale;
                    final pageBox = Container(
                      width: pageWpx,
                      height: pageHpx,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFFFF),
                        border: Border.all(color: const Color(0xFFCCCCCC)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          for (var i = 0; i < _imgs.length; i++)
                            Positioned(
                              left:
                                  (_margin +
                                      _gap / 2 +
                                      (i % cols) * (a.wMm + _gap)) *
                                  scale,
                              top:
                                  (_margin +
                                      _gap / 2 +
                                      (i ~/ cols) * (a.hMm + _gap)) *
                                  scale,
                              width: a.wMm * scale,
                              height: a.hMm * scale,
                              child: RawImage(
                                image: _imgs[i],
                                fit: BoxFit.fill,
                              ),
                            ),
                        ],
                      ),
                    );
                    // True-scale rulers around the page (mm/inch/vernier), at the
                    // same px-per-mm as the rendered page.
                    final content = rulers
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: RulerStrip(
                                  pxPerMm: scale,
                                  lengthPx: pageWpx,
                                  band: band,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  pageBox,
                                  const SizedBox(width: 6),
                                  RulerStrip(
                                    pxPerMm: scale,
                                    lengthPx: pageHpx,
                                    horizontal: false,
                                    band: band,
                                  ),
                                ],
                              ),
                            ],
                          )
                        : pageBox;
                    return SingleChildScrollView(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: content,
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (hidden > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '+ $hidden more on this page — all export',
              style: const TextStyle(
                fontSize: 11,
                color: MacosColors.systemGrayColor,
              ),
            ),
          ),
        if (continuous)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              fmtLabel,
              style: const TextStyle(
                fontSize: 11,
                color: MacosColors.systemGrayColor,
              ),
            ),
          )
        else
          _PageTabs(
            info: fmtLabel,
            pageIndex: pageIndex,
            pageCount: pageCount,
            onSelect: (p) => ref.read(batchPageProvider.notifier).set(p),
          ),
      ],
    );
  }

  Future<void> _renderLatest(
    String sig,
    AppSettings s,
    LabelSpec spec,
    List<String> serials,
  ) async {
    if (sig == _pendingSig) return; // already rendering this exact state
    _pendingSig = sig;
    final ps = s.copyWith(dpi: _previewDpi);
    final out = <ui.Image>[];
    ui.Image? logo;
    try {
      // Decode the picked logo once; renderImage paints it into each label's
      // 2D centre dead-space (so the on-screen sheet matches the export).
      logo = await ExportActions.loadLogo(s.logoImagePath);
      for (final serial in serials) {
        out.add(
          await LabelExport.renderImage(ps, spec, serial: serial, logo: logo),
        );
      }
    } catch (_) {
      logo?.dispose();
      for (final im in out) {
        im.dispose();
      }
      return; // a transient invalid state (e.g. mid-edit); keep the last sheet
    }
    logo?.dispose();
    if (sig != _pendingSig) {
      // Superseded by a newer request — discard.
      for (final im in out) {
        im.dispose();
      }
      return;
    }
    if (!mounted) {
      for (final im in out) {
        im.dispose();
      }
      return;
    }
    final old = _imgs;
    setState(() {
      _sig = sig;
      _imgs = out;
    });
    for (final im in old) {
      im.dispose();
    }
  }

  Widget _centered(String msg) => Center(
    child: Text(
      msg,
      style: const TextStyle(color: MacosColors.systemGrayColor),
    ),
  );
}
