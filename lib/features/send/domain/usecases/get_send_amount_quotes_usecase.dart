import 'package:meta/meta.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:primitives/primitives.dart';

class GetSendAmountQuotesUsecase {
  final GetSettingsUsecase _settings;
  final IndexPricesReader _read;

  const GetSendAmountQuotesUsecase({
    required this._settings,
    required this._read,
  });

  @useResult
  Future<Result<Map<SupportedCurrency, BitcoinPrice>, SendFailure>>
  execute() async {
    final SettingsEntity settings;
    try {
      settings = await _settings.execute();
    } catch (error) {
      return Err(SendUnexpectedFailure('$error'));
    }
    final result = await _read(
      network: switch (settings.environment) {
        Environment.mainnet => BitcoinNetwork.mainnet,
        Environment.testnet => BitcoinNetwork.testnet,
        Environment.regtest => BitcoinNetwork.regtest,
      },
    );
    return result.mapErr(
      (failure) => SendPriceUnavailableFailure(failure.logMessage),
    );
  }
}
