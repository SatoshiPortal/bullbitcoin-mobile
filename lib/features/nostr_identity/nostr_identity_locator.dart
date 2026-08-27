import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/domain/get_nostr_public_key_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/domain/nostr_identity_key_resolver.dart';
import 'package:bb_mobile/features/nostr_identity/domain/sign_nostr_hash_usecase.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:get_it/get_it.dart';

class NostrIdentityLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<NostrIdentityFacade>(() {
      final resolver = NostrIdentityKeyResolver(
        locator<GetSettingsUsecase>(),
        locator<GetDefaultSeedUsecase>(),
      );
      return NostrIdentityFacade(
        GetNostrPublicKeyUsecase(resolver),
        SignNostrHashUsecase(resolver),
      );
    });
  }
}
