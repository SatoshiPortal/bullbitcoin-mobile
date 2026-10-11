import 'package:bb_mobile/features/nostr_identity/domain/backup_credential_resolver.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:get_it/get_it.dart';

abstract final class NostrIdentityLocator {
  static void setup(GetIt locator) {
    locator.registerFactory(
      () => BackupCredentialResolver(
        getDefaultSeed: locator(),
        getSettings: locator(),
      ),
    );
    locator.registerFactory(() => NostrIdentityFacade(locator()));
  }
}
