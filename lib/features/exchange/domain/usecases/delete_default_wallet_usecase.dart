import 'package:bb_mobile/core/exchange/domain/entity/default_wallet.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_recipient_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';

class DeleteDefaultWalletUsecase {
  final ExchangeRecipientRepository _mainnetRepository;
  final ExchangeRecipientRepository _testnetRepository;
  final SettingsRepository _settingsRepository;

  DeleteDefaultWalletUsecase({
    required this._mainnetRepository,
    required this._testnetRepository,
    required this._settingsRepository,
  });

  Future<void> execute({
    required String recipientId,
    required WalletAddressType walletType,
    required String address,
  }) async {
    final settings = await _settingsRepository.fetch();
    final isTestnet = settings.environment.isTestnet;

    final repository = isTestnet ? _testnetRepository : _mainnetRepository;
    await repository.deleteDefaultWallet(
      recipientId: recipientId,
      walletType: walletType,
      address: address,
    );
  }
}
