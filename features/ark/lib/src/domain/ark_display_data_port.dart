import 'package:ark/ark.dart';
import 'package:bull_pricer/bull_pricer.dart' show BitcoinPrice;
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'ark_failure.dart';

/// A read-only observation, never permission to select or spend inputs.
final class ArkDisplayData {
  final ArkAccountId account;
  final String walletId;
  final Sats? available;
  final BitcoinPrice? price;

  const ArkDisplayData({
    required this.account,
    required this.walletId,
    required this.available,
    this.price,
  });
}

/// The host resolves the selected on-chain source and keeps its authority.
abstract interface class ArkDisplayDataPort {
  /// Invalidates observations after a source revision or app currency change.
  Stream<void> changes(ArkAccountId account);

  @useResult
  Future<Result<ArkDisplayData, ArkFailure>> read(ArkAccountId account);
}
