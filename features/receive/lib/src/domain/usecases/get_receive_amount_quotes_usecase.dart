import 'package:meta/meta.dart';
import 'package:preferences/preferences.dart';

import '../receive_failure.dart';

import 'package:bull_pricer/bull_pricer.dart';
import 'package:primitives/primitives.dart';

class GetReceiveAmountQuotesUsecase {
  final Preferences _settings;
  final IndexPricesReader _read;

  const GetReceiveAmountQuotesUsecase({
    required this._settings,
    required this._read,
  });

  @useResult
  Future<Result<Map<SupportedCurrency, BitcoinPrice>, ReceiveFailure>>
  execute() async {
    final SettingsEntity settings;
    try {
      switch (await _settings.fetch()) {
        case Ok(:final value):
          settings = value;
        case Err():
          return const Err(ReceiveUnexpectedFailure('Preferences read failed'));
      }
    } on Exception catch (error) {
      return Err(ReceiveUnexpectedFailure('$error'));
    }
    final result = await _read(
      network: switch (settings.environment) {
        Environment.mainnet => BitcoinNetwork.mainnet,
        Environment.testnet => BitcoinNetwork.testnet,
        Environment.regtest => BitcoinNetwork.regtest,
      },
    );
    return result.mapErr(
      (failure) => ReceivePriceUnavailableFailure(failure.logMessage),
    );
  }
}
