// Regression test for a bug where `BdkWalletDatasource.buildPsbt` silently
// dropped manual UTXO selection and the RBF-off sequence flag.
//
// bdk_dart's `TxBuilder` is an IMMUTABLE builder: every method (`addUtxos`,
// `setExactSequence`, `feeAbsolute`, `unspendable`, ...) returns a brand new
// `TxBuilder` instance rather than mutating the receiver in place. Two call
// sites in `buildPsbt` called `txBuilder.addUtxos(...)` and
// `txBuilder.setExactSequence(...)` without reassigning the result, so both
// calls were silent no-ops: BDK picked inputs on its own regardless of the
// user's manual coin selection, and the RBF-off toggle never took effect.
//
// This test exercises the real production method end-to-end against a real
// (offline, in-process) BDK wallet — no network, no mocked repository — so
// it proves the actual `TxBuilder` wiring, not just that a mock was called
// with the right arguments.
//
// Setup, fully deterministic and offline:
//   1. A fixed BIP84 testnet wallet (the canonical
//      "abandon ... abandon about" test mnemonic) is used to derive a
//      public (watch-only) descriptor pair — exactly what
//      `BitcoinWalletRepository.buildPsbt` passes down in production.
//   2. The wallet is "funded" by hand-crafting a raw funding transaction
//      with two outputs (to two of the wallet's own addresses) and applying
//      it as an unconfirmed transaction via `Wallet.applyUnconfirmedTxs`.
//      This is the standard offline way to seed known, deterministic UTXOs
//      into a BDK wallet without hitting a real Electrum server.
//   3. `path_provider`'s method channel is mocked to a temp directory so
//      `BdkFacade`'s sqlite-file persister (production code, untouched)
//      works under `flutter test`.
import 'dart:io';
import 'dart:typed_data';

