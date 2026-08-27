import 'dart:io';
import 'dart:typed_data';

import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_facade.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_utxo_model.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_coin_selection_exception.dart';
import 'package:bb_mobile/core/wallet/domain/insufficient_funds_exception.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bdk_wallet_test_fixture.dart';

// The canonical BIP39 test mnemonic ("abandon" x11 + "about"). Public
// knowledge, no funds, safe to hardcode.
const _testMnemonic =
    'abandon abandon abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon about';

// A well-known BIP173 test-vector P2WPKH testnet address, used only as an
// external send destination (not owned by the test wallet).
const _externalTestnetAddress = 'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx';

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

/// Hand-crafts a minimal, legacy-serialized (non-segwit) raw transaction
/// with one throwaway input (never meant to be valid/spendable — BDK's
/// `apply_unconfirmed_txs` doesn't validate it) and one output per entry in
/// [outputs]. Used to seed deterministic, known UTXOs into an otherwise
/// empty offline wallet.
Uint8List _buildFundingTx(List<({bdk.Script script, int amountSat})> outputs) {
  final bytes = BytesBuilder();
  bytes.add(_leUint32(2)); // version
  bytes.add(_varInt(1)); // 1 (fake) input
  bytes.add(Uint8List(32)); // prev txid (all-zero, never spent for real)
  bytes.add(_leUint32(0)); // prev vout
  bytes.add(_varInt(0)); // empty scriptSig
  bytes.add(_leUint32(0xFFFFFFFF)); // sequence
  bytes.add(_varInt(outputs.length));
  for (final output in outputs) {
    bytes.add(_leUint64(output.amountSat));
    final script = output.script.toBytes();
    bytes.add(_varInt(script.length));
    bytes.add(script);
  }
  bytes.add(_leUint32(0)); // locktime
  return bytes.toBytes();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late PublicBdkWalletModel walletModel;
  late String utxoLargeTxId;
  late int utxoLargeVout;

  const utxoLargeAmountSat = 200000;
  const utxoSmallAmountSat = 30000;
  // Both UTXOs share utxoLargeTxId (same funding tx); only vout differs.
  const utxoSmallVout = 1;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('bdk_wallet_datasource_');
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
              id: 'bdk-wallet-datasource-test',
              descriptor: twoPathDescriptor(
                external.toString(),
                internal.toString(),
              ),
              isTestnet: true,
            )
            as PublicBdkWalletModel;

    // Build the wallet once here to fund it, then persist so the
    // datasource's own (separate) `BdkFacade.createWallet` call sees the
    // exact same UTXOs when the test invokes `buildPsbt`.
    final wallet = await BdkFacade.createWallet(walletModel);

    final addr0 = wallet.revealNextAddress(
      keychain: bdk.KeychainKind.external_,
    );
    final addr1 = wallet.revealNextAddress(
      keychain: bdk.KeychainKind.external_,
    );

    final fundingTxBytes = _buildFundingTx([
      (script: addr0.address.scriptPubkey(), amountSat: utxoLargeAmountSat),
      (script: addr1.address.scriptPubkey(), amountSat: utxoSmallAmountSat),
    ]);
    final fundingTx = bdk.Transaction(transactionBytes: fundingTxBytes);
    final fundingTxid = fundingTx.computeTxid().toString();

    wallet.applyUnconfirmedTxs(
      unconfirmedTxs: [
        bdk.UnconfirmedTx(
          tx: fundingTx,
          lastSeen: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        ),
      ],
    );

    // Sanity-check the funding actually landed before persisting, so a
    // failure here points clearly at the test's own setup rather than at
    // `buildPsbt`.
    final utxos = wallet.listUnspent();
    expect(
      utxos.length,
      2,
      reason: 'test setup: expected exactly 2 synthetic UTXOs after funding',
    );

    utxoLargeTxId = fundingTxid;
    utxoLargeVout = 0;

    await BdkFacade.saveWallet(wallet, walletModel.hexId);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'buildPsbt sets a non-RBF sequence when replaceByFee is false',
    () async {
      final datasource = BdkWalletDatasource();

      final psbt = await datasource.buildPsbt(
        wallet: walletModel,
        address: _externalTestnetAddress,
        amountSat: 25000,
        networkFee: const NetworkFee.relativeSatPerKwu(1000),
        selected: [
          WalletUtxoModel.bitcoin(
            txId: utxoLargeTxId,
            vout: utxoLargeVout,
            amountSat: BigInt.from(utxoLargeAmountSat),
            scriptPubkey: Uint8List(0),
            address: '',
            isExternalKeyChain: true,
          ),
        ],
        replaceByFee: false,
      );

      final tx = bdk.Psbt(psbtBase64: psbt).extractTx();
      final selectedInput = tx.input().firstWhere(
        (input) =>
            input.previousOutput.txid.toString() == utxoLargeTxId &&
            input.previousOutput.vout == utxoLargeVout,
      );

      expect(selectedInput.sequence, 0xFFFFFFFE);
    },
  );

  test(
    'buildPsbt keeps the default RBF sequence when replaceByFee is true',
    () async {
      final datasource = BdkWalletDatasource();

      final psbt = await datasource.buildPsbt(
        wallet: walletModel,
        address: _externalTestnetAddress,
        amountSat: 25000,
        networkFee: const NetworkFee.relativeSatPerKwu(1000),
        selected: [
          WalletUtxoModel.bitcoin(
            txId: utxoLargeTxId,
            vout: utxoLargeVout,
            amountSat: BigInt.from(utxoLargeAmountSat),
            scriptPubkey: Uint8List(0),
            address: '',
            isExternalKeyChain: true,
          ),
        ],
        replaceByFee: true,
      );

      final tx = bdk.Psbt(psbtBase64: psbt).extractTx();
      final selectedInput = tx.input().firstWhere(
        (input) =>
            input.previousOutput.txid.toString() == utxoLargeTxId &&
            input.previousOutput.vout == utxoLargeVout,
      );

      expect(selectedInput.sequence, 0xFFFFFFFD);
    },
  );

  // BDK has two exception types for a shortfall. Both must use Bull's stable
  // failure type for the applicable coin-selection mode.
  test(
    'buildPsbt reports more than the whole balance as insufficient funds',
    () async {
      final datasource = BdkWalletDatasource();

      await expectLater(
        datasource.buildPsbt(
          wallet: walletModel,
          address: _externalTestnetAddress,
          amountSat: utxoLargeAmountSat + utxoSmallAmountSat + 10000,
          networkFee: const NetworkFee.relativeSatPerKwu(1000),
        ),
        throwsA(isA<InsufficientFundsException>()),
      );
    },
  );

  // The amount fits the picked coin but not the fee. The large coin must be
  // unspendable too: `addUtxos` only makes a coin required, so BDK would
  // otherwise top the transaction up from it and never fall short.
  test('buildPsbt reports a selected-coin fee shortfall', () async {
    final datasource = BdkWalletDatasource();

    await expectLater(
      datasource.buildPsbt(
        wallet: walletModel,
        address: _externalTestnetAddress,
        amountSat: utxoSmallAmountSat,
        networkFee: const NetworkFee.relativeSatPerKwu(1000),
        selected: [
          WalletUtxoModel.bitcoin(
            txId: utxoLargeTxId,
            vout: utxoSmallVout,
            amountSat: BigInt.from(utxoSmallAmountSat),
            scriptPubkey: Uint8List(0),
            address: '',
            isExternalKeyChain: true,
          ),
        ],
        unspendable: [(txId: utxoLargeTxId, vout: utxoLargeVout)],
      ),
      throwsA(isA<SelectedBitcoinCoinsInsufficientException>()),
    );
  });
}
