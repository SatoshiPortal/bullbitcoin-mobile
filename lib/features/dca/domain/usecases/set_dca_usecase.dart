import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/save_user_preferences_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/dca/domain/dca.dart';
import 'package:bb_mobile/features/dca/domain/dca_failure.dart';
import 'package:meta/meta.dart';

class SetDcaUsecase {
  final ExchangeOrderRepository _mainnetDcaRepository;
  final ExchangeOrderRepository _testnetDcaRepository;
  // TODO: Don't use the repositories of other domains directly, but use reduced
  // interfaces for each domain just for what is needed from them in the DCA context/domain
  final WalletRepository _wallet;
  final SettingsRepository _settingsRepository;
  final WalletAddressRepository _walletAddressRepository;
  final SaveUserPreferencesUsecase _saveUserPreferencesUsecase;

  SetDcaUsecase({
    required ExchangeOrderRepository mainnetExchangeOrderRepository,
    required ExchangeOrderRepository testnetExchangeOrderRepository,
    required this._wallet,
    required this._settingsRepository,
    required this._walletAddressRepository,
    required this._saveUserPreferencesUsecase,
  }) : _mainnetDcaRepository = mainnetExchangeOrderRepository,
       _testnetDcaRepository = testnetExchangeOrderRepository;

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
      settings = await _settingsRepository.fetch();
    } catch (e, st) {
      log.severe(message: 'Failed to load settings', error: e, trace: st);
      return Err(DcaUnexpectedFailure(e.toString()));
    }
    final environment = settings.environment;

    final String address;
    if (network == DcaNetwork.lightning) {
      // Defensive: the wallet-selection screen validates this before we run.
      if (lightningAddress == null || lightningAddress.isEmpty) {
        return const Err(DcaLightningAddressRequiredFailure());
      }
      address = lightningAddress;
    } else {
      try {
        final wallets = await _wallet.getWallets(
          environment: environment,
          onlyDefaults: true,
          onlyBitcoin: network == DcaNetwork.bitcoin,
          onlyLiquid: network == DcaNetwork.liquid,
        );

        if (wallets.isEmpty) {
          log.warning('No default wallet found for DCA network $network');
          return const Err(DcaReceiveAddressFailure());
        }

        final walletAddress = await _walletAddressRepository
            .generateNewReceiveAddress(walletId: wallets.first.id);
        address = walletAddress.address;
      } catch (e, st) {
        log.severe(
          message: 'Failed to resolve a DCA receive address',
          error: e.runtimeType,
          trace: st,
        );
        return Err(DcaReceiveAddressFailure(e.toString()));
      }
    }

    final Dca dca;
    try {
      final repository = environment.isMainnet
          ? _mainnetDcaRepository
          : _testnetDcaRepository;
      dca = await repository.createDca(
        amount: amount,
        currency: currency,
        frequency: frequency,
        network: network,
        address: address,
      );
    } catch (e, st) {
      log.warning('Exchange rejected DCA creation', error: e, trace: st);
      return Err(DcaOrderCreationFailure(e.toString()));
    }

    try {
      await _saveUserPreferencesUsecase.execute(dcaEnabled: true);
    } catch (e, st) {
      log.severe(
        message: 'DCA created but enabling the preference failed',
        error: e,
        trace: st,
      );
      return Err(DcaUnexpectedFailure(e.toString()));
    }

    return Ok(dca);
  }
}
