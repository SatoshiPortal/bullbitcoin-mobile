import 'dart:io';

import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:bb_mobile/features/keychain_manifest/data/nostr_key_repository_impl.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/nostr_key_record.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/manage_backup_identities_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/manage_nostr_keys_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/presentation/nostr_keys_cubit.dart';
import 'package:bb_mobile/features/keychain_manifest/ui/screens/nostr_keys_screen.dart';
import 'package:bb_mobile/features/nostr_identity/domain/backup_credential_resolver.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/features/wallet_backup/data/drift_wallet_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_state.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:go_router/go_router.dart';

import '../../test/features/nostr_identity/fixtures/backup_credential_vectors.dart';
import '../../test/features/keychain_manifest/ui/nostr_keys_screen_test.dart'
    as screens;

class _Defaults extends Mock implements GetDefaultSeedUsecase {}

class _Settings extends Mock implements GetSettingsUsecase {}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Nostr create/reveal and backup state survive Android database reopen',
    (tester) async {
      await locator.reset();
      final directory = await Directory.systemTemp.createTemp(
        'bull-narrow-keys-',
      );
      final file = File('${directory.path}/keys.sqlite');
      var database = SqliteDatabase(NativeDatabase(file));
      addTearDown(() async {
        await database.close();
        await locator.reset();
        await directory.delete(recursive: true);
      });
      final defaults = _Defaults();
      final settings = _Settings();
      when(() => settings.execute()).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'CAD',
        ),
      );
      when(() => defaults.execute(environment: Environment.mainnet)).thenAnswer(
        (_) async => Seed.bytes(
          bytes: backupCredentialVectorSeed,
          masterFingerprint: 'aabbccdd',
        ),
      );
      final identities = NostrIdentityFacade(
        BackupCredentialResolver(
          getDefaultSeed: defaults,
          getSettings: settings,
        ),
      );
      final keys = NostrKeyRepositoryImpl(database);
      locator.registerFactory(
        () => NostrKeysCubit(
          getKeys: GetNostrKeysUsecase(keys),
          watchKeys: WatchNostrKeysUsecase(keys),
          createKey: CreateNostrKeyUsecase(defaults, settings, keys),
          getBackupIdentities: GetBackupIdentitiesUsecase(identities),
        ),
      );
      locator.registerFactory(() => RevealNostrKeyUsecase(defaults, settings));
      locator.registerFactory(() => RevealBackupIdentityUsecase(identities));
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const NostrKeysScreen()),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('create-nostr-key')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('nostr-key-name')),
        'Device fixture',
      );
      await tester.enterText(
        find.byKey(const ValueKey('nostr-key-description')),
        'Public record',
      );
      await tester.tap(find.byKey(const ValueKey('save-nostr-key')));
      await tester.pumpAndSettle();
      expect(find.text('Device fixture'), findsOneWidget);
      await tester.tap(find.text('Device fixture'));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) => widget is CopyInput && widget.text.startsWith('npub1'),
        ),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('Show nsec'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Show nsec'));
      await tester.pumpAndSettle();
      expect(find.text('Show your nsec'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is CopyInput && widget.text.startsWith('nsec1'),
        ),
        findsNothing,
      );
      await tester.tap(find.text('I understand'));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (widget) => widget is CopyInput && widget.text.startsWith('nsec1'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      final state = DriftWalletBackupStateRepository(database);
      expect(await state.setEnabled(true), isA<Ok>());
      expect(
        await state.recordPublication(
          identity: '1' * 64,
          expectedEtag: null,
          checkpoint: WalletBackupCheckpoint(
            generation: 4,
            etag: '2' * 64,
            ciphertextHash: '3' * 64,
          ),
          contentHash: '4' * 64,
          succeededAt: DateTime.utc(2026, 9, 18),
        ),
        isA<Ok>(),
      );
      expect(await state.setRecoveryIncomplete(true), isA<Ok>());
      await database.close();
      database = SqliteDatabase(NativeDatabase(file));
      final recovered =
          (await NostrKeyRepositoryImpl(database).getAll()
                  as Ok<List<NostrKeyRecord>, KeychainManifestFailure>)
              .value;
      expect(recovered.single.purpose, 'Device fixture');
      final restored =
          (await DriftWalletBackupStateRepository(database).get('1' * 64)
                  as Ok<WalletBackupState, WalletBackupFailure>)
              .value;
      expect(restored.enabled, isTrue);
      expect(restored.checkpoint?.generation, 4);
      expect(restored.confirmedContentHash, '4' * 64);
      expect(restored.recoveryIncomplete, isTrue);
    },
  );
  group('Nostr warning and form controls', screens.main);
}
