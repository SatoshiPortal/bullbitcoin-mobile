import 'dart:io';
import 'dart:typed_data';

import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/src/data/datasources/spend_gate_store_datasource.dart';
import 'package:sync/src/data/native_store_paths.dart';
import 'package:sync/src/data/write/datasources/bdk_wallet_store_datasource.dart';
import 'package:sync/src/data/write/spend/native_spend.dart';
import 'package:sync/sync.dart';
import 'package:sync/testing.dart' show MemoryFreezeStore;
import 'package:sync/write.dart';

import '../support/connections.dart';
import '../support/funding_reservations.dart';
import '../support/regtest_wallet.dart';

// The prototype's protocol on the real BDK builder: abandoned previews and
// bumps reveal no new change index, because each command opens the wallet
// fresh from its store. The funding transaction is synthetic and nothing
// reaches a network.

/// BIP173's regtest P2WPKH vector, outside the test wallet.
const _recipient = 'bcrt1qw508d6qejxtdg4y5r3zarvary0c5xw7kygt080';

/// The SDK sessions, with the signature check of the original answered
/// valid: its verifier lives in the Rust library unit tests do not build.
final class _Sessions implements NativeSpendSessions {
  final SdkSpendSessions _sdk;
  _Sessions(String root) : _sdk = SdkSpendSessions(root);

  @override
  Future<NativeBitcoinSpend> bitcoin(
    BitcoinWalletDescriptor descriptor,
  ) async => _Verified(await _sdk.bitcoin(descriptor));

  @override
  Future<NativeLiquidSpend> liquid(LiquidWalletDescriptor descriptor) =>
      _sdk.liquid(descriptor);

  @override
  List<Outpoint> psetInputs(String pset) => _sdk.psetInputs(pset);

  @override
  Future<Result<LiquidNetwork, SyncFailure>> liquidAddressNetwork(
    String address,
  ) => _sdk.liquidAddressNetwork(address);
}

final class _Verified implements NativeBitcoinSpend {
  final NativeBitcoinSpend _native;
  _Verified(this._native);

  @override
  Future<SignatureCheck> originalSignatures(String txid) async =>
      _native.transactionInputs(txid) == null
      ? SignatureCheck.unverifiable
      : SignatureCheck.valid;

  @override
  Set<Outpoint> unspent() => _native.unspent();
  @override
  List<Outpoint>? transactionInputs(String txid) =>
      _native.transactionInputs(txid);
  @override
  BuiltTransaction build(BitcoinSpendRequest request, Set<Outpoint> excluded) =>
      _native.build(request, excluded);
  @override
  BuiltTransaction bumpFee(String txid, SpendFeeRate fee) =>
      _native.bumpFee(txid, fee);
  @override
  bool paysAsRequested(String psbt, BitcoinSpendRequest request) =>
      _native.paysAsRequested(psbt, request);
  @override
  bool keepsPayees(String psbt, String txid) => _native.keepsPayees(psbt, txid);
  @override
  String annotate(String psbt) => _native.annotate(psbt);
  @override
  bool persist() => _native.persist();
  @override
  void close() => _native.close();
}

final class _NoReservations implements InputReservationPort {
  @override
  Future<Result<List<InputReservation>, SyncFailure>> reservations() async =>
      const Ok([]);
}

/// A transaction paying [amounts] to [scripts], from an unknown outpoint.
bdk.Transaction _funding(List<Uint8List> scripts, List<int> amounts) {
  final bytes = BytesBuilder()
    ..add([2, 0, 0, 0, 1])
    ..add(List.filled(32, 0x11))
    ..add([0, 0, 0, 0, 0, 0xff, 0xff, 0xff, 0xff, scripts.length]);
  for (var index = 0; index < scripts.length; index++) {
    final value = ByteData(8)..setUint64(0, amounts[index], Endian.little);
    bytes
      ..add(value.buffer.asUint8List())
      ..add([scripts[index].length])
      ..add(scripts[index]);
  }
  bytes.add([0, 0, 0, 0]);
  return bdk.Transaction(transactionBytes: bytes.toBytes());
}

