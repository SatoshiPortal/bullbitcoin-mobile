import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:bb_mobile/features/nostr_identity/domain/derive_nostr_identity_handle_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:get_it/get_it.dart';

class NostrIdentityLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<DeriveNostrIdentityHandleUsecase>(
      () => DeriveNostrIdentityHandleUsecase(
        registry: locator<Bip85RegistryFacade>(),
      ),
    );
    locator.registerFactory<NostrIdentityFacade>(
      () => NostrIdentityFacade(
        deriveHandle: locator<DeriveNostrIdentityHandleUsecase>(),
      ),
    );
  }
}
