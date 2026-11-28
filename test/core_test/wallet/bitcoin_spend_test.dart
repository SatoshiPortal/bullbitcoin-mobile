import 'package:sync/storage.dart' show SyncWalletValuesDatasource;
import 'package:sync/testing.dart';

import '../../../features/send/test/payment/testing/legacy_spend_fixture.dart';

// Regression test for a bug where `wallet.tx.build` silently
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

import 'package:fees/fees.dart';

import 'support/bdk_test_store.dart';
import 'support/sync_spend_fixture.dart';

import 'package:primitives/primitives.dart' show BitcoinNetwork, Err, Ok;
import 'package:sync/sync.dart'
    show
        SyncInsufficientFundsFailure,
        SyncNoSpendableInputsFailure,
        SyncProtectedInputsFailure;
import 'package:sync/sync.dart' as sync;

import 'support/wallet_model.dart';

import 'package:rust_bindings/bdk.dart' as bdk;
import 'package:flutter/foundation.dart';
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

List<({String address, int? amountSat})> _fixedRecipients(int amountSat) => [
  (address: _externalTestnetAddress, amountSat: amountSat),
];

final _remainderRecipients = <({String address, int? amountSat})>[
  (address: _externalTestnetAddress, amountSat: null),
];

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
  late SyncSpendFixture fixture;
  late PublicBdkWalletModel walletModel;
  late String utxoLargeTxId;
  late int utxoLargeVout;
  late String firstRecipientAddress;
  late String secondRecipientAddress;

  const utxoLargeAmountSat = 200000;
  const utxoSmallAmountSat = 30000;
  // All test UTXOs share utxoLargeTxId (same funding tx); only vout differs.
  const utxoSmallVout = 1;
  const utxoOtherAmountSat = 50000;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('bitcoin_spend_');
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

    walletModel = WalletModel.publicBdk(
      id: 'bdk-wallet-datasource-test',
      externalDescriptor: external.toString(),
      internalDescriptor: internal.toString(),
      network: BitcoinNetwork.testnet,
    ) as PublicBdkWalletModel;

    // Build the wallet once here to fund it, then persist so the
    // datasource's own (separate) `BdkTestStore.createWallet` call sees the
    // exact same UTXOs when the test invokes `buildPsbt`.
    final wallet = await BdkTestStore.createWallet(walletModel);

    final addr0 = wallet.revealNextAddress(
      keychain: bdk.KeychainKind.external_,
    );
    final addr1 = wallet.revealNextAddress(
      keychain: bdk.KeychainKind.external_,
    );
    final addr2 = wallet.revealNextAddress(
      keychain: bdk.KeychainKind.external_,
    );
    firstRecipientAddress = addr0.address.toString();
    secondRecipientAddress = wallet
        .revealNextAddress(keychain: bdk.KeychainKind.external_)
        .address
        .toString();

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

    await BdkTestStore.saveWallet(wallet, walletModel.hexId);

    // The same wallet and funding in sync's store, where spends are built.
    fixture = await SyncSpendFixture.open(tempDir.path, walletModel);
    fixture.onStore((store) {
      for (var i = 0; i < 4; i++) {
        store.revealNextAddress(keychain: bdk.KeychainKind.external_);
      }
      store.applyUnconfirmedTxs(
        unconfirmedTxs: [
          bdk.UnconfirmedTx(
            tx: bdk.Transaction(transactionBytes: fundingTxBytes),
            lastSeen: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        ],
      );
    });
  });

  tearDown(() async {
    await fixture.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('last revealed index read does not reveal an address', () async {
    final native = await BdkTestStore.createWallet(walletModel);
    final wallet = await testWalletFromNative(
      native,
      key: sync.WalletKey(id: walletModel.id, network: walletModel.network),
    );
    final before = native.nextDerivationIndex(
      keychain: bdk.KeychainKind.external_,
    );
    expect(wallet.addresses.book.now.data?.receiveIndex, before - 1);
    expect(
      native.nextDerivationIndex(keychain: bdk.KeychainKind.external_),
      before,
    );
  });

  test('load mismatch preserves the existing native store', () async {
    final file = File('${tempDir.path}/${walletModel.hexId}_bdk_dart');
    final before = await file.readAsBytes();
    final mismatched = WalletModel.publicBdk(
      id: walletModel.id,
      externalDescriptor: walletModel.internalDescriptor,
      internalDescriptor: walletModel.externalDescriptor,
      network: BitcoinNetwork.testnet,
    );
    await expectLater(BdkTestStore.createWallet(mismatched), throwsA(anything));
    expect(await file.readAsBytes(), before);
  });

  test('checks multiple addresses against one wallet', () async {
    final datasource = SyncWalletValuesDatasource(
      load: (key) async => testWalletFromNative(
        await BdkTestStore.createWallet(walletModel),
        key: key,
      ),
    );

    final key = sync.WalletKey(
      id: walletModel.id,
      network: walletModel.network,
    );

    expect(
      await datasource.areAddressesMine([
        firstRecipientAddress,
        secondRecipientAddress,
      ], key: key),
      isTrue,
    );
    expect(
      await datasource.areAddressesMine([
        firstRecipientAddress,
        _externalTestnetAddress,
      ], key: key),
      isFalse,
    );
  });

  test(
    'buildPsbt refuses a selected coin the request excludes: exclusions only '
    'narrow what sync may spend',
    () async {
      final datasource = _Datasource(fixture);

      // BDK alone lets a manually added coin override its unspendable list.
      // Sync checks the effective inputs after the build and refuses one the
      // request excluded, so an exclusion can never be bypassed.
      await expectLater(
        datasource.buildPsbt(
          wallet: walletModel,
          recipients: _fixedRecipients(150000),
          networkFee: const NetworkFee.relativeSatPerKwu(1000),
          unspendable: [(txId: utxoLargeTxId, vout: utxoLargeVout)],
          selected: [(txId: utxoLargeTxId, vout: utxoLargeVout)],
          replaceByFee: true,
        ),
        throwsA(isA<StateError>()),
      );
    },
  );

  test(
    'buildPsbt sets a non-RBF sequence when replaceByFee is false',
    () async {
      final datasource = _Datasource(fixture);

      final psbt = await datasource.buildPsbt(
        wallet: walletModel,
        recipients: _fixedRecipients(25000),
        networkFee: const NetworkFee.relativeSatPerKwu(1000),
        selected: [(txId: utxoLargeTxId, vout: utxoLargeVout)],
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
      final datasource = _Datasource(fixture);

      final psbt = await datasource.buildPsbt(
        wallet: walletModel,
        recipients: _fixedRecipients(25000),
        networkFee: const NetworkFee.relativeSatPerKwu(1000),
        selected: [(txId: utxoLargeTxId, vout: utxoLargeVout)],
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

  test('buildPsbt spends only the selected input and returns change', () async {
    const sendAmountSat = 50000;
    const feeSat = 1000;
    final datasource = _Datasource(fixture);

    final psbt = await datasource.buildPsbt(
      wallet: walletModel,
      recipients: _fixedRecipients(sendAmountSat),
      networkFee: const NetworkFee.absolute(feeSat),
      selectedOnly: true,
      selected: [(txId: utxoLargeTxId, vout: utxoLargeVout)],
    );

    final parsed = bdk.Psbt(psbtBase64: psbt);
    final tx = parsed.extractTx();
    final inputs = tx.input();
    final outputs = tx.output();
    final recipientScript = bdk.Address(
      address: _externalTestnetAddress,
      network: bdk.Network.testnet,
    ).scriptPubkey();

    expect(inputs, hasLength(1));
    expect(inputs.single.previousOutput.txid.toString(), utxoLargeTxId);
    expect(inputs.single.previousOutput.vout, utxoLargeVout);
    expect(outputs, hasLength(2));
    expect(
      outputs
          .singleWhere(
            (output) => listEquals(
              output.scriptPubkey.toBytes(),
              recipientScript.toBytes(),
            ),
          )
          .value
          .toSat(),
      sendAmountSat,
    );
    expect(
      outputs.fold(0, (total, output) => total + output.value.toSat()),
      utxoLargeAmountSat - feeSat,
    );

    tx.dispose();
    parsed.dispose();
  });

  // BDK has two exception types for a shortfall and doesn't say which it uses
  // when, so these pin it against the real builder: either must arrive as
  // InsufficientFundsException.
  test(
    'buildPsbt reports more than the whole balance as insufficient funds',
    () async {
      final datasource = _Datasource(fixture);

      await expectLater(
        datasource.buildPsbt(
          wallet: walletModel,
          recipients: _fixedRecipients(
            utxoLargeAmountSat +
                utxoSmallAmountSat +
                utxoOtherAmountSat +
                10000,
          ),
          networkFee: const NetworkFee.relativeSatPerKwu(1000),
        ),
        throwsA(isA<InsufficientFundsException>()),
      );
    },
  );

  test('buildPsbt reports an aggregate multi-recipient shortfall', () async {
    final datasource = _Datasource(fixture);

    await expectLater(
      datasource.buildPsbt(
        wallet: walletModel,
        recipients: [
          (address: _externalTestnetAddress, amountSat: 150000),
          (address: secondRecipientAddress, amountSat: 140000),
        ],
        networkFee: const NetworkFee.relativeSatPerKwu(1000),
      ),
      throwsA(isA<InsufficientFundsException>()),
    );
  });

  // The amount fits the picked coin but not the fee. The other coins must be
  // unspendable: `addUtxos` only makes a coin required, so BDK would otherwise
  // top the transaction up from them and never fall short.
  test(
    'buildPsbt reports a fee-only shortfall as insufficient funds',
    () async {
      final datasource = _Datasource(fixture);

      await expectLater(
        datasource.buildPsbt(
          wallet: walletModel,
          recipients: _fixedRecipients(utxoSmallAmountSat),
          networkFee: const NetworkFee.relativeSatPerKwu(1000),
          selected: [(txId: utxoLargeTxId, vout: utxoSmallVout)],
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
      final datasource = _Datasource(fixture);

      final psbt = await datasource.buildPsbt(
        wallet: walletModel,
        recipients: _remainderRecipients,
        networkFee: const NetworkFee.absolute(feeSat),
        selectedOnly: true,
        selected: [
          (txId: utxoLargeTxId, vout: utxoLargeVout),
          (txId: utxoLargeTxId, vout: 1),
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

  test('buildPsbt creates every fixed recipient and wallet change', () async {
    const firstAmountSat = 25000;
    const secondAmountSat = 30000;
    const feeSat = 1000;
    final datasource = _Datasource(fixture);

    final psbt = await datasource.buildPsbt(
      wallet: walletModel,
      recipients: [
        (address: _externalTestnetAddress, amountSat: firstAmountSat),
        (address: secondRecipientAddress, amountSat: secondAmountSat),
      ],
      networkFee: const NetworkFee.absolute(feeSat),
    );

    final parsed = bdk.Psbt(psbtBase64: psbt);
    final tx = parsed.extractTx();
    final firstScript = bdk.Address(
      address: _externalTestnetAddress,
      network: bdk.Network.testnet,
    ).scriptPubkey();
    final secondScript = bdk.Address(
      address: secondRecipientAddress,
      network: bdk.Network.testnet,
    ).scriptPubkey();

    expect(tx.output(), hasLength(3));
    expect(
      tx.output().where(
        (output) =>
            listEquals(output.scriptPubkey.toBytes(), firstScript.toBytes()),
      ),
      hasLength(1),
    );
    expect(
      tx
          .output()
          .singleWhere(
            (output) => listEquals(
              output.scriptPubkey.toBytes(),
              firstScript.toBytes(),
            ),
          )
          .value
          .toSat(),
      firstAmountSat,
    );
    expect(
      tx
          .output()
          .singleWhere(
            (output) => listEquals(
              output.scriptPubkey.toBytes(),
              secondScript.toBytes(),
            ),
          )
          .value
          .toSat(),
      secondAmountSat,
    );
    expect(parsed.fee(), feeSat);

    tx.dispose();
    parsed.dispose();
  });

  test(
    'buildPsbt gives the selected-input remainder to its recipient',
    () async {
      const fixedAmountSat = 50000;
      const feeSat = 1000;
      final datasource = _Datasource(fixture);

      final psbt = await datasource.buildPsbt(
        wallet: walletModel,
        recipients: [
          (address: secondRecipientAddress, amountSat: null),
          (address: _externalTestnetAddress, amountSat: fixedAmountSat),
        ],
        networkFee: const NetworkFee.absolute(feeSat),
        selectedOnly: true,
        selected: [
          (txId: utxoLargeTxId, vout: utxoLargeVout),
          (txId: utxoLargeTxId, vout: utxoSmallVout),
        ],
      );

      final parsed = bdk.Psbt(psbtBase64: psbt);
      final tx = parsed.extractTx();
      final remainderScript = bdk.Address(
        address: secondRecipientAddress,
        network: bdk.Network.testnet,
      ).scriptPubkey();
      final remainder = tx.output().singleWhere(
        (output) => listEquals(
          output.scriptPubkey.toBytes(),
          remainderScript.toBytes(),
        ),
      );

      expect(tx.input(), hasLength(2));
      expect(tx.output(), hasLength(2));
      expect(
        remainder.value.toSat(),
        utxoLargeAmountSat + utxoSmallAmountSat - fixedAmountSat - feeSat,
      );
      expect(parsed.fee(), feeSat);

      tx.dispose();
      parsed.dispose();
    },
  );

  test('buildPsbt recalculates the remainder when the fee changes', () async {
    const fixedAmountSat = 50000;
    final datasource = _Datasource(fixture);
    final selected = [(txId: utxoLargeTxId, vout: utxoLargeVout)];
    final recipients = [
      (address: _externalTestnetAddress, amountSat: fixedAmountSat),
      (address: secondRecipientAddress, amountSat: null),
    ];

    final lowFeePsbt = await datasource.buildPsbt(
      wallet: walletModel,
      recipients: recipients,
      networkFee: const NetworkFee.absolute(1000),
      selectedOnly: true,
      selected: selected,
    );
    final highFeePsbt = await datasource.buildPsbt(
      wallet: walletModel,
      recipients: recipients,
      networkFee: const NetworkFee.absolute(2000),
      selectedOnly: true,
      selected: selected,
    );

    final lowFeeAmounts = await datasource.getRecipientAmounts(
      lowFeePsbt,
      recipients,
      network: BitcoinNetwork.testnet,
    );
    final highFeeAmounts = await datasource.getRecipientAmounts(
      highFeePsbt,
      recipients,
      network: BitcoinNetwork.testnet,
    );
    expect(lowFeeAmounts.first, fixedAmountSat);
    expect(highFeeAmounts.first, fixedAmountSat);
    expect(lowFeeAmounts[1] - highFeeAmounts[1], 1000);
  });

  test('reports an uppercase Bech32 remainder by script', () async {
    const feeSat = 1000;
    final datasource = _Datasource(fixture);
    final recipients = [
      (address: _externalTestnetAddress.toUpperCase(), amountSat: null),
    ];

    final psbt = await datasource.buildPsbt(
      wallet: walletModel,
      recipients: recipients,
      networkFee: const NetworkFee.absolute(feeSat),
      selectedOnly: true,
      selected: [(txId: utxoLargeTxId, vout: utxoLargeVout)],
    );

    expect(
      await datasource.getRecipientAmounts(
        psbt,
        recipients,
        network: BitcoinNetwork.testnet,
      ),
      [utxoLargeAmountSat - feeSat],
    );
  });

  test(
    'separates fixed and remainder amounts sent to the same script',
    () async {
      const fixedAmountSat = 50000;
      const secondFixedAmountSat = 20000;
      const feeSat = 1000;
      final datasource = _Datasource(fixture);
      final recipients = [
        (address: _externalTestnetAddress, amountSat: fixedAmountSat),
        (
          address: _externalTestnetAddress.toUpperCase(),
          amountSat: secondFixedAmountSat,
        ),
        (address: _externalTestnetAddress.toUpperCase(), amountSat: null),
      ];

      final psbt = await datasource.buildPsbt(
        wallet: walletModel,
        recipients: recipients,
        networkFee: const NetworkFee.absolute(feeSat),
        selectedOnly: true,
        selected: [(txId: utxoLargeTxId, vout: utxoLargeVout)],
      );

      expect(
        await datasource.getRecipientAmounts(
          psbt,
          recipients,
          network: BitcoinNetwork.testnet,
        ),
        [
          fixedAmountSat,
          secondFixedAmountSat,
          utxoLargeAmountSat - fixedAmountSat - secondFixedAmountSat - feeSat,
        ],
      );
    },
  );

  test('buildPsbt rejects a fixed output below dust', () async {
    final datasource = _Datasource(fixture);

    await expectLater(
      datasource.buildPsbt(
        wallet: walletModel,
        recipients: [(address: _externalTestnetAddress, amountSat: 1)],
        networkFee: const NetworkFee.absolute(1000),
      ),
      throwsA(isA<InsufficientFundsException>()),
    );
  });

  test('buildPsbt rejects a dust remainder', () async {
    final datasource = _Datasource(fixture);

    await expectLater(
      datasource.buildPsbt(
        wallet: walletModel,
        recipients: [
          (address: _externalTestnetAddress, amountSat: 28800),
          (address: secondRecipientAddress, amountSat: null),
        ],
        networkFee: const NetworkFee.absolute(1000),
        selectedOnly: true,
        selected: [(txId: utxoLargeTxId, vout: utxoSmallVout)],
      ),
      throwsA(isA<InsufficientFundsException>()),
    );
  });

  test(
    'buildPsbt never treats an empty exact selection as a wallet drain',
    () async {
      final datasource = _Datasource(fixture);

      await expectLater(
        datasource.buildPsbt(
          wallet: walletModel,
          recipients: _remainderRecipients,
          networkFee: const NetworkFee.absolute(1000),
          selectedOnly: true,
          selected: const [],
        ),
        throwsA(isA<NoSpendableUtxoException>()),
      );
    },
  );
}

/// The datasource over sync's writer, with its failures thrown as the
/// exceptions these tests name.
final class _Datasource {
  final SyncSpendFixture _fixture;
  _Datasource(this._fixture);

  Future<String> buildPsbt({
    required List<({String address, int? amountSat})> recipients,
    required NetworkFee networkFee,
    List<({String txId, int vout})>? unspendable,
    List<({String txId, int vout})>? selected,
    bool selectedOnly = false,
    bool replaceByFee = true,
    required WalletModel wallet,
  }) async => switch (await (await _fixture.wallet(wallet.id)).tx.build(
    sync.BitcoinSpendRequest(
      recipients: [
        for (final recipient in recipients)
          sync.SpendRecipient(
            recipient.address,
            amountSat: recipient.amountSat,
          ),
      ],
      fee: switch (networkFee) {
        AbsoluteFee(:final sats) => sync.SpendAbsoluteFee(sats),
        RelativeFee(:final satPerKwu) => sync.SpendFeeRate(satPerKwu),
      },
      exclude: {...?unspendable},
      selected: selected,
      selectedOnly: selectedOnly,
      replaceable: replaceByFee,
    ),
  )) {
    Ok(:final value) => value.encoded,
    Err(failure: SyncInsufficientFundsFailure()) =>
      throw InsufficientFundsException('insufficient funds'),
    Err(failure: SyncNoSpendableInputsFailure()) ||
    Err(
      failure: SyncProtectedInputsFailure(),
    ) => throw NoSpendableUtxoException('no spendable input'),
    Err(:final failure) => throw StateError(failure.logCode),
  };

  Future<List<int>> getRecipientAmounts(
    String psbt,
    List<({String address, int? amountSat})> recipients, {
    required BitcoinNetwork network,
  }) async => switch (await sync.bitcoinRecipientAmounts(
    psbt: psbt,
    network: network,
    recipients: [
      for (final recipient in recipients)
        (address: recipient.address, amountSat: recipient.amountSat),
    ],
  )) {
    Ok(:final value) => value,
    Err(:final failure) => throw StateError(failure.logCode),
  };

  Future<int> getAmountSentToAddress(
    String psbt,
    String address, {
    required BitcoinNetwork network,
  }) async => (await getRecipientAmounts(psbt, [
    (address: address, amountSat: null),
  ], network: network)).single;
}
