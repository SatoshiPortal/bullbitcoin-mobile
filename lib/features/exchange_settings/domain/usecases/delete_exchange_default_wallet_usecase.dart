import 'package:bb_mobile/core/exchange/domain/entity/default_wallet.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/delete_default_wallet_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/domain/exchange_settings_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Wraps the shared exchange use-case, which still throws, so the cubit above
/// can switch on a `Result` instead of catching.
class DeleteExchangeDefaultWalletUsecase {
  final DeleteDefaultWalletUsecase _deleteDefaultWalletUsecase;

  const DeleteExchangeDefaultWalletUsecase({
    required this._deleteDefaultWalletUsecase,
  });

  @useResult
  Future<Result<void, ExchangeSettingsFailure>> execute({
    required String recipientId,
    required WalletAddressType walletType,
    required String address,
  }) async {
    try {
      await _deleteDefaultWalletUsecase.execute(
        recipientId: recipientId,
        walletType: walletType,
        address: address,
      );
      return const Ok(null);
    } catch (e, st) {
      log.severe(message: 'deleteDefaultWallet failed', error: e, trace: st);
      return Err(
        ExchangeSettingsWalletDeleteFailure(
          'deleteDefaultWallet failed: ${e.runtimeType}',
        ),
      );
    }
  }
}