/// Signs [psbt] with the published vector's keys, in memory.
String _sign(String psbt) {
  final mnemonic = bdk.Mnemonic.fromString(
    mnemonic:
        'abandon abandon abandon abandon abandon abandon abandon abandon '
        'abandon abandon abandon about',
  );
  final secret = bdk.DescriptorSecretKey(
    networkKind: bdk.NetworkKind.test,
    mnemonic: mnemonic,
    password: null,
  );
  bdk.Descriptor derive(bdk.KeychainKind keychain) => bdk.Descriptor.newBip84(
    secretKey: secret,
    keychainKind: keychain,
    networkKind: bdk.NetworkKind.test,
  );
  final persister = bdk.Persister.newInMemory();
  final wallet = bdk.Wallet(
    descriptor: derive(bdk.KeychainKind.external_),
    changeDescriptor: derive(bdk.KeychainKind.internal),
    network: bdk.Network.regtest,
    persister: persister,
    lookahead: 25,
  );
  final parsed = bdk.Psbt(psbtBase64: psbt);
  try {
    wallet.sign(
      psbt: parsed,
      signOptions: bdk.SignOptions(
        trustWitnessUtxo: true,
        allowAllSighashes: false,
        tryFinalize: true,
        signWithTapInternalKey: false,
        allowGrinding: true,
      ),
    );
    return parsed.serialize();
  } finally {
    parsed.dispose();
    wallet.dispose();
    persister.dispose();
    secret.dispose();
    mnemonic.dispose();
  }
}

