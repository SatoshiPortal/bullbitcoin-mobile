import 'dart:typed_data';

import 'package:rust_bindings/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/src/data/read/wallet_frame_mapper.dart';
import 'package:sync/sync.dart';

class _Txid extends Fake implements bdk.Txid {
  final String value;
  final void Function() onConvert;
  int disposals = 0;

  _Txid(this.value, this.onConvert);

  @override
  String toString() {
    expect(disposals, 0, reason: 'a disposed native handle cannot be reused');
    onConvert();
    return value;
  }

  @override
  void dispose() => disposals++;
}

class _Transaction extends Fake implements bdk.Transaction {
  final int index;
  final _History history;

  _Transaction(this.index, this.history);

  @override
  bdk.Txid computeTxid() {
    history.computations++;
    final id = _Txid('tx-$index', () {
      history.conversions++;
      if (history.failConversion) throw StateError('synthetic txid failure');
    });
    history.ownedIds.add(id);
    return id;
  }

  @override
  List<bdk.TxIn> input() {
    final previous = _Txid('tx-${(index + 199) % 200}', () {
      history.conversions++;
    });
    history.ownedIds.add(previous);
    return [
      bdk.TxIn(
        previousOutput: bdk.OutPoint(txid: previous, vout: 0),
        scriptSig: history.emptyScript,
        sequence: 0xfffffffd,
        witness: [],
      ),
    ];
  }

  @override
  List<bdk.TxOut> output() => history.outputs;

  @override
  int vsize() => 141;

  @override
  bool isExplicitlyRbf() => true;
}

class _History extends Fake implements bdk.Wallet {
  final List<bdk.TxOut> outputs;
  final bdk.Script emptyScript;
  final bdk.Amount sent;
  final bdk.Amount received;
  final bdk.Amount fee;
  final ownedIds = <_Txid>[];
  int conversions = 0;
  int computations = 0;
  bool failConversion = false;
  int disposals = 0;

  _History(this.outputs, this.emptyScript, this.sent, this.received, this.fee);

  @override
  List<bdk.CanonicalTx> transactions() => [
    for (var index = 0; index < 200; index++)
      bdk.CanonicalTx(
        transaction: _Transaction(index, this),
        chainPosition: bdk.UnconfirmedChainPosition(null),
      ),
  ];

  @override
  List<bdk.LocalOutput> listOutput() => [
    for (var index = 0; index < 200; index++)
      bdk.LocalOutput(
        outpoint: bdk.OutPoint(txid: changeId(index), vout: 0),
        txout: outputs.first,
        keychain: bdk.KeychainKind.internal,
        isSpent: true,
        derivationIndex: index,
        chainPosition: bdk.UnconfirmedChainPosition(null),
      ),
  ];

  _Txid changeId(int index) {
    final id = _Txid('tx-$index', () => conversions++);
    ownedIds.add(id);
    return id;
  }

  @override
  bool isMine({required bdk.Script script}) => script.toBytes().last == 1;

  @override
  bdk.SentAndReceivedValues sentAndReceived({required bdk.Transaction tx}) =>
      bdk.SentAndReceivedValues(sent: sent, received: received);

  @override
  bdk.Amount calculateFee({required bdk.Transaction tx}) => fee;

  @override
  bdk.Network network() => bdk.Network.testnet;

  @override
  bdk.Balance balance() => bdk.Balance(
    immature: bdk.Amount.fromSat(satoshi: 0),
    trustedPending: bdk.Amount.fromSat(satoshi: 0),
    untrustedPending: bdk.Amount.fromSat(satoshi: 0),
    confirmed: bdk.Amount.fromSat(satoshi: 0),
    trustedSpendable: bdk.Amount.fromSat(satoshi: 0),
    total: bdk.Amount.fromSat(satoshi: 0),
  );

  @override
  bdk.BlockId latestCheckpoint() => bdk.BlockId(height: 0, hash: _Hash());

  @override
  List<bdk.LocalOutput> listUnspent() => const [];

  @override
  int nextDerivationIndex({required bdk.KeychainKind keychain}) => 0;

