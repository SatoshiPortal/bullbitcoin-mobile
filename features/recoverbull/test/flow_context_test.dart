import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/src/data/secrets_vault_repository.dart';
import 'package:bull_recoverbull/src/domain/usecases/create_vault_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/start_vault_flow_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/test_vault_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
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
      final wallets = _Wallets(initial);
      final captured = await StartVaultFlowUsecase(
        wallets,
        _Environment(),
      ).execute(RecoverBullFlow.testVault);
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
