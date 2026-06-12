// dart format off
// ignore_for_file: type=lint

// GENERATED FILE, DO NOT MODIFY
// Generated with jaspr_builder

import 'package:jaspr/client.dart';

import 'package:site/components/generator.dart' deferred as _generator;
import 'package:site/components/license_gate.dart' deferred as _license_gate;

/// Default [ClientOptions] for use with your Jaspr project.
///
/// Use this to initialize Jaspr **before** calling [runApp].
///
/// Example:
/// ```dart
/// import 'main.client.options.dart';
///
/// void main() {
///   Jaspr.initializeApp(
///     options: defaultClientOptions,
///   );
///
///   runApp(...);
/// }
/// ```
ClientOptions get defaultClientOptions => ClientOptions(
  clients: {
    'generator': ClientLoader(
      (p) => _generator.Generator(),
      loader: _generator.loadLibrary,
    ),
    'license_gate': ClientLoader(
      (p) => _license_gate.LicenseGate(),
      loader: _license_gate.loadLibrary,
    ),
  },
);
