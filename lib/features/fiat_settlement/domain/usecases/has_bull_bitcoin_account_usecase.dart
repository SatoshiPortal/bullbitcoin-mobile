import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';

/// A purely LOCAL check: is a Bull Bitcoin account connected on THIS device?
///
/// It reads the stored API key for the current environment and performs no
/// network I/O. The editor uses it to decide whether to prompt for login before
/// offering a fiat/mixed settlement (Bitcoin-only never needs a connection).
class HasBullBitcoinAccountUsecase {
  final BullbitcoinApiKeyDatasource _apiKeyDatasource;
  final GetSettingsUsecase _getSettings;

  const HasBullBitcoinAccountUsecase({
    required this._apiKeyDatasource,
    required this._getSettings,
  });

  Future<bool> execute() async {
    final settings = await _getSettings.execute();
    final key = await _apiKeyDatasource.get(
      isTestnet: settings.environment.isTestnet,
    );
    return key != null;
  }
}
