// Regression test for a send-to-self recorded with the whole value of the
// utxos it consumed instead of the amount paid. `sentAndReceived.sent` is the
// sum of our own inputs, so when we own every output it is what coin
// selection spent, not what the user entered — the old `sent - fee` reported
// that. Only the keychain separates the recipient from the change.
//
// Every test drives the real `getTransactions` against an offline, in-process
// bdk wallet, so they cover `listOutput()` -> keychain -> `isChange` -> the
// amount. Setup mirrors bdk_wallet_datasource_test.dart: a fixed BIP84 testnet
// wallet seeded with hand-crafted raw transactions, path_provider mocked to a
// temp directory. `setUp` funds the wallet; each test then applies its own
// spend of that funding so the scenarios don't double-spend each other.
import 'dart:io';
import 'dart:typed_data';

import 'package:bb_mobile/core/wallet/data/datasources/bdk_facade.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_transaction_model.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bdk_wallet_test_fixture.dart';

// The canonical BIP39 test mnemonic ("abandon" x11 + "about"). Public
// knowledge, no funds, safe to hardcode.
const _testMnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon about';

// A well-known BIP173 test-vector P2WPKH testnet address: our unowned source
// of funds, and an unowned send destination.
const _externalTestnetAddress = 'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx';

const _sourceAmountSat = 300000;
const _fundedLargeAmountSat = 200000;
const _fundedSmallAmountSat = 30000;

const _feeSat = 200;
// 10 000 out of the 200 000 utxo: the change dominates, which is what made
// the bug visible.
const _paidAmountSat = 10000;
const _changeAmountSat = _fundedLargeAmountSat - _paidAmountSat - _feeSat;

Uint8List _leUint32(int value) {
  final bytes = ByteData(4)..setUint32(0, value, Endian.little);
  return bytes.buffer.asUint8List();
}

Uint8List _leUint64(int value) {
  final bytes = ByteData(8)..setUint64(0, value, Endian.little);
  return bytes.buffer.asUint8List();
}

Uint8List _varInt(int value) {
  if (value < 0xfd) return Uint8List.fromList([value]);
  if (value <= 0xffff) {
    final bytes = ByteData(3)
      ..setUint8(0, 0xfd)
      ..setUint16(1, value, Endian.little);
    return bytes.buffer.asUint8List();
  }
  throw UnimplementedError('varint > 0xffff not needed for this test');
}

