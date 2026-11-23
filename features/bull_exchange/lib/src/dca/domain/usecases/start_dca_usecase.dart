import 'package:primitives/primitives.dart';
import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_exchange/src/dca/domain/dca_failure.dart';
import 'package:meta/meta.dart';

typedef DcaStartData = ({
  List<UserBalance> balances,
  FiatCurrency? currency,
  String? lightningAddress,
});

class StartDcaUsecase {
  final Preferences _settingsRepository;
  final Exchange _exchange;

  StartDcaUsecase({required this._settingsRepository, required this._exchange});

  @useResult
  Future<Result<DcaStartData, DcaFailure>> execute() async {
    final bool isMainnet;
    try {
      final settings = (await _settingsRepository.fetch()).fold(
        (value) => value,
        (failure) => throw Exception('Preferences read failed'),
      );
      if (!NetworkCapabilities.supports(
        BitcoinNetwork.fromName(settings.environment.name),
        NetworkCapability.exchange,
      )) {
        return const Err(DcaAccountUnavailableFailure('network unsupported'));
      }
      isMainnet = settings.environment.isMainnet;
    } on Exception catch (e, st) {
      log.severe(
        message: 'Failed to load settings',
        error: e.runtimeType,
        trace: st,
      );
      return const Err(DcaUnexpectedFailure('settings fetch failed'));
    }

    // The repository is the boundary: it already caught, logged the raw
    // reason, and handed back a sanitized failure — including the
    // "no API key stored" case.
    // Not final: Dart 3.14.0 AOT crashes on a switch-assigned final captured by a closure (dart-lang/sdk#64917).
    UserSummary userSummary;
    switch (await _exchange.getUserSummary(
      isMainnet ? ExchangeEnvironment.mainnet : ExchangeEnvironment.testnet,
    )) {
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
