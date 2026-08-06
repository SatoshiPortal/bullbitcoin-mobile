import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/fees/domain/repositories/fees_repository.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class ReceiveWithPayjoinUsecase {
  final PayjoinRepository _payjoinRepository;
  final SettingsRepository _settingsRepository;
  final FeesRepository _feesRepository;

  const ReceiveWithPayjoinUsecase({
    required this._payjoinRepository,
    required this._settingsRepository,
    required this._feesRepository,
  });

  Future<PayjoinReceiver> execute({
    required String walletId,
    required String address,
    int? expireAfterSec,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final environment = settings.environment;

      final payjoinReceiver = await _payjoinRepository.createPayjoinReceiver(
        walletId: walletId,
        address: address,
        isTestnet: environment.isTestnet,
        maxFeeRateSatPerVb: BigInt.from(
          await _maxFeeRateSatPerVb(isTestnet: environment.isTestnet),
        ),
        // The user-configured session lifetime (see the payjoin settings
        // screen) unless the caller explicitly overrides it (e.g. tests).
        expireAfterSec: expireAfterSec ?? settings.payjoinExpireAfterSec,
      );

      return payjoinReceiver;
    } catch (e) {
      throw ReceivePayjoinException(e.toString());
    }
  }

  /// Caps how much of the receiver's own money a sender can push into miner
  /// fees, tracking the live network rate so the cap is neither too tight to
  /// accept a legitimate payjoin nor loose enough to be worth attacking. See
  /// [PayjoinConstants.maxFeeRateMultiplier] for the full rationale.
  ///
  /// A fee-source failure falls back to the floor rather than failing the
  /// receive: the floor is the conservative end of the range, so degrading
  /// here costs at worst a declined payjoin, never a larger burn.
  Future<int> _maxFeeRateSatPerVb({required bool isTestnet}) async {
    try {
      final fees = await _feesRepository.getNetworkFees(
        network: Network.fromEnvironment(isTestnet: isTestnet, isLiquid: false),
      );
      final fastest = fees.fastest.value.toDouble();
      return (fastest * PayjoinConstants.maxFeeRateMultiplier).ceil().clamp(
        PayjoinConstants.minMaxFeeRateSatPerVb,
        PayjoinConstants.maxMaxFeeRateSatPerVb,
      );
    } catch (e) {
      log.warning(
        'ReceiveWithPayjoinUsecase: live fee lookup failed ($e); '
        'falling back to the ${PayjoinConstants.minMaxFeeRateSatPerVb} '
        'sat/vB floor',
      );
      return PayjoinConstants.minMaxFeeRateSatPerVb;
    }
  }
}

class ReceivePayjoinException extends BullException {
  ReceivePayjoinException(super.message);
}
