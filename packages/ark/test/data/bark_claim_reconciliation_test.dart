import 'package:ark/ark.dart';
import 'package:ark/src/data/ark_native_session.dart';
import 'package:ark/src/data/bark_native_opener.dart' as adapter;
import 'package:bark_bitcoin/bark_bitcoin.dart' as bark;
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

/// Exercise the actual adapter method with Dart implementations of the native
/// handles through the package-private-src session constructor.
/// No FFI function, native opener or network request is invoked by these tests.
ArkNativeSession session(List<bark.ExitVtxo> exits) {
  final account = ArkAccountId(
    parent: Fingerprint('12345678'),
    network: BitcoinNetwork.regtest,
    serverIdentity: 'server',
  );
  return adapter.BarkNativeSession(
    _Wallet(exits),
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
  _Wallet(this.exits);
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
