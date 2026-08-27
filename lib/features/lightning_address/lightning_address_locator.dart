import 'package:bb_mobile/core/deterministic_wallets/prepare_deterministic_wallets_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/apply_wallet_behavior_defaults_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_preferences_usecase.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/get_paid_settings/public/get_paid_settings_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/activate_wallet_owned_lightning_address_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/deactivate_wallet_owned_lightning_address_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/delete_lightning_address_registration_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/ensure_lightning_address_registration_live_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/get_lightning_address_permanent_name_capability_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/get_lightning_address_wallet_behavior_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/lookup_lightning_address_receive_readiness_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/lookup_lightning_address_registration_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/lookup_wallet_owned_lightning_address_registration_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/prepare_lightning_address_wallet_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/register_lightning_address_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/register_wallet_owned_lightning_address_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/update_lightning_address_wallet_behavior_usecase.dart';
import 'package:bb_mobile/features/lightning_address/presentation/lightning_address_activation_cubit.dart';
import 'package:bb_mobile/features/lightning_address/public/lightning_address_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:get_it/get_it.dart';

abstract final class LightningAddressLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<LightningAddressFacade>(() {
      final operations = _LightningAddressOperations(locator);
      return LightningAddressFacade(
        operations.prepareWallet.execute,
        operations.registerWalletOwned.execute,
        operations.lookupWalletOwned.execute,
        operations.ensureRegistrationLive.execute,
      );
    });
    locator.registerFactory<LightningAddressActivationCubit>(() {
      final operations = _LightningAddressOperations(locator);
      return LightningAddressActivationCubit(
        getCapability: GetLightningAddressPermanentNameCapabilityUsecase(
          locator<BullnymFacade>(),
        ).execute,
        activate: ActivateWalletOwnedLightningAddressUsecase(
          operations.registerWalletOwned,
        ).execute,
        deactivate: DeactivateWalletOwnedLightningAddressUsecase(
          DeleteLightningAddressRegistrationUsecase(locator<BullnymFacade>()),
        ).execute,
        lookupReadiness: LookupLightningAddressReceiveReadinessUsecase(
          operations.lookupWalletOwned,
          operations.prepareWallet,
          locator<GetWalletPreferencesUsecase>(),
        ).execute,
        getWalletBehavior: GetLightningAddressWalletBehaviorUsecase(
          getPaidSettings: locator<GetPaidSettingsFacade>(),
        ).execute,
        updateWalletBehavior: UpdateLightningAddressWalletBehaviorUsecase(
          getPaidSettings: locator<GetPaidSettingsFacade>(),
        ).execute,
      );
    });
  }
}

final class _LightningAddressOperations {
  final PrepareLightningAddressWalletUsecase prepareWallet;
  final RegisterWalletOwnedLightningAddressUsecase registerWalletOwned;
  final LookupWalletOwnedLightningAddressRegistrationUsecase lookupWalletOwned;
  final EnsureLightningAddressRegistrationLiveUsecase ensureRegistrationLive;

  factory _LightningAddressOperations(GetIt locator) {
    final prepareWallet = PrepareLightningAddressWalletUsecase(
      locator<GetSettingsUsecase>(),
      locator<PrepareDeterministicWalletsUsecase>(),
      locator<KeychainManifestFacade>(),
      locator<ApplyWalletBehaviorDefaultsUsecase>(),
    );
    final registerWalletOwned = RegisterWalletOwnedLightningAddressUsecase(
      prepareWallet,
      RegisterLightningAddressUsecase(
        locator<BullnymFacade>(),
        locator<NostrIdentityFacade>(),
      ),
    );
    final lookupWalletOwned =
        LookupWalletOwnedLightningAddressRegistrationUsecase(
          LookupLightningAddressRegistrationUsecase(locator<BullnymFacade>()),
        );
    return _LightningAddressOperations._(
      prepareWallet,
      registerWalletOwned,
      lookupWalletOwned,
      EnsureLightningAddressRegistrationLiveUsecase(
        lookupWalletOwned,
        registerWalletOwned,
      ),
    );
  }

  const _LightningAddressOperations._(
    this.prepareWallet,
    this.registerWalletOwned,
    this.lookupWalletOwned,
    this.ensureRegistrationLive,
  );
}
