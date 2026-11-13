import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/src/data/secrets_vault_repository.dart';
import 'package:bull_recoverbull/src/domain/usecases/create_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/start_vault_flow_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/test_vault_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bull_recoverbull/src/public/recoverbull_feature.dart';
import 'package:secrets/secrets.dart' as custody;
import 'package:secrets/testing.dart';

void main() {
  test(
    'selection and fetch delays cannot change the wallet certified by a flow',
    () async {
      FakeSecureStoragePlatform().install();
      final secrets = custody.Secrets(scratchDirectory: () async => '.');
      expect(
        await secrets.import(words: '${'abandon ' * 11}about'.split(' ')),
        isA<Ok>(),
      );
      final vaults = SecretsVaultRepository(secrets);
      final initial = VaultContext(
        fingerprint: Fingerprint('73c5da0a'),
        network: BitcoinNetwork.testnet,
      );
      final wallets = _Wallets(
        VaultContext(
          fingerprint: Fingerprint('00000001'),
          network: BitcoinNetwork.mainnet,
        ),
      );
      final captured = await StartVaultFlowUsecase(
        wallets,
        _Environment(),
      ).execute(RecoverBullFlow.testVault, backupContext: initial);
      expect(wallets.reads, 0);
      final scoped = CapturedRecoverBullWalletPort(wallets, captured);
      final backup = await CreateVaultUsecase(vaults, scoped).execute();
      final vault = (backup as Ok<VaultBackup, RecoverBullFailure>).value;
      // A settings/default change while a file or a key is being retrieved.
      wallets.context = VaultContext(
        fingerprint: Fingerprint('00000001'),
        network: BitcoinNetwork.mainnet,
      );
      final tested = await TestVaultUsecase(
        vaults,
        scoped,
      ).execute(vault: vault.vault, key: vault.key);
      expect(tested, isA<Ok<VaultContext, RecoverBullFailure>>());
      expect(
        (tested as Ok<VaultContext, RecoverBullFailure>).value.matches(initial),
        isTrue,
      );
    },
  );

  testWidgets('selected-seed setup returns only after backup testing', (
    tester,
  ) async {
    final selected = VaultContext(
      fingerprint: Fingerprint('73c5da0a'),
      network: BitcoinNetwork.testnet,
    );
    final feature = RecoverBullFeature.create(
      secrets: custody.Secrets(scratchDirectory: () async => '.'),
      wallets: _Wallets(null),
    );
    final vault = EncryptedVault(
      id: '11' * 32,
      salt: '22' * 16,
      ciphertext: List.filled(64, 0),
      createdAt: DateTime.utc(2026),
    );
    bool? result;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await feature.openSetup(
                  context,
                  backupContext: selected,
                );
              },
              child: const Text('Set up'),
            ),
          ),
        ),
        GoRoute(
          path: '/backup',
          name: 'recoverbullFlows',
          builder: (context, state) {
            final request = state.extra as RecoverBullFlowRequest;
            expect(request.backupContext?.matches(selected), isTrue);
            expect(request.returnCompletion, isTrue);
            final testing = request.flow == RecoverBullFlow.testVault;
            if (testing) expect(request.vault, isNull);
            return Scaffold(
              body: TextButton(
                onPressed: () => context.pop(
                  VaultCompletion(
                    vault: vault,
                    verifiedContext: testing ? selected : null,
                  ),
                ),
                child: Text(testing ? 'Test backup' : 'Save backup'),
              ),
            );
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Set up'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save backup'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(find.text('Test backup'), findsOneWidget);
    await tester.tap(find.text('Test backup'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  test(
    'restoration captures the environment without querying a missing wallet',
    () async {
      final wallets = _Wallets(null);
      final captured = await StartVaultFlowUsecase(
        wallets,
        _Environment(),
      ).execute(RecoverBullFlow.recoverVault);
      expect(wallets.reads, 0);
      expect(
        (captured.network as Ok<BitcoinNetwork, RecoverBullFailure>).value,
        BitcoinNetwork.testnet,
      );
    },
  );

  test('a failed environment read remains a failure, never mainnet', () async {
    final captured = await StartVaultFlowUsecase(
      _Wallets(null),
      _Environment(fail: true),
    ).execute(RecoverBullFlow.recoverVault);
    expect(captured.network, isA<Err<BitcoinNetwork, RecoverBullFailure>>());
  });
}

final class _Wallets implements RecoverBullWalletPort {
  VaultContext? context;
  int reads = 0;
  _Wallets(this.context);
  @override
  Future<Result<VaultContext?, RecoverBullFailure>> currentDefault() async {
    reads++;
    return Ok(context);
  }

  @override
  Future<Result<VaultContext, RecoverBullFailure>> restoreDefaults(
    VaultContext requested,
  ) async => Ok(requested);
}

final class _Environment implements RecoverBullEnvironmentPort {
  final bool fail;
  _Environment({this.fail = false});
  @override
  Future<Result<BitcoinNetwork, RecoverBullFailure>> currentNetwork() async =>
      fail
      ? const Err(VaultStorageFailure())
      : const Ok(BitcoinNetwork.testnet);
}