import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_facade.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_utxo_model.dart';
import 'package:bb_mobile/core/wallet/domain/insufficient_funds_exception.dart';
import 'package:bb_mobile/core/wallet/domain/selected_inputs_unavailable_exception.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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
  // All test UTXOs share utxoLargeTxId (same funding tx); only vout differs.
  const utxoSmallVout = 1;
  const utxoOtherAmountSat = 50000;

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
              externalDescriptor: external.toString(),
              internalDescriptor: internal.toString(),
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
    final addr2 = wallet.revealNextAddress(
      keychain: bdk.KeychainKind.external_,
    );

    final fundingTxBytes = _buildFundingTx([
      (script: addr0.address.scriptPubkey(), amountSat: utxoLargeAmountSat),
      (script: addr1.address.scriptPubkey(), amountSat: utxoSmallAmountSat),
      (script: addr2.address.scriptPubkey(), amountSat: utxoOtherAmountSat),
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
      3,
      reason: 'test setup: expected exactly 3 synthetic UTXOs after funding',
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
    'buildPsbt honors manual UTXO selection: a manually selected UTXO must '
    'be spendable even when every other UTXO is frozen/unspendable',
    () async {
      final datasource = BdkWalletDatasource();

      // The LARGE utxo (200k) is marked unspendable — i.e. excluded from
      // BDK's own automatic coin-selection pool. It is ALSO the one
      // manually `selected` here, which per BDK's documented semantics
      // forces it into the transaction as a mandatory input REGARDLESS of
      // the unspendable flag.
      //
      // NOTE: this selected-overrides-unspendable behavior is raw BDK
      // semantics that this datasource deliberately preserves as a thin
      // wrapper — it is the INVERSE of the app-level D7 invariant ("a
      // frozen coin must never be spendable"). D7 is enforced one layer
      // up: BitcoinWalletRepository.buildPsbt strips selected ∩
      // unspendable before calling down (see
      // bitcoin_wallet_repository_test.dart), and
      // PrepareBitcoinSendUsecase additionally strips frozen coins from
      // the selection. The combination is exploited here ONLY because it
      // is a deterministic discriminator for the addUtxos-reassignment
      // regression, with no dependency on BDK's coin-selection
      // heuristics.
      //
      // The only utxo left in the automatic pool is the SMALL one (30k),
      // which alone cannot cover the 150k send. This makes the two code
      // paths unambiguous, with no dependency on BDK's coin-selection
      // tie-breaking heuristics:
      //   * Fixed code: `addUtxos` really runs, forcing the large utxo in
      //     -> the build succeeds and spends it.
      //   * Buggy code (return value of `addUtxos` discarded): no utxo is
      //     forced in; BDK's automatic selection is left with only the
      //     30k utxo, which can't cover 150k -> the build throws.
      const sendAmountSat = 150000; // only the large (200k) utxo covers this
      final psbt = await datasource.buildPsbt(
        wallet: walletModel,
        address: _externalTestnetAddress,
        amountSat: sendAmountSat,
        networkFee: const NetworkFee.relativeSatPerKwu(1000), // 4 sat/vB
        unspendable: [(txId: utxoLargeTxId, vout: utxoLargeVout)],
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
      final spendsLargeUtxo = tx.input().any(
        (input) =>
            input.previousOutput.txid.toString() == utxoLargeTxId &&
            input.previousOutput.vout == utxoLargeVout,
      );

      expect(
        spendsLargeUtxo,
        isTrue,
        reason:
            'the manually selected UTXO must be forced into the built '
            'transaction even though it is also marked unspendable for '
            "BDK's own automatic selection",
      );
    },
  );

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

  // BDK has two exception types for a shortfall and doesn't say which it uses
  // when, so these pin it against the real builder: either must arrive as
  // InsufficientFundsException.
  test(
    'buildPsbt reports more than the whole balance as insufficient funds',
    () async {
      final datasource = BdkWalletDatasource();

      await expectLater(
        datasource.buildPsbt(
          wallet: walletModel,
          address: _externalTestnetAddress,
          amountSat:
              utxoLargeAmountSat +
              utxoSmallAmountSat +
              utxoOtherAmountSat +
              10000,
          networkFee: const NetworkFee.relativeSatPerKwu(1000),
        ),
        throwsA(isA<InsufficientFundsException>()),
      );
    },
  );

  // The amount fits the picked coin but not the fee. The other coins must be
  // unspendable: `addUtxos` only makes a coin required, so BDK would otherwise
  // top the transaction up from them and never fall short.
  test(
    'buildPsbt reports a fee-only shortfall as insufficient funds',
    () async {
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
          unspendable: [
            (txId: utxoLargeTxId, vout: utxoLargeVout),
            (txId: utxoLargeTxId, vout: 2),
          ],
        ),
        throwsA(isA<InsufficientFundsException>()),
      );
    },
  );

  test(
    'buildPsbt drains exactly the manually selected UTXOs to one recipient',
    () async {
      const feeSat = 1000;
      final datasource = BdkWalletDatasource();

      final psbt = await datasource.buildPsbt(
        wallet: walletModel,
        address: _externalTestnetAddress,
        networkFee: const NetworkFee.absolute(feeSat),
        drain: true,
        selectedOnly: true,
        selected: [
          WalletUtxoModel.bitcoin(
            txId: utxoLargeTxId,
            vout: utxoLargeVout,
            amountSat: BigInt.from(utxoLargeAmountSat),
            scriptPubkey: Uint8List(0),
            address: '',
            isExternalKeyChain: true,
          ),
          WalletUtxoModel.bitcoin(
            txId: utxoLargeTxId,
            vout: 1,
            amountSat: BigInt.from(utxoSmallAmountSat),
            scriptPubkey: Uint8List(0),
            address: '',
            isExternalKeyChain: true,
          ),
        ],
      );

      final parsed = bdk.Psbt(psbtBase64: psbt);
      final tx = parsed.extractTx();
      final inputs = tx.input();
      final outputs = tx.output();
      final recipientScript = bdk.Address(
        address: _externalTestnetAddress,
        network: bdk.Network.testnet,
      ).scriptPubkey();

      expect(inputs, hasLength(2));
      expect(
        {
          for (final input in inputs)
            (
              txId: input.previousOutput.txid.toString(),
              vout: input.previousOutput.vout,
            ),
        },
        {
          (txId: utxoLargeTxId, vout: utxoLargeVout),
          (txId: utxoLargeTxId, vout: 1),
        },
      );
      expect(outputs, hasLength(1));
      expect(
        outputs.single.value.toSat(),
        utxoLargeAmountSat + utxoSmallAmountSat - feeSat,
      );
      expect(outputs.single.scriptPubkey.toBytes(), recipientScript.toBytes());

      tx.dispose();
      parsed.dispose();
    },
  );

  test(
    'buildPsbt never treats an empty exact selection as a wallet drain',
    () async {
      final datasource = BdkWalletDatasource();

      await expectLater(
        datasource.buildPsbt(
          wallet: walletModel,
          address: _externalTestnetAddress,
          networkFee: const NetworkFee.absolute(1000),
          drain: true,
          selectedOnly: true,
          selected: const [],
        ),
        throwsA(isA<SelectedInputsUnavailableException>()),
      );
    },
  );
}
