import 'package:meta/meta.dart';
import 'package:preferences/preferences.dart';
import 'package:swaps/order_swaps.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:primitives/primitives.dart';

class GetSwapAmountQuotesUsecase {
  final Preferences _settings;
  final IndexPricesReader _read;

  const GetSwapAmountQuotesUsecase({
    required this._settings,
    required this._read,
  });

  @useResult
  Future<Result<Map<SupportedCurrency, BitcoinPrice>, SwapFailure>>
  execute() async {
    final SettingsEntity settings;
    try {
      settings = (await _settings.fetch()).fold(
        (value) => value,
        (failure) => throw Exception('Preferences read failed'),
      );
    } catch (error) {
      return Err(SwapUnexpectedFailure('$error'));
    }
    final result = await _read(
      network: switch (settings.environment) {
        Environment.mainnet => BitcoinNetwork.mainnet,
        Environment.testnet => BitcoinNetwork.testnet,
        Environment.regtest => BitcoinNetwork.regtest,
      },
    );
    return result.mapErr(
      (failure) => SwapPriceUnavailableFailure(failure.logMessage),
    );
  }
}
