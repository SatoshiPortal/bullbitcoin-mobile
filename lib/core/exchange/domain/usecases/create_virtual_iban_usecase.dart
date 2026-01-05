import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/domain/entity/virtual_iban_recipient.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/virtual_iban_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';

/// Usecase to create a Virtual IBAN (Confidential SEPA) for the user.
///
/// This creates an FR_VIRTUAL_ACCOUNT recipient type which provides the user
/// with a personal virtual IBAN for private EUR deposits and withdrawals.
class CreateVirtualIbanUsecase {
  final VirtualIbanRepository _mainnetVirtualIbanRepository;
  final VirtualIbanRepository _testnetVirtualIbanRepository;
  final SettingsRepository _settingsRepository;

  CreateVirtualIbanUsecase({
    required VirtualIbanRepository mainnetVirtualIbanRepository,
    required VirtualIbanRepository testnetVirtualIbanRepository,
    required SettingsRepository settingsRepository,
  }) : _mainnetVirtualIbanRepository = mainnetVirtualIbanRepository,
       _testnetVirtualIbanRepository = testnetVirtualIbanRepository,
       _settingsRepository = settingsRepository;

  Future<VirtualIbanRecipient> execute() async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repo =
          isTestnet
              ? _testnetVirtualIbanRepository
              : _mainnetVirtualIbanRepository;

      return await repo.createVirtualIban();
    } on ApiKeyException {
      rethrow;
    } catch (e) {
      throw CreateVirtualIbanException('$e');
    }
  }
}

class CreateVirtualIbanException extends BullException {
  CreateVirtualIbanException(super.message);
}


