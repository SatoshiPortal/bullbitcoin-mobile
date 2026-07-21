import 'package:bb_mobile/core/exchange/domain/repositories/exchange_api_key_repository.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';

/// A purely LOCAL check: is a Bull Bitcoin account connected on THIS device?
///
/// It reads through the exchange API-key repository for the current environment
/// and performs no network I/O. The editor uses it to decide whether to prompt
/// for login before offering a fiat/mixed settlement (Bitcoin-only never needs
/// a connection).
class HasBullBitcoinAccountUsecase {
  final ExchangeApiKeyRepository _apiKeyRepository;
  final GetSettingsUsecase _getSettings;

  const HasBullBitcoinAccountUsecase({
    required this._apiKeyRepository,
    required this._getSettings,
  });

  Future<bool> execute() async {
    final settings = await _getSettings.execute();
    return _apiKeyRepository.hasApiKey(
      isTestnet: settings.environment.isTestnet,
    );
  }
}
