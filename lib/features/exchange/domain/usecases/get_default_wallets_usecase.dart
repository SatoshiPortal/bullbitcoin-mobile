import 'package:bb_mobile/core/exchange/domain/entity/default_wallet.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_recipient_repository.dart';
import 'package:preferences/preferences.dart';

class GetDefaultWalletsUsecase {
  final ExchangeRecipientRepository _mainnetRepository;
  final ExchangeRecipientRepository _testnetRepository;
  final Preferences _settingsRepository;

  GetDefaultWalletsUsecase({
    required this._mainnetRepository,
    required this._testnetRepository,
    required this._settingsRepository,
  });

  Future<DefaultWallets> execute() async {
    final settings = (await _settingsRepository.fetch()).fold(
      (value) => value,
      (failure) => throw Exception('Preferences read failed'),
    );
    final isTestnet = settings.environment.requireHistoricalTestnet();

    final repository = isTestnet ? _testnetRepository : _mainnetRepository;
    return repository.getDefaultWallets();
  }
}
