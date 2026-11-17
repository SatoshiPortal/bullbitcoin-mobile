import 'package:bull_sdk/bull_sdk.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart' as wallet;
import 'package:swaps/src/data/models/swap_master_key_model.dart';
import 'package:bb_mobile/core/swaps/swaps_adapters.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart'
    as settings;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _Wallets extends Mock implements WalletRepository {}

class _Wallet extends Mock implements wallet.Wallet {}

void main() {
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
    'real glue derives and rehydrates the captured concrete key network',
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
        final rehydrated = SwapMasterKeyModel.fromJson(
          SwapMasterKeyModel.fromDerived(derived).toJson(),
        ).toBoltz();
        expect(rehydrated.network.name, environment.name);
      }
    },
  );
}
