import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest.dart';
import 'package:bb_mobile/features/keychain_manifest/presentation/nostr_keys_cubit.dart';
import 'package:bb_mobile/features/keychain_manifest/ui/screens/nostr_key_detail_screen.dart';
import 'package:bb_mobile/features/keychain_manifest/ui/screens/nostr_key_form_screen.dart';
import 'package:bb_mobile/features/keychain_manifest/ui/screens/nostr_keys_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

abstract final class KeychainManifestRoutes {
  static const listName = 'nostrKeys';
  static const createName = 'nostrKeyCreate';
  static const detailName = 'nostrKeyDetail';

  static final route = GoRoute(
    name: listName,
    path: 'nostr-keys',
    builder: (_, _) => BlocProvider(
      create: (_) => locator<NostrKeysCubit>(),
      child: const NostrKeysScreen(),
    ),
    routes: [
      GoRoute(
        name: createName,
        path: 'create',
        builder: (_, _) => BlocProvider(
          create: (_) => locator<NostrKeysCubit>(),
          child: const NostrKeyFormScreen(),
        ),
      ),
      GoRoute(
        name: detailName,
        path: 'detail',
        builder: (_, state) =>
            NostrKeyDetailScreen(entry: state.extra! as KeychainManifestEntry),
      ),
    ],
  );
}
