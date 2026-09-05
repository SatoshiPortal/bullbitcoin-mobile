import 'dart:async';

import 'package:bull_recoverbull/src/domain/entities/encrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/entities/decrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/entities/vault_provider.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart' as core;
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/presentation/bloc.dart';
import 'package:bull_recoverbull/src/router/flow_type.dart';
import 'package:primitives/primitives.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/recoverbull_bloc_harness.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(MockEncryptedVault());
    registerFallbackValue(const DecryptedVault());
  });
  setUp(setUpRecoverBullBloc);
  tearDown(tearDownRecoverBullBloc);

  group('OnVaultPasswordSet guard', () {
    test('no vault set -> VaultNotSetFailure, password not stored, key never '
        'fetched', () async {
      // recoverVault hits the default branch; no preSelectedVault => null.
      final bloc = buildBloc(flow: RecoverBullFlow.recoverVault);

      bloc.add(const OnVaultPasswordSet(password: 'pw'));
      await pumpEventQueue();

      expect(bloc.state.failure, isA<VaultNotSetFailure>());
      // The guard must return before storing the password or fetching the
      // key — proving the early `return` is effective (the pre-fix code fell
      // through to `state.vault!`).
      expect(bloc.state.vaultPassword, isNull);
      verifyNever(
        () => fetchKey.execute(
          vault: any(named: 'vault'),
          password: any(named: 'password'),
        ),
      );

      await bloc.close();
    });

    test('drops concurrent password fetches', () async {
      final pending = Completer<Result<String, core.RecoverBullFailure>>();
      final vault = MockEncryptedVault();
      when(
        () => fetchKey.execute(
          vault: vault,
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) => pending.future);
      when(
        () => decrypt.execute(vault: vault, vaultKey: 'key'),
      ).thenReturn(const Err(core.RecoverBullUnexpectedFailure()));
      final bloc = buildBloc(
        flow: RecoverBullFlow.recoverVault,
        preSelectedVault: vault,
      );

      bloc.add(const OnVaultPasswordSet(password: 'one'));
      await pumpEventQueue();
      bloc.add(const OnVaultPasswordSet(password: 'two'));
      await pumpEventQueue();
      verify(() => fetchKey.execute(vault: vault, password: 'one')).called(1);
      verifyNever(() => fetchKey.execute(vault: vault, password: 'two'));

      pending.complete(const Ok('key'));
      await pumpEventQueue();
      await bloc.close();
    });
  });

  group('OnVaultProviderSelection (secureVault) guard', () {
    test(
      'no password set -> PasswordNotSetFailure, creation never started',
      () async {
        final bloc = buildBloc(flow: RecoverBullFlow.secureVault);

        bloc.add(
          const OnVaultProviderSelection(
            provider: VaultProvider.customLocation,
          ),
        );
        await pumpEventQueue();

        // The pre-fix code fell through to `state.vaultPassword!`, which threw and
        // surfaced as a generic RecoverBullUnexpectedFailure. The guard must keep
        // the intended typed failure and never reach vault creation.
        expect(bloc.state.failure, isA<PasswordNotSetFailure>());
        verifyNever(() => createVault.execute());

        await bloc.close();
      },
    );

    test(
      'rejects a password submitted after server storage and never retries storage',
      () async {
        final vault = MockEncryptedVault();
        when(() => vault.id).thenReturn('00');
        when(() => vault.toFile()).thenReturn('{}');
        when(() => vault.filename).thenReturn('vault.json');
        when(
          () => createVault.execute(),
        ).thenAnswer((_) async => Ok((vault: vault, vaultKey: 'key')));
        when(
          () => storeKey.execute(password: 'pw', vault: vault, vaultKey: 'key'),
        ).thenAnswer((_) async => const Ok(null));
        when(
          () => saveFile.execute(
            content: any(named: 'content'),
            filename: any(named: 'filename'),
          ),
        ).thenAnswer(
          (_) async => const Err(core.RecoverBullUnexpectedFailure()),
        );

        final bloc = buildBloc(flow: RecoverBullFlow.secureVault);
        bloc.add(const OnVaultPasswordSet(password: 'pw'));
        await pumpEventQueue();
        bloc.add(
          const OnVaultProviderSelection(
            provider: VaultProvider.customLocation,
          ),
        );
        await pumpEventQueue();
        expect(bloc.hasPendingProviderSave, isTrue);

        bloc.add(const OnVaultPasswordSet(password: 'changed-password'));
        await pumpEventQueue();

        expect(bloc.state.failure, isA<VaultProviderSaveFailure>());
        verify(
          () => storeKey.execute(password: 'pw', vault: vault, vaultKey: 'key'),
        ).called(1);
        verify(() => createVault.execute()).called(1);
        verifyNever(
          () => storeKey.execute(
            password: 'changed-password',
            vault: any(named: 'vault'),
            vaultKey: any(named: 'vaultKey'),
          ),
        );
        await bloc.close();
      },
    );
  });

  group('OnVaultCreation store-key failure mapping', () {
    test('server failure never calls the provider', () async {
      final vault = MockEncryptedVault();
      when(
        () => createVault.execute(),
      ).thenAnswer((_) async => Ok((vault: vault, vaultKey: 'key')));
      when(
        () => checkConnection.execute(),
      ).thenAnswer((_) async => const Ok(true));
      when(
        () => storeKey.execute(password: 'pw', vault: vault, vaultKey: 'key'),
      ).thenAnswer((_) async => const Err(core.KeyServerUnavailableFailure()));

      final bloc = buildBloc(flow: RecoverBullFlow.secureVault);
      bloc.add(
        const OnVaultCreation(
          provider: VaultProvider.customLocation,
          password: 'pw',
        ),
      );
      await pumpEventQueue();

      expect(bloc.state.failure, isA<KeyServerConnectionFailure>());
      verifyNever(
        () => saveFile.execute(
          content: any(named: 'content'),
          filename: any(named: 'filename'),
        ),
      );
      await bloc.close();
    });

    test(
      'provider failure can be retried without storing the key again',
      () async {
        final vault = MockEncryptedVault();
        when(() => vault.id).thenReturn('00');
        when(() => vault.toFile()).thenReturn('{}');
        when(() => vault.filename).thenReturn('vault.json');
        when(
          () => createVault.execute(),
        ).thenAnswer((_) async => Ok((vault: vault, vaultKey: 'key')));
        when(
          () => saveFile.execute(
            content: any(named: 'content'),
            filename: any(named: 'filename'),
          ),
        ).thenAnswer(
          (_) async => const Err(core.KeyServerUnavailableFailure()),
        );
        when(
          () => storeKey.execute(password: 'pw', vault: vault, vaultKey: 'key'),
        ).thenAnswer((_) async => const Ok(null));
        final bloc = buildBloc(flow: RecoverBullFlow.secureVault);

        bloc.add(
          const OnVaultCreation(
            provider: VaultProvider.customLocation,
            password: 'pw',
          ),
        );
        await pumpEventQueue();
        expect(bloc.state.failure, isA<VaultProviderSaveFailure>());
        expect(bloc.state.vault, isNull);
        expect(await attemptMonitoringStore.monitoredBackups(), isEmpty);

        when(
          () => saveFile.execute(
            content: any(named: 'content'),
            filename: any(named: 'filename'),
          ),
        ).thenAnswer((_) async => const Ok(null));
        bloc.add(
          const OnVaultProviderSelection(
            provider: VaultProvider.customLocation,
          ),
        );
        await pumpEventQueue();

        verify(() => createVault.execute()).called(1);
        verify(
          () => storeKey.execute(password: 'pw', vault: vault, vaultKey: 'key'),
        ).called(1);
        verify(
          () => saveFile.execute(
            content: any(named: 'content'),
            filename: any(named: 'filename'),
          ),
        ).called(2);
        expect(bloc.state.vault, same(vault));
        expect(bloc.state.failure, isNull);
        expect(bloc.state.vaultPassword, isNull);
        expect(await attemptMonitoringStore.monitoredBackups(), hasLength(1));
        await bloc.close();
      },
    );

    test(
      'busy storeVaultKey -> VaultServiceBusyFailure (cooldown kept)',
      () async {
        const cooldown = Duration(minutes: 5);
        final vault = MockEncryptedVault();
        when(() => vault.id).thenReturn('00');
        when(() => vault.toFile()).thenReturn('{}');
        when(() => vault.filename).thenReturn('vault.json');

        when(
          () => createVault.execute(),
        ).thenAnswer((_) async => Ok((vault: vault, vaultKey: 'deadbeef')));
        when(
          () => checkConnection.execute(),
        ).thenAnswer((_) async => const Ok(true));
        when(
          () => saveFile.execute(
            content: any(named: 'content'),
            filename: any(named: 'filename'),
          ),
        ).thenAnswer((_) async => const Ok(null));
        when(
          () => storeKey.execute(
            password: any(named: 'password'),
            vault: any(named: 'vault'),
            vaultKey: any(named: 'vaultKey'),
          ),
        ).thenAnswer(
          (_) async => Err(const core.KeyServerBusyFailure(retryIn: cooldown)),
        );

        final bloc = buildBloc(flow: RecoverBullFlow.secureVault);

        // secureVault stores the password, then provider selection triggers
        // creation.
        bloc.add(const OnVaultPasswordSet(password: 'pw'));
        await pumpEventQueue();
        bloc.add(
          const OnVaultProviderSelection(
            provider: VaultProvider.customLocation,
          ),
        );
        await pumpEventQueue();

        // The 503 cooldown must survive the create path instead of collapsing
        // into the generic VaultCreationFailure.
        expect(bloc.state.failure, isA<VaultServiceBusyFailure>());
        expect(
          (bloc.state.failure as VaultServiceBusyFailure).retryIn,
          cooldown,
        );
        verifyNever(() => lifecycle.markStored());

        await bloc.close();
      },
    );

    test(
      'marks the backup stored after provider and key store succeed',
      () async {
        final vault = MockEncryptedVault();
        when(() => vault.id).thenReturn('00');
        when(() => vault.toFile()).thenReturn('{}');
        when(() => vault.filename).thenReturn('vault.json');
        when(
          () => createVault.execute(),
        ).thenAnswer((_) async => Ok((vault: vault, vaultKey: 'key')));
        when(
          () => saveFile.execute(
            content: any(named: 'content'),
            filename: any(named: 'filename'),
          ),
        ).thenAnswer((_) async => const Ok(null));
        when(
          () => storeKey.execute(password: 'pw', vault: vault, vaultKey: 'key'),
        ).thenAnswer((_) async => const Ok(null));
        final bloc = buildBloc(flow: RecoverBullFlow.secureVault);

        bloc.add(const OnVaultPasswordSet(password: 'pw'));
        await pumpEventQueue();
        bloc.add(
          const OnVaultProviderSelection(
            provider: VaultProvider.customLocation,
          ),
        );
        await pumpEventQueue();

        expect(bloc.state.failure, isNull);
        verify(() => lifecycle.markStored()).called(1);
        expect(await attemptMonitoringStore.monitoredBackups(), hasLength(1));
        expect(bloc.state.vaultPassword, isNull);
        await bloc.close();
      },
    );

    test('rejects unsupported iCloud before storing the remote key', () async {
      final vault = MockEncryptedVault();
      when(
        () => createVault.execute(),
      ).thenAnswer((_) async => Ok((vault: vault, vaultKey: 'key')));
      when(
        () => storeKey.execute(password: 'pw', vault: vault, vaultKey: 'key'),
      ).thenAnswer((_) async => const Ok(null));
      final bloc = buildBloc(flow: RecoverBullFlow.secureVault);

      bloc.add(
        const OnVaultCreation(provider: VaultProvider.iCloud, password: 'pw'),
      );
      await pumpEventQueue();

      expect(bloc.state.failure, isA<SelectVaultFailure>());
      verifyNever(
        () => storeKey.execute(
          password: any(named: 'password'),
          vault: any(named: 'vault'),
          vaultKey: any(named: 'vaultKey'),
        ),
      );
      verifyNever(() => lifecycle.markStored());
      await bloc.close();
    });

    test(
      'drops concurrent provider selections while creation is in flight',
      () async {
        final creation =
            Completer<
              Result<
                ({EncryptedVault vault, String vaultKey}),
                core.RecoverBullFailure
              >
            >();
        final vault = MockEncryptedVault();
        when(() => vault.id).thenReturn('00');
        when(() => vault.toFile()).thenReturn('{}');
        when(() => vault.filename).thenReturn('vault.json');
        when(() => createVault.execute()).thenAnswer((_) => creation.future);
        when(
          () => saveFile.execute(
            content: any(named: 'content'),
            filename: any(named: 'filename'),
          ),
        ).thenAnswer((_) async => const Ok(null));
        when(
          () => storeKey.execute(password: 'pw', vault: vault, vaultKey: 'key'),
        ).thenAnswer((_) async => const Ok(null));
        final bloc = buildBloc(flow: RecoverBullFlow.secureVault);

        bloc.add(const OnVaultPasswordSet(password: 'pw'));
        await pumpEventQueue();
        bloc.add(
          const OnVaultProviderSelection(
            provider: VaultProvider.customLocation,
          ),
        );
        bloc.add(
          const OnVaultProviderSelection(
            provider: VaultProvider.customLocation,
          ),
        );
        await pumpEventQueue();
        verify(() => createVault.execute()).called(1);

        creation.complete(Ok((vault: vault, vaultKey: 'key')));
        await pumpEventQueue();
        verify(
          () => storeKey.execute(password: 'pw', vault: vault, vaultKey: 'key'),
        ).called(1);
        verify(
          () => saveFile.execute(
            content: any(named: 'content'),
            filename: any(named: 'filename'),
          ),
        ).called(1);
        await bloc.close();
      },
    );

    test('closing during creation prevents external side effects', () async {
      final creation =
          Completer<
            Result<
              ({EncryptedVault vault, String vaultKey}),
              core.RecoverBullFailure
            >
          >();
      final vault = MockEncryptedVault();
      when(() => createVault.execute()).thenAnswer((_) => creation.future);
      final bloc = buildBloc(flow: RecoverBullFlow.secureVault);

      bloc.add(
        const OnVaultCreation(
          provider: VaultProvider.customLocation,
          password: 'pw',
        ),
      );
      await pumpEventQueue();
      final closing = bloc.close();
      creation.complete(Ok((vault: vault, vaultKey: 'key')));
      await closing;

      verifyNever(
        () => storeKey.execute(
          password: any(named: 'password'),
          vault: any(named: 'vault'),
          vaultKey: any(named: 'vaultKey'),
        ),
      );
      verifyNever(
        () => saveFile.execute(
          content: any(named: 'content'),
          filename: any(named: 'filename'),
        ),
      );
    });
  });
  test(
    'maps external failure while storing without announcing creation',
    () async {
      final vault = MockEncryptedVault();
      when(
        () => createVault.execute(),
      ).thenAnswer((_) async => Ok((vault: vault, vaultKey: 'key')));
      when(
        () => connectDrive.execute(),
      ).thenAnswer((_) async => const Ok(null));
      when(
        () => saveDrive.execute(vault),
      ).thenAnswer((_) async => const Ok(null));
      when(
        () => storeKey.execute(password: 'pw', vault: vault, vaultKey: 'key'),
      ).thenAnswer(
        (_) async => const Err(core.ExternalTorProxyUnavailableFailure()),
      );
      final bloc = buildBloc(flow: RecoverBullFlow.secureVault);
      addTearDown(bloc.close);

      bloc.add(
        const OnVaultCreation(
          provider: VaultProvider.googleDrive,
          password: 'pw',
        ),
      );
      await pumpEventQueue();

      expect(bloc.state.failure, isA<ExternalTorProxyUnavailableFailure>());
      expect(bloc.state.vault, isNull);
      verify(
        () => storeKey.execute(password: 'pw', vault: vault, vaultKey: 'key'),
      ).called(1);
    },
  );
}
