import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_definition.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:bb_mobile/features/wallet_backup/data/models/wallet_definitions_model.dart';
import 'package:bb_mobile/features/wallet_backup/data/wallet_definitions_backup.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_definitions_section.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const codec = WalletDefinitionsCodec();
  const key =
      '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798';
  late List<WalletDefinition> localDefinitions;
  late Map<String, WalletDefinitionRestoreResult> restoreResults;
  late List<WalletDefinition> restoreCalls;
  late WalletDefinitionsBackupImpl backup;

  final definition = WalletDefinition(
    walletRef: 'wallet-a',
    network: Network.bitcoinMainnet,
    receiveDescriptor: 'tr($key)',
    provenance: WalletProvenance.watchOnly,
  );

  setUp(() {
    localDefinitions = [];
    restoreResults = {};
    restoreCalls = [];
    backup = WalletDefinitionsBackupImpl(() async => localDefinitions, (
      definition,
    ) async {
      restoreCalls.add(definition);
      return restoreResults[definition.walletRef]!;
    }, () => const Stream.empty());
  });

  test('publishes the current local catalogue', () async {
    localDefinitions = [definition];

    final result = await backup.compose(remotePayload: null);

    expect(result, isA<Ok<String?, WalletBackupFailure>>());
    expect(
      (result as Ok<String?, WalletBackupFailure>).value,
      codec.encode([definition]),
    );
  });

  test(
    'carries remote definitions when the local catalogue is empty',
    () async {
      final remote = codec.encode([definition]);

      final result = await backup.compose(remotePayload: remote);

      expect((result as Ok<String?, WalletBackupFailure>).value, remote);
    },
  );

  test(
    'replaces remote definitions when the local catalogue is populated',
    () async {
      final remote = codec.encode([
        WalletDefinition(
          walletRef: 'remote',
          network: Network.bitcoinMainnet,
          receiveDescriptor: 'wpkh(02$key)',
          provenance: WalletProvenance.watchOnly,
        ),
      ]);
      localDefinitions = [definition];

      final result = await backup.compose(remotePayload: remote);

      expect(
        (result as Ok<String?, WalletBackupFailure>).value,
        codec.encode([definition]),
      );
    },
  );

  test('omits the section when both catalogues are empty', () async {
    final result = await backup.compose(remotePayload: null);

    expect((result as Ok<String?, WalletBackupFailure>).value, isNull);
  });

  test('validates the complete payload before restoring any wallet', () async {
    final malformed = codec
        .encode([definition])
        .replaceFirst('"version":1', '"version":2');

    final result = await backup.recover(payload: malformed);

    expect(
      result,
      isA<Err<WalletDefinitionsRecoveryResult, WalletBackupFailure>>(),
    );
    expect(restoreCalls, isEmpty);
  });

  test('reports created, existing, and conflicting definitions', () async {
    final existing = WalletDefinition(
      walletRef: 'wallet-b',
      network: Network.bitcoinMainnet,
      receiveDescriptor: 'wpkh(02$key)',
      provenance: WalletProvenance.watchOnly,
    );
    final conflicting = WalletDefinition(
      walletRef: 'wallet-c',
      network: Network.bitcoinMainnet,
      receiveDescriptor: 'pkh(02$key)',
      provenance: WalletProvenance.watchOnly,
    );
    restoreResults = {
      'wallet-a': const WalletDefinitionRestoreResult(
        walletRef: 'wallet-a',
        status: WalletDefinitionRestoreStatus.created,
      ),
      'wallet-b': const WalletDefinitionRestoreResult(
        walletRef: 'wallet-b',
        status: WalletDefinitionRestoreStatus.alreadyPresent,
      ),
      'wallet-c': const WalletDefinitionRestoreResult(
        walletRef: 'wallet-c',
        status: WalletDefinitionRestoreStatus.conflict,
      ),
    };

    final result = await backup.recover(
      payload: codec.encode([definition, existing, conflicting]),
    );
    final value =
        (result as Ok<WalletDefinitionsRecoveryResult, WalletBackupFailure>)
            .value;

    expect(value.restoredCount, 2);
    expect(value.failedCount, 1);
    expect(value.createdWalletRefs, ['wallet-a']);
  });
}
