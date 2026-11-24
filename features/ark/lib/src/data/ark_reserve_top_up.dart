import 'package:ark/ark.dart';
import 'package:primitives/primitives.dart';

import '../domain/ark_failure.dart';
import '../domain/ark_reserve_top_up_port.dart';

/// Tops the Ark fee reserve up from the Secure Bitcoin wallet the Ark account
/// belongs to, through the app's own send for that wallet.
final class WalletArkReserveTopUp implements ArkReserveTopUpPort {
  final Future<Result<String, ArkFailure>> Function(ArkAccountId account)
  _sourceWallet;

  /// Sends [amount] to [address] from [walletId]; its txid, or a failure.
  final Future<Result<String, ArkFailure>> Function(
    String walletId,
    String address,
    Sats amount,
  )
  _send;

  const WalletArkReserveTopUp({
    required this._sourceWallet,
    required this._send,
  });

  @override
  Future<Result<String, ArkFailure>> topUp(
    ArkAccountId account, {
    required String address,
    required Sats amount,
  }) async {
    switch (await _sourceWallet(account)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final walletId):
        return _send(walletId, address, amount);
    }
  }
}

/// Builds its top-up on first use, so opening Ark never needs the wallet's
/// send stack: only an exit that must top the reserve up does.
final class DeferredArkReserveTopUp implements ArkReserveTopUpPort {
  final ArkReserveTopUpPort Function() _build;
  ArkReserveTopUpPort? _built;

  DeferredArkReserveTopUp(this._build);

  @override
  Future<Result<String, ArkFailure>> topUp(
    ArkAccountId account, {
    required String address,
    required Sats amount,
  }) => (_built ??= _build()).topUp(account, address: address, amount: amount);
}
