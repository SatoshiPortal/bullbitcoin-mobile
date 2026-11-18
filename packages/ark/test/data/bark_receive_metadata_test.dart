import 'dart:convert';

import 'package:ark/ark.dart';
import 'package:ark/src/data/ark_codec.dart';
import 'package:ark/src/data/ark_native_session.dart';
import 'package:ark/src/data/bark_native_opener.dart';
import 'package:bark_bitcoin/bark_bitcoin.dart' as bark;
import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

final _htlcId = '${'b' * 64}:1';
final _outputId = '${'c' * 64}:0';

final class _Wallet implements bark.Wallet {
  final String status, metadata, identity;
  _Wallet(this.status, this.metadata, this.identity);
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      switch (invocation.memberName) {
        #dispose => null,
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
            id: _htlcId,
            amountSats: 10000,
            expiryHeight: 1100,
            kind: 'pubkey',
            state: bark.SpentVtxoState(),
            exitDepth: 0,
            exitTxWeightWu: 0,
            registered: true,
          ),
        ]),
        #history => Future.value([
          bark.Movement(
            id: 1,
            status: status,
            subsystemName: 'bark.lightning_receive',
            subsystemKind: 'receive',
            metadataJson: metadata,
            intendedBalanceSats: 0,
            effectiveBalanceSats: 0,
            offchainFeeSats: 0,
            sentToAddresses: [],
            receivedOnAddresses: [],
            inputVtxoIds: [],
            outputVtxoIds: status == 'successful' ? [_outputId] : [],
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
        #fingerprint => identity,
        _ => throw StateError('Unexpected native method'),
      };
}

final class _Onchain implements bark.OnchainWallet {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      switch (invocation.memberName) {
        #dispose => null,
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

final class _Boundary implements BarkOpenBoundary {
  final _Wallet wallet;
  final _Onchain onchain;
  _Boundary(this.wallet, this.onchain);
  @override
  bark.DatadirInfo? inspect(String datadir) => bark.DatadirInfo(
    dbFile: '$datadir/db.sqlite',
    network: bark.Network.regtest,
    fingerprint: wallet.identity,
  );
  @override
  bool hasData(String datadir) => true;
  @override
  Future<bark.OnchainWallet> openOnchain({
    required bark.Network network,
    required String mnemonic,
    required bark.Config config,
    required String datadir,
  }) async => onchain;
  @override
  Future<bark.Wallet> openWallet({
    required bark.Network network,
    required String mnemonicOrSeed,
    required bark.Config config,
    required bark.WalletOpenArgs args,
  }) async => wallet;
}

void main() {
  // Public BIP39 zero-entropy vector, never a retained wallet or secret source.
  final words = Mnemonic(List<int>.filled(16, 0), Language.english).sentence;
  const identity = '53bdf6b1';
  final account = ArkAccountId(
    parent: Fingerprint('12345678'),
    network: BitcoinNetwork.regtest,
    serverIdentity: 'server',
  );
  final config = ArkAccountConfig(
    id: account,
    arkUrl: Uri.parse('http://localhost:1'),
    primaryEsploraUrl: Uri.parse('http://localhost:2'),
  );
  Map<String, Object?> metadata() => {
    'payment_hash': 'a' * 64,
    'htlc_vtxos': [_htlcId],
    'payment_preimage': '0' * 64,
  };
  Future<ArkSnapshot> observe(String status, String encoded) async {
    final wallet = _Wallet(status, encoded, identity);
    final session =
        await BarkNativeOpener(boundary: _Boundary(wallet, _Onchain())).open(
          config: config,
          datadir: 'scripted-fixture',
          mnemonic: words,
          childFingerprint: Fingerprint(identity),
          chainSource: config.primaryEsploraUrl,
          create: false,
          expectedFingerprint: identity,
          nativePreviouslyAdmitted: true,
          onNativeAdmission: () {},
          stages: _Stages(),
          onOnchainOpened: () {},
          onOpened: (_, _) {},
        );
    try {
      return await session.observe(
        account: account,
        revision: 1,
        now: DateTime.utc(2026, 11, 18),
        chainSource: config.primaryEsploraUrl,
        operations: [],
        previousRecovery: ArkRecoveryStatus.complete,
      );
    } finally {
      session.close();
    }
  }

  for (final status in ['successful', 'canceled']) {
    test(
      'real opener maps $status receive HTLC metadata without native consumed inputs',
      () async {
        final snapshot = await observe(status, jsonEncode(metadata()));
        final movement = snapshot.movements.single;
        expect(movement.inputVtxoIds, [_htlcId]);
        expect(
          terminalMovementRetires(movement, _htlcId, snapshot.vtxos),
          true,
        );
        expect(
          () => movement.inputVtxoIds.add('mutate'),
          throwsUnsupportedError,
        );
      },
    );
  }
  for (final invalid in [
    'missing',
    'duplicate',
    'bad-id',
    'bad-hash',
    'extra',
    'malformed',
  ]) {
    test(
      'unsupported $invalid receive metadata never proves retirement',
      () async {
        final data = metadata();
        switch (invalid) {
          case 'missing':
            data.remove('htlc_vtxos');
          case 'duplicate':
            data['htlc_vtxos'] = [_htlcId, _htlcId];
          case 'bad-id':
            data['htlc_vtxos'] = ['bad'];
          case 'bad-hash':
            data['payment_hash'] = 1;
          case 'extra':
            data['unknown'] = true;
        }
        final snapshot = await observe(
          'canceled',
          invalid == 'malformed' ? '{' : jsonEncode(data),
        );
        expect(snapshot.movements.single.inputVtxoIds, isEmpty);
        expect(
          terminalMovementRetires(
            snapshot.movements.single,
            _htlcId,
            snapshot.vtxos,
          ),
          false,
        );
      },
    );
  }
}
