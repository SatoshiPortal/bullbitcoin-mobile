import 'package:rust_bindings/rust_bindings.dart';
import 'package:swaps/swaps.dart' as swaps;
import 'package:swaps/src/data/swap_integrations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _Rows extends Mock implements swaps.SwapRowStore {}

class _Electrum extends Mock implements swaps.ElectrumRunner {}

class _Lockup extends Mock implements swaps.LockupChain {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(BullSdk.init);
  for (final environment in [
    NetworkEnv.mainnet,
    NetworkEnv.testnet,
    NetworkEnv.regtest,
  ]) {
    test(
      'key source captures ${environment.name} for the default master key',
      () async {
        final selected = <NetworkEnv>[];
        FakeSecureStoragePlatform().install();
        final source = SwapKeySource(
          Secrets(
            authority: unlockedSessionAuthority(),
            scratchDirectory: () async => '/unused',
          ),
          (environment) async {
            selected.add(environment);
            return null;
          },
        );
        expect(await source.swapMasterKey(environment: environment), isNull);
        expect(selected, [environment]);
      },
    );
  }
  test('does not substitute a stored seed for a watch-only default', () async {
    FakeSecureStoragePlatform().install();
    final secrets = Secrets(
      authority: unlockedSessionAuthority(),
      scratchDirectory: () async => '/unused',
    );
    final created = await secrets.generate();
    final secret = switch (created) {
      Ok(:final value) => value,
      Err() => throw StateError('Ephemeral secret generation failed'),
    };
    final choice = Fingerprint(
      secret.id.hex == '00000000' ? 'ffffffff' : '00000000',
    );
    final source = SwapKeySource(secrets, (_) async => choice);
    expect(await source.swapMasterKey(environment: NetworkEnv.mainnet), isNull);
  });
  test(
    'key source derives and persists the captured concrete key network',
    () async {
      FakeSecureStoragePlatform().install();
      final secrets = Secrets(
        authority: unlockedSessionAuthority(),
        scratchDirectory: () async => '/unused',
      );
      final created = await secrets.generate();
      final secret = switch (created) {
        Ok(:final value) => value,
        Err() => throw StateError('Ephemeral secret generation failed'),
      };
      final source = SwapKeySource(secrets, (_) async => secret.id);
      final canonical = swaps.SwapStorage(
        rows: _Rows(),
        secrets: secrets.swapKeychain,
      );
      for (final environment in [
        NetworkEnv.mainnet,
        NetworkEnv.testnet,
        NetworkEnv.regtest,
      ]) {
        final derived = await source.swapMasterKey(environment: environment);
        if (derived == null) fail('Expected the ephemeral default wallet key');
        expect(derived.environment, environment);
        final electrum = _Electrum();
        final lockup = _Lockup();
        final repository = swaps.BoltzSwapRepository.connect(
          url: 'fixture.example',
          environment: environment,
          webSocketUrl: environment == NetworkEnv.regtest
              ? 'ws://fixture.example:9004'
              : null,
          storage: environment == NetworkEnv.regtest
              ? canonical.regtestView(rows: _Rows())
              : canonical,
          electrum: electrum,
          lockupChain: lockup,
          newAddressFor: (_) async => throw StateError('No address operation'),
          walletTx: (_, {required walletId}) async => null,
          walletTxs: (_, {bool sync = false}) async => const [],
          fastestFee: ({
            required txSize,
            required isLiquid,
            required environment,
          }) async => throw StateError('No fee operation'),
          wallets: ({required environment}) async => const [],
          swapMasterKeySource: ({required environment}) async =>
              throw StateError('Existing key must not be rederived'),
        );
        addTearDown(repository.close);
        await repository.storeSwapMasterKey(derived);
        final stored = await repository.getSwapMasterKeyInfo(
          walletFingerprint: derived.walletFingerprint,
        );
        expect(stored?.network, environment.name);
        expect(stored?.fingerprint, derived.fingerprint);
        verifyZeroInteractions(electrum);
        verifyZeroInteractions(lockup);
      }
    },
  );
}
