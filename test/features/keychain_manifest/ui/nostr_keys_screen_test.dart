import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/nostr_key_record.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/nostr_key_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/manage_nostr_keys_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/manage_backup_identities_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/presentation/nostr_keys_cubit.dart';
import 'package:bb_mobile/features/keychain_manifest/ui/screens/nostr_keys_screen.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Defaults extends Mock implements GetDefaultSeedUsecase {}

class _Settings extends Mock implements GetSettingsUsecase {}

class _Identities extends Mock implements NostrIdentityFacade {}

class _Keys extends Fake implements NostrKeyRepository {
  @override
  Stream<void> get changes => const Stream.empty();
  @override
  Future<Result<List<NostrKeyRecord>, KeychainManifestFailure>>
  getAll() async => const Ok([]);
}

void main() {
  late _Defaults defaults;
  late _Identities identities;
  setUp(() async {
    await locator.reset();
    defaults = _Defaults();
    identities = _Identities();
    final keys = _Keys();
    locator.registerFactory(
      () => NostrKeysCubit(
        getKeys: GetNostrKeysUsecase(keys),
        watchKeys: WatchNostrKeysUsecase(keys),
        createKey: CreateNostrKeyUsecase(defaults, _Settings(), keys),
        getBackupIdentities: GetBackupIdentitiesUsecase(identities),
      ),
    );
  });
  tearDown(() async => locator.reset());
  Future<void> pump(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 840));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const NostrKeysScreen(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'opening the list and cancelling the system warning never read a seed',
    (tester) async {
      await pump(tester);
      expect(find.text('No Nostr keys have been created yet.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('show-system-keys')));
      await tester.pumpAndSettle();
      expect(find.text('System keys'), findsOneWidget);
      verifyZeroInteractions(identities);
      verifyZeroInteractions(defaults);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      verifyZeroInteractions(identities);
      expect(find.text('System keys'), findsNothing);
    },
  );
  testWidgets('empty names stay on the form without deriving a key', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('create-nostr-key')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-nostr-key')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a name for this key.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    verifyZeroInteractions(defaults);
  });
}
