import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';

class ReceiveWithPayjoinUsecase {
  final PayjoinRepository _payjoinRepository;
  final SettingsRepository _settingsRepository;

  const ReceiveWithPayjoinUsecase({
    required this._payjoinRepository,
    required this._settingsRepository,
  });

  Future<PayjoinReceiver> execute({
    required String walletId,
    required String address,
    int? expireAfterSec,
    int? amountSat,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final environment = settings.environment;

      final payjoinReceiver = await _payjoinRepository.createPayjoinReceiver(
        walletId: walletId,
        address: address,
        isTestnet: environment.isTestnet,
        maxFeeRateSatPerVb: BigInt.from(10000),
        // The user-configured session lifetime (see the payjoin settings
        // screen) unless the caller explicitly overrides it (e.g. tests).
        expireAfterSec: expireAfterSec ?? settings.payjoinExpireAfterSec,
        amountSat: amountSat,
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
