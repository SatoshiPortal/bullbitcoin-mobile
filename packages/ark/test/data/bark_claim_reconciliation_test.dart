import 'package:ark/ark.dart';
import 'package:ark/src/data/ark_native_session.dart';
import 'package:ark/src/data/bark_native_opener.dart' as adapter;
import 'package:bark_bitcoin/bark_bitcoin.dart' as bark;
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

/// Exercise the actual adapter method with Dart implementations of the native
/// handles through the package-private-src session constructor.
/// No FFI function, native opener or network request is invoked by these tests.
ArkNativeSession session(
  List<bark.ExitVtxo> exits, {
  List<bark.Movement> movements = const [],
  bark.LightningSendStatus? lightning,
  List<String>? paymentReads,
}) {
  final account = ArkAccountId(
    parent: Fingerprint('12345678'),
    network: BitcoinNetwork.regtest,
    serverIdentity: 'server',
  );
  return adapter.BarkNativeSession(
    _Wallet(exits, movements, lightning, paymentReads),
    _Onchain(),
    _Stages(),
    ArkAccountConfig(
      id: account,
      arkUrl: Uri.parse('http://localhost:3535'),
      primaryEsploraUrl: Uri.parse('http://localhost:3000'),
    ),
  );
}

final class _Wallet implements bark.Wallet {
  final List<bark.ExitVtxo> exits;
  final List<bark.Movement> movements;
  final bark.LightningSendStatus? lightning;
  final List<String>? paymentReads;
  _Wallet(this.exits, this.movements, this.lightning, this.paymentReads);
  @override
  Future<bark.LightningSendStatus> lightningSendState({
    required String paymentHash,
  }) async {
    paymentReads?.add(paymentHash);
    final state = lightning;
    if (state == null) throw StateError('Unexpected lightning status read');
    return state;
  }

  @override
  Future<List<bark.Movement>> history() async => movements;
  @override
  Future<List<bark.ExitVtxo>> getExitVtxos() async => exits;
  @override
  void dispose() {}
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected native handle method');
}

final class _Onchain implements bark.OnchainWallet {
  @override
  void dispose() {}
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected onchain method');
}

final class _Stages implements ArkStageRunner {
  @override
  Future<T> run<T>(String name, Future<T> Function() action) => action();
}

void main() {
  final txid = 'a' * 64;
  ArkOperation operation({String? reference}) => ArkOperation(
    id: 'claim',
    kind: ArkOperationKind.claim,
    status: ArkOperationStatus.outcomeUnknown,
    chainSource: Uri.parse('http://localhost:3000'),
    configGeneration: 1,
    nativeReference: reference,
    actualIds: ['actual'],
    skippedIds: ['skipped'],
  );
  bark.ExitVtxo claimed(String id, String hash) => bark.ExitVtxo(
    vtxoId: id,
    amountSats: 1000,
    isClaimable: false,
    state: bark.ClaimedExitState(
      tipHeight: 101,
      txid: hash,
      block: bark.BlockRef(height: 100, hash: 'block'),
    ),
  );
  for (final failed in [false, true]) {
    test(
      'Lightning failed revocation $failed preserves uncertainty on reconciliation',
      () async {
        final hash = 'a' * 64;
        final reads = <String>[];
        final native = session(
          [],
          paymentReads: reads,
          lightning: bark.InProgressLightningSendStatus(
            bark.LightningSend(
              invoice: 'synthetic-unparsed-invoice',
              paymentHash: hash,
              amountSats: 1000,
              feeSats: 10,
              htlcVtxoCount: 1,
              hasFailedRevocation: failed,
            ),
          ),
        );
        final original = ArkOperation(
          id: 'payment',
          kind: ArkOperationKind.payment,
          status: ArkOperationStatus.outcomeUnknown,
          chainSource: Uri.parse('http://localhost:3000'),
          configGeneration: 1,
          nativeReference: hash,
          actualIds: ['input'],
        );
        try {
          final observed = await native.reconcile(original);
          expect(reads, [hash]);
          expect(observed?.nativeReference, hash);
          expect(observed?.chainSource, original.chainSource);
          expect(observed?.actualIds, ['input']);
          expect(
            observed?.status,
            failed
                ? ArkOperationStatus.outcomeUnknown
                : ArkOperationStatus.pending,
          );
        } finally {
          native.close();
        }
      },
    );
  }
  for (final status in ['failed', 'successful']) {
    test(
      'native payment $status preserves effect uncertainty and original binding',
      () async {
        final native = session(
          [],
          movements: [
            bark.Movement(
              id: 42,
              status: status,
              subsystemName: 'bark.arkoor',
              subsystemKind: 'send',
              metadataJson: '{}',
              intendedBalanceSats: -1000,
              effectiveBalanceSats: -1000,
              offchainFeeSats: 0,
              sentToAddresses: ['{"type":"ark","value":"destination"}'],
              receivedOnAddresses: [],
              inputVtxoIds: ['actual'],
              outputVtxoIds: ['change'],
              exitedVtxoIds: [],
              createdAt: '2026-11-16T00:00:00Z',
              updatedAt: '2026-11-16T00:00:01Z',
            ),
          ],
        );
        final original = ArkOperation(
          id: 'payment',
          kind: ArkOperationKind.payment,
          status: ArkOperationStatus.outcomeUnknown,
          chainSource: Uri.parse('http://localhost:3000'),
          configGeneration: 1,
          nativeReference: '42',
          actualIds: ['actual'],
        );
        final result = await native.reconcile(original);
        expect(
          result?.status,
          status == 'failed'
              ? ArkOperationStatus.outcomeUnknown
              : ArkOperationStatus.succeeded,
        );
        expect(result?.nativeReference, original.nativeReference);
        expect(result?.chainSource, original.chainSource);
        expect(result?.actualIds, original.actualIds);
        native.close();
      },
    );
  }
  test(
    'claimed actual ids with another txid are conflict, never success',
    () async {
      final native = session([claimed('actual', 'b' * 64)]);
      final result = await native.reconcile(operation(reference: txid));
      expect(result?.status, isNot(ArkOperationStatus.succeeded));
      expect(result?.status.name, 'conflicted');
      expect(result?.nativeReference, txid);
      expect(result?.actualIds, ['actual']);
      expect(result?.skippedIds, ['skipped']);
      native.close();
    },
  );
  test(
    'matching transaction settles actual ids regardless of skipped ids',
    () async {
      final native = session([
        claimed('actual', txid),
        claimed('skipped', 'b' * 64),
      ]);
      expect(
        (await native.reconcile(operation(reference: txid)))?.status,
        ArkOperationStatus.succeeded,
      );
      native.close();
    },
  );
  test(
    'absent journal transaction identity cannot establish claim success',
    () async {
      final native = session([claimed('actual', txid)]);
      final result = await native.reconcile(operation());
      expect(result?.status, isNot(ArkOperationStatus.succeeded));
      native.close();
    },
  );
}
