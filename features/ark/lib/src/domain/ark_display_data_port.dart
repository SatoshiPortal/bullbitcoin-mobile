import 'package:ark/ark.dart';
import 'package:bull_pricer/bull_pricer.dart' show BitcoinPrice;
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'ark_failure.dart';

/// How the source wallet is named to the user, as the host app names it.
sealed class ArkSourceWalletName {
  const ArkSourceWalletName();
}

/// The seed's default Bitcoin wallet, shown under the app's default name.
final class ArkDefaultSourceWallet extends ArkSourceWalletName {
  const ArkDefaultSourceWallet();
}

/// Any other wallet, shown under its own name.
final class ArkNamedSourceWallet extends ArkSourceWalletName {
  final String name;
  const ArkNamedSourceWallet(this.name);
}

/// A read-only observation, never permission to select or spend inputs.
final class ArkDisplayData {
  final ArkAccountId account;
  final String walletId;
  final Sats? available;
  final BitcoinPrice? price;

  /// Unknown when the host could not read the wallet's name.
  final ArkSourceWalletName? walletName;

  const ArkDisplayData({
    required this.account,
    required this.walletId,
    required this.available,
    this.price,
    this.walletName,
  });
}

/// The host resolves the selected on-chain source and keeps its authority.
abstract interface class ArkDisplayDataPort {
  /// Invalidates observations after a source revision or app currency change.
  Stream<void> changes(ArkAccountId account);

  @useResult
  Future<Result<ArkDisplayData, ArkFailure>> read(ArkAccountId account);
}
