import 'package:primitives/primitives.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/receive/domain/receive_failure.dart';
import 'package:meta/meta.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';

/// Receive-owned boundary for the shared wallet use-case, which still throws.
class GetReceiveWalletsUsecase {
  final GetWalletsUsecase _getWalletsUsecase;

  const GetReceiveWalletsUsecase(this._getWalletsUsecase);

  @useResult
  Future<Result<List<Wallet>, ReceiveFailure>> execute({
    bool? onlyDefaults,
    bool? onlyBitcoin,
    bool? onlyLiquid,
    bool sync = false,
  }) async {
    try {
      return switch (await _getWalletsUsecase.execute(
        onlyDefaults: onlyDefaults,
        onlyBitcoin: onlyBitcoin,
        onlyLiquid: onlyLiquid,
        sync: sync,
      )) {
        Ok(:final value) => Ok(value),
        Err(:final failure) => _loadFailed(failure),
      };
    } on Object catch (e, st) {
      // Logged HERE, at the boundary that owns the raw reason. The failure's
      // logMessage stays secondary (equality, debug): if a caller chooses not
      // to log, the diagnostic must still exist.
      log.severe(
        message: 'Failed to load wallets for receive',
        error: e,
        trace: st,
      );
      return Err(ReceiveUnexpectedFailure(e.toString()));
    }
  }

  /// Selection is receive policy; the bloc only projects its outcome.
  @useResult
  static Result<({Wallet wallet, List<Wallet> choices}), ReceiveFailure>
  selectBitcoin({
    required Result<List<Wallet>, ReceiveFailure> catalog,
    Wallet? explicitWallet,
    Wallet? entryWallet,
    Wallet? currentWallet,
  }) {
    final selected =
        explicitWallet ??
        (entryWallet?.isBitcoin == true ? entryWallet : null) ??
        currentWallet;
    return switch (catalog) {
      Err(:final failure) =>
        selected == null
            ? Err(failure)
            : Ok((wallet: selected, choices: [selected])),
      Ok(:final value) =>
        selected != null
            ? Ok((wallet: selected, choices: value))
            : value.isEmpty
            ? const Err(ReceiveAddressUnavailableFailure())
            : Ok((
                wallet: value.firstWhere(
                  (wallet) => wallet.isDefault,
                  orElse: () => value.first,
                ),
                choices: value,
              )),
    };
  }

  /// Logged here, type only: not every wallet failure was logged upstream
  /// (`NoWalletsFoundFailure` is minted without one), so this keeps the
  /// no-wallets case from being silent.
  Err<List<Wallet>, ReceiveFailure> _loadFailed(WalletFailure failure) {
    log.warning('Failed to load wallets for receive: ${failure.runtimeType}');
    return Err(ReceiveUnexpectedFailure(failure.logMessage));
  }
}
