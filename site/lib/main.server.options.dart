// dart format off
// ignore_for_file: type=lint

// GENERATED FILE, DO NOT MODIFY
// Generated with jaspr_builder

import 'package:jaspr/server.dart';
import 'package:site/components/generator.dart' as _generator;
import 'package:site/components/license_gate.dart' as _license_gate;

/// Default [ServerOptions] for use with your Jaspr project.
///
/// Use this to initialize Jaspr **before** calling [runApp].
///
/// Example:
/// ```dart
/// import 'main.server.options.dart';
///
/// void main() {
///   Jaspr.initializeApp(
///     options: defaultServerOptions,
///   );
///
///   runApp(...);
/// }
/// ```
ServerOptions get defaultServerOptions => ServerOptions(
  clientId: 'main.client.dart.js',
  clients: {
    _generator.Generator: ClientTarget<_generator.Generator>('generator'),
    _license_gate.LicenseGate: ClientTarget<_license_gate.LicenseGate>(
      'license_gate',
    ),
  },
);
