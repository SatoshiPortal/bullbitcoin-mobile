import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/apply_wallet_behavior_defaults_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/update_wallet_behavior_usecase.dart';
import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/deterministic_wallets/public/deterministic_wallets_facade.dart';
import 'package:bb_mobile/features/get_paid_settings/domain/usecases/get_get_paid_wallet_behaviors_usecase.dart';
import 'package:bb_mobile/features/get_paid_settings/public/get_paid_settings_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/lightning_address/data/default_wallet_xprv_adapter.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_default_wallet_xprv_port.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/activate_wallet_owned_lightning_address_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/ensure_lightning_address_registration_live_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/lookup_lightning_address_receive_readiness_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/lookup_lightning_address_registration_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/lookup_wallet_owned_lightning_address_registration_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/prepare_lightning_address_wallet_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/register_lightning_address_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/register_wallet_owned_lightning_address_usecase.dart';
import 'package:bb_mobile/features/lightning_address/presentation/lightning_address_activation_cubit.dart';
import 'package:bb_mobile/features/lightning_address/public/lightning_address_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:get_it/get_it.dart';

class LightningAddressLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<LightningAddressDefaultWalletXprvPort>(
      () => DefaultWalletXprvAdapter(
        getSettings: locator<GetSettingsUsecase>(),
        walletRepository: locator<WalletRepository>(),
        seedRepository: locator<SeedRepository>(),
      ),
    );
    locator.registerFactory<PrepareLightningAddressWalletUsecase>(
      () => PrepareLightningAddressWalletUsecase(
        getSettings: locator<GetSettingsUsecase>(),
        deterministicWallets: locator<DeterministicWalletsFacade>(),
        keychainManifest: locator<KeychainManifestFacade>(),
        applyWalletBehaviorDefaults:
            locator<ApplyWalletBehaviorDefaultsUsecase>(),
        bip85Registry: locator<Bip85RegistryFacade>(),
      ),
    );
    locator.registerFactory<RegisterLightningAddressUsecase>(
      () => RegisterLightningAddressUsecase(
        locator<BullnymFacade>(),
        locator<NostrIdentityFacade>(),
      ),
    );
    locator.registerFactory<LookupLightningAddressRegistrationUsecase>(
      () => LookupLightningAddressRegistrationUsecase(locator<BullnymFacade>()),
    );
    locator.registerFactory<RegisterWalletOwnedLightningAddressUsecase>(
      () => RegisterWalletOwnedLightningAddressUsecase(
        defaultWalletXprv: locator<LightningAddressDefaultWalletXprvPort>(),
        prepareWallet: locator<PrepareLightningAddressWalletUsecase>(),
        register: locator<RegisterLightningAddressUsecase>(),
        getPaidSettings: locator<GetPaidSettingsFacade>(),
      ),
    );
    locator
        .registerFactory<LookupWalletOwnedLightningAddressRegistrationUsecase>(
          () => LookupWalletOwnedLightningAddressRegistrationUsecase(
            defaultWalletXprv: locator<LightningAddressDefaultWalletXprvPort>(),
            lookupRegistration:
                locator<LookupLightningAddressRegistrationUsecase>(),
            nostrIdentity: locator<NostrIdentityFacade>(),
          ),
        );
    locator.registerFactory<LookupLightningAddressReceiveReadinessUsecase>(
      () => LookupLightningAddressReceiveReadinessUsecase(
        lookupRegistration:
            locator<LookupWalletOwnedLightningAddressRegistrationUsecase>(),
        prepareWallet: locator<PrepareLightningAddressWalletUsecase>(),
        getWallet: locator<GetWalletUsecase>(),
      ),
    );
    locator.registerFactory<EnsureLightningAddressRegistrationLiveUsecase>(
      () => EnsureLightningAddressRegistrationLiveUsecase(
        lookup: locator<LookupWalletOwnedLightningAddressRegistrationUsecase>(),
        register: locator<RegisterWalletOwnedLightningAddressUsecase>(),
      ),
    );
    locator.registerFactory<LightningAddressFacade>(() {
      final prepareWallet = locator<PrepareLightningAddressWalletUsecase>();
      final lookupRegistration =
          locator<LookupLightningAddressRegistrationUsecase>();
      final registerWalletOwned =
          locator<RegisterWalletOwnedLightningAddressUsecase>();
      final lookupWalletOwnedRegistration =
          locator<LookupWalletOwnedLightningAddressRegistrationUsecase>();
      final ensureRegistrationLive =
          locator<EnsureLightningAddressRegistrationLiveUsecase>();

      return LightningAddressFacade(
        prepareWallet: prepareWallet.execute,
        lookupRegistration: ({required npubHex}) =>
            lookupRegistration.execute(npubHex: npubHex),
        registerWalletOwned: ({required nym}) =>
            registerWalletOwned.execute(nym: nym),
        lookupWalletOwnedRegistration: lookupWalletOwnedRegistration.execute,
        ensureRegistrationLive: ensureRegistrationLive.execute,
      );
    });
    locator.registerFactory<ActivateWalletOwnedLightningAddressUsecase>(
      () => ActivateWalletOwnedLightningAddressUsecase(
        locator<RegisterWalletOwnedLightningAddressUsecase>(),
      ),
    );
    locator.registerFactory<LightningAddressActivationCubit>(
      () => LightningAddressActivationCubit(
        locator<ActivateWalletOwnedLightningAddressUsecase>(),
        locator<LookupLightningAddressReceiveReadinessUsecase>(),
        locator<GetGetPaidWalletBehaviorsUsecase>(),
        locator<UpdateWalletBehaviorUsecase>(),
      ),
    );
  }
}
