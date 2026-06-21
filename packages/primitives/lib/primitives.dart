/// Pure-Dart shared primitives for the Bull monorepo.
///
/// Hosts the canonical [Result]/[Failure] pair (issue #1895 shapes) and the
/// cross-cutting value types every package agrees on: [Fingerprint], [Network],
/// [ScriptType], [XpubType]. Zero Flutter, zero domain dependencies.
library;

export 'src/failure.dart';
export 'src/fingerprint.dart';
export 'src/network.dart';
export 'src/result.dart';
export 'src/script_type.dart';
export 'src/xpub_type.dart';
