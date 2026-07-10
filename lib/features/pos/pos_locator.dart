import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/apply_wallet_behavior_defaults_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/update_wallet_behavior_usecase.dart';
import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_config.dart'
    show bullnymDefaultBaseUrl;
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/deterministic_wallets/public/deterministic_wallets_facade.dart';
import 'package:bb_mobile/features/get_paid_settings/domain/usecases/get_get_paid_wallet_behaviors_usecase.dart';
import 'package:bb_mobile/features/get_paid_settings/public/get_paid_settings_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/lightning_address/public/lightning_address_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/pos/data/pos_default_wallet_xprv_adapter.dart';
import 'package:bb_mobile/features/pos/domain/pos_default_wallet_xprv_port.dart';
import 'package:bb_mobile/features/pos/domain/usecases/archive_pos_usecase.dart';
import 'package:bb_mobile/features/pos/domain/usecases/ensure_pos_live_usecase.dart';
import 'package:bb_mobile/features/pos/domain/usecases/find_pos_usecase.dart';
import 'package:bb_mobile/features/pos/domain/usecases/get_pos_usecase.dart';
import 'package:bb_mobile/features/pos/domain/usecases/get_supported_display_currencies_usecase.dart';
import 'package:bb_mobile/features/pos/domain/usecases/prepare_pos_wallet_usecase.dart';
import 'package:bb_mobile/features/pos/domain/usecases/provision_pos_usecase.dart';
import 'package:bb_mobile/features/pos/domain/usecases/resolve_pos_identity_usecase.dart';
import 'package:bb_mobile/features/pos/presentation/pos_cubit.dart';
import 'package:bb_mobile/features/pos/public/pos_facade.dart';
import 'package:get_it/get_it.dart';

class PosLocator {
  static void setup(GetIt locator) {
    // The terminal URL is constructed client-side against the SAME base the
    // shared bullnym client is configured with (DG-P5), never a server echo.
    const terminalBaseUrl = bullnymDefaultBaseUrl;

    locator.registerFactory<PosDefaultWalletXprvPort>(
      () => PosDefaultWalletXprvAdapter(
        getSettings: locator<GetSettingsUsecase>(),
        walletRepository: locator<WalletRepository>(),
        seedRepository: locator<SeedRepository>(),
      ),
    );
    locator.registerFactory<PreparePosWalletUsecase>(
      () => PreparePosWalletUsecase(
        getSettings: locator<GetSettingsUsecase>(),
        deterministicWallets: locator<DeterministicWalletsFacade>(),
        keychainManifest: locator<KeychainManifestFacade>(),
        applyWalletBehaviorDefaults:
            locator<ApplyWalletBehaviorDefaultsUsecase>(),
        bip85Registry: locator<Bip85RegistryFacade>(),
      ),
    );
    locator.registerFactory<ResolvePosIdentityUsecase>(
      () => ResolvePosIdentityUsecase(
        defaultWalletXprv: locator<PosDefaultWalletXprvPort>(),
        nostrIdentity: locator<NostrIdentityFacade>(),
        lightningAddress: locator<LightningAddressFacade>(),
      ),
    );
    locator.registerFactory<GetPosUsecase>(
      () => GetPosUsecase(
        locator<BullnymFacade>(),
        terminalBaseUrl: terminalBaseUrl,
      ),
    );
    locator.registerFactory<FindPosUsecase>(
      () => FindPosUsecase(locator<GetPosUsecase>()),
    );
    locator.registerFactory<ProvisionPosUsecase>(
      () => ProvisionPosUsecase(
        resolveIdentity: locator<ResolvePosIdentityUsecase>(),
        prepareWallet: locator<PreparePosWalletUsecase>(),
        bullnym: locator<BullnymFacade>(),
        getPaidSettings: locator<GetPaidSettingsFacade>(),
        terminalBaseUrl: terminalBaseUrl,
      ),
    );
    locator.registerFactory<ArchivePosUsecase>(
      () => ArchivePosUsecase(
        resolveIdentity: locator<ResolvePosIdentityUsecase>(),
        bullnym: locator<BullnymFacade>(),
        terminalBaseUrl: terminalBaseUrl,
      ),
    );
    locator.registerFactory<GetSupportedDisplayCurrenciesUsecase>(
      () => GetSupportedDisplayCurrenciesUsecase(locator<BullnymFacade>()),
    );
    locator.registerFactory<EnsurePosLiveUsecase>(
      () => EnsurePosLiveUsecase(
        lightningAddress: locator<LightningAddressFacade>(),
        findPos: locator<FindPosUsecase>(),
      ),
    );
    locator.registerFactory<PosFacade>(() {
      final find = locator<FindPosUsecase>();
      final provision = locator<ProvisionPosUsecase>();
      final archive = locator<ArchivePosUsecase>();
      final currencies = locator<GetSupportedDisplayCurrenciesUsecase>();
      final ensureLive = locator<EnsurePosLiveUsecase>();
      return PosFacade(
        find: ({required nym}) => find.execute(nym: nym),
        provision: (command) => provision.execute(
          label: command.label,
          displayCurrency: command.displayCurrency,
        ),
        archive: archive.execute,
        supportedCurrencies: currencies.execute,
        ensurePosLive: ensureLive.execute,
      );
    });
    locator.registerFactory<PosCubit>(
      () => PosCubit(
        facade: locator<PosFacade>(),
        lightningAddress: locator<LightningAddressFacade>(),
        getWalletBehaviors: locator<GetGetPaidWalletBehaviorsUsecase>(),
        updateWalletBehavior: locator<UpdateWalletBehaviorUsecase>(),
      ),
    );
  }
}
