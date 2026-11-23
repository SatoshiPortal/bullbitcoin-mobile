import 'package:all_seed_view/testing.dart';

import 'dart:async';
import 'dart:io';

import '../../support/inventory_fixture.dart';

import 'package:access/access.dart';
import 'package:access/setup.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:swaps/swaps.dart';

class _MockGetAllSecretsUsecase extends Mock implements GetAllSecretsUsecase {}

class _MockGetWalletsUsecase extends Mock implements GetWalletsUsecase {}

class _MockDeleteSecretUsecase extends Mock implements DeleteSecretUsecase {}

class _MockGetSwapMasterKeyUsecase extends Mock
    implements GetSwapMasterKeyUsecase {}

class _MockDeleteSwapMasterKeyUsecase extends Mock
    implements DeleteSwapMasterKeyUsecase {}

/// The re-authentication gate: nothing about the user's secrets is fetched before the PIN is confirmed on this screen.
///
/// The state holds `Secret` handles now rather than the words themselves, so the gate protects a listing rather than the material — but it still protects the only screen that enumerates a user's secrets, and the reproducer is unchanged.
void main() {
  const words = [
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'about',
  ];

  late _MockGetAllSecretsUsecase getAllSecretsUsecase;
  late _MockGetWalletsUsecase getWalletsUsecase;
  late _MockGetSwapMasterKeyUsecase getSwapMasterKeyUsecase;
  late AllSeedViewCubit cubit;
  late Secret aSecret;
  late GetIt accessServices;
  late Directory inventoryDirectory;
  late InventoryFixture inventoryFixture;

  Future<AppUnlockGrant> authenticate(WidgetTester tester) async {
    AppUnlockGrant? grant;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Access().buildReauthenticationGate(
          onSuccess: (value) => grant = value,
        ),
      ),
    );
    await pumpUntilInventoryReady(tester, () => grant != null);
    return grant ?? (throw StateError('Unlock did not issue a grant'));
  }

  late _MockDeleteSwapMasterKeyUsecase deleteSwapMasterKeyUsecase;

  setUp(() async {
    FakeSecureStoragePlatform().install();
    inventoryDirectory = await Directory.systemTemp.createTemp('seed-access-');
    inventoryFixture = await InventoryFixture.open(inventoryDirectory);
    final secrets = Secrets(scratchDirectory: () async => '/tmp');
    accessServices = GetIt.asNewInstance()..registerSingleton(secrets);
    AccessFeature.mount(
      services: accessServices,
      inventory: inventoryFixture.inventory,
      backupVerification: inventoryFixture.backup,
      hasVerifiedBackup: () async => false,
      onUnlocked: (_) {},
      onBackUp: (_) async {},
    );
    final stored = await secrets.import(
      words: words,
      language: Language.english,
    );
    aSecret = (stored as Ok<Secret, SecretFailure>).value;

    getAllSecretsUsecase = _MockGetAllSecretsUsecase();
    getWalletsUsecase = _MockGetWalletsUsecase();
    getSwapMasterKeyUsecase = _MockGetSwapMasterKeyUsecase();
    when(() => getAllSecretsUsecase.execute())
        .thenAnswer((_) async => Ok([aSecret]));
    when(() => getWalletsUsecase.execute())
        .thenAnswer((_) async => const Ok(<String>{}));
    when(() => getSwapMasterKeyUsecase.execute())
        .thenAnswer((_) async => const Ok(null));

    cubit = AllSeedViewCubit(
      getAllSecretsUsecase: getAllSecretsUsecase,
      getWalletsUsecase: getWalletsUsecase,
      deleteSecretUsecase: _MockDeleteSecretUsecase(),
      // Pure and total: the real one, so the split this screen shows is the one the code computes.
      separateSecretsUsecase: const SeparateSecretsUsecase(),
      getSwapMasterKeyUsecase: getSwapMasterKeyUsecase,
      deleteSwapMasterKeyUsecase: deleteSwapMasterKeyUsecase =
          _MockDeleteSwapMasterKeyUsecase(),
    );
  });

  tearDown(() async {
    await cubit.close();
    await accessServices.reset();
    await inventoryFixture.close();
    await inventoryDirectory.delete(recursive: true);
  });

  group('AllSeedViewCubit — re-authentication gate (audit)', () {
    testWidgets(
      'an all-unreadable keystore reaches state as a count, not as empty',
      (tester) async {
        // The fss9 cohort in the seed viewer: zero readable secrets, N entries
        // the package could not parse. The screen shows the count in the
        // empty branch; this holds the state it reads.
        when(() => getAllSecretsUsecase.execute()).thenAnswer(
          (_) async => const Ok([
            UnreadableSecret(failure: FetchSecretFailure()),
            UnreadableSecret(failure: FetchSecretFailure()),
          ]),
        );
        await cubit.unlock(await authenticate(tester));

        expect(cubit.state.allSeeds, isEmpty);
        expect(cubit.state.unreadableEntries, 2);
        expect(cubit.state.failure, isNull);
      },
    );

    testWidgets('readable and unreadable entries remain visible together', (
      tester,
    ) async {
      when(() => getAllSecretsUsecase.execute()).thenAnswer(
        (_) async => Ok([
          aSecret,
          const UnreadableSecret(failure: FetchSecretFailure()),
        ]),
      );

      await cubit.unlock(await authenticate(tester));

      expect(cubit.state.allSeeds, [aSecret]);
      expect(cubit.state.unreadableEntries, 1);
      expect(cubit.state.failure, isNull);
    });

    test(
      'audit reproducer: secrets are never listed before re-authentication',
      () async {
        await cubit.fetchAllSeeds();

        verifyNever(() => getAllSecretsUsecase.execute());
        expect(cubit.state.allSeeds, isEmpty);
        expect(cubit.state.isUnlocked, isFalse);
      },
    );

    testWidgets('unlock() marks the state unlocked and lists the secrets', (
      tester,
    ) async {
      await cubit.unlock(await authenticate(tester));

      expect(cubit.state.isUnlocked, isTrue);
      verify(() => getAllSecretsUsecase.execute()).called(1);
      expect(cubit.state.allSeeds, [aSecret]);
    });

    testWidgets('unlock() is idempotent', (tester) async {
      final grant = await authenticate(tester);

      await cubit.unlock(grant);
      await cubit.unlock(grant);

      verify(() => getAllSecretsUsecase.execute()).called(1);
    });

    testWidgets('a matching wallet keeps the secret in the existing section', (
      tester,
    ) async {
      when(() => getWalletsUsecase.execute())
          .thenAnswer((_) async => Ok({aSecret.id.hex}));

      await cubit.unlock(await authenticate(tester));

      expect(cubit.state.existingWallets, [aSecret]);
      expect(cubit.state.oldWallets, isEmpty);
    });

    testWidgets('a secret no wallet uses is listed as old, not hidden', (
      tester,
    ) async {
      // The old usecase deduplicated by comparing raw words; this one does not, so nothing a user stored can vanish from the only screen that lists it.
      await cubit.unlock(await authenticate(tester));

      expect(cubit.state.oldWallets, [aSecret]);
      expect(cubit.state.existingWallets, isEmpty);
    });
  });

  test(
    'a completed swap deletion does not emit after the viewer closes',
    () async {
      const key = SwapMasterKeyInfo(
        fingerprint: 'key',
        walletFingerprint: 'wallet',
        network: 'mainnet',
      );
      final completion = Completer<Result<void, AllSeedViewFailure>>();
      when(() => deleteSwapMasterKeyUsecase.execute(key))
          .thenAnswer((_) => completion.future);
      final deletion = cubit.deleteSwapMnemonic(key);
      await cubit.close();
      completion.complete(const Ok(null));
      await deletion;
      expect(cubit.isClosed, isTrue);
    },
  );

  test('a swap key the keychain failed to delete is reported', () async {
    const key = SwapMasterKeyInfo(
      fingerprint: 'key',
      walletFingerprint: 'wallet',
      network: 'mainnet',
    );
    when(() => deleteSwapMasterKeyUsecase.execute(key))
        .thenAnswer((_) async => const Err(AllSeedViewDeleteFailure()));

    await cubit.deleteSwapMnemonic(key);

    expect(cubit.state.failure, isA<AllSeedViewDeleteFailure>());
  });
}
