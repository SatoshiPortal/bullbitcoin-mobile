import 'package:primitives/primitives.dart';
import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_exchange/src/dca/domain/dca_failure.dart';
import 'package:meta/meta.dart';
import 'package:secrets/secrets.dart' show WalletSelection;

import '../../../exchange_payout_wallets.dart';

class SetDcaUsecase {
  final ExchangePayoutWallets _payouts;
  final Preferences _settingsRepository;
  final Exchange _exchange;

  SetDcaUsecase({
    required this._payouts,
    required this._settingsRepository,
    required this._exchange,
  });

  @useResult
  Future<Result<Dca, DcaFailure>> execute({
    required double amount,
    required FiatCurrency currency,
    required DcaBuyFrequency frequency,
    required DcaNetwork network,
    String? lightningAddress,
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

    final String address;
    switch (network) {
      case DcaNetwork.lightning:
        // Defensive: the wallet-selection screen validates this before we run.
        if (lightningAddress == null || lightningAddress.isEmpty) {
          return const Err(DcaLightningAddressRequiredFailure());
        }
        address = lightningAddress;
      case DcaNetwork.bitcoin:
      case DcaNetwork.liquid:
        final Network chain = network == DcaNetwork.bitcoin
            ? BitcoinNetwork.fromName(environment.name)
            : LiquidNetwork.fromName(environment.name);
        switch (await _payouts.walletsForNetwork(chain)) {
          case Ok(value: WalletSelection(defaultWallet: final wallet?))
              when wallet.network == chain:
            final issued = await _payouts.receive(
              wallet,
              advance: true,
              requiresDefault: true,
            );
            if (issued == null) return const Err(DcaReceiveAddressFailure());
            address = issued;
          case Ok():
            return const Err(DcaReceiveAddressFailure());
          case Err(:final failure):
            return Err(
              DcaUnexpectedFailure('default wallet: ${failure.runtimeType}'),
            );
        }
    }

    // Read the preference set BEFORE creating anything on the exchange. The
    // DCA flag is operative — the exchange web client stops a recurring buy
    // by writing it — and saveUserPreferences replaces the whole stored set,
    // so the enabling write must carry the current values. Aborting here is
    // clean: nothing exists on the exchange yet.
    final exchangeEnvironment = environment.requireHistoricalTestnet()
        ? ExchangeEnvironment.testnet
        : ExchangeEnvironment.mainnet;

    final UserSummary summary;
    switch (await _exchange.getUserSummary(exchangeEnvironment)) {
      case Ok(:final value):
        summary = value;
      case Err(:final failure):
        log.warning(
          'DCA aborted before creation: user summary unavailable: '
          '${failure.runtimeType}',
        );
        return const Err(
          DcaAccountUnavailableFailure('user summary unavailable'),
        );
    }

    // The active environment can change while the address or summary is read.
    final current = await _settingsRepository.fetch();
    if (current is! Ok<SettingsEntity, PreferencesFailure> ||
        current.value.environment != environment) {
      return const Err(DcaAccountUnavailableFailure('environment changed'));
    }
    final Dca dca;
    switch (await _exchange
        .orders(exchangeEnvironment)
        .createDca(
          amount: amount,
          currency: currency,
          frequency: frequency,
          network: network,
          address: address,
        )) {
      case Ok(:final value):
        dca = value;
      case Err(:final failure):
        log.warning(
          'Exchange rejected DCA creation',
          error: failure.runtimeType,
        );
        return const Err(DcaOrderCreationFailure('createDca rejected'));
    }

    if (await _exchange.saveUserPreference(
          exchangeEnvironment,
          language: summary.language,
          currency: summary.currency,
          dcaEnabled: true,
          autoBuyEnabled: summary.autoBuy.isActive.toString(),
          emailNotificationsEnabled: summary.emailNotificationsEnabled,
        )
        case Err(:final failure)) {
      // The recurring buy already exists on the exchange at this point, so
      // this must NOT be reported as a failure: the user would be told
      // nothing happened and could create a second one. The repository
      // already logged the reason, so note the outcome and continue.
      log.warning(
        'DCA created but enabling the preference failed: '
        '${failure.runtimeType}',
      );
    }

    return Ok(dca);
  }
}
