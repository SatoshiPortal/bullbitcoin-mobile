import 'package:bb_mobile/_core/domain/entities/payjoin.dart';
import 'package:bb_mobile/_core/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/_core/domain/repositories/settings_repository.dart';

class ReceiveWithPayjoinUsecase {
  final PayjoinRepository _payjoinRepository;
  final SettingsRepository _settingsRepository;

  const ReceiveWithPayjoinUsecase({
    required PayjoinRepository payjoinRepository,
    required SettingsRepository settingsRepository,
  })  : _payjoinRepository = payjoinRepository,
        _settingsRepository = settingsRepository;

  Future<PayjoinReceiver> execute({
    required String walletId,
    required String address,
    int? expireAfterSec,
  }) async {
    try {
      final environment = await _settingsRepository.getEnvironment();

      final payjoinReceiver = await _payjoinRepository.createPayjoinReceiver(
        walletId: walletId,
        address: address,
        isTestnet: environment.isTestnet,
        maxFeeRateSatPerVb: BigInt.from(10000),
        expireAfterSec: expireAfterSec,
      );

      return payjoinReceiver;
    } catch (e) {
      throw ReceivePayjoinException(e.toString());
    }
  }
}

class ReceivePayjoinException implements Exception {
  final String message;

  ReceivePayjoinException(this.message);
}
