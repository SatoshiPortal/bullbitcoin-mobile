import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/apply_wallet_behavior_defaults_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/update_wallet_behavior_usecase.dart';
import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/deterministic_wallets/public/deterministic_wallets_facade.dart';
import 'package:bb_mobile/features/get_paid_settings/domain/usecases/get_get_paid_wallet_behaviors_usecase.dart';
import 'package:bb_mobile/features/get_paid_settings/public/get_paid_settings_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/lightning_address/public/lightning_address_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/payment_page/data/payment_page_default_wallet_xprv_adapter.dart';
import 'package:bb_mobile/features/payment_page/domain/payment_page_default_wallet_xprv_port.dart';
import 'package:bb_mobile/features/payment_page/domain/usecases/archive_payment_page_usecase.dart';
import 'package:bb_mobile/features/payment_page/domain/usecases/ensure_payment_page_live_usecase.dart';
import 'package:bb_mobile/features/payment_page/domain/usecases/find_payment_page_usecase.dart';
import 'package:bb_mobile/features/payment_page/domain/usecases/get_payment_page_usecase.dart';
import 'package:bb_mobile/features/payment_page/domain/usecases/get_supported_display_currencies_usecase.dart';
import 'package:bb_mobile/features/payment_page/domain/usecases/prepare_payment_page_wallet_usecase.dart';
import 'package:bb_mobile/features/payment_page/domain/usecases/resolve_payment_page_identity_usecase.dart';
import 'package:bb_mobile/features/payment_page/domain/usecases/save_payment_page_usecase.dart';
import 'package:bb_mobile/features/payment_page/presentation/payment_page_cubit.dart';
import 'package:bb_mobile/features/payment_page/public/payment_page_facade.dart';
import 'package:get_it/get_it.dart';

class PaymentPageLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<PaymentPageDefaultWalletXprvPort>(
      () => PaymentPageDefaultWalletXprvAdapter(
        getSettings: locator<GetSettingsUsecase>(),
        walletRepository: locator<WalletRepository>(),
        seedRepository: locator<SeedRepository>(),
      ),
    );
    locator.registerFactory<PreparePaymentPageWalletUsecase>(
      () => PreparePaymentPageWalletUsecase(
        getSettings: locator<GetSettingsUsecase>(),
        deterministicWallets: locator<DeterministicWalletsFacade>(),
        keychainManifest: locator<KeychainManifestFacade>(),
        applyWalletBehaviorDefaults:
            locator<ApplyWalletBehaviorDefaultsUsecase>(),
        bip85Registry: locator<Bip85RegistryFacade>(),
      ),
    );
    locator.registerFactory<ResolvePaymentPageIdentityUsecase>(
      () => ResolvePaymentPageIdentityUsecase(
        defaultWalletXprv: locator<PaymentPageDefaultWalletXprvPort>(),
        nostrIdentity: locator<NostrIdentityFacade>(),
        lightningAddress: locator<LightningAddressFacade>(),
      ),
    );
    locator.registerFactory<GetPaymentPageUsecase>(
      () => GetPaymentPageUsecase(locator<BullnymFacade>()),
    );
    locator.registerFactory<FindPaymentPageUsecase>(
      () => FindPaymentPageUsecase(locator<GetPaymentPageUsecase>()),
    );
    locator.registerFactory<SavePaymentPageUsecase>(
      () => SavePaymentPageUsecase(
        resolveIdentity: locator<ResolvePaymentPageIdentityUsecase>(),
        prepareWallet: locator<PreparePaymentPageWalletUsecase>(),
        bullnym: locator<BullnymFacade>(),
        getPaidSettings: locator<GetPaidSettingsFacade>(),
      ),
    );
    locator.registerFactory<ArchivePaymentPageUsecase>(
      () => ArchivePaymentPageUsecase(
        resolveIdentity: locator<ResolvePaymentPageIdentityUsecase>(),
        bullnym: locator<BullnymFacade>(),
      ),
    );
    locator.registerFactory<GetSupportedDisplayCurrenciesUsecase>(
      () => GetSupportedDisplayCurrenciesUsecase(locator<BullnymFacade>()),
    );
    locator.registerFactory<EnsurePaymentPageLiveUsecase>(
      () => EnsurePaymentPageLiveUsecase(
        lightningAddress: locator<LightningAddressFacade>(),
        findPage: locator<FindPaymentPageUsecase>(),
      ),
    );
    locator.registerFactory<PaymentPageFacade>(() {
      final find = locator<FindPaymentPageUsecase>();
      final save = locator<SavePaymentPageUsecase>();
      final archive = locator<ArchivePaymentPageUsecase>();
      final currencies = locator<GetSupportedDisplayCurrenciesUsecase>();
      final ensureLive = locator<EnsurePaymentPageLiveUsecase>();
      return PaymentPageFacade(
        find: ({required nym}) => find.execute(nym: nym),
        save: (command) => save.execute(
          header: command.header,
          description: command.description,
          displayCurrency: command.displayCurrency,
          website: command.website,
          twitter: command.twitter,
          instagram: command.instagram,
        ),
        archive: archive.execute,
        supportedCurrencies: currencies.execute,
        ensurePageLive: ensureLive.execute,
      );
    });
    locator.registerFactory<PaymentPageCubit>(
      () => PaymentPageCubit(
        facade: locator<PaymentPageFacade>(),
        lightningAddress: locator<LightningAddressFacade>(),
        getWalletBehaviors: locator<GetGetPaidWalletBehaviorsUsecase>(),
        updateWalletBehavior: locator<UpdateWalletBehaviorUsecase>(),
      ),
    );
  }
}
