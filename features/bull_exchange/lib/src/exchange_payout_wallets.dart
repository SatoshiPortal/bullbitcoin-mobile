import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:sync/sync.dart';
import 'package:sync/write.dart' show WalletNativeLifecycle;

/// Authorized wallet choices and receive addresses for exchange payouts.
final class ExchangePayoutWallets {
  final WalletInventory _inventory;
  final WalletNativeLifecycle _native;

  const ExchangePayoutWallets(this._inventory, this._native);

  @useResult
  Future<Result<WalletSelection, SecretFailure>> walletsForNetwork(
    Network network,
  ) => _inventory.walletsForNetwork(network);

  @useResult
  Future<String?> receive(
    WalletRegistration wallet, {
    required bool advance,
    bool requiresDefault = false,
  }) async {
    final key = WalletKey(id: wallet.id, network: wallet.network);
    // Busy is a native admission outcome. Never retry Exchange writes here.
    for (var attempt = 0; attempt < 5; attempt++) {
      if (!await _stillAuthorized(wallet, requiresDefault)) return null;
      switch (await _native.receive(key, advance: advance)) {
        case Ok(:final value):
          if (await validateAddress(value.address, key.network) case Err()) {
            return null;
          }
          return await _stillAuthorized(wallet, requiresDefault)
              ? value.address
              : null;
        case Err(failure: SyncBusyFailure()) when attempt < 4:
          await Future<void>.delayed(
            Duration(milliseconds: 250 * (attempt + 1)),
          );
        case Err(:final failure):
          log.warning(
            'Exchange receive address unavailable: ${failure.logCode}',
          );
          return null;
      }
    }
    return null;
  }

  Future<bool> _stillAuthorized(
    WalletRegistration wallet,
    bool requiresDefault,
  ) async => switch (await _inventory.readWallet(wallet.id)) {
    Ok(:final value) =>
      value.id == wallet.id &&
          value.network == wallet.network &&
          value.signer == wallet.signer &&
          value.scriptType == wallet.scriptType &&
          (!requiresDefault || value.isDefault),
    Err() => false,
  };
}
