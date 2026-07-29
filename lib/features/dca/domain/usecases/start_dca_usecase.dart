import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_user_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
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
      log.severe(message: 'Failed to load settings', error: e, trace: st);
      return Err(DcaUnexpectedFailure(e.toString()));
    }

    final UserSummary userSummary;
    try {
      final summary = isMainnet
          ? await _mainnetExchangeUserRepository.getUserSummary()
          : await _testnetExchangeUserRepository.getUserSummary();
      if (summary == null) {
        // Null also covers "no API key stored" — the repository returns null
        // instead of throwing in that case.
        return const Err(DcaAccountUnavailableFailure());
      }
      userSummary = summary;
    } catch (e, st) {
      log.warning('Failed to fetch user summary', error: e, trace: st);
      return Err(DcaAccountUnavailableFailure(e.toString()));
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
