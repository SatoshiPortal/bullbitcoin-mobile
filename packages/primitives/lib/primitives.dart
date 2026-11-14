/// Pure-Dart shared primitives for the Bull monorepo.
///
/// Hosts the canonical [Result]/[Failure] pair and the cross-cutting value
/// types every workspace package agrees on. Zero Flutter, zero domain
/// dependencies.
library;

export 'src/bitcoin_unit.dart';
export 'src/database_key.dart';
export 'src/failure.dart';
export 'src/money.dart';
export 'src/bitcoin_transaction_recipient.dart';
export 'src/fingerprint.dart';
export 'src/network.dart';
export 'src/outpoint.dart';
export 'src/result.dart';
export 'src/script_type.dart';
export 'src/xpub_type.dart';
