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
