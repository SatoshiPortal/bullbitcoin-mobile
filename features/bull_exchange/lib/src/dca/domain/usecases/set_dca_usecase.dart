import 'package:primitives/primitives.dart';
import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_exchange/src/dca/domain/dca_failure.dart';
import 'package:meta/meta.dart';

/// Creates the recurring buy. [execute]'s `address` is the payout destination
/// for every run (the server reuses it): an exchange default wallet's address,
/// a typed address or a Lightning address, never an app wallet's receive
/// address.
class SetDcaUsecase {
  final Preferences _settingsRepository;
  final Exchange _exchange;

  SetDcaUsecase({required this._settingsRepository, required this._exchange});

  @useResult
  Future<Result<Dca, DcaFailure>> execute({
    required double amount,
    required FiatCurrency currency,
    required DcaBuyFrequency frequency,
    required DcaNetwork network,
    required String address,
  }) async {
    final SettingsEntity settings;
    try {
      switch (await _settingsRepository.fetch()) {
        case Ok(:final value):
          settings = value;
        case Err():
          return const Err(DcaUnexpectedFailure('settings fetch failed'));
      }
    } on Exception catch (e, st) {
      log.severe(
        message: 'Failed to load settings',
        error: e.runtimeType,
        trace: st,
      );
      return const Err(DcaUnexpectedFailure('settings fetch failed'));
    }
    final environment = settings.environment;
    if (!NetworkCapabilities.supports(
      BitcoinNetwork.fromName(environment.name),
      NetworkCapability.exchange,
    )) {
      log.warning('Capability refused feature=dca reason=unsupported');
      return const Err(DcaAccountUnavailableFailure('network unsupported'));
    }

    // Defensive: the wallet-selection screen only continues with an address.
    if (address.isEmpty) {
      final DcaFailure failure = switch (network) {
        DcaNetwork.lightning => const DcaLightningAddressRequiredFailure(),
        DcaNetwork.bitcoin ||
        DcaNetwork.liquid => const DcaDestinationAddressRequiredFailure(),
      };
      return Err(failure);
    }

    final exchangeEnvironment = environment.requireHistoricalTestnet()
        ? ExchangeEnvironment.testnet
        : ExchangeEnvironment.mainnet;

    // The active environment can change while the address or summary is read.
    final current = await _settingsRepository.fetch();
    if (current is! Ok<SettingsEntity, PreferencesFailure> ||
        current.value.environment != environment) {
      return const Err(DcaAccountUnavailableFailure('environment changed'));
    }
    final result = await _exchange
        .orders(exchangeEnvironment)
        .createDca(
          amount: amount,
          currency: currency,
          frequency: frequency,
          network: network,
          address: address,
          enablePreference: true,
        );
    switch (result) {
      case Ok(:final value):
        return Ok(value);
      case Err(
        failure: ExchangeAccountUnavailableFailure() ||
            ExchangeCredentialReadFailure(),
      ):
        return const Err(
          DcaAccountUnavailableFailure('user summary unavailable'),
        );
      case Err(:final failure):
        log.warning(
          'Exchange rejected DCA creation',
          error: failure.runtimeType,
        );
        return const Err(DcaOrderCreationFailure('createDca rejected'));
    }
  }
}
