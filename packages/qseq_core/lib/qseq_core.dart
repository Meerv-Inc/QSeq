// QSeq â€” Sustainable Identity on Every Thing
// Copyright (c) 2026 Meerv Inc.  Required Notice: https://qseq.app
// Licensed under the PolyForm Noncommercial License 1.0.0 â€” noncommercial use
// only; reuse requires attribution to Meerv Inc. See the repository LICENSE.

/// QSeq domain core â€” the pure-Dart encoders and sizing engine shared between
/// the Flutter desktop app and the Jaspr web app.
library qseq_core;

// Encoders
export 'src/encoders/gtin.dart';
export 'src/encoders/sgtin.dart';
export 'src/encoders/gs1.dart';

// Sizing engine
export 'src/sizing/dpi.dart';
export 'src/sizing/qr_capacity.dart';
export 'src/sizing/datamatrix_capacity.dart';
export 'src/sizing/linear_metrics.dart';
export 'src/sizing/logo_ec.dart';
export 'src/sizing/sizer.dart';

// Models
export 'src/models/symbology.dart';
export 'src/models/encode_config.dart';
export 'src/models/size_result.dart';
export 'src/models/caption.dart';
export 'src/models/data_source.dart';
export 'src/models/combined_label.dart';
export 'src/models/batch.dart';
