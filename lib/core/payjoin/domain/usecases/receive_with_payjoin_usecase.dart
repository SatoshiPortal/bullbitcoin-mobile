import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/constants.dart';

class ReceiveWithPayjoinUsecase {
  final PayjoinRepository _payjoinRepository;
  final SettingsRepository _settingsRepository;

  const ReceiveWithPayjoinUsecase({
    required this._payjoinRepository,
    required this._settingsRepository,
  });

  /// Returns null if payjoin is disabled in settings — the caller should
  /// treat that the same as "no payjoin for this address", not an error.
  Future<PayjoinReceiver?> execute({
    required String walletId,
    required String address,
    int? expireAfterSec,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      if (!settings.isPayjoinEnabled) return null;

      final environment = settings.environment;

      final payjoinReceiver = await _payjoinRepository.createPayjoinReceiver(
        walletId: walletId,
        address: address,
        isTestnet: environment.isTestnet,
        maxFeeRateSatPerVb: BigInt.from(10000),
        expireAfterSec:
            expireAfterSec ?? PayjoinConstants.defaultExpireAfterSec,
      );

      return payjoinReceiver;
    } catch (e) {
      throw ReceivePayjoinException(e.toString());
    }
  }
}

class ReceivePayjoinException extends BullException {
  ReceivePayjoinException(super.message);
}
