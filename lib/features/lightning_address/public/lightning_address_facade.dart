import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bb_mobile/features/deterministic_wallets/public/deterministic_wallets_facade.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_registration.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_wallet.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/delete_lightning_address_registration_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/lookup_lightning_address_registration_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/prepare_lightning_address_wallet_usecase.dart';
import 'package:bb_mobile/features/lightning_address/domain/usecases/register_lightning_address_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';

export 'package:bb_mobile/features/lightning_address/domain/lightning_address_error.dart';
export 'package:bb_mobile/features/lightning_address/domain/lightning_address_registration.dart';
export 'package:bb_mobile/features/lightning_address/domain/lightning_address_wallet.dart'
    show PreparedLightningAddressWallet;

class LightningAddressFacade {
  final PrepareLightningAddressWalletUsecase _prepareWallet;
  final RegisterLightningAddressUsecase _register;
  final DeleteLightningAddressRegistrationUsecase _deleteRegistration;
  final LookupLightningAddressRegistrationUsecase _lookupRegistration;

  LightningAddressFacade({
    required GetSettingsUsecase getSettings,
    required DeterministicWalletsFacade deterministicWallets,
    required KeychainManifestFacade keychainManifest,
    required Bip85RegistryFacade bip85Registry,
    required BullnymFacade bullnym,
    required NostrIdentityFacade nostrIdentity,
  }) : _prepareWallet = PrepareLightningAddressWalletUsecase(
         getSettings: getSettings,
         deterministicWallets: deterministicWallets,
         keychainManifest: keychainManifest,
         bip85Registry: bip85Registry,
       ),
       _register = RegisterLightningAddressUsecase(bullnym, nostrIdentity),
       _deleteRegistration = DeleteLightningAddressRegistrationUsecase(
         bullnym,
         nostrIdentity,
       ),
       _lookupRegistration = LookupLightningAddressRegistrationUsecase(bullnym);

  Future<PreparedLightningAddressWallet> prepareWallet() {
    return _prepareWallet.execute();
  }

  Future<LightningAddressRegistration> register({
    required String xprvBase58,
    required String nym,
    required String ctDescriptor,
  }) {
    return _register.execute(
      xprvBase58: xprvBase58,
      nym: nym,
      ctDescriptor: ctDescriptor,
    );
  }

  Future<void> deleteRegistration({
    required String xprvBase58,
    required String nym,
  }) {
    return _deleteRegistration.execute(xprvBase58: xprvBase58, nym: nym);
  }

  Future<LightningAddressStatus> lookupRegistration({required String npubHex}) {
    return _lookupRegistration.execute(npubHex: npubHex);
  }
}
