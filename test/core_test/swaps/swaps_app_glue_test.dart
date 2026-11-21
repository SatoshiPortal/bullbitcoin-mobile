import 'package:rust_bindings/rust_bindings.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart' as wallet;
import 'package:swaps/swaps.dart' as swaps;
import 'package:bb_mobile/core/swaps/swaps_adapters.dart';
import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:preferences/preferences.dart' as settings;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _Wallets extends Mock implements WalletRepository {}

class _Wallet extends Mock implements wallet.Wallet {}

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
      'glue captures ${environment.name} for wallets and the default master key',
      () async {
        final wallets = _Wallets();
        final selected = settings.Environment.fromName(environment.name);
        when(() => wallets.getWallets(environment: selected))
            .thenAnswer((_) async => const Ok([]));
        when(
          () => wallets.getWallets(
            environment: selected,
            onlyDefaults: true,
            onlyBitcoin: true,
          ),
        ).thenAnswer((_) async => const Ok([]));
        FakeSecureStoragePlatform().install();
        final glue = SwapsAppGlue(
          walletRepository: wallets,
          secrets: Secrets(scratchDirectory: () async => '/unused'),
        );
        expect(await glue.wallets(environment: environment), isEmpty);
        expect(await glue.swapMasterKey(environment: environment), isNull);
        verify(() => wallets.getWallets(environment: selected)).called(1);
        verify(
          () => wallets.getWallets(
            environment: selected,
            onlyDefaults: true,
            onlyBitcoin: true,
          ),
        ).called(1);
      },
    );
  }
  test(
    'real glue derives and persists the captured concrete key network',
    () async {
      FakeSecureStoragePlatform().install();
      final secrets = Secrets(scratchDirectory: () async => '/unused');
      final created = await secrets.generate();
      final secret = switch (created) {
        Ok(:final value) => value,
        Err() => throw StateError('Ephemeral secret generation failed'),
      };
      final wallets = _Wallets();
      final defaultWallet = _Wallet();
      when(() => defaultWallet.masterFingerprint).thenReturn(secret.id.hex);
      final glue = SwapsAppGlue(walletRepository: wallets, secrets: secrets);
      final canonical = swaps.SwapStorage(
        rows: _Rows(),
        secrets: secrets.swapKeychain,
      );
      for (final environment in [
        NetworkEnv.mainnet,
        NetworkEnv.testnet,
        NetworkEnv.regtest,
      ]) {
        when(
          () => wallets.getWallets(
            environment: settings.Environment.fromName(environment.name),
            onlyDefaults: true,
            onlyBitcoin: true,
          ),
        ).thenAnswer((_) async => Ok([defaultWallet]));
        final derived = await glue.swapMasterKey(environment: environment);
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
