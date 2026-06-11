// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

/// A human-readable caption printed under a code. [prefix] renders in a normal
/// weight; [bold] renders bold (for serialized sheets this is the incrementing
/// portion, for a single code it is the serial number itself).
class LabelCaption {
  final String prefix;
  final String bold;

  const LabelCaption({this.prefix = '', this.bold = ''});

  /// Human-readable interpretation: the full encoded string [data], with the
  /// trailing [boldTail] (the incrementing serial, when serialized) in bold.
  factory LabelCaption.hri(String data, {String? boldTail}) {
    if (boldTail != null && boldTail.isNotEmpty && data.endsWith(boldTail)) {
      return LabelCaption(
          prefix: data.substring(0, data.length - boldTail.length),
          bold: boldTail);
    }
    return LabelCaption(prefix: data);
  }

  bool get isEmpty => prefix.isEmpty && bold.isEmpty;
  bool get isNotEmpty => !isEmpty;

  String get text => '$prefix$bold';
}
