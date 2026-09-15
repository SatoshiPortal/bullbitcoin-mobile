import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_user_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/dca/domain/dca_failure.dart';
import 'package:meta/meta.dart';

typedef DcaStartData = ({
  List<UserBalance> balances,
  FiatCurrency? currency,
  String? lightningAddress,
});

class StartDcaUsecase {
  final SettingsRepository _settingsRepository;
  final ExchangeUserRepository _mainnetExchangeUserRepository;
  final ExchangeUserRepository _testnetExchangeUserRepository;

  StartDcaUsecase({
    required this._settingsRepository,
    required this._mainnetExchangeUserRepository,
    required this._testnetExchangeUserRepository,
  });

  @useResult
  Future<Result<DcaStartData, DcaFailure>> execute() async {
    final bool isMainnet;
    try {
      final settings = await _settingsRepository.fetch();
      isMainnet = settings.environment.isMainnet;
    } catch (e, st) {
      if (e is Error) rethrow;
      log.severe(message: 'Failed to load settings', error: e, trace: st);
      return const Err(DcaUnexpectedFailure('settings fetch failed'));
    }

    // The repository is the boundary: it already caught, logged the raw
    // reason, and handed back a sanitized failure — including the
    // "no API key stored" case.
    final UserSummary userSummary;
    switch (await (isMainnet
        ? _mainnetExchangeUserRepository.getUserSummary()
        : _testnetExchangeUserRepository.getUserSummary())) {
      case Ok(:final value):
        userSummary = value;
      case Err(:final failure):
        return Err(DcaAccountUnavailableFailure(failure.logMessage));
    }

    final balances = userSummary.balances.where((b) => b.amount > 0).toList();

    final currencyCode = balances.isEmpty
        ? null
        : balances
              .firstWhere(
                (b) => b.currencyCode == userSummary.currency,
                orElse: () => balances.first,
              )
              .currencyCode;
    final currency = currencyCode == null
        ? null
        : FiatCurrency.fromCode(currencyCode);
    final defaultLightningAddress = userSummary.autoBuy.addresses.lightning;

    return Ok((
      balances: balances,
      currency: currency,
      lightningAddress: defaultLightningAddress,
    ));
  }
}
