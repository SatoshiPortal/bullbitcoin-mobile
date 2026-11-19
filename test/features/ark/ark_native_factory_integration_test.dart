// Exercise the real public feature factory without provisioning a native wallet.
import 'dart:io';

import 'package:ark/ark.dart';
import 'package:ark/ark_setup.dart' as native;
import 'package:bull_ark/ark_setup.dart' as host;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

final class _PermissiveAuthority implements native.ArkExecutionPolicyPort {
  final List<(ArkAccountId, native.ArkExecutionMode)> calls = [];

  @override
  bool mayRun(ArkAccountId account, native.ArkExecutionMode mode) {
    calls.add((account, mode));
    return true;
  }
}

final class _TrueBudget implements native.ArkStageBudget {
  int calls = 0;

  @override
  bool get mayAdmitNextStage {
    calls++;
    return true;
  }
}

final class _ChildSpy implements native.ArkChildProviderPort {
  int calls = 0;

  @override
  Future<Result<T, ArkWalletFailure>> withChild<T>(
    ArkAccountId account,
    Future<Result<T, ArkWalletFailure>> Function(String, Fingerprint) action,
  ) async {
    calls++;
    // Never derive or fabricate words if a regression reaches this capability.
    return const Err(ArkUnavailableFailure());
  }
}

final class _VerifierSpy implements ArkTransactionVerifierPort {
  int calls = 0;

  @override
  Future<Result<ArkTransactionFacts, ArkWalletFailure>> inspectTransaction({
    required String transactionHex,
    required String signedPsbt,
    required BitcoinNetwork network,
  }) async {
    calls++;
    return const Err(ArkValidationFailure());
  }

  @override
  Future<Result<ArkBoardPsbtFacts, ArkWalletFailure>> inspectBoardPsbt({
    required String unfinalisedPsbt,
    required BitcoinNetwork network,
  }) async {
    calls++;
    return const Err(ArkValidationFailure());
  }
}

void _expectPolicyRefusal<T>(Result<T, ArkWalletFailure> result) {
  expect(
    result,
    isA<Err<T, ArkWalletFailure>>().having(
      (value) => value.failure.reason,
      'effectful admission refusal',
      ArkFailureReason.budgetExhausted,
    ),
  );
}

Future<void> _probe(
  BitcoinNetwork network,
  native.ArkExecutionMode mode, {
  required bool delegationControl,
}) async {
  final directory = await Directory.systemTemp.createTemp(
    'ark-factory-policy-',
  );
  final sentinel = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  var connections = 0;
  final listener = sentinel.listen((socket) {
    connections++;
    socket.destroy();
  });
  var createdEntries = 0;
  // The first storage directory creation must be visible in this parent.
  final fileEvents = directory.watch(events: FileSystemEvent.create).listen((
    _,
  ) {
    createdEntries++;
  });
  final authority = _PermissiveAuthority();
  final budget = _TrueBudget();
  final child = _ChildSpy();
  final verifier = _VerifierSpy();
  final storage = '${directory.path}/must-stay-absent';
  ArkClient? client;
  try {
    final endpoint = Uri.parse('https://127.0.0.1:${sentinel.port}');
    final account = ArkAccountId(
      parent: Fingerprint('12345678'),
      network: network,
      serverIdentity: endpoint.toString(),
    );
    final config = ArkAccountConfig(
      id: account,
      arkUrl: endpoint,
      primaryEsploraUrl: endpoint,
    );
    final factoryClient = host.createArkNativeClient(
      storagePath: storage,
      childProvider: child,
      transactionVerifier: verifier,
      executionPolicy: authority,
      executionMode: mode,
      stageBudget: budget,
    );
    client = factoryClient;
    expect(FileSystemEntity.typeSync(storage), FileSystemEntityType.notFound);
    if (delegationControl) {
      // Intentionally absent storage: prove regtest reached beyond policy,
      // without allowing a native open, provisioning or network operation.
      final result = await factoryClient.synchronize(account, renew: false);
      expect(
        result,
        isA<Err<ArkPassOutcome, ArkWalletFailure>>().having(
          (value) => value.failure.reason,
          'permissive regtest proceeds to missing storage',
          ArkFailureReason.accountMissing,
        ),
      );
      expect(authority.calls, [(account, mode)]);
    } else {
      _expectPolicyRefusal(await factoryClient.create(config));
      _expectPolicyRefusal(
        await factoryClient.synchronize(account, renew: false),
      );
      expect(authority.calls, isEmpty);
    }
    expect(budget.calls, greaterThan(0));
    await factoryClient.close();
    client = null;
    await Future<void>.delayed(Duration.zero);
    expect(child.calls, 0);
    expect(verifier.calls, 0);
    // Zero accepted TCP connections is stronger than zero HTTP requests and
    // covers the HTTPS-only mainnet config without external/TLS fixtures.
    expect(connections, 0);
    expect(createdEntries, 0);
    expect(FileSystemEntity.typeSync(storage), FileSystemEntityType.notFound);
    expect(
      await directory.list(recursive: true, followLinks: false).toList(),
      isEmpty,
    );
  } finally {
    try {
      await client?.close();
    } finally {
      await fileEvents.cancel();
      await listener.cancel();
      await sentinel.close();
      await directory.delete(recursive: true);
    }
  }
}

void main() {
  for (final mode in native.ArkExecutionMode.values) {
    for (final network in [
      BitcoinNetwork.mainnet,
      BitcoinNetwork.testnet,
      BitcoinNetwork.signet,
    ]) {
      test(
        'real host factory refuses ${network.name} in ${mode.name} before side effects',
        () async {
          await _probe(network, mode, delegationControl: false);
        },
      );
    }
    test(
      'real host factory delegates regtest admission in ${mode.name}',
      () async {
        await _probe(BitcoinNetwork.regtest, mode, delegationControl: true);
      },
    );
  }
}
