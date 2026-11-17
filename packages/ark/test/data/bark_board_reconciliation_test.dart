import 'package:ark/ark.dart';
import 'package:ark/src/data/ark_native_session.dart';
import 'package:ark/src/data/bark_native_opener.dart';
import 'package:bark_bitcoin/bark_bitcoin.dart' as bark;
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

// Actual Dart adapter with scripted binding records; no FFI or wallet open.
const funding =
    'b4b8410fb2300f4eef152975691153aae9dfc66dc4b1d43a54f9f1b30f36d46a';
const produced =
    '9b5cf9283b95eb2a79be211c2d759b0f374aece83e01645795e3f1a99e924e83:0';

bark.Movement movement({
  String? metadata,
  String status = 'successful',
  List<String> outputs = const [produced],
}) => bark.Movement(
  id: 1,
  status: status,
  subsystemName: 'bark.board',
  subsystemKind: 'board',
  metadataJson:
      metadata ?? '{"chain_anchor":"$funding:1","onchain_fee_sat":17}',
  intendedBalanceSats: 20000,
  effectiveBalanceSats: 19670,
  offchainFeeSats: 330,
  sentToAddresses: [],
  receivedOnAddresses: [],
  inputVtxoIds: [],
  outputVtxoIds: outputs,
  exitedVtxoIds: [],
  createdAt: '2026-11-17T00:00:00Z',
  updatedAt: '2026-11-17T00:00:00Z',
);

final class Wallet implements bark.Wallet {
  List<bark.Movement> movements;
  String id = produced;
  bark.VtxoState state = bark.SpendableVtxoState();
  Wallet(this.movements);
  @override
  Future<List<bark.Movement>> history() async => movements;
  @override
  Future<List<bark.Vtxo>> allVtxos() async => [
    bark.Vtxo(
      id: id,
      amountSats: 19670,
      expiryHeight: 5022,
      kind: 'pubkey',
      state: state,
      exitDepth: 1,
      exitTxWeightWu: 1000,
      registered: true,
    ),
  ];
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected native call');
}

final class Onchain implements bark.OnchainWallet {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected onchain call');
}

final class Stages implements ArkStageRunner {
  @override
  Future<T> run<T>(String name, Future<T> Function() action) => action();
}

ArkNativeSession session(Wallet wallet) => BarkNativeSession(
  wallet,
  Onchain(),
  Stages(),
  ArkAccountConfig(
    id: ArkAccountId(
      parent: Fingerprint('12345678'),
      network: BitcoinNetwork.regtest,
      serverIdentity: 'server',
    ),
    arkUrl: Uri.parse('http://localhost:3535'),
    primaryEsploraUrl: Uri.parse('http://localhost:3000'),
  ),
);
ArkOperation operation() => ArkOperation(
  id: 'board',
  kind: ArkOperationKind.board,
  status: ArkOperationStatus.pending,
  chainSource: Uri.parse('http://localhost:3000'),
  configGeneration: 1,
  nativeReference: funding,
);

void main() {
  test(
    'Board reconciliation follows the chain anchor to the distinct W3 VTXO id',
    () async {
      // W3's observed IDs, with a deliberately synthetic nonzero funding vout.
      final result = await session(Wallet([movement()])).reconcile(operation());
      expect(result, isNotNull);
      expect(result?.status, ArkOperationStatus.succeeded);
      expect(result?.nativeReference, funding);
      expect(result?.id, 'board');
    },
  );
  for (final metadata in [
    '{',
    '{}',
    '{"chain_anchor":"$funding:1","onchain_fee_sat":17.0}',
    '{"chain_anchor":"$funding:4294967296","onchain_fee_sat":17}',
    '{"chain_anchor":"$funding:01","onchain_fee_sat":17}',
    '{"chain_anchor":"${'a' * 64}:1","onchain_fee_sat":17}',
  ]) {
    test(
      'invalid or unrelated anchor metadata does not settle a Board: $metadata',
      () async {
        expect(
          await session(Wallet([movement(metadata: metadata)]))
              .reconcile(operation()),
          isNull,
        );
      },
    );
  }
  test(
    'a duplicate Board movement is ambiguous even if only one succeeded',
    () async {
      expect(
        await session(Wallet([movement(), movement(status: 'pending')]))
            .reconcile(operation()),
        isNull,
      );
    },
  );
  test(
    'a pending movement or an unrelated produced VTXO is not settlement',
    () async {
      expect(
        await session(Wallet([movement(status: 'pending')]))
            .reconcile(operation()),
        isNull,
      );
      expect(
        await session(
          Wallet([
            movement(outputs: ['other']),
          ]),
        ).reconcile(operation()),
        isNull,
      );
      final wallet = Wallet([movement()])..state = bark.LockedVtxoState(null);
      expect(await session(wallet).reconcile(operation()), isNull);
    },
  );
  test('a VTXO prefix matching the funding txid is not Board proof', () async {
    final wallet = Wallet([])..id = '$funding:0';
    expect(await session(wallet).reconcile(operation()), isNull);
  });
}
