// `findTransactionSpending` against an offline, in-process bdk wallet seeded
// with hand-crafted raw transactions; setup mirrors
// bdk_wallet_datasource_self_send_test.dart.
import 'dart:io';
import 'dart:typed_data';

import 'package:bb_mobile/core/wallet/data/datasources/bdk_facade.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart' show Outpoint;

// The canonical BIP39 test mnemonic ("abandon" x11 + "about"). Public
// knowledge, no funds, safe to hardcode.
const _testMnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon about';

const _externalTestnetAddress = 'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx';

Uint8List _leUint32(int value) {
  final bytes = ByteData(4)..setUint32(0, value, Endian.little);
  return bytes.buffer.asUint8List();
}

Uint8List _leUint64(int value) {
  final bytes = ByteData(8)..setUint64(0, value, Endian.little);
  return bytes.buffer.asUint8List();
}

/// Txids are displayed big-endian but serialized little-endian.
Uint8List _txidToLeBytes(String txidHex) {
  final bytes = Uint8List(32);
  for (var i = 0; i < 32; i++) {
    bytes[31 - i] = int.parse(txidHex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}

/// A minimal legacy-serialized raw transaction; bdk does not validate inputs.
bdk.Transaction _rawTx({
  required List<Outpoint> inputs,
  required List<({bdk.Script script, int amountSat})> outputs,
}) {
  final bytes = BytesBuilder();
  bytes.add(_leUint32(2));
  bytes.addByte(inputs.length);
  for (final input in inputs) {
    bytes.add(_txidToLeBytes(input.txId));
    bytes.add(_leUint32(input.vout));
    bytes.addByte(0);
    bytes.add(_leUint32(0xFFFFFFFF));
  }
  bytes.addByte(outputs.length);
  for (final output in outputs) {
    bytes.add(_leUint64(output.amountSat));
    final script = output.script.toBytes();
    bytes.addByte(script.length);
    bytes.add(script);
  }
  bytes.add(_leUint32(0));
  return bdk.Transaction(transactionBytes: bytes.toBytes());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final senderInput = (txId: '11' * 32, vout: 0);
  final external = bdk.Address(
    address: _externalTestnetAddress,
    network: bdk.Network.testnet,
  ).scriptPubkey();
  late Directory tempDir;
  late PublicBdkWalletModel walletModel;
  late Outpoint ownInput;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('bdk_spending_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return tempDir.path;
          }
          return null;
        });

    final secretKey = bdk.DescriptorSecretKey(
      networkKind: bdk.NetworkKind.test,
      mnemonic: bdk.Mnemonic.fromString(mnemonic: _testMnemonic),
      password: null,
    );
    walletModel =
        WalletModel.publicBdk(
              id: 'bdk-spending-test',
              externalDescriptor: bdk.Descriptor.newBip84(
                secretKey: secretKey,
                keychainKind: bdk.KeychainKind.external_,
                networkKind: bdk.NetworkKind.test,
              ).toString(),
              internalDescriptor: bdk.Descriptor.newBip84(
                secretKey: secretKey,
                keychainKind: bdk.KeychainKind.internal,
                networkKind: bdk.NetworkKind.test,
              ).toString(),
              isTestnet: true,
            )
            as PublicBdkWalletModel;

    final wallet = await BdkFacade.createWallet(walletModel);
    final receive = wallet
        .revealNextAddress(keychain: bdk.KeychainKind.external_)
        .address
        .scriptPubkey();
    final funding = _rawTx(
      inputs: [(txId: '00' * 32, vout: 0)],
      outputs: [(script: receive, amountSat: 100000)],
    );
    ownInput = (txId: funding.computeTxid().toString(), vout: 0);
    wallet.applyUnconfirmedTxs(
      unconfirmedTxs: [bdk.UnconfirmedTx(tx: funding, lastSeen: 1)],
    );
    await BdkFacade.saveWallet(wallet, walletModel.hexId);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  Future<String> land(List<Outpoint> inputs) async {
    final wallet = await BdkFacade.createWallet(walletModel);
    final tx = _rawTx(
      inputs: inputs,
      outputs: [(script: external, amountSat: 90000)],
    );
    wallet.applyUnconfirmedTxs(
      unconfirmedTxs: [bdk.UnconfirmedTx(tx: tx, lastSeen: 2)],
    );
    await BdkFacade.saveWallet(wallet, walletModel.hexId);
    return tx.computeTxid().toString();
  }

  Future<String?> find() => BdkWalletDatasource().findTransactionSpending(
    wallet: walletModel,
    outpoints: {senderInput, ownInput},
  );

  test('returns the transaction spending every outpoint', () async {
    final payjoin = await land([senderInput, ownInput]);

    expect(await find(), payjoin);
  });

  test('returns null while the wallet still holds its outpoint', () async {
    expect(await find(), isNull);
  });

  test('ignores a transaction spending only some of them', () async {
    await land([ownInput]);

    expect(await find(), isNull);
  });
}
