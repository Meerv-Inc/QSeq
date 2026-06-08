// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';

import '../encoders/sgtin.dart';
import '../models/combined_label.dart';
import '../models/encode_config.dart';
import '../models/size_result.dart';
import '../render/batch_pdf.dart';
import '../render/clipboard_export.dart';
import '../render/label_renderer.dart';
import '../render/pdf_exporter.dart';
import '../render/raster_renderer.dart';
import '../render/ruler.dart';
import '../render/svg_exporter.dart';
import '../state/app_controller.dart';

/// Bundles the export operations used by the toolbar/preview buttons.
class ExportActions {
  ExportActions._();

  /// Decodes a logo image file into a [ui.Image], or null on failure.
  static Future<ui.Image?> loadLogo(String? path) async {
    if (path == null) return null;
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  static double _logoFraction(SizeResult? size, EncodeConfig cfg) {
    if (size == null || cfg.logoSideMm <= 0) return 0;
    final side = size.outer.widthMm;
    return side <= 0 ? 0 : (cfg.logoSideMm / side);
  }

  /// Renders the current static workspace to a [ui.Image] (single or combo).
  /// Serialized sheets are exported as PDF, not a single raster.
  static Future<ui.Image?> renderImage(AppSettings s) async {
    final logo = await loadLogo(s.logoImagePath);
    if (s.mode == AppMode.combo) {
      final label = _combined(s);
      return label == null ? null : LabelRenderer.render(label, logo: logo);
    }
    if (s.resolved.data == null) return null;
    return RasterRenderer.render(s.singleConfig,
        logo: logo, caption: s.data.caption());
  }

  static CombinedLabel? _combined(AppSettings s) {
    try {
      return CombinedLabel.fromSgtin(
        sgtin: Sgtin(gtin: s.data.gtin, serial: s.data.serial),
        twoDSymbology: s.twoDSymbology,
        digitalLinkDomain: s.data.digitalLinkDomain,
        dpi: s.dpi,
        xDimensionMm: s.xDimensionMm,
        barHeightMm: s.barHeightMm,
        ecLevel: s.ecLevel,
        arrangement: s.arrangement,
        gapMm: s.labelGapMm,
        paddingMm: s.labelPaddingMm,
        logoSideMm: s.logoSideMm,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<bool> exportPng(AppSettings s) async {
    var image = await renderImage(s);
    if (image == null) return false;
    image = await Ruler.addRulers(image, s.dpi);
    final bytes = await RasterRenderer.toPng(image, s.dpi);
    return _save(bytes, 'code.png', 'PNG image', ['png']);
  }

  static Future<bool> copyPng(AppSettings s) async {
    var image = await renderImage(s);
    if (image == null) return false;
    image = await Ruler.addRulers(image, s.dpi);
    final bytes = await RasterRenderer.toPng(image, s.dpi);
    return ClipboardExport.copyPng(bytes);
  }

  static Future<bool> exportSvg(AppSettings s, SizeResult? size) async {
    // SVG export covers static single codes; combos and sheets use PNG/PDF.
    if (s.mode.isCombo || s.mode.isSerialized || s.resolved.data == null) {
      return false;
    }
    final cfg = s.singleConfig;
    Uint8List? logoPng;
    if (cfg.logoSideMm > 0 && s.logoImagePath != null) {
      try {
        logoPng = await File(s.logoImagePath!).readAsBytes();
      } catch (_) {}
    }
    final svg = SvgExporter.export(
      cfg,
      logoPng: logoPng,
      logoFraction: _logoFraction(size, cfg),
      caption: s.data.caption(),
    );
    return _saveString(svg, 'code.svg', 'SVG image', ['svg']);
  }

  static Future<bool> exportBatchPdf(AppSettings s) async {
    final batch = buildBatchFor(s);
    if (batch == null || batch.items.isEmpty) return false;
    Uint8List? logoPng;
    if (s.logoImagePath != null && s.logoSideMm > 0) {
      try {
        logoPng = await File(s.logoImagePath!).readAsBytes();
      } catch (_) {}
    }
    final bytes = await BatchPdf.build(batch, logoPng: logoPng);
    return _save(bytes, 'batch.pdf', 'PDF document', ['pdf']);
  }

  static Future<bool> exportPdf(AppSettings s, SizeResult? size) async {
    if (s.mode.isSerialized) return exportBatchPdf(s);
    Uint8List bytes;
    if (s.mode.isCombo) {
      var image = await renderImage(s);
      if (image == null) return false;
      image = await Ruler.addRulers(image, s.dpi);
      bytes = await RasterRenderer.toPng(image, s.dpi);
      // A combined label is rasterised; save as PNG at its physical size.
      return _save(bytes, 'label.png', 'PNG image', ['png']);
    }
    if (s.resolved.data == null || size == null) return false;
    final logoPng = (s.logoImagePath != null)
        ? await File(s.logoImagePath!).readAsBytes().catchError((_) => Uint8List(0))
        : null;
    bytes = await PdfExporter.export(s.singleConfig, size,
        logoPng: (logoPng != null && logoPng.isNotEmpty) ? logoPng : null,
        caption: s.data.caption());
    return _save(bytes, 'code.pdf', 'PDF document', ['pdf']);
  }

  static Future<bool> _save(
      Uint8List bytes, String name, String label, List<String> ext) async {
    final location = await getSaveLocation(
      suggestedName: name,
      acceptedTypeGroups: [XTypeGroup(label: label, extensions: ext)],
    );
    if (location == null) return false;
    await File(location.path).writeAsBytes(bytes);
    return true;
  }

  static Future<bool> _saveString(
      String content, String name, String label, List<String> ext) async {
    final location = await getSaveLocation(
      suggestedName: name,
      acceptedTypeGroups: [XTypeGroup(label: label, extensions: ext)],
    );
    if (location == null) return false;
    await File(location.path).writeAsString(content);
    return true;
  }
}
