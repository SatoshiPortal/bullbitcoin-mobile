import 'dart:io';

import 'package:ark/ark.dart';
import 'package:ark/ark_setup.dart';
import 'package:bull_ark/src/data/ark_network_execution_policy.dart';
import 'package:bull_ark/ark_setup.dart' show createArkNativeClient;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import 'ark_operations_test.dart' show account;

class Authority implements ArkExecutionPolicyPort {
  final calls = <(ArkAccountId, ArkExecutionMode)>[];
  bool admitted = true;
  final protected = <ArkAccountId>{};
  @override
  bool mayRun(ArkAccountId account, ArkExecutionMode mode) {
    calls.add((account, mode));
    return admitted &&
        (mode == ArkExecutionMode.foreground || protected.contains(account));
  }
}

class NeverUsed implements ArkChildProviderPort, ArkTransactionVerifierPort {
  int calls = 0;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls++;
    throw StateError('Unexpected key or verifier admission');
  }
}

void main() {
  for (final mode in ArkExecutionMode.values) {
    test(
      'real public factory refuses mainnet before local or child admission in $mode',
      () async {
        final directory = Directory.systemTemp.createTempSync('ark-policy-');
        addTearDown(() => directory.deleteSync(recursive: true));
        final blocked = ArkAccountId(
          parent: account().parent,
          network: BitcoinNetwork.mainnet,
          serverIdentity: account().serverIdentity,
        );
        final authority = Authority()..protected.add(blocked);
        final ports = NeverUsed();
        final client = createArkNativeClient(
          storagePath: '${directory.path}/absent',
          childProvider: ports,
          transactionVerifier: ports,
          executionPolicy: authority,
          executionMode: mode,
          stageBudget: const ArkUnlimitedStageBudget(),
        );
        addTearDown(client.close);
        expect(
          await client.synchronize(blocked, renew: true),
          isA<Err<ArkPassOutcome, ArkWalletFailure>>().having(
            (r) => r.failure.reason,
            'policy refused before account-missing admission',
            ArkFailureReason.budgetExhausted,
          ),
        );
        expect(authority.calls, isEmpty);
        expect(ports.calls, 0);
        expect(Directory('${directory.path}/absent').existsSync(), false);
      },
    );
    test('canonical network refusal precedes authority in $mode', () {
      final authority = Authority()..protected.add(account());
      final policy = ArkNetworkExecutionPolicy(authority);
      for (final network in [
        BitcoinNetwork.mainnet,
        BitcoinNetwork.testnet,
        BitcoinNetwork.signet,
      ]) {
        final blocked = ArkAccountId(
          parent: account().parent,
          network: network,
          serverIdentity: account().serverIdentity,
        );
        expect(policy.mayRun(blocked, mode), false);
      }
      expect(authority.calls, isEmpty);
    });
    test(
      'regtest forwards exact identity and mode, preserves delegate refusal in $mode',
      () {
        final authority = Authority()..protected.add(account());
        final policy = ArkNetworkExecutionPolicy(authority);
        expect(policy.mayRun(account(), mode), true);
        authority.admitted = false;
        expect(policy.mayRun(account(), mode), false);
        expect(authority.calls, [(account(), mode), (account(), mode)]);
      },
    );
  }
  test('background protected account remains eligible while routing is off', () {
    final authority = Authority()..protected.add(account());
    final policy = ArkNetworkExecutionPolicy(authority);
    // No enabled preference enters this guard. The persisted authority owns it.
    expect(policy.mayRun(account(), ArkExecutionMode.backgroundExisting), true);
    authority.protected.clear();
    expect(
      policy.mayRun(account(), ArkExecutionMode.backgroundExisting),
      false,
    );
  });
  test('internal guard is absent from ordinary and setup barrels', () {
    final root = Directory('features/ark').existsSync() ? 'features/ark' : '.';
    for (final path in [
      '$root/lib/bull_ark.dart',
      '$root/lib/ark_ui.dart',
      '$root/lib/ark_setup.dart',
    ]) {
      expect(
        File(path).readAsStringSync(),
        isNot(contains("export 'src/data/ark_network_execution_policy.dart'")),
      );
    }
  });
}