  @override
  bdk.AddressInfo peekAddress({
    required bdk.KeychainKind keychain,
    required int index,
  }) => bdk.AddressInfo(
    index: index,
    address: bdk.Address(
      address: 'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx',
      network: bdk.Network.testnet,
    ),
    keychain: keychain,
  );

  @override
  void dispose() => disposals++;
}

class _Hash extends Fake implements bdk.BlockHash {}

void main() {
  final key = WalletKey(
    id: 'synthetic-history',
    network: BitcoinNetwork.testnet,
  );
  final revision = WalletRevision(key: key, generation: 0, revision: 1);

  for (final failConversion in [false, true]) {
    test(
      failConversion
          ? 'txid conversion failure releases its owned handle'
          : '200 transactions map once with linear txid conversions',
      () {
        // Native scripts/amounts exercise the normal address and value conversion;
        // counting txid handles expose every call at the leaking FFI boundary.
        final own = bdk.Script(
          rawOutputScript: Uint8List.fromList([0, 20, ...List.filled(20, 1)]),
        );
        final foreign = bdk.Script(
          rawOutputScript: Uint8List.fromList([0, 20, ...List.filled(20, 2)]),
        );
        final empty = bdk.Script(rawOutputScript: Uint8List(0));
        final received = bdk.Amount.fromSat(satoshi: 400);
        final paid = bdk.Amount.fromSat(satoshi: 500);
        final sent = bdk.Amount.fromSat(satoshi: 1000);
        final fee = bdk.Amount.fromSat(satoshi: 100);
        final history = _History(
          [
            bdk.TxOut(value: received, scriptPubkey: own),
            bdk.TxOut(value: paid, scriptPubkey: foreign),
          ],
          empty,
          sent,
          received,
          fee,
        );
        addTearDown(() {
          for (final script in [own, foreign, empty]) {
            script.dispose();
          }
          for (final amount in [received, paid, sent, fee]) {
            amount.dispose();
          }
        });
        history.failConversion = failConversion;
        if (failConversion) {
          expect(() => bitcoinFrameData(history, revision), throwsStateError);
          expect(history.ownedIds.every((id) => id.disposals == 1), isTrue);
          expect(history.disposals, 0);
          return;
        }
        final frame = bitcoinFrameData(history, revision);
        final result = frame.transactions
            .whereType<BitcoinTransaction>()
            .toList();
        expect(result, hasLength(200));
        for (var index = 0; index < 200; index++) {
          final tx = result[index];
          expect(tx.txid, 'tx-$index');
          expect(tx.sentSat, 1000);
          expect(tx.receivedSat, 400);
          expect(tx.feeSat, 100);
          expect(tx.vsize, 141);
          expect(tx.isExplicitlyRbf, isTrue);
          expect(tx.confirmationTime, isNull);
          expect(tx.inputs.single.previousOutput, (
            txId: 'tx-${(index + 199) % 200}',
            vout: 0,
          ));
          expect(tx.inputs.single.scriptSig, isEmpty);
          expect(tx.outputs.map((o) => o.vout), [0, 1]);
          expect(tx.outputs.map((o) => o.isOwn), [true, false]);
          expect(tx.outputs.map((o) => o.valueSat), [
            BigInt.from(400),
            BigInt.from(500),
          ]);
          expect(tx.outputs.map((o) => o.isChange), [true, false]);
          expect(tx.outputs.first.scriptPubkey, own.toBytes());
          expect(tx.outputs.last.scriptPubkey, foreign.toBytes());
          expect(
            tx.outputs.every((o) => o.address?.startsWith('tb1q') ?? false),
            isTrue,
          );
        }
        // Every output the wallet held, spent included, is owned.
        expect(frame.ownership?.ownsOutpoint((txId: 'tx-7', vout: 0)), isTrue);
        // 200 transaction ids + 200 previous ids + 200 wallet outputs.
        expect(history.conversions, 600);
        expect(history.computations, 200);
        expect(history.ownedIds.every((id) => id.disposals == 1), isTrue);
        expect(history.disposals, 0, reason: 'the shared wallet is borrowed');
      },
    );
  }
}