void main() {
  late Directory dir;
  late ForegroundStores stores;
  late BitcoinWalletDescriptor descriptor;
  late SqliteFundingReservations funding;
  final sent = <SignedTransaction>[];

  T ok<T>(Result<T, SyncFailure> result) => switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => fail('Unexpected ${failure.logCode}'),
  };

  /// Runs [body] on the store as a sync pass would, then persists.
  void onStore(void Function(bdk.Wallet wallet) body) {
    final store = BdkWalletStoreDatasource.load(
      nativeWalletStoragePath(dir.path, descriptor.key),
      descriptor,
    );
    try {
      body(store.wallet);
      store.persist();
    } finally {
      store.close();
    }
  }

  int? changeIndex() {
    int? index;
    onStore(
      (wallet) =>
          index = wallet.derivationIndex(keychain: bdk.KeychainKind.internal),
    );
    return index;
  }

  Uint8List changeScript(UnsignedSpend spend) {
    final recipient = bitcoinAddressScript(_recipient, BitcoinNetwork.regtest);
    final script = (recipient as Ok<Uint8List, SyncFailure>).value;
    return decodeBitcoinPsbt(spend.encoded).outputs
        .singleWhere(
          (output) =>
              output.scriptPubkey.length != script.length ||
              !Iterable.generate(script.length)
                  .every((i) => output.scriptPubkey[i] == script[i]),
        )
        .scriptPubkey;
  }

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('spend-native-');
    descriptor = regtestDescriptor();
    funding = SqliteFundingReservations('${dir.path}/funding.sqlite');
    sent.clear();
    stores = openForeground(
      documentsDirectory: dir.path,
      catalog: SingleWalletCatalog(descriptor),
      reservedAddresses: NoReservedAddresses(),
      freezes: MemoryFreezeStore(),
      inputReservations: _NoReservations(),
      fundingReservations: funding,
      connections: FixtureConnections(const []),
      spendSessions: _Sessions(dir.path),
      spendTransport: (transaction, network) async {
        sent.add(transaction);
        return switch (transaction) {
          SignedBitcoinTransaction(:final bytes) => Ok(
            decodeBitcoinTransaction(bytes).txid,
          ),
          _ => const Err(SyncInvalidTransactionFailure()),
        };
      },
    );
    ok(await stores.writer.create(descriptor.key, expectedGeneration: 0));
    onStore((wallet) {
      final scripts = [
        for (var index = 0; index < 2; index++)
          wallet
              .peekAddress(keychain: bdk.KeychainKind.external_, index: index)
              .address
              .scriptPubkey()
              .toBytes(),
      ];
      wallet.applyUnconfirmedTxs(
        unconfirmedTxs: [
          bdk.UnconfirmedTx(
            tx: _funding(scripts, [1000000, 400000]),
            lastSeen: 1,
          ),
        ],
      );
    });
  });

  tearDown(() async {
    await stores.close();
    funding.close();
    dir.deleteSync(recursive: true);
  });

  Future<int> generation() async =>
      ok(await stores.revisions.read(descriptor.key)).stamp.generation;

  test(
    'real BDK funding stays unfinalised and reserved through owner broadcast',
    () async {
      final key = descriptor.key;
      final owner = SpendOwner(protocol: 'ark', session: 'native-board');
      final sync = Sync.foreground(
        documentsDirectory: dir.path,
        catalog: SingleWalletCatalog(descriptor),
        reservedAddresses: NoReservedAddresses(),
        freezes: MemoryFreezeStore(),
        inputReservations: _NoReservations(),
        fundingReservations: funding,
        connections: FixtureConnections(const []),
      );
      late UnsignedSpend spend;
      try {
        final wallet = ok(await sync.wallet(key));
        spend = ok(
          await wallet.tx.prepareFunding(
            BitcoinSpendRequest(
              recipients: [SpendRecipient(_recipient, amountSat: 10000)],
              fee: SpendFeeRate(500),
              owner: owner,
            ),
            context: 'board-output:0',
          ),
        );
      } finally {
        await sync.close();
      }
      final parsed = bdk.Psbt(psbtBase64: spend.encoded);
      try {
        expect(parsed.input(), isNotEmpty);
        for (final input in parsed.input()) {
          expect(input.finalScriptSig, isNull);
          expect(input.finalScriptWitness, isNull);
          expect(input.partialSigs, isEmpty);
          expect(input.witnessUtxo?.scriptPubkey.toBytes().take(2), [0, 20]);
        }
      } finally {
        parsed.dispose();
      }
      expect(funding.encoded, spend.encoded);
      final signed = _sign(spend.encoded);
      expect(
        decodeBitcoinPsbt(signed).txid,
        decodeBitcoinPsbt(spend.encoded).txid,
      );
      final attempted = await stores.spend.build(
        key,
        await generation(),
        BitcoinSpendRequest(
          recipients: [SpendRecipient(_recipient, amountSat: 10000)],
          fee: SpendFeeRate(500),
          selected: spend.inputs,
          selectedOnly: true,
        ),
      );
      expect(attempted, isA<Err<UnsignedSpend, SyncFailure>>());
      expect(
        (attempted as Err<UnsignedSpend, SyncFailure>).failure,
        isA<SyncProtectedInputsFailure>(),
      );
      final receipt = ok(
        await stores.spend.broadcast(spend.signed(SignedPsbt(signed))),
      );
      expect(receipt.durable, isTrue);
      expect(sent, hasLength(1));
    },
  );

  test('abandoned previews and bumps reveal no new change index', () async {
    final key = descriptor.key;
    final request = BitcoinSpendRequest(
      recipients: [SpendRecipient(_recipient, amountSat: 10000)],
      fee: SpendFeeRate(500),
    );
    final previews = [
      for (var i = 0; i < 100; i++)
        ok(await stores.spend.build(key, await generation(), request)),
    ];
    final first = changeScript(previews.first);
    for (final preview in previews) {
      expect(changeScript(preview), first);
    }
    expect(changeIndex(), 0);

    // The 101st is signed and broadcast; a sync then sees it.
    final spend = ok(
      await stores.spend.build(key, await generation(), request),
    );
    expect(changeScript(spend), first);
    final signed = _sign(spend.encoded);
    final receipt = ok(
      await stores.spend.broadcast(spend.signed(SignedPsbt(signed))),
    );
    expect(receipt.durable, isTrue);
    final transaction = decodeBitcoinPsbt(signed);
    onStore(
      (wallet) => wallet.applyUnconfirmedTxs(
        unconfirmedTxs: [
          bdk.UnconfirmedTx(
            tx: bdk.Transaction(transactionBytes: transaction.bytes),
            lastSeen: 2,
          ),
        ],
      ),
    );
    final gate = SpendGateStoreDatasource.openExisting(
      spendGateStorePath(dir.path),
    );
    try {
      gate.observed(descriptor, spend.revision.generation, {receipt.txid});
    } finally {
      gate.close();
    }

    // Thirty abandoned replacements, then their check.
    final bumps = [
      for (var i = 0; i < 30; i++)
        ok(
          await stores.spend.bump(
            key,
            await generation(),
            BumpFeeRequest(txid: receipt.txid, fee: SpendFeeRate(2000 + i)),
          ),
        ),
    ];
    final bumpChange = changeScript(bumps.first);
    for (final bump in bumps) {
      expect(bump.replacing, receipt.txid);
      expect(bump.inputs, transaction.inputs);
      expect(changeScript(bump), bumpChange);
    }
    expect(changeIndex(), 1);
    expect(sent, hasLength(1));
  });
}
