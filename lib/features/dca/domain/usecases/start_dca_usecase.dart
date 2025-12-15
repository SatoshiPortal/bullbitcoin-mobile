import 'package:bb_mobile/core_deprecated/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core_deprecated/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core_deprecated/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core_deprecated/exchange/domain/repositories/exchange_user_repository.dart';
import 'package:bb_mobile/core_deprecated/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core_deprecated/settings/data/settings_repository.dart';

class StartDcaUsecase {
  final SettingsRepository _settingsRepository;
  final ExchangeUserRepository _mainnetExchangeUserRepository;
  final ExchangeUserRepository _testnetExchangeUserRepository;
  final ExchangeOrderRepository _mainnetDcaRepository;
  final ExchangeOrderRepository _testnetDcaRepository;

  StartDcaUsecase({
    required SettingsRepository settingsRepository,
    required ExchangeUserRepository mainnetExchangeUserRepository,
    required ExchangeUserRepository testnetExchangeUserRepository,
    required ExchangeOrderRepository mainnetExchangeOrderRepository,
    required ExchangeOrderRepository testnetExchangeOrderRepository,
  }) : _settingsRepository = settingsRepository,
       _mainnetExchangeUserRepository = mainnetExchangeUserRepository,
       _testnetExchangeUserRepository = testnetExchangeUserRepository,
       _mainnetDcaRepository = mainnetExchangeOrderRepository,
       _testnetDcaRepository = testnetExchangeOrderRepository;

  Future<
    ({
      List<UserBalance> balances,
      FiatCurrency? currency,
      String? lightningAddress,
      Map<String, dynamic> buyLimits,
    })
  >
  execute() async {
    final settings = await _settingsRepository.fetch();
    final environment = settings.environment;

    final userSummary =
        environment.isMainnet
            ? await _mainnetExchangeUserRepository.getUserSummary()
            : await _testnetExchangeUserRepository.getUserSummary();

    if (userSummary == null) {
      throw GetExchangeUserSummaryException('User summary is null');
    }

    final balances = userSummary.balances.where((b) => b.amount > 0).toList();

    final currencyCode =
        balances.isEmpty
            ? null
            : balances
                .firstWhere(
                  (b) => b.currencyCode == userSummary.currency,
                  orElse: () => balances.first,
                )
                .currencyCode;
    final currency =
        currencyCode == null ? null : FiatCurrency.fromCode(currencyCode);
    final defaultLightningAddress = userSummary.autoBuy.addresses.lightning;

    final buyLimits =
        environment.isMainnet
            ? await _mainnetDcaRepository.getBuyLimits()
            : await _testnetDcaRepository.getBuyLimits();

    return (
      balances: balances,
      currency: currency,
      lightningAddress: defaultLightningAddress,
      buyLimits: buyLimits,
    );
  }
}
