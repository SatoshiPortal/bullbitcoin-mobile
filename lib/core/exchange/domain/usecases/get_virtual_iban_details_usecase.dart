import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/domain/entity/virtual_iban_recipient.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/virtual_iban_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';

/// Usecase to get the user's Virtual IBAN details.
///
/// Returns the Virtual IBAN recipient if one exists, or null if not created yet.
class GetVirtualIbanDetailsUsecase {
  final VirtualIbanRepository _mainnetVirtualIbanRepository;
  final VirtualIbanRepository _testnetVirtualIbanRepository;
  final SettingsRepository _settingsRepository;

  GetVirtualIbanDetailsUsecase({
    required VirtualIbanRepository mainnetVirtualIbanRepository,
    required VirtualIbanRepository testnetVirtualIbanRepository,
    required SettingsRepository settingsRepository,
  }) : _mainnetVirtualIbanRepository = mainnetVirtualIbanRepository,
       _testnetVirtualIbanRepository = testnetVirtualIbanRepository,
       _settingsRepository = settingsRepository;

  Future<VirtualIbanRecipient?> execute() async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repo =
          isTestnet
              ? _testnetVirtualIbanRepository
              : _mainnetVirtualIbanRepository;

      return await repo.getVirtualIbanDetails();
    } on ApiKeyException {
      rethrow;
    } catch (e) {
      throw GetVirtualIbanDetailsException('$e');
    }
  }
}

class GetVirtualIbanDetailsException extends BullException {
  GetVirtualIbanDetailsException(super.message);
}

