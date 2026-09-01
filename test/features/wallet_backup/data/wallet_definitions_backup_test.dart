import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_definition.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:bb_mobile/features/wallet_backup/data/wallet_definitions_backup.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_definitions_section.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const descriptor =
      'wpkh([86241f88/84h/0h/0h]xpub6DJwRncrB8eNrzUq8XxgjwCZsEeWP8FeqBJbJQZ8JfuDwLdAzyjhHiHJieNuar1wjQTyihhMWtaKGE4DUd8uBgtyrNJqF5drwbNVUqb83b7/<0;1>/*)#n8txaeah';
  late List<WalletDefinition> localDefinitions;
  late Map<String, WalletDefinitionRestoreResult> restoreResults;
  late List<WalletDefinition> restoreCalls;
  late WalletDefinitionsBackupImpl backup;

  final definition = WalletDefinition(
    walletRef: 'wallet-a',
    network: Network.bitcoinMainnet,
    descriptor: descriptor,
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

    final result = await backup.read();

    expect(_value(result), [definition]);
  });

  test(
    'a Liquid wallet does not affect the remote definitions section',
    () async {
      localDefinitions = [
        definition,
        WalletDefinition(
          walletRef: 'liquid-wallet',
          network: Network.liquidMainnet,
          descriptor: 'ct(liquid)',
          provenance: WalletProvenance.watchOnly,
        ),
      ];

      final result = await backup.read();

      expect(_value(result), [definition]);
    },
  );

  test('omits the section when the local catalogue is empty', () async {
    final result = await backup.read();

    expect(_value(result), isEmpty);
  });

  test('reports created, existing, and conflicting definitions', () async {
    final existing = WalletDefinition(
      walletRef: 'wallet-b',
      network: Network.bitcoinMainnet,
      descriptor: descriptor
          .replaceFirst('86241f88', '76241f88')
          .split('#')
          .first,
      provenance: WalletProvenance.watchOnly,
    );
    final conflicting = WalletDefinition(
      walletRef: 'wallet-c',
      network: Network.bitcoinMainnet,
      descriptor: descriptor
          .replaceFirst('86241f88', '66241f88')
          .split('#')
          .first,
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
      definitions: [definition, existing, conflicting],
    );
    final value =
        (result as Ok<WalletDefinitionsRecoveryResult, WalletBackupFailure>)
            .value;

    expect(restoreCalls, hasLength(3));
    expect(value.restoredCount, 2);
    expect(value.failedCount, 1);
    expect(value.createdWalletRefs, ['wallet-a']);
  });
}

List<WalletDefinition> _value(
  Result<List<WalletDefinition>, WalletBackupFailure> result,
) => (result as Ok<List<WalletDefinition>, WalletBackupFailure>).value;
