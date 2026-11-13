import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/src/data/secrets_vault_repository.dart';
import 'package:bull_recoverbull/src/public/recoverbull_runtime.dart';
import 'package:bull_tor/tor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/secrets.dart' as custody;
import 'package:secrets/testing.dart';
import 'package:primitives/primitives.dart' show DatabaseKey;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FilePicker.platform = _Picker();
  test(
    'corrupt metadata blocks the server but preserves manual recovery',
    () async {
      final directory = await Directory.systemTemp.createTemp('rb-manual-');
      final file = File('${directory.path}/recoverbull.sqlite');
      await file.writeAsString('damaged local metadata');
      final original = await file.readAsBytes();
      final secure = FakeSecureStoragePlatform().install();
      final secrets = custody.Secrets(
        scratchDirectory: () async => directory.path,
      );
      expect(
        await secrets.import(words: '${'abandon ' * 11}about'.split(' ')),
        isA<Ok>(),
      );
      final context = VaultContext(
        fingerprint: Fingerprint('73c5da0a'),
        network: BitcoinNetwork.testnet,
      );
      final backup =
          (await SecretsVaultRepository(secrets).create(context)
                  as Ok<VaultBackup, RecoverBullFailure>)
              .value;
      secure.entries.clear();
      final routes = _Routes();
      final owners = _Owners();
      final runtime = await RecoverBullRuntime.open(
        databasePath: file.path,
        databaseKey: DatabaseKey.fromHex('42' * 32),
        secrets: secrets,
        wallets: owners,
        environment: owners,
        legacy: owners,
        routes: routes,
        clients: const TorHttpClientFactory(),
      );
      addTearDown(() async {
        await runtime.dispose();
        await directory.delete(recursive: true);
      });
      final flow = await runtime.flow(
        RecoverBullFlow.recoverVault,
        vault: backup.vault,
      );
      addTearDown(flow.close);
      await flow.cubit.settings();
      expect(flow.cubit.state.failure, isA<RecoverBullStorageDamagedFailure>());
      await flow.cubit.verify('test password', BitcoinNetwork.testnet);
      expect(flow.cubit.state.failure, isA<RecoverBullStorageDamagedFailure>());
      expect(routes.opens, 0);
      await flow.cubit.manual(backup.key, BitcoinNetwork.testnet);
      expect(flow.cubit.state.completion?.recovery, isA<VaultRecovered>());
      expect(
        flow.cubit.state.completion?.warning,
        isA<RecoverBullStorageDamagedFailure>(),
      );
      expect(await secrets.fetch(context.fingerprint), isA<Ok>());
      expect(owners.restored?.matches(context), isTrue);
      expect(routes.opens, 0);
      expect(await file.readAsBytes(), original);
    },
  );
}

final class _Routes implements RecoverBullRoutePort {
  int opens = 0;
  @override
  Future<Result<RecoverBullRoute, RecoverBullFailure>> open({
    bool restartEmbedded = false,
  }) async {
    opens++;
    return const Err(RecoverBullUnexpectedFailure());
  }
}

final class _Owners
    implements
        RecoverBullWalletPort,
        RecoverBullEnvironmentPort,
        RecoverBullLegacySettingsPort {
  VaultContext? restored;
  @override
  Future<Result<VaultContext?, RecoverBullFailure>> currentDefault() async =>
      const Ok(null);
  @override
  Future<Result<VaultContext, RecoverBullFailure>> restoreDefaults(
    VaultContext requested,
  ) async {
    restored = requested;
    return Ok(requested);
  }

  @override
  Future<Result<BitcoinNetwork, RecoverBullFailure>> currentNetwork() async =>
      const Ok(BitcoinNetwork.testnet);
  @override
  Future<Result<LegacyBackupSettings, RecoverBullFailure>> read() async =>
      const Err(RecoverBullUnexpectedFailure());
}

final class _Picker extends FilePicker {}
