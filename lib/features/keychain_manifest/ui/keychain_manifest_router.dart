import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/keychain_manifest/ui/screens/nostr_keys_screen.dart';
import 'package:go_router/go_router.dart';

abstract final class KeychainManifestRouter {
  static final route = GoRoute(
    name: KeychainManifestFacade.nostrKeysRouteName,
    path: '/nostr-keys',
    builder: (_, _) => const NostrKeysScreen(),
  );
}
