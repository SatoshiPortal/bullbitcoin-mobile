import 'dart:typed_data';

import 'package:rust_bindings/lwk.dart' as lwk;
import 'package:rust_bindings/testing.dart' show BullSdk, BullSdkApi;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';
import 'package:sync/src/data/codec/liquid_codec.dart'
    show liquidPsetAmountToAddress;

// The pinned LWK library is not built for unit tests: this fake stands in for
// the binding so the mapping and its refusals run without it. The real parser
// runs in native_test/liquid_codec_test.dart.
final class _Sdk implements BullSdkApi {
  lwk.LiquidTransaction? transaction;
  Object? error;
  lwk.LiquidNetwork network = lwk.LiquidNetwork.mainnet;
  var calls = 0;
  List<lwk.PsetOutput> outputs = [];

  lwk.LiquidTransaction _answer() {
    calls++;
    final error = this.error;
    if (error != null) throw error;
    return transaction ?? (throw StateError('No transaction scripted'));
  }

  @override
  lwk.LiquidTransaction lwkApiTransactionLiquidTransactionFromBytes({
    required List<int> txBytes,
  }) => _answer();

  @override
  lwk.PartiallySignedElementsTransaction
  lwkApiTransactionPartiallySignedElementsTransactionFromString({
    required String psetString,
  }) {
    calls++;
    final error = this.error;
    if (error != null) throw error;
    return _Pset(_answer, outputs);
  }

  @override
  Future<lwk.LiquidNetwork> lwkApiTypesAddressValidate({
    required String addressString,
  }) async {
    calls++;
    final error = this.error;
    if (error != null) throw error;
    return network;
  }

  @override
  Future<lwk.Address> lwkApiTypesAddressAddressFromScript({
    required lwk.LiquidNetwork network,
    required String script,
    String? blindingKey,
  }) async =>
      lwk.Address(standard: script, confidential: '$script-confidential');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

final class _Pset implements lwk.PartiallySignedElementsTransaction {
  final lwk.LiquidTransaction Function() _extract;
  final List<lwk.PsetOutput> outputs;
  _Pset(this._extract, this.outputs);

  @override
  List<lwk.PsetOutput> getOutputs() => outputs;

