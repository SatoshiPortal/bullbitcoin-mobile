import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/domain/backup_credential_resolver.dart';
import 'package:bb_mobile/features/nostr_identity/domain/get_backup_identity_public_key_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/domain/reveal_backup_words_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/domain/sign_backup_identity_hash_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:get_it/get_it.dart';

class NostrIdentityLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<NostrIdentityFacade>(() {
      final resolver = BackupCredentialResolver(
        locator<GetSettingsUsecase>(),
        locator<GetDefaultSeedUsecase>(),
      );
      return NostrIdentityFacade(
        GetBackupIdentityPublicKeyUsecase(resolver),
        SignBackupIdentityHashUsecase(resolver),
        RevealBackupWordsUsecase(resolver),
      );
    });
  }
}
