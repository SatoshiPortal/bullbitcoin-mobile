import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/features/address_view/domain/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:bb_mobile/features/dca/domain/dca_failure.dart';
import 'package:meta/meta.dart';

class SetDcaUsecase {
  // TODO: Don't use the repositories of other domains directly, but use reduced
  // interfaces for each domain just for what is needed from them in the DCA context/domain
  final WalletRepository _wallet;
  final Preferences _settingsRepository;
  final WalletAddressRepository _walletAddressRepository;
  final Exchange _exchange;

  SetDcaUsecase({
    required this._wallet,
    required this._settingsRepository,
    required this._walletAddressRepository,
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
    } catch (e, st) {
      if (e is Error) rethrow;
      log.severe(message: 'Failed to load settings', error: e, trace: st);
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
    if (network == DcaNetwork.lightning) {
      // Defensive: the wallet-selection screen validates this before we run.
      if (lightningAddress == null || lightningAddress.isEmpty) {
        return const Err(DcaLightningAddressRequiredFailure());
      }
      address = lightningAddress;
    } else {
      try {
        final List<Wallet> wallets;
        switch (await _wallet.getWallets(
          environment: environment,
          onlyDefaults: true,
          onlyBitcoin: network == DcaNetwork.bitcoin,
          onlyLiquid: network == DcaNetwork.liquid,
        )) {
          case Ok(:final value):
            wallets = value;
          case Err(:final failure):
            log.warning('DCA receive address: ${failure.logMessage}');
            return Err(
              DcaUnexpectedFailure('default wallet: ${failure.runtimeType}'),
            );
        }

        if (wallets.isEmpty) {
          log.warning('No default wallet found for DCA network $network');
          return const Err(DcaReceiveAddressFailure());
        }

        final walletAddress = await _walletAddressRepository
            .generateNewReceiveAddress(walletId: wallets.first.id);
        address = walletAddress.address;
      } catch (e, st) {
        if (e is Error) rethrow;
        log.severe(
          message: 'Failed to resolve a DCA receive address',
          error: e,
          trace: st,
        );
        return const Err(
          DcaReceiveAddressFailure('receive address generation failed'),
        );
      }
    }

    final exchangeEnvironment = environment.requireHistoricalTestnet()
        ? ExchangeEnvironment.testnet
        : ExchangeEnvironment.mainnet;

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
