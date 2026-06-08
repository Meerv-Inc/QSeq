// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

/// Computes which QR modules are *function patterns* — finder patterns and
/// their separators, timing patterns, alignment patterns, format/version
/// information and the dark module — for a given version.
///
/// A scanner relies on these for locating and geometrically correcting the
/// symbol; unlike data/EC modules they are NOT recoverable by error correction.
/// The renderer uses this to keep a centre logo from destroying them (a centred
/// logo most often threatens a *central alignment pattern*).
class QrStructure {
  final int version;
  final int n; // modules per side = 17 + 4*version
  late final List<int> _alignCenters;

  QrStructure(this.version) : n = 17 + 4 * version {
    _alignCenters = _alignmentCenters(version);
  }

  /// True if module ([row], [col]) is a function-pattern module.
  bool isFunction(int row, int col) {
    // Finder patterns + 1-module separators (8×8 at three corners).
    if (_inBox(row, col, 0, 0, 8, 8)) return true; // top-left
    if (_inBox(row, col, 0, n - 8, 8, 8)) return true; // top-right
    if (_inBox(row, col, n - 8, 0, 8, 8)) return true; // bottom-left

    // Timing patterns: full row 6 and column 6.
    if (row == 6 || col == 6) return true;

    // Format information: row 8 and column 8 near the finders, plus the
    // mirrored strips, and the always-dark module at (n-8, 8).
    if (row == 8 && (col <= 8 || col >= n - 8)) return true;
    if (col == 8 && (row <= 8 || row >= n - 7)) return true;

    // Version information (version ≥ 7): two 6×3 / 3×6 blocks by the finders.
    if (version >= 7) {
      if (_inBox(row, col, 0, n - 11, 6, 3)) return true;
      if (_inBox(row, col, n - 11, 0, 3, 6)) return true;
    }

    // Alignment patterns: 5×5 blocks centred on every coordinate pair, except
    // the three that coincide with the finder corners.
    final last = _alignCenters.isEmpty ? -1 : _alignCenters.last;
    for (final r in _alignCenters) {
      for (final c in _alignCenters) {
        if (_isFinderCorner(r, c, last)) continue;
        if (row >= r - 2 && row <= r + 2 && col >= c - 2 && col <= c + 2) {
          return true;
        }
      }
    }
    return false;
  }

  bool _isFinderCorner(int r, int c, int last) {
    const first = 6;
    return (r == first && c == first) ||
        (r == first && c == last) ||
        (r == last && c == first);
  }

  static bool _inBox(int row, int col, int top, int left, int h, int w) =>
      row >= top && row < top + h && col >= left && col < left + w;

  /// Alignment-pattern centre coordinates per QR version (ISO/IEC 18004
  /// Annex E). Version 1 has none.
  static List<int> _alignmentCenters(int version) {
    const table = <List<int>>[
      [], // v1
      [6, 18],
      [6, 22],
      [6, 26],
      [6, 30],
      [6, 34],
      [6, 22, 38],
      [6, 24, 42],
      [6, 26, 46],
      [6, 28, 50],
      [6, 30, 54],
      [6, 32, 58],
      [6, 34, 62],
      [6, 26, 46, 66],
      [6, 26, 48, 70],
      [6, 26, 50, 74],
      [6, 30, 54, 78],
      [6, 30, 56, 82],
      [6, 30, 58, 86],
      [6, 34, 62, 90],
      [6, 28, 50, 72, 94],
      [6, 26, 50, 74, 98],
      [6, 30, 54, 78, 102],
      [6, 28, 54, 80, 106],
      [6, 32, 58, 84, 110],
      [6, 30, 58, 86, 114],
      [6, 34, 62, 90, 118],
      [6, 26, 50, 74, 98, 122],
      [6, 30, 54, 78, 102, 126],
      [6, 26, 52, 78, 104, 130],
      [6, 30, 56, 82, 108, 134],
      [6, 34, 60, 86, 112, 138],
      [6, 30, 58, 86, 114, 142],
      [6, 34, 62, 90, 118, 146],
      [6, 30, 54, 78, 102, 126, 150],
      [6, 24, 50, 76, 102, 128, 154],
      [6, 28, 54, 80, 106, 132, 158],
      [6, 32, 58, 84, 110, 136, 162],
      [6, 26, 54, 82, 110, 138, 166],
      [6, 30, 58, 86, 114, 142, 170], // v40
    ];
    return table[version - 1];
  }
}
