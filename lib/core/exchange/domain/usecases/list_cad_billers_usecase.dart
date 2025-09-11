import 'package:bb_mobile/core/exchange/domain/entity/cad_biller.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_recipient_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';

class ListCadBillersUsecase {
  final ExchangeRecipientRepository _mainnetExchangeRecipientRepository;
  final ExchangeRecipientRepository _testnetExchangeRecipientRepository;
  final SettingsRepository _settingsRepository;

  ListCadBillersUsecase({
    required ExchangeRecipientRepository mainnetExchangeRecipientRepository,
    required ExchangeRecipientRepository testnetExchangeRecipientRepository,
    required SettingsRepository settingsRepository,
  }) : _mainnetExchangeRecipientRepository = mainnetExchangeRecipientRepository,
       _testnetExchangeRecipientRepository = testnetExchangeRecipientRepository,
       _settingsRepository = settingsRepository;

  Future<List<CadBiller>> execute({required String searchTerm}) async {
    try {
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final repo =
          isTestnet
              ? _testnetExchangeRecipientRepository
              : _mainnetExchangeRecipientRepository;
      final cadBillers = await repo.listCadBillers(searchTerm: searchTerm);
      return cadBillers;
    } catch (e) {
      log.severe('Error in ListCadBillersUsecase: $e');
      throw ListCadBillersException('$e');
    }
  }
}

class ListCadBillersException implements Exception {
  final String message;

  ListCadBillersException(this.message);

  @override
  String toString() => '[ListCadBillersUsecase]: $message';
}
