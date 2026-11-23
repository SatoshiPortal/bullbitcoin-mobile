/// Pure-Dart shared primitives for the Bull monorepo.
///
/// Hosts the canonical [Result]/[Failure] pair and the cross-cutting value
/// types every workspace package agrees on. Zero Flutter, zero domain
/// dependencies.
library;

export 'src/amount_conversions.dart';
export 'src/amount_formatting.dart';
export 'src/bitcoin_unit.dart';
export 'src/failure.dart';
export 'src/money.dart';
export 'src/bitcoin_transaction_recipient.dart';
export 'src/fingerprint.dart';
export 'src/msats.dart';
export 'src/network.dart';
export 'src/network_capabilities.dart';
export 'src/outpoint.dart';
export 'src/payment_network.dart';
export 'src/regtest_host_profile.dart';
export 'src/result.dart';
export 'src/script_type.dart';
export 'src/percentage.dart';
export 'src/string_formatting.dart';
export 'src/xpub_type.dart';
