import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/exchange/domain/entity/default_wallet_address.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/default_wallets_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';

class SaveDefaultWalletUsecase {
  final DefaultWalletsRepository _mainnetRepository;
  final DefaultWalletsRepository _testnetRepository;
  final SettingsRepository _settingsRepository;

  SaveDefaultWalletUsecase({
    required DefaultWalletsRepository mainnetDefaultWalletsRepository,
    required DefaultWalletsRepository testnetDefaultWalletsRepository,
    required SettingsRepository settingsRepository,
  })  : _mainnetRepository = mainnetDefaultWalletsRepository,
        _testnetRepository = testnetDefaultWalletsRepository,
        _settingsRepository = settingsRepository;

  Future<DefaultWalletAddress> execute({
    required WalletAddressType addressType,
    required String address,
    String? existingRecipientId,
  }) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repo = isTestnet ? _testnetRepository : _mainnetRepository;

      // Validate address first
      final isValid = await repo.validateAddress(
        addressType: addressType,
        address: address,
      );

      if (!isValid) {
        throw SaveDefaultWalletException(
          'Invalid ${addressType.displayName} address',
        );
      }

      return await repo.saveDefaultWallet(
        addressType: addressType,
        address: address,
        existingRecipientId: existingRecipientId,
      );
    } catch (e) {
      if (e is SaveDefaultWalletException) rethrow;
      throw SaveDefaultWalletException('$e');
    }
  }
}

class SaveDefaultWalletException extends BullException {
  SaveDefaultWalletException(super.message);
}






