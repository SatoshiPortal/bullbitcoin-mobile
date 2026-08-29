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
    'buildPsbt keeps the selected UTXO after rebuilding with a changed fee',
    () async {
      final datasource = BdkWalletDatasource();
      final selected = [
        WalletUtxoModel.bitcoin(
          txId: utxoLargeTxId,
          vout: utxoLargeVout,
          amountSat: BigInt.from(utxoLargeAmountSat),
          scriptPubkey: Uint8List(0),
          address: '',
          isExternalKeyChain: true,
        ),
      ];

      Future<bool> buildsWithSelectedUtxo(NetworkFee fee) async {
        final psbt = await datasource.buildPsbt(
          wallet: walletModel,
          address: _externalTestnetAddress,
          amountSat: 150000,
          networkFee: fee,
          selected: selected,
          replaceByFee: true,
        );

        final tx = bdk.Psbt(psbtBase64: psbt).extractTx();
        return tx.input().any(
          (input) =>
              input.previousOutput.txid.toString() == utxoLargeTxId &&
              input.previousOutput.vout == utxoLargeVout,
        );
      }

      expect(
        await buildsWithSelectedUtxo(const NetworkFee.relativeSatPerKwu(1000)),
        isTrue,
      );
      expect(
        await buildsWithSelectedUtxo(const NetworkFee.relativeSatPerKwu(5000)),
        isTrue,
      );
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
          amountSat: utxoLargeAmountSat + utxoSmallAmountSat + 10000,
          networkFee: const NetworkFee.relativeSatPerKwu(1000),
        ),
        throwsA(isA<InsufficientFundsException>()),
      );
    },
  );

  // The amount fits the picked coin but not the fee. Marking the large coin
  // unspendable is belt-and-braces here: `manuallySelectedOnly` already keeps
  // BDK from topping the transaction up, and the test below covers that on
  // its own.
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
          unspendable: [(txId: utxoLargeTxId, vout: utxoLargeVout)],
        ),
        throwsA(isA<InsufficientFundsException>()),
      );
    },
  );

  // The reported bug, reproduced with nothing marked unspendable.
  //
  // `addUtxos` makes a coin REQUIRED, not EXCLUSIVE, so BDK's coin selection stayed free to append any other wallet coin to cover the shortfall. Picking coins that fell a few hundred sats short of amount + fee therefore produced a valid, broadcastable PSBT that spent a coin the user had deliberately left unselected — linking its history to the selection under the common-input-ownership heuristic, irreversibly and on-chain.
  //
  // `manuallySelectedOnly` empties BDK's optional pool, so the shortfall has to surface as an error instead.
  test(
    'buildPsbt does not top up a short manual selection with an unselected coin',
    () async {
      final datasource = BdkWalletDatasource();

      await expectLater(
        datasource.buildPsbt(
          wallet: walletModel,
          address: _externalTestnetAddress,
          // Exactly the picked coin's value: covered before fees, short once
          // the fee lands — the shape of the original report (2 020 sats
          // selected for a 2 000 sat send at a ~500 sat fee).
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
          replaceByFee: true,
        ),
        throwsA(isA<InsufficientFundsException>()),
      );
    },
  );

  // The other half of the contract: restricting the pool must not make BDK
  // pad a selection that is genuinely sufficient.
  test(
    'buildPsbt spends only the selected coin when it covers amount and fee',
    () async {
      final datasource = BdkWalletDatasource();

      final psbt = await datasource.buildPsbt(
        wallet: walletModel,
        address: _externalTestnetAddress,
        // Leaves ~10 000 sats of headroom over the 30 000 sat coin, far more
        // than the fee at 4 sat/vB.
        amountSat: 20000,
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
        replaceByFee: true,
      );

      final inputs = bdk.Psbt(psbtBase64: psbt).extractTx().input();

      expect(
        inputs.length,
        1,
        reason:
            'a sufficient selection must be spent as-is, with no extra coin '
            'pulled in from the wallet',
      );
      expect(inputs.single.previousOutput.txid.toString(), utxoLargeTxId);
      expect(inputs.single.previousOutput.vout, utxoSmallVout);
    },
  );

  // Drain gets no carve-out from `manuallySelectedOnly`: BDK empties the
  // optional pool before `drain_wallet` folds it into the required set, so
  // draining with a selection spends — and drains — exactly the picked coins.
  // MAX with coin control means "MAX of the selection"; SendCubit derives the
  // displayed amount from the selection total to match.
  test(
    'buildPsbt drains only the selected coin when draining with a selection',
    () async {
      final datasource = BdkWalletDatasource();

      final psbt = await datasource.buildPsbt(
        wallet: walletModel,
        address: _externalTestnetAddress,
        networkFee: const NetworkFee.relativeSatPerKwu(1000),
        drain: true,
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
        replaceByFee: true,
      );

      final tx = bdk.Psbt(psbtBase64: psbt).extractTx();
      final inputs = tx.input();
      expect(
        inputs.length,
        1,
        reason:
            'a drain with a manual selection must spend only the picked '
            'coin, never the rest of the wallet',
      );
      expect(inputs.single.previousOutput.txid.toString(), utxoLargeTxId);
      expect(inputs.single.previousOutput.vout, utxoSmallVout);

      // A drain of one coin has a single output paying the coin's value
      // minus the fee — proving the drained amount comes from the
      // selection, not the whole wallet balance.
      final outputs = tx.output();
      expect(outputs.length, 1);
      final drainedSat = outputs.single.value.toSat();
      expect(drainedSat, lessThan(utxoSmallAmountSat));
      expect(
        drainedSat,
        greaterThan(utxoSmallAmountSat - 2000),
        reason:
            'the drain output must be the selected coin minus a plausible '
            'fee (~440 sats at 4 sat/vB for a 1-in-1-out P2WPKH tx)',
      );
    },
  );
}
