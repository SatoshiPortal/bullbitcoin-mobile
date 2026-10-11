import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/backup_identity_record.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/nostr_key_record.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/nostr_key_deriver.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/nostr_key_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/manage_backup_identities_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/manage_nostr_keys_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/presentation/nostr_keys_cubit.dart';
import 'package:bb_mobile/features/keychain_manifest/ui/screens/nostr_key_detail_screen.dart';
import 'package:bb_mobile/features/keychain_manifest/ui/screens/nostr_keys_screen.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../nostr_identity/fixtures/backup_credential_vectors.dart';

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
  late _Settings settings;
  late _Identities identities;
  setUp(() async {
    await locator.reset();
    defaults = _Defaults();
    settings = _Settings();
    identities = _Identities();
    final keys = _Keys();
    locator.registerFactory(
      () => NostrKeysCubit(
        getKeys: GetNostrKeysUsecase(keys),
        watchKeys: WatchNostrKeysUsecase(keys),
        createKey: CreateNostrKeyUsecase(defaults, settings, keys),
        getBackupIdentities: GetBackupIdentitiesUsecase(identities),
      ),
    );
  });
  tearDown(() async => locator.reset());
  Future<void> pump(
    WidgetTester tester, {
    Widget screen = const NostrKeysScreen(),
    double textScale = 1,
    Size size = const Size(390, 840),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => screen)],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
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
  for (final (system, size) in [
    (false, const Size(320, 568)),
    (true, const Size(568, 320)),
  ]) {
    testWidgets(
      'large text keeps ${system ? 'system' : 'user'} reveal warning and secret controls reachable',
      (tester) async {
        final seed = Seed.bytes(
          bytes: backupCredentialVectorSeed,
          masterFingerprint: 'aabbccdd',
        );
        final credential = BackupCredential.fromSeed(seed);
        final userKey = NostrKeyRecord(
          parentFingerprint: 'aabbccdd',
          identity: 1,
          publicKey: NostrKeyDeriver.publicKey(seed, 1),
          purpose: 'Personal identity',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        );
        final systemKey = BackupIdentityRecord(
          parentFingerprint: 'aabbccdd',
          publicKey: credential.artifactPublicKey,
          kind: BackupIdentityKind.artifact,
        );
        final nsec = system
            ? credential.revealArtifactNsec()
            : NostrKeyDeriver.reveal(seed, userKey);
        final privacyCalls = <String>[];
        const channel = MethodChannel('com.flutterplaza.no_screenshot_methods');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              privacyCalls.add(call.method);
              return true;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null),
        );
        when(() => settings.execute()).thenAnswer(
          (_) async => const SettingsEntity(
            environment: Environment.mainnet,
            bitcoinUnit: BitcoinUnit.sats,
            currencyCode: 'CAD',
          ),
        );
        when(
          () => defaults.execute(environment: Environment.mainnet),
        ).thenAnswer((_) async {
          expect(privacyCalls.last, 'screenshotOff');
          return Ok(seed);
        });
        when(() => identities.resolve()).thenAnswer((_) async {
          expect(privacyCalls.last, 'screenshotOff');
          return Ok(credential);
        });
        locator.registerSingleton<RevealNostrKeyUsecase>(
          RevealNostrKeyUsecase(defaults, settings),
        );
        locator.registerSingleton<RevealBackupIdentityUsecase>(
          RevealBackupIdentityUsecase(identities),
        );
        await pump(
          tester,
          screen: system
              ? NostrKeyDetailScreen.system(systemKey)
              : NostrKeyDetailScreen.user(userKey),
          textScale: 3.2,
          size: size,
        );
        final show = find.text('Show nsec');
        await tester.scrollUntilVisible(
          show,
          250,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        await tester.tap(show);
        await tester.pumpAndSettle();
        verifyZeroInteractions(defaults);
        verifyZeroInteractions(identities);
        expect(find.text(nsec), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('I understand'));
        await tester.tap(find.text('I understand'));
        await tester.pumpAndSettle();
        expect(
          find.byWidgetPredicate(
            (widget) => widget is CopyInput && widget.text == nsec,
          ),
          findsOneWidget,
        );
        expect(
          find.ancestor(
            of: find.text(nsec),
            matching: find.byType(ExcludeSemantics),
          ),
          findsWidgets,
        );
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Close'));
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(find.text(nsec), findsNothing);
        expect(privacyCalls.last, 'screenshotOn');
      },
    );
  }
}