/// Txids are displayed big-endian but serialized little-endian, so the bytes
/// have to be reversed to reference an outpoint in a raw transaction.
Uint8List _txidToLeBytes(String txidHex) {
  final bytes = Uint8List(32);
  for (var i = 0; i < 32; i++) {
    bytes[31 - i] = int.parse(txidHex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}

/// A minimal legacy-serialized raw transaction. A null [inputs] txid means the
/// throwaway all-zero outpoint; bdk does not validate inputs here.
bdk.Transaction _rawTx({
  required List<({String? txId, int vout})> inputs,
  required List<({bdk.Script script, int amountSat})> outputs,
}) {
  final bytes = BytesBuilder();
  bytes.add(_leUint32(2)); // version
  bytes.add(_varInt(inputs.length));
  for (final input in inputs) {
    bytes.add(input.txId == null ? Uint8List(32) : _txidToLeBytes(input.txId!));
    bytes.add(_leUint32(input.vout));
    bytes.add(_varInt(0)); // empty scriptSig
    bytes.add(_leUint32(0xFFFFFFFF)); // sequence
  }
  bytes.add(_varInt(outputs.length));
  for (final output in outputs) {
    bytes.add(_leUint64(output.amountSat));
    final script = output.script.toBytes();
    bytes.add(_varInt(script.length));
    bytes.add(script);
  }
  bytes.add(_leUint32(0)); // locktime
  return bdk.Transaction(transactionBytes: bytes.toBytes());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late PublicBdkWalletModel walletModel;
  late String fundingTxId;
  // Two funded receive addresses, a third as the self-send destination, and a
  // change address on the internal keychain.
  late bdk.Script receive0;
  late bdk.Script receive2;
  late bdk.Script change0;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('bdk_self_send_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return tempDir.path;
          }
          return null;
        });

    final mnemonic = bdk.Mnemonic.fromString(mnemonic: _testMnemonic);
    final secretKey = bdk.DescriptorSecretKey(
      networkKind: bdk.NetworkKind.test,
      mnemonic: mnemonic,
      password: null,
    );
    final external = bdk.Descriptor.newBip84(
      secretKey: secretKey,
      keychainKind: bdk.KeychainKind.external_,
      networkKind: bdk.NetworkKind.test,
    );
    final internal = bdk.Descriptor.newBip84(
      secretKey: secretKey,
      keychainKind: bdk.KeychainKind.internal,
      networkKind: bdk.NetworkKind.test,
    );

    walletModel =
        WalletModel.publicBdk(
              id: 'bdk-self-send-test',
              descriptor: twoPathDescriptor(
                external.toString(),
                internal.toString(),
              ),
              isTestnet: true,
            )
            as PublicBdkWalletModel;

    final wallet = await BdkFacade.createWallet(walletModel);

    receive0 = wallet
        .revealNextAddress(keychain: bdk.KeychainKind.external_)
        .address
        .scriptPubkey();
    final receive1 = wallet
        .revealNextAddress(keychain: bdk.KeychainKind.external_)
        .address
        .scriptPubkey();
    // The self-send destination: our own address, external keychain, as
    // pasting a receive address of the same wallet would give.
    receive2 = wallet
        .revealNextAddress(keychain: bdk.KeychainKind.external_)
        .address
        .scriptPubkey();
    change0 = wallet
        .revealNextAddress(keychain: bdk.KeychainKind.internal)
        .address
        .scriptPubkey();

    // `getTransactions` calculates a fee for every transaction, so bdk needs
    // the value of each input's previous output. Our funding comes from a
    // throwaway outpoint no transaction backs, so register it as a floating
    // txout.
    wallet.insertTxout(
      outpoint: bdk.OutPoint(
        txid: bdk.Txid.fromString(hex: '00' * 32),
        vout: 0,
      ),
      txout: bdk.TxOut(
        value: bdk.Amount.fromSat(satoshi: _sourceAmountSat),
        scriptPubkey: bdk.Address(
          address: _externalTestnetAddress,
          network: bdk.Network.testnet,
        ).scriptPubkey(),
      ),
    );

    final fundingTx = _rawTx(
      inputs: [(txId: null, vout: 0)],
      outputs: [
        (script: receive0, amountSat: _fundedLargeAmountSat),
        (script: receive1, amountSat: _fundedSmallAmountSat),
      ],
    );
    fundingTxId = fundingTx.computeTxid().toString();

    wallet.applyUnconfirmedTxs(
      unconfirmedTxs: [
        bdk.UnconfirmedTx(
          tx: fundingTx,
          lastSeen: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        ),
      ],
    );

    // Sanity-check the funding landed, so a failure here points at the setup.
    expect(
      wallet.listUnspent().length,
      2,
      reason: 'test setup: expected exactly 2 synthetic utxos after funding',
    );

    await BdkFacade.saveWallet(wallet, walletModel.hexId);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// Spends the funding utxos into [outputs] and returns what the datasource
  /// then reports for that transaction.
  Future<WalletTransactionModel> spend({
    required List<({bdk.Script script, int amountSat})> outputs,
    List<int> spendingVouts = const [0],
  }) async {
    final wallet = await BdkFacade.createWallet(walletModel);
    final tx = _rawTx(
      inputs: [
        for (final vout in spendingVouts) (txId: fundingTxId, vout: vout),
      ],
      outputs: outputs,
    );
    wallet.applyUnconfirmedTxs(
      unconfirmedTxs: [
        bdk.UnconfirmedTx(
          tx: tx,
          lastSeen: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        ),
      ],
    );
    await BdkFacade.saveWallet(wallet, walletModel.hexId);

    final transactions = await BdkWalletDatasource().getTransactions(
      wallet: walletModel,
    );
    return transactions.firstWhere(
      (transaction) => transaction.txId == tx.computeTxid().toString(),
    );
  }

  test(
    'a send to self records the amount paid, not the utxo consumed',
    () async {
      final selfSend = await spend(
        outputs: [
          (script: receive2, amountSat: _paidAmountSat),
          (script: change0, amountSat: _changeAmountSat),
        ],
      );

      expect(
        selfSend.isToSelf,
        isTrue,
        reason: 'every input and output is owned by this wallet',
      );
      // The bug reported `sent - fee` = 199 800 here.
      expect(selfSend.amountSat, _paidAmountSat);
      expect(selfSend.feeSat, _feeSat);
    },
  );

  test('the change of a send to self is identified by its keychain', () async {
    final selfSend = await spend(
      outputs: [
        (script: receive2, amountSat: _paidAmountSat),
        (script: change0, amountSat: _changeAmountSat),
      ],
    );

    final change = selfSend.outputs.where((output) => output.isChange);
    final paidOut = selfSend.outputs.where((output) => !output.isChange);

    expect(change.single.value, BigInt.from(_changeAmountSat));
    expect(paidOut.single.value, BigInt.from(_paidAmountSat));
  });

  test('a send of the whole utxo to ourselves leaves no change', () async {
    // What masked the bug: with no change, `sent - fee` happened to be right.
    const sweptAmountSat = _fundedLargeAmountSat - _feeSat;
    final sweep = await spend(
      outputs: [(script: receive2, amountSat: sweptAmountSat)],
    );

    expect(sweep.isToSelf, isTrue);
    expect(sweep.amountSat, sweptAmountSat);
    expect(sweep.outputs.every((output) => !output.isChange), isTrue);
  });

  test('a consolidation into change alone reports the fee', () async {
    // Both utxos into one change output. Nothing was paid out, so the fee is
    // the only balance change — and it must not report zero.
    const consolidatedSat =
        _fundedLargeAmountSat + _fundedSmallAmountSat - _feeSat;
    final consolidation = await spend(
      spendingVouts: [0, 1],
      outputs: [(script: change0, amountSat: consolidatedSat)],
    );

    expect(consolidation.isToSelf, isTrue);
    expect(consolidation.amountSat, _feeSat);
    expect(consolidation.outputs.every((output) => output.isChange), isTrue);
  });

  test('an ordinary send to someone else is unaffected', () async {
    final external = bdk.Address(
      address: _externalTestnetAddress,
      network: bdk.Network.testnet,
    ).scriptPubkey();
    final send = await spend(
      outputs: [
        (script: external, amountSat: _paidAmountSat),
        (script: change0, amountSat: _changeAmountSat),
      ],
    );

    expect(send.isToSelf, isFalse);
    expect(send.isIncoming, isFalse);
    expect(send.amountSat, _paidAmountSat);
  });

  test('an incoming transaction is unaffected', () async {
    final transactions = await BdkWalletDatasource().getTransactions(
      wallet: walletModel,
    );
    final funding = transactions.firstWhere((tx) => tx.txId == fundingTxId);

    expect(funding.isToSelf, isFalse);
    expect(funding.isIncoming, isTrue);
    // The sender paid the fee, so it is not deducted here.
    expect(funding.amountSat, _fundedLargeAmountSat + _fundedSmallAmountSat);
  });
}
