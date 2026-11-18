import 'dart:io';
import 'dart:convert';

import 'package:ark/ark.dart';
import 'package:ark/ark_setup.dart';
import 'package:ark/src/data/ark_native_session.dart';
import 'package:ark/src/data/bark_ark_client.dart';
import 'package:ark/src/data/bark_native_opener.dart';
import 'package:bark_bitcoin/bark_bitcoin.dart' as bark;
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

import '../support/fake_native.dart';

final class _Wallet implements bark.Wallet {
  final String status, subsystem;
  final bark.VtxoState state;
  _Wallet(this.status, this.subsystem, this.state);
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      switch (invocation.memberName) {
        #balance => Future.value(
          bark.Balance(
            spendableSats: 10000,
            needsRefreshSats: 0,
            pendingInRoundSats: 0,
            pendingExitSats: 0,
            pendingLightningSendSats: 0,
            claimableLightningReceiveSats: 0,
            pendingBoardSats: 0,
            pendingArkoorSendSats: 0,
            pendingOffboardSats: 0,
          ),
        ),
        #allVtxos => Future.value([
          bark.Vtxo(
            id: FakeOpener.firstId,
            amountSats: 10000,
            expiryHeight: 1100,
            kind: 'pubkey',
            state: state,
            exitDepth: 0,
            exitTxWeightWu: 0,
            registered: true,
          ),
        ]),
        #history => Future.value([
          bark.Movement(
            id: 1,
            status: status,
            subsystemName: subsystem,
            subsystemKind: 'lightning',
            metadataJson: subsystem == 'bark.lightning_receive'
                ? jsonEncode({
                    'payment_hash': 'a' * 64,
                    'htlc_vtxos': [FakeOpener.firstId],
                    'payment_preimage': '0' * 64,
                  })
                : '{}',
            intendedBalanceSats: 0,
            effectiveBalanceSats: 0,
            offchainFeeSats: 0,
            sentToAddresses: [],
            receivedOnAddresses: [],
            inputVtxoIds: subsystem == 'bark.lightning_receive'
                ? []
                : [FakeOpener.firstId],
            outputVtxoIds: [],
            exitedVtxoIds: [],
            createdAt: '2026-11-18T00:00:00Z',
            updatedAt: '2026-11-18T00:00:00Z',
          ),
        ]),
        #pendingRoundInputVtxos ||
        #pendingRoundStates ||
        #pendingBoards ||
        #pendingLightningReceives ||
        #pendingLightningSends ||
        #getExitVtxos => Future.value(const <Never>[]),
        #arkInfo => Future<bark.ArkInfo?>.value(null),
        #recoveryStatus => bark.NotRunRecoveryStatus(),
        _ => throw StateError('Unexpected native method'),
      };
}

final class _Onchain implements bark.OnchainWallet {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      switch (invocation.memberName) {
        #balance => Future.value(
          bark.OnchainBalance(
            confirmedSats: 5000,
            pendingSats: 0,
            totalSats: 5000,
          ),
        ),
        #tipHeight => Future.value(100),
        _ => throw StateError('Unexpected onchain method'),
      };
}

final class _Stages implements ArkStageRunner {
  @override
  Future<T> run<T>(String name, Future<T> Function() action) => action();
}

void main() {
  final account = ArkAccountId(
    parent: Fingerprint('12345678'),
    network: BitcoinNetwork.regtest,
    serverIdentity: 'server',
  );
  final config = ArkAccountConfig(
    id: account,
    arkUrl: Uri.parse('http://localhost:3535'),
    primaryEsploraUrl: Uri.parse('http://localhost:3000'),
  );
  T ok<T>(Result<T, ArkWalletFailure> value) => switch (value) {
    Ok(:final value) => value,
    Err() => throw StateError('Expected success'),
  };
  for (final scenario in [
    ('failed', 'bark.lightning_send', true),
    ('canceled', 'bark.lightning_receive', true),
    ('successful', 'bark.lightning_receive', true),
    ('pending', 'bark.lightning_send', false),
    ('unsupported', 'bark.lightning_send', false),
  ]) {
    test(
      'real adapter terminal inventory ${scenario.$1}/${scenario.$2}',
      () async {
        final temp = Directory.systemTemp.createTempSync('ark-terminal-');
        final native = FakeOpener();
        BarkArkClient build() => BarkArkClient(
          storagePath: temp.path,
          childProvider: FakeChild(),
          transactionVerifier: FakeVerifier(),
          executionPolicy: FakePolicy(),
          executionMode: ArkExecutionMode.foreground,
          stageBudget: FakeBudget(),
          opener: native,
          preflight: FakePreflight(),
          clock: () => DateTime.utc(2026, 11, 18),
        );
        var client = build();
        try {
          ok(await client.create(config));
          final adapter = BarkNativeSession(
            _Wallet(scenario.$1, scenario.$2, bark.SpentVtxoState()),
            _Onchain(),
            _Stages(),
            config,
          );
          final mapped = await adapter.observe(
            account: account,
            revision: 1,
            now: DateTime.utc(2026, 11, 18),
            chainSource: config.primaryEsploraUrl,
            operations: [],
            previousRecovery: ArkRecoveryStatus.complete,
          );
          // Preserve the unrelated live id: only the movement input disappears.
          native.inventoryOverride = [
            ...mapped.vtxos,
            ArkVtxo(
              id: FakeOpener.secondId,
              amount: Sats.fromInt(10000),
              expiryHeight: 1100,
              state: ArkVtxoState.spendable,
            ),
          ];
          native.movementEvidence = mapped.movements;
          final result = ok(await client.synchronize(account, renew: false));
          expect(result.snapshot.stale, !scenario.$3);
          expect(
            result.snapshot.vtxos.any(
              (v) =>
                  v.id == FakeOpener.firstId && v.state == ArkVtxoState.unknown,
            ),
            !scenario.$3,
          );
          await client.close();
          client = build();
          expect(ok(await client.read(account)).stale, !scenario.$3);
        } finally {
          await client.close();
          temp.deleteSync(recursive: true);
        }
      },
    );
  }
}
