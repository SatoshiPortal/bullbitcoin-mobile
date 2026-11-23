import 'dart:io';

import 'package:ark/funding.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:spend/setup.dart';
import 'package:spend/spend.dart';
import 'package:spend/testing.dart';
import 'package:sync/sync.dart';
import 'package:sync/testing.dart';
import 'package:sync/write.dart';

import 'public_bitcoin_fixture.dart';

void main() {
  late Directory directory;
  late MemoryFreezeStore freezes;
  late _Connections connections;
  late _Reservations reservations;
  late WalletNativeRuntime runtime;
  late Spend spend;
  late String hex;
  late Outpoint input;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('spend-import-');
    freezes = MemoryFreezeStore();
    connections = _Connections();
    reservations = _Reservations();
    runtime = WalletNativeRuntime.open(
      catalog: const NoCatalog(),
      reserved: const NoReservedAddresses(),
      inputReservations: reservations,
      deleteCatalogEntry: (_) async => throw StateError('Unexpected deletion'),
      sync: ElectrumSync(
        connections: connections,
        documentsDirectory: () async => directory.path,
        readRevision: (_) async => throw StateError('Unexpected revision read'),
      ),
      documentsDirectory: () async => directory.path,
      freezes: freezes,
      connections: connections,
    );
    spend = Spend.open(
      sync: runtime,
      secrets: Secrets(scratchDirectory: () async => directory.path),
      arkFunding: const ArkFundingSigningGuard(authority: null),
      catalog: _NoSpendCatalog(),
    );
    final decoded = bitcoinPsbtSkeleton(publicBitcoinPsbt).fold(
      (value) => value,
      (failure) => throw StateError('Invalid public fixture: $failure'),
    );
    input = decoded.inputs.single;
    hex = decoded.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  });

  tearDown(() async {
    expect(await runtime.close(), isA<Ok>());
    await directory.delete(recursive: true);
  });

  test('global freezes refuse an imported input before connection', () async {
    expect(
      await freezes.freeze([FrozenOutpoint(input, origin: 'test')]),
      isA<Ok>(),
    );
    expect(
      await spend.broadcastImportedBitcoin(
        transaction: hex,
        network: BitcoinNetwork.regtest,
        isPsbt: false,
      ),
      _failure<SpendSelectedInputsUnavailableFailure>(),
    );
    expect(connections.networks, isEmpty);
  });

  test('ordinary selection refuses an input reserved by Payjoin', () async {
    reservations.entries.add(
      InputReservation(
        outpoint: input,
        protocol: 'payjoin',
        session: 'session',
        walletId: 'wallet',
        network: BitcoinNetwork.regtest,
        state: 'pending',
      ),
    );
    expect(
      await runtime.checkUnreservedInputs({input}),
      isA<Err<void, SyncFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<SyncProtectedInputsFailure>().having(
          (failure) => failure.reserved,
          'reserved',
          {input},
        ),
      ),
    );
    expect(connections.networks, isEmpty);
  });

  test(
    'import keeps the captured network and developer authorization',
    () async {
      expect(
        await spend.broadcastImportedBitcoin(
          transaction: hex,
          network: BitcoinNetwork.regtest,
          isPsbt: false,
        ),
        _failure<SpendDeveloperAuthorizationFailure>(),
      );
      expect(connections.networks, [BitcoinNetwork.regtest]);
    },
  );

  test('test spend values cannot reach production broadcast', () async {
    final result = await spend.broadcastBitcoin(
      SpendFixtures.signedBitcoin(hex),
    );
    expect(
      result,
      isA<Err<SpendBroadcastReceipt, SpendFailure>>().having(
        (error) => error.failure,
        'failure',
        isA<SpendInvalidRequestFailure>(),
      ),
    );
    expect(connections.networks, isEmpty);
  });

  test('an unsigned imported PSBT never opens a connection', () async {
    expect(
      await spend.broadcastImportedBitcoin(
        transaction: publicBitcoinPsbt,
        network: BitcoinNetwork.mainnet,
        isPsbt: true,
      ),
      _failure<SpendInvalidTransactionFailure>(),
    );
    expect(connections.networks, isEmpty);
  });

  test('an uncertain relay result stays unknown, not a rejection', () async {
    connections.failure = const SyncOutcomeUnknownFailure();
    expect(
      await spend.broadcastImportedBitcoin(
        transaction: hex,
        network: BitcoinNetwork.mainnet,
        isPsbt: false,
      ),
      _failure<SpendBroadcastOutcomeUnknownFailure>(),
    );
    expect(connections.networks, [BitcoinNetwork.mainnet]);
  });

  test(
    'a definitive connection failure stays distinct from uncertainty',
    () async {
      connections.failure = const SyncConnectionFailure();
      expect(
        await spend.broadcastImportedBitcoin(
          transaction: hex,
          network: BitcoinNetwork.mainnet,
          isPsbt: false,
        ),
        _failure<SpendBroadcastConnectionFailure>(),
      );
    },
  );

  test('reports a captured network rejected by connection admission', () async {
    connections.failure = const SyncUnauthorizedNetworkFailure();
    expect(
      await spend.broadcastImportedBitcoin(
        transaction: hex,
        network: BitcoinNetwork.testnet,
        isPsbt: false,
      ),
      _failure<SpendDeveloperAuthorizationFailure>(),
    );
    expect(connections.networks, [BitcoinNetwork.testnet]);
  });

  test('a test preparation cannot publish a Payjoin reservation', () async {
    final prepared = SpendFixtures.preparedBitcoin(
      unsignedPsbt: publicBitcoinPsbt,
      fee: Sats.fromInt(100),
    );
    final result = await spend.handOffToPayjoin(
      prepared,
      sessionId: 'session',
      signedPsbt: publicBitcoinPsbt,
      persist: () async => fail('An unbound preparation must not persist'),
    );
    expect(
      result,
      isA<Err<PayjoinSpendHandoff, SpendFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<SpendInvalidRequestFailure>(),
      ),
    );
  });
}

Matcher _failure<F extends SpendFailure>() => isA<Err<String, SpendFailure>>()
    .having((error) => error.failure, 'failure', isA<F>());

final class _NoSpendCatalog implements SpendCatalog {
  @override
  Future<Result<SpendWallet, SpendFailure>> resolve(String walletId) async =>
      throw StateError('An imported spend must never resolve a wallet');
}

final class _Reservations implements InputReservationPort {
  final entries = <InputReservation>[];

  @override
  Future<Result<List<InputReservation>, SyncFailure>> reservations() async =>
      Ok(List.unmodifiable(entries));
}

final class _Connections implements WalletConnectionPort {
  final networks = <Network>[];
  SyncFailure failure = const SyncUnauthorizedNetworkFailure();

  @override
  Future<Result<T, SyncFailure>> run<T>({
    required Network network,
    required Future<Result<T, SyncFailure>> Function(WalletConnection)
    operation,
    required bool Function(SyncFailure) mayRetry,
  }) async {
    networks.add(network);
    return Err(failure);
  }
}
