// QSeq — Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 — noncommercial use
// only; reuse requires attribution to Meerv Inc. See LICENSE for terms.
// https://polyformproject.org/licenses/noncommercial/1.0.0/

import '../models/symbology.dart';

/// QR Code capacity tables (ISO/IEC 18004) and version geometry.
class QrCapacity {
  QrCapacity._();

  /// Byte-mode (8-bit) data capacity per version (1–40), indexed by EC level.
  /// Order of the 4-element rows: L, M, Q, H.
  static const List<List<int>> _byteCapacity = [
    [17, 14, 11, 7], // v1
    [32, 26, 20, 14],
    [53, 42, 32, 24],
    [78, 62, 46, 34],
    [106, 84, 60, 44], // v5
    [134, 106, 74, 58],
    [154, 122, 86, 64],
    [192, 152, 108, 84],
    [230, 180, 130, 98],
    [271, 213, 151, 119], // v10
    [321, 251, 177, 137],
    [367, 287, 203, 155],
    [425, 331, 241, 177],
    [458, 362, 258, 194],
    [520, 412, 292, 220], // v15
    [586, 450, 322, 250],
    [644, 504, 364, 280],
    [718, 560, 394, 310],
    [792, 624, 442, 338],
    [858, 666, 482, 382], // v20
    [929, 711, 509, 403],
    [1003, 779, 565, 439],
    [1091, 857, 611, 461],
    [1171, 911, 661, 511],
    [1273, 997, 715, 535], // v25
    [1367, 1059, 751, 593],
    [1465, 1125, 805, 625],
    [1528, 1190, 868, 658],
    [1628, 1264, 908, 698],
    [1732, 1370, 982, 742], // v30
    [1840, 1452, 1030, 790],
    [1952, 1538, 1112, 842],
    [2068, 1628, 1168, 898],
    [2188, 1722, 1228, 958],
    [2303, 1809, 1283, 983], // v35
    [2431, 1911, 1351, 1051],
    [2563, 1989, 1423, 1093],
    [2699, 2099, 1499, 1139],
    [2809, 2213, 1579, 1219],
    [2953, 2331, 1663, 1273], // v40
  ];

  static int _ecColumn(QrEcLevel ec) => switch (ec) {
        QrEcLevel.low => 0,
        QrEcLevel.medium => 1,
        QrEcLevel.quartile => 2,
        QrEcLevel.high => 3,
      };

  /// Number of modules along one side of a QR symbol of the given [version]
  /// (excluding the quiet zone): `17 + 4 * version`.
  static int moduleCount(int version) => 17 + 4 * version;

  /// Byte-mode capacity for a specific [version] (1–40) and EC level.
  static int byteCapacity(int version, QrEcLevel ec) {
    if (version < 1 || version > 40) {
      throw RangeError.range(version, 1, 40, 'version');
    }
    return _byteCapacity[version - 1][_ecColumn(ec)];
  }

  /// Smallest QR version (1–40) whose byte-mode capacity holds [byteCount] at
  /// the given EC level, or null if it does not fit in any version.
  static int? minVersionForBytes(int byteCount, QrEcLevel ec) {
    final col = _ecColumn(ec);
    for (var v = 1; v <= 40; v++) {
      if (_byteCapacity[v - 1][col] >= byteCount) return v;
    }
    return null;
  }
}
