import 'package:bb_mobile/core/exchange/domain/entity/default_wallet.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/save_default_wallet_usecase.dart';
import 'package:bb_mobile/features/exchange_settings/domain/exchange_settings_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Wraps the shared exchange use-case, which still throws, so the cubit above
/// can switch on a `Result` instead of catching.
class SaveExchangeDefaultWalletUsecase {
  final SaveDefaultWalletUsecase _saveDefaultWalletUsecase;

  const SaveExchangeDefaultWalletUsecase({
    required this._saveDefaultWalletUsecase,
  });

  /// The synchronous part of the rule, so a caller can reject an empty address
  /// without showing a progress indicator for a round trip that will not
  /// happen. [execute] applies it too, so the rule holds either way.
  @useResult
  static ExchangeSettingsFailure? validate(String address) =>
      address.trim().isEmpty
      ? const ExchangeSettingsWalletAddressEmptyFailure()
      : null;

  @useResult
  Future<Result<DefaultWallet, ExchangeSettingsFailure>> execute({
    required WalletAddressType walletType,
    required String address,
    String? existingRecipientId,
  }) async {
    final invalid = validate(address);
    if (invalid != null) {
      return Err(invalid);
    }

    try {
      return Ok(
        await _saveDefaultWalletUsecase.execute(
          walletType: walletType,
          address: address,
          existingRecipientId: existingRecipientId,
        ),
      );
    } catch (e, st) {
      log.severe(message: 'saveDefaultWallet failed', error: e, trace: st);
      return Err(
        ExchangeSettingsWalletSaveFailure(
          'saveDefaultWallet failed: ${e.runtimeType}',
        ),
      );
    }
  }
}
