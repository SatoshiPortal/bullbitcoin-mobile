import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_api_key_repository.dart';
import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/fiat_settlement/data/fiat_settlement_default_wallet_xprv_adapter.dart';
import 'package:bb_mobile/features/fiat_settlement/data/scoped_settlement_key_adapter.dart';
import 'package:bb_mobile/features/fiat_settlement/domain/fiat_settlement_default_wallet_xprv_port.dart';
import 'package:bb_mobile/features/fiat_settlement/domain/scoped_settlement_key_port.dart';
import 'package:bb_mobile/features/fiat_settlement/domain/usecases/disable_fiat_settlement_usecase.dart';
import 'package:bb_mobile/features/fiat_settlement/domain/usecases/get_fiat_settlement_configuration_usecase.dart';
import 'package:bb_mobile/features/fiat_settlement/domain/usecases/has_bull_bitcoin_account_usecase.dart';
import 'package:bb_mobile/features/fiat_settlement/domain/usecases/set_fiat_settlement_usecase.dart';
import 'package:bb_mobile/features/fiat_settlement/public/fiat_settlement_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:get_it/get_it.dart';

class FiatSettlementLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<FiatSettlementDefaultWalletXprvPort>(
      () => FiatSettlementDefaultWalletXprvAdapter(
        getSettings: locator<GetSettingsUsecase>(),
        walletRepository: locator<WalletRepository>(),
        seedRepository: locator<SeedRepository>(),
      ),
    );
    locator.registerFactory<ScopedSettlementKeyPort>(
      () => ScopedSettlementKeyAdapter(
        datasource: locator<BullbitcoinApiKeyDatasource>(),
        getSettings: locator<GetSettingsUsecase>(),
      ),
    );
    locator.registerFactory<GetFiatSettlementConfigurationUsecase>(
      () => GetFiatSettlementConfigurationUsecase(
        bullnym: locator<BullnymFacade>(),
        xprvPort: locator<FiatSettlementDefaultWalletXprvPort>(),
        nostrIdentity: locator<NostrIdentityFacade>(),
      ),
    );
    locator.registerFactory<SetFiatSettlementUsecase>(
      () => SetFiatSettlementUsecase(
        bullnym: locator<BullnymFacade>(),
        xprvPort: locator<FiatSettlementDefaultWalletXprvPort>(),
        nostrIdentity: locator<NostrIdentityFacade>(),
        scopedKey: locator<ScopedSettlementKeyPort>(),
      ),
    );
    locator.registerFactory<DisableFiatSettlementUsecase>(
      () => DisableFiatSettlementUsecase(
        bullnym: locator<BullnymFacade>(),
        xprvPort: locator<FiatSettlementDefaultWalletXprvPort>(),
        nostrIdentity: locator<NostrIdentityFacade>(),
      ),
    );
    locator.registerFactory<HasBullBitcoinAccountUsecase>(
      () => HasBullBitcoinAccountUsecase(
        apiKeyRepository: locator<ExchangeApiKeyRepository>(),
        getSettings: locator<GetSettingsUsecase>(),
      ),
    );
    locator.registerFactory<FiatSettlementFacade>(
      () => FiatSettlementFacade(
        getConfiguration: locator<GetFiatSettlementConfigurationUsecase>(),
        set: locator<SetFiatSettlementUsecase>(),
        disable: locator<DisableFiatSettlementUsecase>(),
      ),
    );
  }
}