  @override
  lwk.LiquidTransaction extractTx() => _extract();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

final class _Transaction implements lwk.LiquidTransaction {
  @override
  String txid() => 'ab' * 32;
  @override
  int version() => 2;
  @override
  int lockTime() => 7;
  @override
  BigInt vsize() => BigInt.from(1200);
  @override
  BigInt weight() => BigInt.from(4800);
  @override
  BigInt fee() => BigInt.from(33);
  @override
  List<lwk.TxInput> getInputs() => const [
    lwk.TxInput(
      txid: 'cd',
      vout: 1,
      scriptSig: '',
      sequence: 0xfffffffd,
      witness: [],
      isPegin: false,
    ),
  ];
  @override
  List<lwk.TxOutput> getOutputs() => [
    // A confidential output: amount and asset blinded.
    const lwk.TxOutput(scriptPubkey: '0014aa'),
    lwk.TxOutput(scriptPubkey: '', asset: 'lbtc', value: BigInt.from(33)),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

T _ok<T>(Result<T, SyncFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw TestFailure('Unexpected ${failure.logCode}'),
};

SyncFailure _err<T>(Result<T, SyncFailure> result) => switch (result) {
  Ok() => throw TestFailure('Unexpected success'),
  Err(:final failure) => failure,
};

void main() {
  final sdk = _Sdk();
  setUpAll(() => BullSdk.initMock(api: sdk));
  tearDownAll(BullSdk.dispose);
  setUp(() {
    sdk
      ..transaction = _Transaction()
      ..error = null
      ..network = lwk.LiquidNetwork.mainnet
      ..calls = 0;
  });

  test('sums only policy outputs to the supplied destination', () async {
    sdk.outputs = [
      lwk.PsetOutput(
        scriptPubkey: 'destination',
        asset: 'lbtc',
        amount: BigInt.from(10),
      ),
      lwk.PsetOutput(
        scriptPubkey: 'destination',
        asset: 'lbtc',
        amount: BigInt.from(20),
      ),
      lwk.PsetOutput(
        scriptPubkey: 'other',
        asset: 'lbtc',
        amount: BigInt.from(80),
      ),
      lwk.PsetOutput(
        scriptPubkey: 'destination',
        asset: 'other-asset',
        amount: BigInt.from(100),
      ),
      lwk.PsetOutput(scriptPubkey: '', asset: 'lbtc', amount: BigInt.from(5)),
    ];
    Future<Result<BigInt, SyncFailure>> amount(String address) =>
        liquidPsetAmountToAddress(
          'test-pset',
          address,
          network: LiquidNetwork.mainnet,
          policyAsset: 'lbtc',
        );
    expect(_ok(await amount('destination')), BigInt.from(30));
    expect(_ok(await amount('destination-confidential')), BigInt.from(30));
    expect(_ok(await amount('absent')), BigInt.zero);
    sdk.outputs = [
      const lwk.PsetOutput(scriptPubkey: 'destination', asset: 'lbtc'),
    ];
    expect(
      _err(await amount('destination')),
      isA<SyncInvalidTransactionFailure>(),
    );
    sdk.outputs = [
      lwk.PsetOutput(scriptPubkey: 'destination', amount: BigInt.one),
    ];
    expect(
      _err(await amount('destination')),
      isA<SyncInvalidTransactionFailure>(),
    );
    sdk.network = lwk.LiquidNetwork.testnet;
    expect(_err(await amount('destination')), isA<SyncInvalidAddressFailure>());
  });

  void expectDecoded(DecodedLiquidTransaction decoded) {
    expect(decoded.txid, 'ab' * 32);
    expect(decoded.version, 2);
    expect(decoded.locktime, 7);
    expect(decoded.vsize, BigInt.from(1200));
    expect(decoded.weight, BigInt.from(4800));
    expect(decoded.feeSat, BigInt.from(33));
    expect(decoded.inputs.single.txid, 'cd');
    expect(decoded.inputs.single.vout, 1);
    expect(decoded.inputs.single.sequence, 0xfffffffd);
    expect(decoded.inputs.single.isPegin, isFalse);
    expect(decoded.outputs.first.scriptHex, '0014aa');
    expect(decoded.outputs.first.valueSat, isNull);
    expect(decoded.outputs.first.asset, isNull);
    expect(decoded.outputs.last.valueSat, BigInt.from(33));
    expect(decoded.outputs.last.asset, 'lbtc');
  }

  test('a transaction maps every field; a blinded amount stays unknown', () {
    expectDecoded(_ok(decodeLiquidTransaction([1, 2, 3])));
  });

  test('a PSET maps the transaction it describes', () {
    expectDecoded(_ok(decodeLiquidPset('cHNldP8=')));
  });

  test('a native refusal is an invalid transaction, without its text', () {
    sdk.error = const lwk.LwkError(msg: 'parse error at private.invalid');
    final failures = [
      _err(decodeLiquidTransaction([1])),
      _err(decodeLiquidPset('x')),
    ];
    expect(failures, everyElement(isA<SyncInvalidTransactionFailure>()));
  });

  test('empty or oversized input never reaches the parser', () {
    final failures = [
      _err(decodeLiquidTransaction(const [])),
      _err(decodeLiquidTransaction(Uint8List(maxLiquidTransactionBytes + 1))),
      _err(decodeLiquidPset('')),
      _err(decodeLiquidPset('A' * (maxEncodedLiquidPsetLength + 1))),
    ];
    expect(failures, everyElement(isA<SyncInvalidTransactionFailure>()));
    expect(sdk.calls, 0);
  });

  test('an address reports its Liquid network', () async {
    for (final (native, expected) in [
      (lwk.LiquidNetwork.mainnet, LiquidNetwork.mainnet),
      (lwk.LiquidNetwork.testnet, LiquidNetwork.testnet),
      (lwk.LiquidNetwork.regtest, LiquidNetwork.regtest),
    ]) {
      sdk.network = native;
      expect(_ok(await liquidAddressNetwork('address')), expected);
    }
  });

  test('an address LWK refuses is invalid', () async {
    sdk.error = const lwk.LwkError(msg: 'invalid address');
    expect(
      _err(await liquidAddressNetwork('address')),
      isA<SyncInvalidAddressFailure>(),
    );
  });
}
