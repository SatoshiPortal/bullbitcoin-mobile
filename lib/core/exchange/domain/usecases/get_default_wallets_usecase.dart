import 'package:bb_mobile/core/exchange/domain/entity/default_wallet.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_recipient_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';

class GetDefaultWalletsUsecase {
  final ExchangeRecipientRepository _mainnetRepository;
  final ExchangeRecipientRepository _testnetRepository;
  final SettingsRepository _settingsRepository;

  GetDefaultWalletsUsecase({
    required ExchangeRecipientRepository mainnetRepository,
    required ExchangeRecipientRepository testnetRepository,
    required SettingsRepository settingsRepository,
  }) : _mainnetRepository = mainnetRepository,
       _testnetRepository = testnetRepository,
       _settingsRepository = settingsRepository;

  Future<DefaultWallets> execute() async {
    final settings = await _settingsRepository.fetch();
    final isTestnet = settings.environment.isTestnet;

    final repository = isTestnet ? _testnetRepository : _mainnetRepository;
    return repository.getDefaultWallets();
  }
}

