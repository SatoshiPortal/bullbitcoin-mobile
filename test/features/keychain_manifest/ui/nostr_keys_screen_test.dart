import 'package:secrets/secrets.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/get_nostr_secret_usecase.dart';
import '../../nostr_identity/fixtures/backup_secret_fixture.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:primitives/primitives.dart' show Ok, Result;
import 'package:bb_mobile/features/keychain_manifest/domain/entities/backup_identity_record.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/nostr_key_record.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_failure.dart';
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

class _Identities extends Mock implements NostrIdentityFacade {}

class _Keys extends Fake implements NostrKeyRepository {
  @override
  Stream<void> get changes => const Stream.empty();
  @override
  Future<Result<List<NostrKeyRecord>, KeychainManifestFailure>>
  getAll() async => const Ok([]);
}

void main() {
  late _Identities identities;
  setUp(() async {
    await locator.reset();
    identities = _Identities();
    final keys = _Keys();
    locator.registerFactory(
      () => NostrKeysCubit(
        getKeys: GetNostrKeysUsecase(keys),
        watchKeys: WatchNostrKeysUsecase(keys),
        createKey: CreateNostrKeyUsecase(identities, keys),
        getBackupIdentities: GetBackupIdentitiesUsecase(identities),
      ),
    );
  });
  tearDown(() async => locator.reset());
  Future<void> pump(
    WidgetTester tester, {
    Widget screen = const NostrKeysScreen(),
    double textScale = 1,
    AppThemeType themeType = AppThemeType.light,
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
        theme: AppTheme.themeData(themeType),
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
    verifyZeroInteractions(identities);
  });
  for (final (system, size) in [
    (false, const Size(320, 568)),
    (true, const Size(568, 320)),
  ]) {
    testWidgets(
      'large text keeps ${system ? 'system' : 'user'} reveal warning and secret controls reachable',
      (tester) async {
        late Secret secret;
        late BackupCredential credential;
        late String publicKey;
        await tester.runAsync(() async {
          secret = await backupSecretFixture();
          credential =
              (await secret.backup.data()
                      as Ok<BackupCredential, SecretFailure>)
                  .value;
          publicKey =
              (await secret.derive.nostrPublicKey(identity: 1)
                      as Ok<String, SecretFailure>)
                  .value;
        });
        final userKey = NostrKeyRecord(
          parentFingerprint: secret.id.hex,
          identity: 1,
          publicKey: publicKey,
          purpose: 'Personal identity',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        );
        final systemKey = BackupIdentityRecord(
          parentFingerprint: secret.id.hex,
          publicKey: credential.artifactPublicKey,
          kind: BackupIdentityKind.artifact,
        );
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
        when(() => identities.defaultSecret()).thenAnswer((_) async {
          expect(privacyCalls.last, 'screenshotOff');
          return Ok(secret);
        });
        locator.registerSingleton<GetNostrSecretUsecase>(
          GetNostrSecretUsecase(identities),
        );
        await pump(
          tester,
          screen: system
              ? NostrKeyDetailScreen.system(systemKey)
              : NostrKeyDetailScreen.user(userKey),
          textScale: 3.2,
          themeType: system ? AppThemeType.dark : AppThemeType.light,
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
        verifyZeroInteractions(identities);
        expect(find.byType(NostrKeyView), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('I understand'));
        await tester.tap(find.text('I understand'));
        await tester.pump();
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 500)),
        );
        await tester.pumpAndSettle();
        expect(find.byType(NostrKeyView), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(NostrKeyView),
            matching: find.byTooltip('Copy'),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Close'));
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(find.byType(NostrKeyView), findsNothing);
        expect(privacyCalls.last, 'screenshotOn');
      },
    );
  }
  testWidgets('privacy refusal never reads the stored key', (tester) async {
    const channel = MethodChannel('com.flutterplaza.no_screenshot_methods');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (_) async => false,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    locator.registerSingleton<GetNostrSecretUsecase>(
      GetNostrSecretUsecase(identities),
    );
    final record = NostrKeyRecord(
      parentFingerprint: 'aabbccdd',
      identity: 1,
      publicKey: '11' * 32,
      purpose: 'Identity',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    await pump(tester, screen: NostrKeyDetailScreen.user(record));
    await tester.tap(find.text('Show nsec'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I understand'));
    await tester.pumpAndSettle();
    verifyZeroInteractions(identities);
    expect(find.byType(NostrKeyView), findsNothing);
  });
}
