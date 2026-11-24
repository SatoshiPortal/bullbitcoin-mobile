import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';

import '../domain/ark_exit_destination_port.dart';
import '../domain/ark_failure.dart';

/// Emergency exits can send their funds to the Secure Bitcoin wallet the Ark
/// account belongs to, at a fresh unused address.
final class WalletArkExitDestination implements ArkExitDestinationPort {
  final Future<Result<String, ArkFailure>> Function(ArkAccountId account)
  _sourceWallet;
  final Future<Result<String, ArkFailure>> Function(String walletId)
  _nextAddress;

  const WalletArkExitDestination({
    required this._sourceWallet,
    required this._nextAddress,
  });

  @override
  Future<Result<String, ArkFailure>> secureBitcoinAddress(
    ArkAccountId account,
  ) async => switch (await _sourceWallet(account)) {
    Err(:final failure) => Err(failure),
    Ok(value: final walletId) => await _nextAddress(walletId),
  };
}
